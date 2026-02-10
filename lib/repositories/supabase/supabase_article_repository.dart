import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/article_alignment_pack.dart';
import '../../models/article_bundle.dart';
import '../../models/article_detail.dart';
import '../../models/article_localization.dart';
import '../../models/article_summary.dart';
import '../../models/topic_feed.dart';
import '../../models/vocab_models.dart';
import '../article_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseArticleRepository implements ArticleRepository {
  const SupabaseArticleRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<ArticleDetail?> getArticleDetailBySlug(String slug) async {
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('articles')
          .select('*, profiles:author_id(display_name, city, country_code)')
          .eq('slug', slug)
          .eq('is_published', true)
          .maybeSingle();
    } on PostgrestException {
      row = await _client
          .from('articles')
          .select('*')
          .eq('slug', slug)
          .eq('is_published', true)
          .maybeSingle();
    }

    if (row == null) {
      return null;
    }

    return _mapDetail(row);
  }

  @override
  Future<ArticleBundle?> getArticleBundleBySlug(
    String slug,
    String topLang,
    String bottomLang,
    String uiLang,
  ) async {
    final articleRow = await _client
        .from('articles')
        .select('*')
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();

    if (articleRow == null) {
      return null;
    }

    final articleId = SupabaseMappingUtils.stringValue(articleRow, const [
      'id',
    ], fallback: slug);
    final canonicalLang = SupabaseMappingUtils.stringValue(articleRow, const [
      'canonical_lang',
      'canonical_language',
      'language_top',
    ], fallback: topLang);
    final canonicalLocalizationId = SupabaseMappingUtils.stringValue(
      articleRow,
      const ['canonical_localization_id'],
    );

    final localizationRows = await _client
        .from('article_localizations')
        .select('''
          id,
          article_id,
          lang,
          title,
          excerpt,
          body,
          content_hash,
          version,
          created_at
        ''')
        .eq('article_id', articleId)
        .inFilter('lang', [canonicalLang, topLang, bottomLang]);

    final localizations = localizationRows
        .map<ArticleLocalization>(
          (dynamic row) => _mapLocalization(row as Map<String, dynamic>),
        )
        .toList();

    if (localizations.isEmpty) {
      final fallbackTopLang = SupabaseMappingUtils.stringValue(
        articleRow,
        const ['language_top'],
        fallback: canonicalLang,
      );
      final fallbackBottomLang = SupabaseMappingUtils.stringValue(
        articleRow,
        const ['language_bottom'],
        fallback: bottomLang,
      );
      localizations.addAll([
        _fallbackLocalization(
          articleRow,
          articleId: articleId,
          lang: fallbackTopLang,
          bodyKey: 'body_top',
          fallbackBody: 'content',
          suffix: 'top',
        ),
        _fallbackLocalization(
          articleRow,
          articleId: articleId,
          lang: fallbackBottomLang,
          bodyKey: 'body_bottom',
          fallbackBody: 'content',
          suffix: 'bottom',
        ),
      ]);
    }

    final ArticleLocalization canonicalLocalization =
        canonicalLocalizationId.isNotEmpty
        ? localizations.firstWhere(
            (item) => item.id == canonicalLocalizationId,
            orElse: () => localizations.first,
          )
        : localizations.firstWhere(
            (item) => item.lang == canonicalLang,
            orElse: () => localizations.first,
          );

    final topLocalization = _pickLocalization(
      localizations,
      lang: topLang,
      fallback: canonicalLocalization,
    );
    final bottomLocalization = _pickLocalization(
      localizations,
      lang: bottomLang,
      fallback: canonicalLocalization,
    );

    final alignmentRows = await _client
        .from('article_alignments')
        .select('''
          id,
          article_id,
          from_localization_id,
          to_localization_id,
          alignment_json,
          algo_version,
          quality_score
        ''')
        .eq('article_id', articleId)
        .eq('from_localization_id', canonicalLocalization.id)
        .inFilter('to_localization_id', [
          topLocalization.id,
          bottomLocalization.id,
        ]);

    ArticleAlignmentPack? alignmentToTop;
    ArticleAlignmentPack? alignmentToBottom;
    for (final dynamic row in alignmentRows) {
      final pack = _mapAlignment(row as Map<String, dynamic>);
      if (pack.toLocalizationId == topLocalization.id) {
        alignmentToTop = pack;
      }
      if (pack.toLocalizationId == bottomLocalization.id) {
        alignmentToBottom = pack;
      }
    }

    final focusRows = await _client
        .from('article_focus_vocab')
        .select('''
          article_id,
          rank,
          vocab_items:vocab_item_id(
            id,
            canonical_lang,
            canonical_lemma,
            pos,
            difficulty,
            created_at,
            vocab_entries(
              id,
              vocab_item_id,
              lang,
              primary_definition,
              usage_notes,
              examples,
              tags,
              updated_at,
              updated_by,
              source
            ),
            vocab_forms(
              id,
              vocab_item_id,
              lang,
              lemma,
              surface,
              notes
            )
          )
        ''')
        .eq('article_id', articleId)
        .order('rank', ascending: true);

    final focusItems = focusRows
        .map<FocusVocabItem>(
          (dynamic row) => _mapFocusItem(
            row as Map<String, dynamic>,
            uiLang: uiLang,
            topLang: topLang,
            bottomLang: bottomLang,
          ),
        )
        .where((item) => item.item.id.isNotEmpty)
        .toList();

    return ArticleBundle(
      articleId: articleId,
      slug: slug,
      canonicalLang: canonicalLang,
      canonicalLocalization: canonicalLocalization,
      topLocalization: topLocalization,
      bottomLocalization: bottomLocalization,
      alignmentToTop: alignmentToTop,
      alignmentToBottom: alignmentToBottom,
      focusVocab: ArticleFocusVocab(articleId: articleId, items: focusItems),
    );
  }

  @override
  Future<TopicFeed> getTopicFeed(String topicOrCountryCode) async {
    final key = topicOrCountryCode.trim();
    final upperCode = key.toUpperCase();
    final lowerKey = key.toLowerCase();

    final allRows = await _client
        .from('articles')
        .select('*')
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(100);

    final merged = <String, ArticleSummary>{};
    for (final dynamic row in allRows) {
      final map = row as Map<String, dynamic>;
      if (!_matchesTopicOrCountry(
        map,
        lowerKey: lowerKey,
        upperCode: upperCode,
      )) {
        continue;
      }
      final summary = _mapSummary(map);
      merged[summary.id] = summary;
    }

    if (merged.isEmpty) {
      for (final dynamic row in allRows.take(20)) {
        final map = row as Map<String, dynamic>;
        final summary = _mapSummary(map);
        merged[summary.id] = summary;
      }
    }

    return TopicFeed(
      code: upperCode,
      displayName: key,
      stories: merged.values.toList(),
    );
  }

  @override
  Future<List<ArticleSummary>> getTopStories() async {
    final rows = await _client
        .from('articles')
        .select('*')
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(25);

    return rows
        .map<ArticleSummary>(
          (dynamic row) => _mapSummary(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> collectFocusVocab({
    required String articleId,
    required List<FocusVocabItem> items,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in required to collect words.');
    }

    final vocabItemIds = items
        .map((item) => item.item.id)
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();
    if (vocabItemIds.isEmpty) {
      return;
    }

    try {
      final now = DateTime.now();
      final eventRows = vocabItemIds
          .map(
            (vocabItemId) => <String, dynamic>{
              'user_id': userId,
              'vocab_item_id': vocabItemId,
              'article_id': articleId,
              'event_type': 'collect',
              'occurred_at': now.toIso8601String(),
              'meta_json': {'source': 'article_collect_words'},
            },
          )
          .toList();
      await _client.from('user_vocab_events').insert(eventRows);

      final existingRows = await _client
          .from('user_vocab_progress')
          .select('vocab_item_id,xp')
          .eq('user_id', userId)
          .inFilter('vocab_item_id', vocabItemIds);
      final existingXpByItemId = <String, int>{};
      for (final dynamic row in existingRows) {
        final map = row as Map<String, dynamic>;
        final vocabItemId = SupabaseMappingUtils.stringValue(map, const [
          'vocab_item_id',
        ]);
        if (vocabItemId.isEmpty) {
          continue;
        }
        existingXpByItemId[vocabItemId] = SupabaseMappingUtils.intValue(
          map,
          const ['xp'],
          fallback: 0,
        );
      }

      final progressRows = vocabItemIds.map((vocabItemId) {
        final nextXp = (existingXpByItemId[vocabItemId] ?? 0) + 10;
        return <String, dynamic>{
          'user_id': userId,
          'vocab_item_id': vocabItemId,
          'xp': nextXp,
          'level': _vocabLevelForXp(nextXp),
          'last_seen_at': now.toIso8601String(),
          'next_review_at': now.add(const Duration(days: 3)).toIso8601String(),
        };
      }).toList();
      await _client
          .from('user_vocab_progress')
          .upsert(progressRows, onConflict: 'user_id,vocab_item_id');
    } on PostgrestException catch (error) {
      throw StateError('Could not collect words: ${error.message}');
    }
  }

  ArticleSummary _mapSummary(Map<String, dynamic> row) {
    final topic = _topicLabel(row);
    final countryCode = _countryCodeLabel(row);
    final publishedAt = SupabaseMappingUtils.dateTimeValue(row, const [
      'published_at',
      'created_at',
    ]);

    return ArticleSummary(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      slug: SupabaseMappingUtils.stringValue(row, const ['slug'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Untitled story'),
      topic: topic,
      countryCode: countryCode,
      readTimeMinutes: SupabaseMappingUtils.intValue(row, const [
        'read_time_minutes',
        'read_time',
      ], fallback: 4),
      publishedAtLabel: SupabaseMappingUtils.upperDateLabel(
        publishedAt,
        fallback: 'RECENT',
      ),
      isPremium: SupabaseMappingUtils.boolValue(row, const [
        'is_premium',
      ], fallback: false),
    );
  }

  ArticleDetail _mapDetail(Map<String, dynamic> row) {
    final profile = row['profiles'];
    final profileMap = profile is Map<String, dynamic> ? profile : null;
    final profileName = SupabaseMappingUtils.stringValue(
      profileMap ?? const {},
      const ['display_name'],
    );
    final profileCity = SupabaseMappingUtils.stringValue(
      profileMap ?? const {},
      const ['city'],
    );
    final profileCountry = SupabaseMappingUtils.stringValue(
      profileMap ?? const {},
      const ['country_code'],
    );
    final authoredLocation = profileCity.isEmpty
        ? profileCountry
        : [
            profileCity,
            profileCountry,
          ].where((item) => item.isNotEmpty).join(', ');
    final publishedAt = SupabaseMappingUtils.dateTimeValue(row, const [
      'published_at',
      'created_at',
    ]);

    return ArticleDetail(
      slug: SupabaseMappingUtils.stringValue(row, const ['slug'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Untitled story'),
      byline: SupabaseMappingUtils.stringValue(row, const [
        'byline',
      ], fallback: 'Editorial team'),
      date: SupabaseMappingUtils.upperDateLabel(
        publishedAt,
        fallback: 'RECENT',
      ),
      imageAsset: SupabaseMappingUtils.stringValue(row, const [
        'hero_image_url',
        'image_asset',
      ], fallback: 'assets/images/placeholder.jpg'),
      topic: _topicLabel(row),
      excerpt: SupabaseMappingUtils.stringValue(row, const [
        'excerpt',
      ], fallback: ''),
      readTime:
          '${SupabaseMappingUtils.intValue(row, const ['read_time_minutes', 'read_time'], fallback: 4)} min read',
      authorName: SupabaseMappingUtils.stringValue(row, const [
        'author_name',
      ], fallback: profileName.isEmpty ? 'nEUws Creator' : profileName),
      authorLocation: SupabaseMappingUtils.stringValue(row, const [
        'author_location',
      ], fallback: authoredLocation.isEmpty ? 'Europe' : authoredLocation),
      languageTop: SupabaseMappingUtils.stringValue(row, const [
        'language_top',
      ], fallback: 'English'),
      languageBottom: SupabaseMappingUtils.stringValue(row, const [
        'language_bottom',
      ], fallback: 'English'),
      bodyTop: SupabaseMappingUtils.stringValue(row, const [
        'body_top',
        'content',
      ], fallback: ''),
      bodyBottom: SupabaseMappingUtils.stringValue(row, const [
        'body_bottom',
        'content',
      ], fallback: ''),
    );
  }

  ArticleLocalization _mapLocalization(Map<String, dynamic> row) {
    return ArticleLocalization(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      articleId: SupabaseMappingUtils.stringValue(row, const [
        'article_id',
      ], fallback: ''),
      lang: SupabaseMappingUtils.stringValue(row, const ['lang'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: ''),
      excerpt: SupabaseMappingUtils.stringValue(row, const [
        'excerpt',
      ], fallback: ''),
      body: SupabaseMappingUtils.stringValue(row, const ['body'], fallback: ''),
      contentHash: SupabaseMappingUtils.stringValue(row, const [
        'content_hash',
      ], fallback: ''),
      version: SupabaseMappingUtils.intValue(row, const [
        'version',
      ], fallback: 1),
      createdAt: SupabaseMappingUtils.dateTimeValue(row, const ['created_at']),
    );
  }

  ArticleLocalization _fallbackLocalization(
    Map<String, dynamic> articleRow, {
    required String articleId,
    required String lang,
    required String bodyKey,
    required String fallbackBody,
    required String suffix,
  }) {
    final body = SupabaseMappingUtils.stringValue(articleRow, [
      bodyKey,
      fallbackBody,
    ], fallback: '');
    return ArticleLocalization(
      id: '$articleId-$suffix',
      articleId: articleId,
      lang: lang,
      title: SupabaseMappingUtils.stringValue(articleRow, const [
        'title',
      ], fallback: ''),
      excerpt: SupabaseMappingUtils.stringValue(articleRow, const [
        'excerpt',
      ], fallback: ''),
      body: body,
      contentHash: '',
      version: 1,
      createdAt: SupabaseMappingUtils.dateTimeValue(articleRow, const [
        'created_at',
      ]),
    );
  }

  ArticleAlignmentPack _mapAlignment(Map<String, dynamic> row) {
    return ArticleAlignmentPack(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      articleId: SupabaseMappingUtils.stringValue(row, const [
        'article_id',
      ], fallback: ''),
      fromLocalizationId: SupabaseMappingUtils.stringValue(row, const [
        'from_localization_id',
      ], fallback: ''),
      toLocalizationId: SupabaseMappingUtils.stringValue(row, const [
        'to_localization_id',
      ], fallback: ''),
      alignmentJson: row['alignment_json'],
      algoVersion: SupabaseMappingUtils.stringValue(row, const [
        'algo_version',
      ], fallback: ''),
      qualityScore: (row['quality_score'] as num?)?.toDouble(),
    );
  }

  ArticleLocalization _pickLocalization(
    List<ArticleLocalization> localizations, {
    required String lang,
    required ArticleLocalization fallback,
  }) {
    return localizations.firstWhere(
      (item) => item.lang == lang,
      orElse: () => fallback,
    );
  }

  FocusVocabItem _mapFocusItem(
    Map<String, dynamic> row, {
    required String uiLang,
    required String topLang,
    required String bottomLang,
  }) {
    final vocabMap = row['vocab_items'];
    if (vocabMap is! Map<String, dynamic>) {
      return FocusVocabItem(
        rank: SupabaseMappingUtils.intValue(row, const ['rank'], fallback: 1),
        item: const VocabItem(
          id: '',
          canonicalLang: '',
          canonicalLemma: '',
          pos: '',
          difficulty: '',
          createdAt: null,
        ),
        entry: null,
        forms: const [],
      );
    }

    final vocabItem = VocabItem(
      id: SupabaseMappingUtils.stringValue(vocabMap, const [
        'id',
      ], fallback: ''),
      canonicalLang: SupabaseMappingUtils.stringValue(vocabMap, const [
        'canonical_lang',
      ], fallback: ''),
      canonicalLemma: SupabaseMappingUtils.stringValue(vocabMap, const [
        'canonical_lemma',
      ], fallback: ''),
      pos: SupabaseMappingUtils.stringValue(vocabMap, const [
        'pos',
      ], fallback: ''),
      difficulty: SupabaseMappingUtils.stringValue(vocabMap, const [
        'difficulty',
      ], fallback: ''),
      createdAt: SupabaseMappingUtils.dateTimeValue(vocabMap, const [
        'created_at',
      ]),
    );

    final entry = _pickEntryForLang(vocabMap['vocab_entries'], uiLang);
    final forms = _pickFormsForLangs(
      vocabMap['vocab_forms'],
      langs: [topLang, bottomLang],
    );

    return FocusVocabItem(
      rank: SupabaseMappingUtils.intValue(row, const ['rank'], fallback: 1),
      item: vocabItem,
      entry: entry,
      forms: forms,
    );
  }

  VocabEntry? _pickEntryForLang(dynamic rawEntries, String uiLang) {
    if (rawEntries is! List) {
      return null;
    }
    for (final dynamic entryRow in rawEntries) {
      final entryMap = entryRow as Map<String, dynamic>;
      if (SupabaseMappingUtils.stringValue(entryMap, const ['lang']) ==
          uiLang) {
        return _mapVocabEntry(entryMap);
      }
    }
    if (rawEntries.isNotEmpty) {
      return _mapVocabEntry(rawEntries.first as Map<String, dynamic>);
    }
    return null;
  }

  List<VocabForm> _pickFormsForLangs(
    dynamic rawForms, {
    required List<String> langs,
  }) {
    if (rawForms is! List) {
      return const [];
    }
    final forms = rawForms
        .map(
          (dynamic formRow) => _mapVocabForm(formRow as Map<String, dynamic>),
        )
        .toList();
    return forms.where((form) => langs.contains(form.lang)).toList();
  }

  VocabEntry _mapVocabEntry(Map<String, dynamic> row) {
    final examples = row['examples'];
    final tags = row['tags'];
    return VocabEntry(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      vocabItemId: SupabaseMappingUtils.stringValue(row, const [
        'vocab_item_id',
      ], fallback: ''),
      lang: SupabaseMappingUtils.stringValue(row, const ['lang'], fallback: ''),
      primaryDefinition: SupabaseMappingUtils.stringValue(row, const [
        'primary_definition',
      ], fallback: ''),
      usageNotes: SupabaseMappingUtils.stringValue(row, const [
        'usage_notes',
      ], fallback: ''),
      examples: examples is List
          ? examples.whereType<String>().toList()
          : const [],
      tags: tags is List ? tags.whereType<String>().toList() : const [],
      updatedAt: SupabaseMappingUtils.dateTimeValue(row, const ['updated_at']),
      updatedBy: SupabaseMappingUtils.stringValue(row, const [
        'updated_by',
      ], fallback: ''),
      source: SupabaseMappingUtils.stringValue(row, const [
        'source',
      ], fallback: ''),
    );
  }

  VocabForm _mapVocabForm(Map<String, dynamic> row) {
    return VocabForm(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      vocabItemId: SupabaseMappingUtils.stringValue(row, const [
        'vocab_item_id',
      ], fallback: ''),
      lang: SupabaseMappingUtils.stringValue(row, const ['lang'], fallback: ''),
      lemma: SupabaseMappingUtils.stringValue(row, const [
        'lemma',
      ], fallback: ''),
      surface: SupabaseMappingUtils.stringValue(row, const [
        'surface',
      ], fallback: ''),
      notes: SupabaseMappingUtils.stringValue(row, const [
        'notes',
      ], fallback: ''),
    );
  }

  String _countryCodeLabel(Map<String, dynamic> row) {
    final one = SupabaseMappingUtils.stringValue(row, const ['country_code']);
    final tags = row['country_tags'];
    if (tags is List) {
      final cleaned = tags
          .whereType<String>()
          .map((item) => item.trim().toUpperCase())
          .where((item) => item.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) {
        return cleaned.join(',');
      }
    }
    if (one.isNotEmpty) {
      return one.toUpperCase();
    }
    return 'EU';
  }

  String _topicLabel(Map<String, dynamic> row) {
    final topic = SupabaseMappingUtils.stringValue(row, const [
      'topic',
      'category',
    ]);
    if (topic.isNotEmpty) {
      return topic;
    }
    final topics = row['topics'];
    if (topics is List) {
      for (final dynamic item in topics) {
        final text = '$item'.trim();
        if (text.isNotEmpty) {
          return text;
        }
      }
    }
    return 'General';
  }

  bool _matchesTopicOrCountry(
    Map<String, dynamic> row, {
    required String lowerKey,
    required String upperCode,
  }) {
    final topic = _topicLabel(row).toLowerCase();
    final category = SupabaseMappingUtils.stringValue(row, const [
      'category',
    ]).toLowerCase();
    if (topic.contains(lowerKey) || category.contains(lowerKey)) {
      return true;
    }

    final countryCode = SupabaseMappingUtils.stringValue(row, const [
      'country_code',
    ]).toUpperCase();
    if (countryCode == upperCode) {
      return true;
    }
    final tags = row['country_tags'];
    if (tags is List) {
      for (final dynamic tag in tags) {
        if ('$tag'.trim().toUpperCase() == upperCode) {
          return true;
        }
      }
    }
    return false;
  }

  String _vocabLevelForXp(int xp) {
    if (xp >= 120) {
      return 'gold';
    }
    if (xp >= 60) {
      return 'silver';
    }
    return 'bronze';
  }
}

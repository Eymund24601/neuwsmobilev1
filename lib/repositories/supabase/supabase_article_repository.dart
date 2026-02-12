import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/article_alignment_pack.dart';
import '../../models/article_bundle.dart';
import '../../models/article_detail.dart';
import '../../models/article_localization.dart';
import '../../models/article_summary.dart';
import '../../models/article_token_graph.dart';
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
    final tokenPayload = await _loadTokenPayload(
      articleId: articleId,
      canonicalLocalization: canonicalLocalization,
      topLocalization: topLocalization,
      bottomLocalization: bottomLocalization,
    );

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
      canonicalTokens: tokenPayload.canonicalTokens,
      topTokens: tokenPayload.topTokens,
      bottomTokens: tokenPayload.bottomTokens,
      tokenAlignmentsToTop: tokenPayload.tokenAlignmentsToTop,
      tokenAlignmentsToBottom: tokenPayload.tokenAlignmentsToBottom,
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
        .limit(100);

    return rows
        .map<ArticleSummary>(
          (dynamic row) => _mapSummary(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<List<ArticleDetail>> getRecentArticleDetails({int limit = 100}) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('articles')
          .select('*, profiles:author_id(display_name, city, country_code)')
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit);
    } on PostgrestException {
      rows = await _client
          .from('articles')
          .select('*')
          .eq('is_published', true)
          .order('published_at', ascending: false)
          .limit(limit);
    }

    return rows
        .map<ArticleDetail>(
          (dynamic row) => _mapDetail(row as Map<String, dynamic>),
        )
        .where((detail) => detail.slug.isNotEmpty)
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

  Future<_BundleTokenPayload> _loadTokenPayload({
    required String articleId,
    required ArticleLocalization canonicalLocalization,
    required ArticleLocalization topLocalization,
    required ArticleLocalization bottomLocalization,
  }) async {
    final localizationIds = <String>{
      canonicalLocalization.id,
      topLocalization.id,
      bottomLocalization.id,
    }.where((id) => id.isNotEmpty).toList();
    if (localizationIds.isEmpty) {
      return const _BundleTokenPayload();
    }

    final tokensByLocalizationId = <String, List<ArticleLocalizationToken>>{};
    try {
      final tokenRows = await _client
          .from('article_localization_tokens')
          .select('''
            id,
            article_id,
            localization_id,
            token_index,
            start_utf16,
            end_utf16,
            surface,
            normalized_surface,
            links:article_token_vocab_links!left(
              vocab_item_id,
              candidate_rank,
              is_primary,
              match_type,
              confidence,
              link_source
            )
          ''')
          .eq('article_id', articleId)
          .inFilter('localization_id', localizationIds)
          .order('token_index', ascending: true);

      for (final dynamic row in tokenRows) {
        final token = _mapLocalizationTokenRow(row as Map<String, dynamic>);
        tokensByLocalizationId
            .putIfAbsent(
              token.localizationId,
              () => <ArticleLocalizationToken>[],
            )
            .add(token);
      }
    } on PostgrestException {
      return const _BundleTokenPayload();
    }

    for (final list in tokensByLocalizationId.values) {
      list.sort((a, b) => a.tokenIndex.compareTo(b.tokenIndex));
    }

    final targetLocalizationIds = <String>{
      if (topLocalization.id != canonicalLocalization.id) topLocalization.id,
      if (bottomLocalization.id != canonicalLocalization.id)
        bottomLocalization.id,
    }.where((id) => id.isNotEmpty).toList();
    final tokenAlignments = <ArticleTokenAlignment>[];
    if (targetLocalizationIds.isNotEmpty) {
      try {
        final alignmentRows = await _client
            .from('article_token_alignments')
            .select('''
              canonical_token_id,
              target_localization_id,
              target_token_id,
              score,
              algo_version
            ''')
            .eq('article_id', articleId)
            .inFilter('target_localization_id', targetLocalizationIds);
        tokenAlignments.addAll(
          alignmentRows.map<ArticleTokenAlignment>(
            (dynamic row) => _mapTokenAlignmentRow(row as Map<String, dynamic>),
          ),
        );
      } on PostgrestException {
        // Optional token alignment table should not block article reading.
      }
    }

    final canonicalTokens =
        tokensByLocalizationId[canonicalLocalization.id] ?? const [];
    final topTokens = topLocalization.id == canonicalLocalization.id
        ? canonicalTokens
        : (tokensByLocalizationId[topLocalization.id] ?? const []);
    final bottomTokens = bottomLocalization.id == canonicalLocalization.id
        ? canonicalTokens
        : (tokensByLocalizationId[bottomLocalization.id] ?? const []);
    final tokenAlignmentsToTop = topLocalization.id == canonicalLocalization.id
        ? const <ArticleTokenAlignment>[]
        : tokenAlignments
              .where((item) => item.targetLocalizationId == topLocalization.id)
              .toList();
    final tokenAlignmentsToBottom =
        bottomLocalization.id == canonicalLocalization.id
        ? const <ArticleTokenAlignment>[]
        : tokenAlignments
              .where(
                (item) => item.targetLocalizationId == bottomLocalization.id,
              )
              .toList();

    return _BundleTokenPayload(
      canonicalTokens: canonicalTokens,
      topTokens: topTokens,
      bottomTokens: bottomTokens,
      tokenAlignmentsToTop: tokenAlignmentsToTop,
      tokenAlignmentsToBottom: tokenAlignmentsToBottom,
    );
  }

  ArticleLocalizationToken _mapLocalizationTokenRow(Map<String, dynamic> row) {
    final primaryLink = _pickPrimaryTokenLink(row['links']);
    return ArticleLocalizationToken(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      articleId: SupabaseMappingUtils.stringValue(row, const [
        'article_id',
      ], fallback: ''),
      localizationId: SupabaseMappingUtils.stringValue(row, const [
        'localization_id',
      ], fallback: ''),
      tokenIndex: SupabaseMappingUtils.intValue(row, const [
        'token_index',
      ], fallback: 0),
      startUtf16: SupabaseMappingUtils.intValue(row, const [
        'start_utf16',
      ], fallback: 0),
      endUtf16: SupabaseMappingUtils.intValue(row, const [
        'end_utf16',
      ], fallback: 0),
      surface: SupabaseMappingUtils.stringValue(row, const [
        'surface',
      ], fallback: ''),
      normalizedSurface: SupabaseMappingUtils.stringValue(row, const [
        'normalized_surface',
      ], fallback: ''),
      primaryVocabItemId: SupabaseMappingUtils.stringValue(primaryLink, const [
        'vocab_item_id',
      ], fallback: ''),
      primaryCandidateRank: primaryLink.containsKey('candidate_rank')
          ? SupabaseMappingUtils.intValue(primaryLink, const [
              'candidate_rank',
            ], fallback: 1)
          : null,
      primaryMatchType: SupabaseMappingUtils.stringValue(primaryLink, const [
        'match_type',
      ], fallback: ''),
      primaryConfidence: (primaryLink['confidence'] as num?)?.toDouble(),
      primaryLinkSource: SupabaseMappingUtils.stringValue(primaryLink, const [
        'link_source',
      ], fallback: ''),
    );
  }

  ArticleTokenAlignment _mapTokenAlignmentRow(Map<String, dynamic> row) {
    return ArticleTokenAlignment(
      canonicalTokenId: SupabaseMappingUtils.stringValue(row, const [
        'canonical_token_id',
      ], fallback: ''),
      targetLocalizationId: SupabaseMappingUtils.stringValue(row, const [
        'target_localization_id',
      ], fallback: ''),
      targetTokenId: SupabaseMappingUtils.stringValue(row, const [
        'target_token_id',
      ], fallback: ''),
      score: (row['score'] as num?)?.toDouble(),
      algoVersion: SupabaseMappingUtils.stringValue(row, const [
        'algo_version',
      ], fallback: ''),
    );
  }

  Map<String, dynamic> _pickPrimaryTokenLink(dynamic rawLinks) {
    if (rawLinks is! List) {
      return const <String, dynamic>{};
    }

    Map<String, dynamic>? fallback;
    for (final dynamic raw in rawLinks) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final rank = SupabaseMappingUtils.intValue(raw, const ['candidate_rank']);
      if (fallback == null ||
          rank <
              SupabaseMappingUtils.intValue(fallback, const [
                'candidate_rank',
              ], fallback: 1 << 30)) {
        fallback = raw;
      }
      if (SupabaseMappingUtils.boolValue(raw, const ['is_primary'])) {
        return raw;
      }
    }
    return fallback ?? const <String, dynamic>{};
  }

  ArticleLocalization _pickLocalization(
    List<ArticleLocalization> localizations, {
    required String lang,
    required ArticleLocalization fallback,
  }) {
    final langCandidates = _languageCandidates(lang);
    return localizations.firstWhere(
      (item) => _matchesLanguage(item.lang, langCandidates),
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
    final uiCandidates = _languageCandidates(uiLang);
    for (final dynamic entryRow in rawEntries) {
      final entryMap = entryRow as Map<String, dynamic>;
      final entryLang = SupabaseMappingUtils.stringValue(entryMap, const [
        'lang',
      ]);
      if (_matchesLanguage(entryLang, uiCandidates)) {
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
    final langCandidates = langs
        .expand(_languageCandidates)
        .map((item) => item.trim().toLowerCase())
        .toSet();
    final forms = rawForms
        .map(
          (dynamic formRow) => _mapVocabForm(formRow as Map<String, dynamic>),
        )
        .toList();
    final picked = forms
        .where((form) => _matchesLanguage(form.lang, langCandidates))
        .toList();
    if (picked.isNotEmpty) {
      return picked;
    }
    return forms;
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

  bool _matchesLanguage(String value, Set<String> candidates) {
    if (candidates.isEmpty) {
      return false;
    }
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    if (candidates.contains(normalized)) {
      return true;
    }
    final mappedCode = _languageAliasToCode[normalized];
    if (mappedCode != null && candidates.contains(mappedCode)) {
      return true;
    }
    final mappedAlias = _languageCodeToAlias[normalized];
    if (mappedAlias != null && candidates.contains(mappedAlias)) {
      return true;
    }
    return false;
  }

  Set<String> _languageCandidates(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const <String>{};
    }
    final out = <String>{normalized};
    final mappedCode = _languageAliasToCode[normalized];
    if (mappedCode != null) {
      out.add(mappedCode);
    }
    final mappedAlias = _languageCodeToAlias[normalized];
    if (mappedAlias != null) {
      out.add(mappedAlias);
    }
    return out;
  }

  static const Map<String, String> _languageAliasToCode = {
    'english': 'en',
    'french': 'fr',
    'german': 'de',
    'swedish': 'sv',
    'spanish': 'es',
    'italian': 'it',
    'portuguese': 'pt',
  };

  static const Map<String, String> _languageCodeToAlias = {
    'en': 'english',
    'fr': 'french',
    'de': 'german',
    'sv': 'swedish',
    'es': 'spanish',
    'it': 'italian',
    'pt': 'portuguese',
  };
}

class _BundleTokenPayload {
  const _BundleTokenPayload({
    this.canonicalTokens = const <ArticleLocalizationToken>[],
    this.topTokens = const <ArticleLocalizationToken>[],
    this.bottomTokens = const <ArticleLocalizationToken>[],
    this.tokenAlignmentsToTop = const <ArticleTokenAlignment>[],
    this.tokenAlignmentsToBottom = const <ArticleTokenAlignment>[],
  });

  final List<ArticleLocalizationToken> canonicalTokens;
  final List<ArticleLocalizationToken> topTokens;
  final List<ArticleLocalizationToken> bottomTokens;
  final List<ArticleTokenAlignment> tokenAlignmentsToTop;
  final List<ArticleTokenAlignment> tokenAlignmentsToBottom;
}

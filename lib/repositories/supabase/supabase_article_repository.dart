import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/article_detail.dart';
import '../../models/article_summary.dart';
import '../../models/topic_feed.dart';
import '../article_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseArticleRepository implements ArticleRepository {
  const SupabaseArticleRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<ArticleDetail?> getArticleDetailBySlug(String slug) async {
    final row = await _client
        .from('articles')
        .select('''
          id,
          slug,
          title,
          content,
          excerpt,
          topic,
          category,
          country_code,
          country_tags,
          read_time_minutes,
          read_time,
          image_asset,
          hero_image_url,
          language_top,
          language_bottom,
          body_top,
          body_bottom,
          published_at,
          created_at,
          author_name,
          author_location,
          byline,
          profiles:author_id(display_name, city, country_code)
          ''')
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();

    if (row == null) {
      return null;
    }

    return _mapDetail(row);
  }

  @override
  Future<TopicFeed> getTopicFeed(String topicOrCountryCode) async {
    final key = topicOrCountryCode.trim();
    final upperCode = key.toUpperCase();
    final lowerKey = key.toLowerCase();

    final topicRows = await _client
        .from('articles')
        .select(_summarySelect)
        .eq('is_published', true)
        .or('topic.ilike.%$lowerKey%,category.ilike.%$lowerKey%')
        .order('published_at', ascending: false)
        .limit(20);

    final countryRows = await _client
        .from('articles')
        .select(_summarySelect)
        .eq('is_published', true)
        .or('country_code.eq.$upperCode,country_tags.cs.{$upperCode}')
        .order('published_at', ascending: false)
        .limit(20);

    final merged = <String, ArticleSummary>{};
    for (final dynamic row in [...topicRows, ...countryRows]) {
      final map = row as Map<String, dynamic>;
      final summary = _mapSummary(map);
      merged[summary.id] = summary;
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
        .select(_summarySelect)
        .eq('is_published', true)
        .order('published_at', ascending: false)
        .limit(25);

    return rows
        .map<ArticleSummary>(
          (dynamic row) => _mapSummary(row as Map<String, dynamic>),
        )
        .toList();
  }

  static const _summarySelect = '''
      id,
      slug,
      title,
      topic,
      category,
      country_code,
      country_tags,
      read_time_minutes,
      read_time,
      published_at,
      created_at,
      is_premium
    ''';

  ArticleSummary _mapSummary(Map<String, dynamic> row) {
    final topic = SupabaseMappingUtils.stringValue(row, const [
      'topic',
      'category',
    ], fallback: 'General');
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
      topic: SupabaseMappingUtils.stringValue(row, const [
        'topic',
        'category',
      ], fallback: 'General'),
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
}

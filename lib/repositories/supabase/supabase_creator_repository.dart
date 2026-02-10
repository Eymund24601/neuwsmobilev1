import 'package:supabase_flutter/supabase_flutter.dart';

import '../creator_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseCreatorRepository implements CreatorRepository {
  const SupabaseCreatorRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<CreatorStudioSnapshot> getStudioSnapshot() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      return const CreatorStudioSnapshot(
        drafts: 0,
        publishedThisMonth: 0,
        estimatedEarnings: 'EUR 0',
      );
    }

    Map<String, dynamic>? profileRow;
    try {
      profileRow = await _client
          .from('profiles')
          .select('estimated_earnings')
          .eq('id', authUser.id)
          .maybeSingle();
    } on PostgrestException {
      // Compatibility fallback for environments that do not have
      // profiles.estimated_earnings yet.
      profileRow = await _client
          .from('profiles')
          .select('id')
          .eq('id', authUser.id)
          .maybeSingle();
    }

    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
    final nextMonth = DateTime(now.year, now.month + 1, 1).toIso8601String();

    final draftsRows = await _client
        .from('articles')
        .select('id')
        .eq('author_id', authUser.id)
        .eq('is_published', false);
    final publishedRows = await _client
        .from('articles')
        .select('id')
        .eq('author_id', authUser.id)
        .eq('is_published', true)
        .gte('published_at', monthStart)
        .lt('published_at', nextMonth);

    final earningsRaw = profileRow == null
        ? ''
        : SupabaseMappingUtils.stringValue(profileRow, const [
            'estimated_earnings',
          ]);

    return CreatorStudioSnapshot(
      drafts: draftsRows.length,
      publishedThisMonth: publishedRows.length,
      estimatedEarnings: earningsRaw.isEmpty ? 'EUR 0' : earningsRaw,
    );
  }

  @override
  Future<void> saveDraft({
    required String headline,
    required String topic,
    required String body,
  }) async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('Sign in required to save drafts.');
    }

    final now = DateTime.now();
    final slugBase = headline.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '-',
    );
    final slug =
        '${slugBase.replaceAll(RegExp(r'^-|-$'), '')}-${now.millisecondsSinceEpoch}';
    final excerpt = body.trim().replaceAll('\n', ' ');
    final safeExcerpt = excerpt.length > 180
        ? '${excerpt.substring(0, 180).trim()}...'
        : excerpt;

    final payload = <String, dynamic>{
      'slug': slug,
      'title': headline.trim(),
      'excerpt': safeExcerpt,
      'topic': topic.trim(),
      'is_published': false,
      'author_id': authUser.id,
      'content': body,
      'body_top': body,
      'body_bottom': body,
      'language_top': 'English',
      'language_bottom': 'English',
      'created_at': now.toIso8601String(),
    };

    try {
      await _client.from('articles').insert(payload);
    } on PostgrestException {
      await _client.from('articles').insert({
        'slug': slug,
        'title': headline.trim(),
        'is_published': false,
      });
    }
  }
}

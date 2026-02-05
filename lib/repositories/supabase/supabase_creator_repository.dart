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

    final profileRow = await _client
        .from('profiles')
        .select('estimated_earnings')
        .eq('id', authUser.id)
        .maybeSingle();

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
}

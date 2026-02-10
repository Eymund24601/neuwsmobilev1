import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/community_models.dart';
import '../community_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseCommunityRepository implements CommunityRepository {
  const SupabaseCommunityRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<MessageThreadSummary>> getMessageThreads() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final participantRows = await _client
          .from('dm_thread_participants')
          .select('thread_id,last_read_at')
          .eq('user_id', userId)
          .order('joined_at', ascending: false)
          .limit(50);

      final threadIds = participantRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['thread_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (threadIds.isEmpty) {
        return const [];
      }

      final messagesRows = await _client
          .from('dm_messages')
          .select('thread_id,body,created_at,sender_user_id')
          .inFilter('thread_id', threadIds)
          .order('created_at', ascending: false)
          .limit(400);

      final latestMessageByThread = <String, Map<String, dynamic>>{};
      final otherUserByThread = <String, String>{};
      final profileIds = <String>{};
      for (final dynamic row in messagesRows) {
        final map = row as Map<String, dynamic>;
        final threadId = SupabaseMappingUtils.stringValue(map, const [
          'thread_id',
        ]);
        final senderUserId = SupabaseMappingUtils.stringValue(map, const [
          'sender_user_id',
        ]);
        if (threadId.isNotEmpty &&
            !latestMessageByThread.containsKey(threadId)) {
          latestMessageByThread[threadId] = map;
        }
        if (threadId.isNotEmpty &&
            senderUserId.isNotEmpty &&
            senderUserId != userId) {
          otherUserByThread.putIfAbsent(threadId, () => senderUserId);
          profileIds.add(senderUserId);
        }
      }

      // Keep this compatibility query for schemas/policies where it is available.
      // In stricter RLS setups we still resolve display names from sender_user_id above.
      final otherParticipantRows = await _client
          .from('dm_thread_participants')
          .select('thread_id,user_id')
          .inFilter('thread_id', threadIds)
          .neq('user_id', userId);

      for (final dynamic row in otherParticipantRows) {
        final map = row as Map<String, dynamic>;
        final threadId = SupabaseMappingUtils.stringValue(map, const [
          'thread_id',
        ]);
        final otherUserId = SupabaseMappingUtils.stringValue(map, const [
          'user_id',
        ]);
        if (threadId.isEmpty || otherUserId.isEmpty) {
          continue;
        }
        otherUserByThread[threadId] = otherUserId;
        profileIds.add(otherUserId);
      }

      final profilesById = await _profilesById(profileIds.toList());
      final threads = <MessageThreadSummary>[];
      for (final dynamic row in participantRows) {
        final map = row as Map<String, dynamic>;
        final threadId = SupabaseMappingUtils.stringValue(map, const [
          'thread_id',
        ]);
        if (threadId.isEmpty) {
          continue;
        }

        final lastReadAt = SupabaseMappingUtils.dateTimeValue(map, const [
          'last_read_at',
        ]);
        final latest = latestMessageByThread[threadId];
        final preview = latest == null
            ? 'No messages yet'
            : SupabaseMappingUtils.stringValue(latest, const [
                'body',
              ], fallback: 'Media message');
        final createdAt = latest == null
            ? null
            : SupabaseMappingUtils.dateTimeValue(latest, const ['created_at']);
        final unread =
            createdAt != null &&
                (lastReadAt == null || createdAt.isAfter(lastReadAt))
            ? 1
            : 0;
        final otherUserId = otherUserByThread[threadId];
        final profile = otherUserId == null ? null : profilesById[otherUserId];
        final displayName = profile == null
            ? 'Conversation'
            : SupabaseMappingUtils.stringValue(profile, const [
                'display_name',
                'username',
              ], fallback: 'Conversation');
        final avatarUrl = profile == null
            ? 'assets/images/placeholder-user.jpg'
            : SupabaseMappingUtils.stringValue(profile, const [
                'avatar_url',
              ], fallback: 'assets/images/placeholder-user.jpg');

        threads.add(
          MessageThreadSummary(
            threadId: threadId,
            displayName: displayName,
            preview: preview,
            timeLabel: _relativeTimeLabel(createdAt),
            unreadCount: unread,
            otherUserId: otherUserId,
            otherUserAvatarUrl: avatarUrl,
          ),
        );
      }

      threads.sort((a, b) {
        final aDate = SupabaseMappingUtils.dateTimeValue(
          latestMessageByThread[a.threadId] ?? const <String, dynamic>{},
          const ['created_at'],
        );
        final bDate = SupabaseMappingUtils.dateTimeValue(
          latestMessageByThread[b.threadId] ?? const <String, dynamic>{},
          const ['created_at'],
        );
        if (aDate == null && bDate == null) {
          return 0;
        }
        if (aDate == null) {
          return 1;
        }
        if (bDate == null) {
          return -1;
        }
        return bDate.compareTo(aDate);
      });

      return threads;
    } on PostgrestException {
      return const [];
    }
  }

  @override
  Future<List<DirectMessage>> getThreadMessages(String threadId) async {
    final userId = _currentUserId;
    if (userId == null || threadId.trim().isEmpty) {
      return const [];
    }

    List<dynamic> messageRows;
    try {
      messageRows = await _client
          .from('dm_messages')
          .select('id,thread_id,sender_user_id,body,created_at')
          .eq('thread_id', threadId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: true)
          .limit(200);
    } on PostgrestException {
      messageRows = await _client
          .from('dm_messages')
          .select('id,thread_id,sender_user_id,body,created_at')
          .eq('thread_id', threadId)
          .order('created_at', ascending: true)
          .limit(200);
    }

    final senderIds = <String>{};
    for (final dynamic row in messageRows) {
      final map = row as Map<String, dynamic>;
      final senderUserId = SupabaseMappingUtils.stringValue(map, const [
        'sender_user_id',
      ]);
      if (senderUserId.isNotEmpty) {
        senderIds.add(senderUserId);
      }
    }

    final profilesById = await _profilesById(senderIds.toList());

    return messageRows.map<DirectMessage>((dynamic row) {
      final map = row as Map<String, dynamic>;
      final senderUserId = SupabaseMappingUtils.stringValue(map, const [
        'sender_user_id',
      ]);
      final isMine = senderUserId == userId;
      final profile = profilesById[senderUserId];
      final senderDisplayName = isMine
          ? 'You'
          : (profile == null
                ? 'User'
                : SupabaseMappingUtils.stringValue(profile, const [
                    'display_name',
                    'username',
                  ], fallback: 'User'));
      final senderAvatarUrl = isMine
          ? 'assets/images/placeholder-user.jpg'
          : (profile == null
                ? 'assets/images/placeholder-user.jpg'
                : SupabaseMappingUtils.stringValue(profile, const [
                    'avatar_url',
                  ], fallback: 'assets/images/placeholder-user.jpg'));
      final createdAt = SupabaseMappingUtils.dateTimeValue(map, const [
        'created_at',
      ]);
      return DirectMessage(
        id: SupabaseMappingUtils.stringValue(map, const ['id']),
        threadId: SupabaseMappingUtils.stringValue(map, const [
          'thread_id',
        ], fallback: threadId),
        senderUserId: senderUserId,
        senderDisplayName: senderDisplayName,
        senderAvatarUrl: senderAvatarUrl,
        body: SupabaseMappingUtils.stringValue(map, const [
          'body',
        ], fallback: ''),
        createdAtIso:
            createdAt?.toUtc().toIso8601String() ??
            DateTime.now().toUtc().toIso8601String(),
        isMine: isMine,
      );
    }).toList();
  }

  @override
  Future<void> sendThreadMessage({
    required String threadId,
    required String body,
  }) async {
    final userId = _currentUserId;
    final trimmedBody = body.trim();
    if (userId == null || threadId.trim().isEmpty || trimmedBody.isEmpty) {
      return;
    }

    await _client.from('dm_messages').insert({
      'thread_id': threadId,
      'sender_user_id': userId,
      'body': trimmedBody,
    });
  }

  @override
  Future<String?> createOrGetDmThread(String otherUserId) async {
    final userId = _currentUserId;
    final other = otherUserId.trim();
    if (userId == null || other.isEmpty || other == userId) {
      return null;
    }

    final result = await _client.rpc(
      'create_or_get_dm_thread',
      params: {'p_other_user_id': other},
    );
    if (result is String && result.trim().isNotEmpty) {
      return result;
    }
    if (result is Map<String, dynamic>) {
      final id = SupabaseMappingUtils.stringValue(result, const ['id']);
      if (id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  @override
  Future<void> markThreadRead(String threadId) async {
    final userId = _currentUserId;
    if (userId == null || threadId.trim().isEmpty) {
      return;
    }

    try {
      await _client
          .from('dm_thread_participants')
          .update({'last_read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('thread_id', threadId)
          .eq('user_id', userId);
    } on PostgrestException {
      // Best-effort update: older environments may not yet have update policy.
    }
  }

  @override
  Future<List<MessageContactSummary>> getMessageContacts() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final followingRows = await _client
          .from('user_follows')
          .select('followed_user_id')
          .eq('follower_user_id', userId)
          .limit(120);
      final followerRows = await _client
          .from('user_follows')
          .select('follower_user_id')
          .eq('followed_user_id', userId)
          .limit(120);

      final following = followingRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['followed_user_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toSet();
      final followers = followerRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['follower_user_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toSet();

      final ids = <String>{...following, ...followers}.toList();
      final profilesById = await _profilesById(ids);
      final contacts = <MessageContactSummary>[];
      for (final id in ids) {
        final profile = profilesById[id];
        if (profile == null) {
          continue;
        }
        final inFollowing = following.contains(id);
        final inFollowers = followers.contains(id);
        final relation = inFollowing && inFollowers
            ? 'You follow each other'
            : (inFollowers ? 'Follows you' : 'You follow');
        contacts.add(
          MessageContactSummary(
            userId: id,
            displayName: SupabaseMappingUtils.stringValue(profile, const [
              'display_name',
              'username',
            ], fallback: 'User'),
            relation: relation,
          ),
        );
      }

      contacts.sort((a, b) => a.displayName.compareTo(b.displayName));
      return contacts.take(80).toList();
    } on PostgrestException {
      return const [];
    }
  }

  @override
  Future<List<SavedArticleSummary>> getSavedArticles() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final bookmarkRows = await _client
          .from('article_bookmarks')
          .select('article_id,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(120);

      final articleIds = bookmarkRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['article_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (articleIds.isEmpty) {
        return const [];
      }

      final articleRows = await _client
          .from('articles')
          .select('id,slug,title,published_at,created_at')
          .inFilter('id', articleIds);
      final articlesById = <String, Map<String, dynamic>>{};
      for (final dynamic row in articleRows) {
        final map = row as Map<String, dynamic>;
        final id = SupabaseMappingUtils.stringValue(map, const ['id']);
        if (id.isNotEmpty) {
          articlesById[id] = map;
        }
      }

      final saved = <SavedArticleSummary>[];
      for (final dynamic row in bookmarkRows) {
        final map = row as Map<String, dynamic>;
        final articleId = SupabaseMappingUtils.stringValue(map, const [
          'article_id',
        ]);
        final article = articlesById[articleId];
        if (article == null) {
          continue;
        }
        final date = SupabaseMappingUtils.dateTimeValue(article, const [
          'published_at',
          'created_at',
        ]);
        saved.add(
          SavedArticleSummary(
            articleId: articleId,
            slug: SupabaseMappingUtils.stringValue(article, const [
              'slug',
            ], fallback: ''),
            title: SupabaseMappingUtils.stringValue(article, const [
              'title',
            ], fallback: 'Saved article'),
            dateLabel: SupabaseMappingUtils.upperDateLabel(
              date,
              fallback: 'RECENT',
            ),
          ),
        );
      }

      return saved;
    } on PostgrestException {
      return const [];
    }
  }

  @override
  Future<List<UserCollectionSummary>> getUserCollections() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final collectionRows = await _client
          .from('user_collections')
          .select('id,name,is_public')
          .eq('user_id', userId)
          .order('updated_at', ascending: false)
          .limit(40);

      final ids = collectionRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (ids.isEmpty) {
        return const [];
      }

      final itemRows = await _client
          .from('collection_items')
          .select('collection_id')
          .inFilter('collection_id', ids);
      final countByCollection = <String, int>{};
      for (final dynamic row in itemRows) {
        final map = row as Map<String, dynamic>;
        final id = SupabaseMappingUtils.stringValue(map, const [
          'collection_id',
        ]);
        if (id.isEmpty) {
          continue;
        }
        countByCollection[id] = (countByCollection[id] ?? 0) + 1;
      }

      return collectionRows.map<UserCollectionSummary>((dynamic row) {
        final map = row as Map<String, dynamic>;
        final id = SupabaseMappingUtils.stringValue(map, const [
          'id',
        ], fallback: '');
        return UserCollectionSummary(
          id: id,
          name: SupabaseMappingUtils.stringValue(map, const [
            'name',
          ], fallback: 'Collection'),
          itemCount: countByCollection[id] ?? 0,
          isPublic: SupabaseMappingUtils.boolValue(map, const [
            'is_public',
          ], fallback: false),
        );
      }).toList();
    } on PostgrestException {
      return const [];
    }
  }

  @override
  Future<List<UserPerkSummary>> getUserPerks() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final perkRows = await _client
          .from('user_perks')
          .select('id,perk_id,status,source_type,expires_at')
          .eq('user_id', userId)
          .order('granted_at', ascending: false)
          .limit(80);

      final perkIds = perkRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['perk_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();

      final perkCatalog = <String, Map<String, dynamic>>{};
      if (perkIds.isNotEmpty) {
        final catalogRows = await _client
            .from('perks_catalog')
            .select('id,name,perk_type,metadata_json')
            .inFilter('id', perkIds);
        for (final dynamic row in catalogRows) {
          final map = row as Map<String, dynamic>;
          final id = SupabaseMappingUtils.stringValue(map, const ['id']);
          if (id.isNotEmpty) {
            perkCatalog[id] = map;
          }
        }
      }

      return perkRows.map<UserPerkSummary>((dynamic row) {
        final map = row as Map<String, dynamic>;
        final perkId = SupabaseMappingUtils.stringValue(map, const ['perk_id']);
        final catalog = perkCatalog[perkId];
        return UserPerkSummary(
          id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
          title: catalog == null
              ? 'Perk'
              : SupabaseMappingUtils.stringValue(catalog, const [
                  'name',
                ], fallback: 'Perk'),
          category: catalog == null
              ? 'General'
              : SupabaseMappingUtils.stringValue(catalog, const [
                  'perk_type',
                ], fallback: 'General'),
          status: SupabaseMappingUtils.stringValue(map, const [
            'status',
          ], fallback: 'available'),
          code: _perkCode(catalog),
        );
      }).toList();
    } on PostgrestException {
      return const [];
    }
  }

  @override
  Future<UserProgressionSummary?> getUserProgression() async {
    final userId = _currentUserId;
    if (userId == null) {
      return null;
    }
    try {
      final row = await _client
          .from('user_progression')
          .select('total_xp,level,current_streak_days,best_streak_days')
          .eq('user_id', userId)
          .maybeSingle();
      if (row == null) {
        return null;
      }
      return UserProgressionSummary(
        totalXp: SupabaseMappingUtils.intValue(row, const [
          'total_xp',
        ], fallback: 0),
        level: SupabaseMappingUtils.intValue(row, const ['level'], fallback: 1),
        currentStreakDays: SupabaseMappingUtils.intValue(row, const [
          'current_streak_days',
        ], fallback: 0),
        bestStreakDays: SupabaseMappingUtils.intValue(row, const [
          'best_streak_days',
        ], fallback: 0),
      );
    } on PostgrestException {
      return null;
    }
  }

  @override
  Future<List<RepostedArticleSummary>> getRepostedArticles() async {
    final userId = _currentUserId;
    if (userId == null) {
      return const [];
    }

    try {
      final repostRows = await _client
          .from('article_reposts')
          .select('article_id,created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(120);
      final articleIds = repostRows
          .map<String>(
            (dynamic row) => SupabaseMappingUtils.stringValue(
              row as Map<String, dynamic>,
              const ['article_id'],
            ),
          )
          .where((item) => item.isNotEmpty)
          .toList();
      if (articleIds.isEmpty) {
        return const [];
      }

      final articleRows = await _client
          .from('articles')
          .select('id,slug,title')
          .inFilter('id', articleIds);
      final articlesById = <String, Map<String, dynamic>>{};
      for (final dynamic row in articleRows) {
        final map = row as Map<String, dynamic>;
        final id = SupabaseMappingUtils.stringValue(map, const ['id']);
        if (id.isNotEmpty) {
          articlesById[id] = map;
        }
      }

      return repostRows.map<RepostedArticleSummary>((dynamic row) {
        final map = row as Map<String, dynamic>;
        final articleId = SupabaseMappingUtils.stringValue(map, const [
          'article_id',
        ], fallback: '');
        final article = articlesById[articleId] ?? const <String, dynamic>{};
        return RepostedArticleSummary(
          articleId: articleId,
          slug: SupabaseMappingUtils.stringValue(article, const [
            'slug',
          ], fallback: ''),
          title: SupabaseMappingUtils.stringValue(article, const [
            'title',
          ], fallback: 'Reposted article'),
          sourceLabel: 'Reposted',
        );
      }).toList();
    } on PostgrestException {
      return const [];
    }
  }

  String? get _currentUserId => _client.auth.currentUser?.id;

  Future<Map<String, Map<String, dynamic>>> _profilesById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _client
        .from('profiles')
        .select('id,display_name,username,avatar_url')
        .inFilter('id', ids);
    final map = <String, Map<String, dynamic>>{};
    for (final dynamic row in rows) {
      final profile = row as Map<String, dynamic>;
      final id = SupabaseMappingUtils.stringValue(profile, const ['id']);
      if (id.isNotEmpty) {
        map[id] = profile;
      }
    }
    return map;
  }

  String _relativeTimeLabel(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }
    return '${dateTime.month}/${dateTime.day}';
  }

  String _perkCode(Map<String, dynamic>? catalogRow) {
    if (catalogRow == null) {
      return '-';
    }
    final metadata = catalogRow['metadata_json'];
    if (metadata is Map<String, dynamic>) {
      final code = SupabaseMappingUtils.stringValue(metadata, const ['code']);
      if (code.isNotEmpty) {
        return code;
      }
    }
    final key = SupabaseMappingUtils.stringValue(catalogRow, const ['id']);
    return key.isEmpty ? '-' : key.substring(0, 6).toUpperCase();
  }
}

import '../../models/community_models.dart';
import '../community_repository.dart';

class MockCommunityRepository implements CommunityRepository {
  static const _threads = [
    MessageThreadSummary(
      threadId: 't1',
      displayName: 'Marta Keller',
      preview: 'New message',
      timeLabel: '2h',
      unreadCount: 1,
      otherUserId: 'u1',
      otherUserAvatarUrl: 'assets/images/placeholder-user.jpg',
      otherUsername: 'MartaKeller',
    ),
    MessageThreadSummary(
      threadId: 't2',
      displayName: 'Lea Novak',
      preview: 'Can we publish this thread tonight?',
      timeLabel: '1d',
      unreadCount: 1,
      otherUserId: 'u3',
      otherUserAvatarUrl: 'assets/images/placeholder-user.jpg',
      otherUsername: 'LeaNovak',
    ),
    MessageThreadSummary(
      threadId: 't3',
      displayName: 'Miguel Sousa',
      preview: 'Sent 5h ago',
      timeLabel: '5h',
      unreadCount: 0,
      otherUserId: 'u2',
      otherUserAvatarUrl: 'assets/images/placeholder-user.jpg',
      otherUsername: 'MiguelSousa',
    ),
  ];

  static const _contacts = [
    MessageContactSummary(
      userId: 'u1',
      displayName: 'Marta Keller',
      username: 'MartaKeller',
      relation: 'Follows you',
    ),
    MessageContactSummary(
      userId: 'u2',
      displayName: 'Lukas Brenner',
      username: 'LukasBrenner',
      relation: 'You follow each other',
    ),
    MessageContactSummary(
      userId: 'u3',
      displayName: 'Lea Novak',
      username: 'LeaNovak',
      relation: 'Follows you',
    ),
  ];

  static const _threadMessages = {
    't1': [
      DirectMessage(
        id: 't1-m1',
        threadId: 't1',
        senderUserId: 'u1',
        senderDisplayName: 'Marta Keller',
        senderAvatarUrl: 'assets/images/placeholder-user.jpg',
        body: 'Hey, did you see the final version?',
        createdAtIso: '2026-02-10T08:40:00Z',
        isMine: false,
      ),
      DirectMessage(
        id: 't1-m2',
        threadId: 't1',
        senderUserId: 'me',
        senderDisplayName: 'You',
        senderAvatarUrl: 'assets/images/placeholder-user.jpg',
        body: 'Yes, looks good. I will publish this afternoon.',
        createdAtIso: '2026-02-10T09:05:00Z',
        isMine: true,
      ),
    ],
    't2': [
      DirectMessage(
        id: 't2-m1',
        threadId: 't2',
        senderUserId: 'u3',
        senderDisplayName: 'Lea Novak',
        senderAvatarUrl: 'assets/images/placeholder-user.jpg',
        body: 'Can we publish this thread tonight?',
        createdAtIso: '2026-02-09T18:10:00Z',
        isMine: false,
      ),
      DirectMessage(
        id: 't2-m2',
        threadId: 't2',
        senderUserId: 'me',
        senderDisplayName: 'You',
        senderAvatarUrl: 'assets/images/placeholder-user.jpg',
        body: 'Yes, let us schedule for 21:00 CET.',
        createdAtIso: '2026-02-09T18:20:00Z',
        isMine: true,
      ),
    ],
    't3': [
      DirectMessage(
        id: 't3-m1',
        threadId: 't3',
        senderUserId: 'u2',
        senderDisplayName: 'Miguel Sousa',
        senderAvatarUrl: 'assets/images/placeholder-user.jpg',
        body: 'Thanks for the feedback on the Porto piece.',
        createdAtIso: '2026-02-10T05:20:00Z',
        isMine: false,
      ),
    ],
  };

  static const _saved = [
    SavedArticleSummary(
      articleId: 'a1',
      slug: 'europe-social-club',
      title:
          'Is Your Social Life Missing Something? This Conversation Is for You.',
      dateLabel: 'FEBRUARY 3, 2026',
    ),
    SavedArticleSummary(
      articleId: 'a2',
      slug: 'midterm-defense',
      title:
          'How Communities Defend Elections Without Waiting for Institutions',
      dateLabel: 'FEBRUARY 2, 2026',
    ),
  ];

  static const _collections = [
    UserCollectionSummary(
      id: 'c1',
      name: 'Elections Toolkit',
      itemCount: 12,
      isPublic: true,
    ),
    UserCollectionSummary(
      id: 'c2',
      name: 'Nordic Long Reads',
      itemCount: 8,
      isPublic: false,
    ),
  ];

  static const _perks = [
    UserPerkSummary(
      id: 'p1',
      title: 'Nordic Rail 20% Off',
      category: 'Travel',
      status: 'available',
      code: 'NEUWS20',
    ),
    UserPerkSummary(
      id: 'p2',
      title: 'Berlin Coffee Pass',
      category: 'Food',
      status: 'available',
      code: 'EUROPEBREW',
    ),
  ];

  static const _reposts = [
    RepostedArticleSummary(
      articleId: 'a3',
      slug: 'baltic-night-train',
      title: 'A Night Train Diary Through the Baltics',
      sourceLabel: 'Reposted from Lea Novak',
    ),
    RepostedArticleSummary(
      articleId: 'a4',
      slug: 'portugal-cities',
      title: 'Why Porto Feels Like the Future of Cities',
      sourceLabel: 'Reposted from Miguel Sousa',
    ),
  ];

  @override
  Future<List<MessageContactSummary>> getMessageContacts() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _contacts;
  }

  @override
  Future<List<MessageThreadSummary>> getMessageThreads() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _threads;
  }

  @override
  Future<List<DirectMessage>> getThreadMessages(String threadId) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    return List<DirectMessage>.from(_threadMessages[threadId] ?? const []);
  }

  @override
  Future<void> sendThreadMessage({
    required String threadId,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
  }

  @override
  Future<String?> createOrGetDmThread(String otherUserId) async {
    await Future<void>.delayed(const Duration(milliseconds: 80));
    for (final thread in _threads) {
      if (thread.otherUserId == otherUserId) {
        return thread.threadId;
      }
    }
    return null;
  }

  @override
  Future<void> markThreadRead(String threadId) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  Future<List<SavedArticleSummary>> getSavedArticles() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _saved;
  }

  @override
  Future<List<UserCollectionSummary>> getUserCollections() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _collections;
  }

  @override
  Future<List<UserPerkSummary>> getUserPerks() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _perks;
  }

  @override
  Future<UserProgressionSummary?> getUserProgression() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const UserProgressionSummary(
      totalXp: 1240,
      level: 6,
      currentStreakDays: 12,
      bestStreakDays: 21,
    );
  }

  @override
  Future<List<RepostedArticleSummary>> getRepostedArticles() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _reposts;
  }
}

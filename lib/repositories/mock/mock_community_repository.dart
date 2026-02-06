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
    ),
    MessageThreadSummary(
      threadId: 't2',
      displayName: 'Lea Novak',
      preview: 'Can we publish this thread tonight?',
      timeLabel: '1d',
      unreadCount: 1,
    ),
    MessageThreadSummary(
      threadId: 't3',
      displayName: 'Miguel Sousa',
      preview: 'Sent 5h ago',
      timeLabel: '5h',
      unreadCount: 0,
    ),
  ];

  static const _contacts = [
    MessageContactSummary(
      userId: 'u1',
      displayName: 'Marta Keller',
      relation: 'Follows you',
    ),
    MessageContactSummary(
      userId: 'u2',
      displayName: 'Lukas Brenner',
      relation: 'You follow each other',
    ),
    MessageContactSummary(
      userId: 'u3',
      displayName: 'Lea Novak',
      relation: 'Follows you',
    ),
  ];

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

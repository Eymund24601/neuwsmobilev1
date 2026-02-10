import '../models/community_models.dart';

abstract class CommunityRepository {
  Future<List<MessageThreadSummary>> getMessageThreads();
  Future<List<DirectMessage>> getThreadMessages(String threadId);
  Future<void> sendThreadMessage({
    required String threadId,
    required String body,
  });
  Future<String?> createOrGetDmThread(String otherUserId);
  Future<void> markThreadRead(String threadId);
  Future<List<MessageContactSummary>> getMessageContacts();
  Future<List<SavedArticleSummary>> getSavedArticles();
  Future<List<UserCollectionSummary>> getUserCollections();
  Future<List<UserPerkSummary>> getUserPerks();
  Future<UserProgressionSummary?> getUserProgression();
  Future<List<RepostedArticleSummary>> getRepostedArticles();
}

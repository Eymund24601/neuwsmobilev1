import '../models/community_models.dart';

abstract class CommunityRepository {
  Future<List<MessageThreadSummary>> getMessageThreads();
  Future<List<MessageContactSummary>> getMessageContacts();
  Future<List<SavedArticleSummary>> getSavedArticles();
  Future<List<UserCollectionSummary>> getUserCollections();
  Future<List<UserPerkSummary>> getUserPerks();
  Future<UserProgressionSummary?> getUserProgression();
  Future<List<RepostedArticleSummary>> getRepostedArticles();
}

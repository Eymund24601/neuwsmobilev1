import '../models/article_detail.dart';
import '../models/article_summary.dart';
import '../models/topic_feed.dart';

abstract class ArticleRepository {
  Future<List<ArticleSummary>> getTopStories();
  Future<TopicFeed> getTopicFeed(String topicOrCountryCode);
  Future<ArticleDetail?> getArticleDetailBySlug(String slug);
}

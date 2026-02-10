import '../models/article_detail.dart';
import '../models/article_summary.dart';
import '../models/article_bundle.dart';
import '../models/topic_feed.dart';
import '../models/vocab_models.dart';

abstract class ArticleRepository {
  Future<List<ArticleSummary>> getTopStories();
  Future<List<ArticleDetail>> getRecentArticleDetails({int limit = 100});
  Future<TopicFeed> getTopicFeed(String topicOrCountryCode);
  Future<ArticleDetail?> getArticleDetailBySlug(String slug);
  Future<ArticleBundle?> getArticleBundleBySlug(
    String slug,
    String topLang,
    String bottomLang,
    String uiLang,
  );
  Future<void> collectFocusVocab({
    required String articleId,
    required List<FocusVocabItem> items,
  });
}

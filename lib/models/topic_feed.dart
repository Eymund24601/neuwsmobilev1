import 'article_summary.dart';

class TopicFeed {
  const TopicFeed({
    required this.code,
    required this.displayName,
    required this.stories,
  });

  final String code;
  final String displayName;
  final List<ArticleSummary> stories;

  factory TopicFeed.fromJson(Map<String, dynamic> json) {
    return TopicFeed(
      code: json['code'] as String,
      displayName: json['displayName'] as String,
      stories: (json['stories'] as List<dynamic>)
          .map((item) => ArticleSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'displayName': displayName,
      'stories': stories.map((story) => story.toJson()).toList(),
    };
  }
}

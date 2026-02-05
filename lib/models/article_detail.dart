import '../data/mock_data.dart';

class ArticleDetail {
  const ArticleDetail({
    required this.slug,
    required this.title,
    required this.byline,
    required this.date,
    required this.imageAsset,
    required this.topic,
    required this.excerpt,
    required this.readTime,
    required this.authorName,
    required this.authorLocation,
    required this.languageTop,
    required this.languageBottom,
    required this.bodyTop,
    required this.bodyBottom,
  });

  final String slug;
  final String title;
  final String byline;
  final String date;
  final String imageAsset;
  final String topic;
  final String excerpt;
  final String readTime;
  final String authorName;
  final String authorLocation;
  final String languageTop;
  final String languageBottom;
  final String bodyTop;
  final String bodyBottom;

  factory ArticleDetail.fromJson(Map<String, dynamic> json) {
    return ArticleDetail(
      slug: json['slug'] as String,
      title: json['title'] as String,
      byline: json['byline'] as String,
      date: json['date'] as String,
      imageAsset: json['imageAsset'] as String,
      topic: json['topic'] as String,
      excerpt: json['excerpt'] as String,
      readTime: json['readTime'] as String,
      authorName: json['authorName'] as String,
      authorLocation: json['authorLocation'] as String,
      languageTop: json['languageTop'] as String,
      languageBottom: json['languageBottom'] as String,
      bodyTop: json['bodyTop'] as String,
      bodyBottom: json['bodyBottom'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slug': slug,
      'title': title,
      'byline': byline,
      'date': date,
      'imageAsset': imageAsset,
      'topic': topic,
      'excerpt': excerpt,
      'readTime': readTime,
      'authorName': authorName,
      'authorLocation': authorLocation,
      'languageTop': languageTop,
      'languageBottom': languageBottom,
      'bodyTop': bodyTop,
      'bodyBottom': bodyBottom,
    };
  }

  ArticleContent toArticleContent() {
    return ArticleContent(
      title: title,
      byline: byline,
      date: date,
      imageAsset: imageAsset,
      topic: topic,
      excerpt: excerpt,
      readTime: readTime,
      authorName: authorName,
      authorLocation: authorLocation,
      languageTop: languageTop,
      languageBottom: languageBottom,
      bodyTop: bodyTop,
      bodyBottom: bodyBottom,
    );
  }
}

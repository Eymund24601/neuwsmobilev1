class ArticleLocalization {
  const ArticleLocalization({
    required this.id,
    required this.articleId,
    required this.lang,
    required this.title,
    required this.excerpt,
    required this.body,
    required this.contentHash,
    required this.version,
    required this.createdAt,
  });

  final String id;
  final String articleId;
  final String lang;
  final String title;
  final String excerpt;
  final String body;
  final String contentHash;
  final int version;
  final DateTime? createdAt;

  factory ArticleLocalization.fromJson(Map<String, dynamic> json) {
    return ArticleLocalization(
      id: json['id'] as String,
      articleId: json['articleId'] as String,
      lang: json['lang'] as String,
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      body: json['body'] as String? ?? '',
      contentHash: json['contentHash'] as String? ?? '',
      version: json['version'] as int? ?? 1,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleId': articleId,
      'lang': lang,
      'title': title,
      'excerpt': excerpt,
      'body': body,
      'contentHash': contentHash,
      'version': version,
      'createdAt': createdAt?.toIso8601String(),
    };
  }
}

class ArticleSummary {
  const ArticleSummary({
    required this.id,
    required this.slug,
    required this.title,
    required this.topic,
    required this.countryCode,
    required this.readTimeMinutes,
    required this.publishedAtLabel,
    required this.isPremium,
  });

  final String id;
  final String slug;
  final String title;
  final String topic;
  final String countryCode;
  final int readTimeMinutes;
  final String publishedAtLabel;
  final bool isPremium;

  factory ArticleSummary.fromJson(Map<String, dynamic> json) {
    return ArticleSummary(
      id: json['id'] as String,
      slug: json['slug'] as String,
      title: json['title'] as String,
      topic: json['topic'] as String,
      countryCode: json['countryCode'] as String,
      readTimeMinutes: json['readTimeMinutes'] as int,
      publishedAtLabel: json['publishedAtLabel'] as String,
      isPremium: json['isPremium'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'title': title,
      'topic': topic,
      'countryCode': countryCode,
      'readTimeMinutes': readTimeMinutes,
      'publishedAtLabel': publishedAtLabel,
      'isPremium': isPremium,
    };
  }
}

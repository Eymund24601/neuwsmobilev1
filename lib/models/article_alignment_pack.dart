class ArticleAlignmentPack {
  const ArticleAlignmentPack({
    required this.id,
    required this.articleId,
    required this.fromLocalizationId,
    required this.toLocalizationId,
    required this.alignmentJson,
    required this.algoVersion,
    required this.qualityScore,
  });

  final String id;
  final String articleId;
  final String fromLocalizationId;
  final String toLocalizationId;
  final Object? alignmentJson;
  final String algoVersion;
  final double? qualityScore;

  factory ArticleAlignmentPack.fromJson(Map<String, dynamic> json) {
    return ArticleAlignmentPack(
      id: json['id'] as String,
      articleId: json['articleId'] as String,
      fromLocalizationId: json['fromLocalizationId'] as String,
      toLocalizationId: json['toLocalizationId'] as String,
      alignmentJson: json['alignmentJson'],
      algoVersion: json['algoVersion'] as String? ?? '',
      qualityScore: (json['qualityScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleId': articleId,
      'fromLocalizationId': fromLocalizationId,
      'toLocalizationId': toLocalizationId,
      'alignmentJson': alignmentJson,
      'algoVersion': algoVersion,
      'qualityScore': qualityScore,
    };
  }
}

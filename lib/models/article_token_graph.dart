class ArticleLocalizationToken {
  const ArticleLocalizationToken({
    required this.id,
    required this.articleId,
    required this.localizationId,
    required this.tokenIndex,
    required this.startUtf16,
    required this.endUtf16,
    required this.surface,
    required this.normalizedSurface,
    this.primaryVocabItemId = '',
    this.primaryCandidateRank,
    this.primaryMatchType = '',
    this.primaryConfidence,
    this.primaryLinkSource = '',
  });

  final String id;
  final String articleId;
  final String localizationId;
  final int tokenIndex;
  final int startUtf16;
  final int endUtf16;
  final String surface;
  final String normalizedSurface;
  final String primaryVocabItemId;
  final int? primaryCandidateRank;
  final String primaryMatchType;
  final double? primaryConfidence;
  final String primaryLinkSource;

  bool containsOffset(int offset) {
    return offset >= startUtf16 && offset < endUtf16;
  }

  factory ArticleLocalizationToken.fromJson(Map<String, dynamic> json) {
    return ArticleLocalizationToken(
      id: json['id'] as String? ?? '',
      articleId:
          json['articleId'] as String? ?? json['article_id'] as String? ?? '',
      localizationId:
          json['localizationId'] as String? ??
          json['localization_id'] as String? ??
          '',
      tokenIndex:
          json['tokenIndex'] as int? ?? json['token_index'] as int? ?? 0,
      startUtf16:
          json['startUtf16'] as int? ?? json['start_utf16'] as int? ?? 0,
      endUtf16: json['endUtf16'] as int? ?? json['end_utf16'] as int? ?? 0,
      surface: json['surface'] as String? ?? '',
      normalizedSurface:
          json['normalizedSurface'] as String? ??
          json['normalized_surface'] as String? ??
          '',
      primaryVocabItemId:
          json['primaryVocabItemId'] as String? ??
          json['primary_vocab_item_id'] as String? ??
          '',
      primaryCandidateRank:
          json['primaryCandidateRank'] as int? ??
          json['primary_candidate_rank'] as int?,
      primaryMatchType:
          json['primaryMatchType'] as String? ??
          json['primary_match_type'] as String? ??
          '',
      primaryConfidence:
          (json['primaryConfidence'] as num?)?.toDouble() ??
          (json['primary_confidence'] as num?)?.toDouble(),
      primaryLinkSource:
          json['primaryLinkSource'] as String? ??
          json['primary_link_source'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'articleId': articleId,
      'localizationId': localizationId,
      'tokenIndex': tokenIndex,
      'startUtf16': startUtf16,
      'endUtf16': endUtf16,
      'surface': surface,
      'normalizedSurface': normalizedSurface,
      'primaryVocabItemId': primaryVocabItemId,
      'primaryCandidateRank': primaryCandidateRank,
      'primaryMatchType': primaryMatchType,
      'primaryConfidence': primaryConfidence,
      'primaryLinkSource': primaryLinkSource,
    };
  }
}

class ArticleTokenAlignment {
  const ArticleTokenAlignment({
    required this.canonicalTokenId,
    required this.targetLocalizationId,
    required this.targetTokenId,
    this.score,
    this.algoVersion = '',
  });

  final String canonicalTokenId;
  final String targetLocalizationId;
  final String targetTokenId;
  final double? score;
  final String algoVersion;

  factory ArticleTokenAlignment.fromJson(Map<String, dynamic> json) {
    return ArticleTokenAlignment(
      canonicalTokenId:
          json['canonicalTokenId'] as String? ??
          json['canonical_token_id'] as String? ??
          '',
      targetLocalizationId:
          json['targetLocalizationId'] as String? ??
          json['target_localization_id'] as String? ??
          '',
      targetTokenId:
          json['targetTokenId'] as String? ??
          json['target_token_id'] as String? ??
          '',
      score:
          (json['score'] as num?)?.toDouble() ??
          (json['quality_score'] as num?)?.toDouble(),
      algoVersion:
          json['algoVersion'] as String? ??
          json['algo_version'] as String? ??
          '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'canonicalTokenId': canonicalTokenId,
      'targetLocalizationId': targetLocalizationId,
      'targetTokenId': targetTokenId,
      'score': score,
      'algoVersion': algoVersion,
    };
  }
}

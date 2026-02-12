import 'article_alignment_pack.dart';
import 'article_localization.dart';
import 'article_token_graph.dart';
import 'vocab_models.dart';

class ArticleBundle {
  const ArticleBundle({
    required this.articleId,
    required this.slug,
    required this.canonicalLang,
    required this.canonicalLocalization,
    required this.topLocalization,
    required this.bottomLocalization,
    required this.alignmentToTop,
    required this.alignmentToBottom,
    required this.focusVocab,
    this.canonicalTokens = const [],
    this.topTokens = const [],
    this.bottomTokens = const [],
    this.tokenAlignmentsToTop = const [],
    this.tokenAlignmentsToBottom = const [],
  });

  final String articleId;
  final String slug;
  final String canonicalLang;
  final ArticleLocalization canonicalLocalization;
  final ArticleLocalization topLocalization;
  final ArticleLocalization bottomLocalization;
  final ArticleAlignmentPack? alignmentToTop;
  final ArticleAlignmentPack? alignmentToBottom;
  final ArticleFocusVocab focusVocab;
  final List<ArticleLocalizationToken> canonicalTokens;
  final List<ArticleLocalizationToken> topTokens;
  final List<ArticleLocalizationToken> bottomTokens;
  final List<ArticleTokenAlignment> tokenAlignmentsToTop;
  final List<ArticleTokenAlignment> tokenAlignmentsToBottom;

  Map<String, dynamic> toJson() {
    return {
      'articleId': articleId,
      'slug': slug,
      'canonicalLang': canonicalLang,
      'canonicalLocalization': canonicalLocalization.toJson(),
      'topLocalization': topLocalization.toJson(),
      'bottomLocalization': bottomLocalization.toJson(),
      'alignmentToTop': alignmentToTop?.toJson(),
      'alignmentToBottom': alignmentToBottom?.toJson(),
      'focusVocab': focusVocab.toJson(),
      'canonicalTokens': canonicalTokens.map((item) => item.toJson()).toList(),
      'topTokens': topTokens.map((item) => item.toJson()).toList(),
      'bottomTokens': bottomTokens.map((item) => item.toJson()).toList(),
      'tokenAlignmentsToTop': tokenAlignmentsToTop
          .map((item) => item.toJson())
          .toList(),
      'tokenAlignmentsToBottom': tokenAlignmentsToBottom
          .map((item) => item.toJson())
          .toList(),
    };
  }

  factory ArticleBundle.fromJson(Map<String, dynamic> json) {
    return ArticleBundle(
      articleId: json['articleId'] as String,
      slug: json['slug'] as String,
      canonicalLang: json['canonicalLang'] as String,
      canonicalLocalization: ArticleLocalization.fromJson(
        json['canonicalLocalization'] as Map<String, dynamic>,
      ),
      topLocalization: ArticleLocalization.fromJson(
        json['topLocalization'] as Map<String, dynamic>,
      ),
      bottomLocalization: ArticleLocalization.fromJson(
        json['bottomLocalization'] as Map<String, dynamic>,
      ),
      alignmentToTop: json['alignmentToTop'] == null
          ? null
          : ArticleAlignmentPack.fromJson(
              json['alignmentToTop'] as Map<String, dynamic>,
            ),
      alignmentToBottom: json['alignmentToBottom'] == null
          ? null
          : ArticleAlignmentPack.fromJson(
              json['alignmentToBottom'] as Map<String, dynamic>,
            ),
      focusVocab: ArticleFocusVocab.fromJson(
        json['focusVocab'] as Map<String, dynamic>,
      ),
      canonicalTokens: (json['canonicalTokens'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ArticleLocalizationToken.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      topTokens: (json['topTokens'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ArticleLocalizationToken.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      bottomTokens: (json['bottomTokens'] as List<dynamic>? ?? const [])
          .map(
            (item) =>
                ArticleLocalizationToken.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      tokenAlignmentsToTop:
          (json['tokenAlignmentsToTop'] as List<dynamic>? ?? const [])
              .map(
                (item) => ArticleTokenAlignment.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
      tokenAlignmentsToBottom:
          (json['tokenAlignmentsToBottom'] as List<dynamic>? ?? const [])
              .map(
                (item) => ArticleTokenAlignment.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class ArticleBundleRequest {
  const ArticleBundleRequest({
    required this.slug,
    required this.topLang,
    required this.bottomLang,
    required this.uiLang,
  });

  final String slug;
  final String topLang;
  final String bottomLang;
  final String uiLang;

  @override
  bool operator ==(Object other) {
    return other is ArticleBundleRequest &&
        other.slug == slug &&
        other.topLang == topLang &&
        other.bottomLang == bottomLang &&
        other.uiLang == uiLang;
  }

  @override
  int get hashCode => Object.hash(slug, topLang, bottomLang, uiLang);
}

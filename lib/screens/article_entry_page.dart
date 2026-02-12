import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/article_bundle.dart';
import '../models/article_detail.dart';
import '../models/article_localization.dart';
import '../models/article_token_graph.dart';
import '../models/vocab_models.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../repositories/settings_repository.dart';
import 'article_page.dart';

class ArticleEntryPage extends ConsumerStatefulWidget {
  const ArticleEntryPage({super.key, required this.slug});

  final String slug;

  @override
  ConsumerState<ArticleEntryPage> createState() => _ArticleEntryPageState();
}

class _ArticleEntryPageState extends ConsumerState<ArticleEntryPage> {
  String? _topLangCodeOverride;
  String? _bottomLangCodeOverride;

  static const List<String> _languageLabels = [
    'English',
    'Swedish',
    'French',
    'German',
    'Spanish',
    'Italian',
    'Portuguese',
  ];

  static const Map<String, String> _langCodeToLabel = {
    'en': 'English',
    'sv': 'Swedish',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'it': 'Italian',
    'pt': 'Portuguese',
  };

  static const Map<String, String> _langLabelToCode = {
    'english': 'en',
    'swedish': 'sv',
    'french': 'fr',
    'german': 'de',
    'spanish': 'es',
    'italian': 'it',
    'portuguese': 'pt',
  };

  @override
  Widget build(BuildContext context) {
    final articleAsync = ref.watch(articleDetailBySlugProvider(widget.slug));
    final settings = ref.watch(settingsProvider).valueOrNull;
    final uiLanguage = settings?.readingLanguage ?? 'English';

    return articleAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stackTrace) => Scaffold(
        appBar: AppBar(title: const Text('Article')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load article: $error'),
          ),
        ),
      ),
      data: (detail) {
        if (detail == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Article')),
            body: const Center(child: Text('Article not found.')),
          );
        }

        var topLangCode =
            _topLangCodeOverride ??
            _normalizeLangCode(
              settings?.readingTopLanguage ??
                  _cleanLanguage(detail.languageTop),
              fallback: 'en',
            );
        var bottomLangCode =
            _bottomLangCodeOverride ??
            _normalizeLangCode(
              settings?.readingBottomLanguage ??
                  _cleanLanguage(detail.languageBottom),
              fallback: _fallbackBottom(topLangCode),
            );
        if (bottomLangCode == topLangCode) {
          bottomLangCode = _fallbackBottom(topLangCode);
        }

        final request = ArticleBundleRequest(
          slug: widget.slug,
          topLang: topLangCode,
          bottomLang: bottomLangCode,
          uiLang: uiLanguage,
        );
        final bundleAsync = ref.watch(articleBundleBySlugProvider(request));
        final bundle = bundleAsync.valueOrNull;
        final article = _toArticleContent(detail, bundle);
        final vocabPairs = bundle == null
            ? const <ArticleVocabPair>[]
            : _toVocabPairs(bundle);

        return Stack(
          children: [
            ArticlePage(
              article: article,
              topLanguage: _labelForCode(topLangCode),
              bottomLanguage: _labelForCode(bottomLangCode),
              languageOptions: _languageLabels,
              onTopLanguageSelected: (label) => _updateReaderLanguages(
                settings: settings,
                nextTop: _normalizeLangCode(label, fallback: topLangCode),
                nextBottom: bottomLangCode,
              ),
              onBottomLanguageSelected: (label) => _updateReaderLanguages(
                settings: settings,
                nextTop: topLangCode,
                nextBottom: _normalizeLangCode(label, fallback: bottomLangCode),
              ),
              vocabPairs: vocabPairs,
              onResolveTapPair: bundle == null
                  ? null
                  : ({
                      required bool fromTop,
                      required String word,
                      required int start,
                      required int end,
                    }) => _resolveTapPair(
                      bundle,
                      fromTop: fromTop,
                      word: word,
                      start: start,
                      end: end,
                    ),
              onCollectWords: bundle == null || bundle.focusVocab.items.isEmpty
                  ? null
                  : () async {
                      await ref
                          .read(articleRepositoryProvider)
                          .collectFocusVocab(
                            articleId: bundle.articleId,
                            items: bundle.focusVocab.items,
                          );
                    },
            ),
            if (bundleAsync.isLoading && bundleAsync.valueOrNull != null)
              const Positioned(
                top: 84,
                right: 20,
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          ],
        );
      },
    );
  }

  void _updateReaderLanguages({
    required AppSettings? settings,
    required String nextTop,
    required String nextBottom,
  }) {
    var normalizedTop = _normalizeLangCode(nextTop, fallback: 'en');
    var normalizedBottom = _normalizeLangCode(
      nextBottom,
      fallback: _fallbackBottom(normalizedTop),
    );
    if (normalizedBottom == normalizedTop) {
      normalizedBottom = _fallbackBottom(normalizedTop);
    }

    setState(() {
      _topLangCodeOverride = normalizedTop;
      _bottomLangCodeOverride = normalizedBottom;
    });

    if (settings != null) {
      unawaited(
        ref
            .read(settingsProvider.notifier)
            .save(
              settings.copyWith(
                readingTopLanguage: normalizedTop,
                readingBottomLanguage: normalizedBottom,
              ),
            ),
      );
    }
  }

  ArticleContent _toArticleContent(
    ArticleDetail detail,
    ArticleBundle? bundle,
  ) {
    if (bundle == null) {
      return detail.toArticleContent();
    }
    return ArticleContent(
      title: detail.title,
      byline: detail.byline,
      date: detail.date,
      imageAsset: detail.imageAsset,
      topic: detail.topic,
      excerpt: detail.excerpt,
      authorName: detail.authorName,
      authorLocation: detail.authorLocation,
      languageTop: bundle.topLocalization.lang,
      languageBottom: bundle.bottomLocalization.lang,
      bodyTop: bundle.topLocalization.body,
      bodyBottom: bundle.bottomLocalization.body,
    );
  }

  List<ArticleVocabPair> _toVocabPairs(ArticleBundle bundle) {
    final pairs = <ArticleVocabPair>[];
    for (final item in bundle.focusVocab.items) {
      final topForm = _formForLanguage(item.forms, bundle.topLocalization.lang);
      final bottomForm = _formForLanguage(
        item.forms,
        bundle.bottomLocalization.lang,
      );
      if (topForm == null || bottomForm == null) {
        continue;
      }
      final label = (item.entry?.primaryDefinition.isNotEmpty ?? false)
          ? item.entry!.primaryDefinition
          : item.item.canonicalLemma;
      pairs.add(
        ArticleVocabPair(
          label: label,
          topText: topForm.surface,
          bottomText: bottomForm.surface,
        ),
      );
    }
    return pairs;
  }

  ArticleVocabPair? _resolveTapPair(
    ArticleBundle bundle, {
    required bool fromTop,
    required String word,
    required int start,
    required int end,
  }) {
    if (word.trim().isEmpty) {
      return null;
    }
    final sourceLocalization = fromTop
        ? bundle.topLocalization
        : bundle.bottomLocalization;
    final targetLocalization = fromTop
        ? bundle.bottomLocalization
        : bundle.topLocalization;
    final sourceTokens = _tokensForLocalization(bundle, sourceLocalization.id);
    final targetTokens = _tokensForLocalization(bundle, targetLocalization.id);
    final sourceToken = _tokenForTap(
      sourceTokens,
      start: start,
      end: end,
      maxDistance: 4,
    );
    if (sourceToken == null) {
      return null;
    }

    final mappedToken = _mapSourceTokenToTarget(
      bundle,
      sourceLocalization: sourceLocalization,
      targetLocalization: targetLocalization,
      sourceToken: sourceToken,
      targetTokens: targetTokens,
    );
    if (mappedToken == null) {
      return null;
    }

    return fromTop
        ? ArticleVocabPair(
            label: sourceToken.surface,
            topText: sourceToken.surface,
            bottomText: mappedToken.surface,
            topStartUtf16: sourceToken.startUtf16,
            topEndUtf16: sourceToken.endUtf16,
            bottomStartUtf16: mappedToken.startUtf16,
            bottomEndUtf16: mappedToken.endUtf16,
            statusMessage:
                'Mapped "${sourceToken.surface}" to "${mappedToken.surface}".',
          )
        : ArticleVocabPair(
            label: sourceToken.surface,
            topText: mappedToken.surface,
            bottomText: sourceToken.surface,
            topStartUtf16: mappedToken.startUtf16,
            topEndUtf16: mappedToken.endUtf16,
            bottomStartUtf16: sourceToken.startUtf16,
            bottomEndUtf16: sourceToken.endUtf16,
            statusMessage:
                'Mapped "${sourceToken.surface}" to "${mappedToken.surface}".',
          );
  }

  List<ArticleLocalizationToken> _tokensForLocalization(
    ArticleBundle bundle,
    String localizationId,
  ) {
    if (localizationId == bundle.canonicalLocalization.id) {
      return bundle.canonicalTokens;
    }
    if (localizationId == bundle.topLocalization.id) {
      return bundle.topTokens;
    }
    if (localizationId == bundle.bottomLocalization.id) {
      return bundle.bottomTokens;
    }
    return const [];
  }

  ArticleLocalizationToken? _mapSourceTokenToTarget(
    ArticleBundle bundle, {
    required ArticleLocalization sourceLocalization,
    required ArticleLocalization targetLocalization,
    required ArticleLocalizationToken sourceToken,
    required List<ArticleLocalizationToken> targetTokens,
  }) {
    if (targetTokens.isEmpty) {
      return null;
    }
    if (sourceLocalization.id == targetLocalization.id) {
      for (final token in targetTokens) {
        if (token.id == sourceToken.id) {
          return token;
        }
      }
      return null;
    }

    return _mapTokenViaStoredAlignments(
      bundle,
      sourceLocalization: sourceLocalization,
      targetLocalization: targetLocalization,
      sourceToken: sourceToken,
      targetTokens: targetTokens,
    );
  }

  ArticleLocalizationToken? _mapTokenViaStoredAlignments(
    ArticleBundle bundle, {
    required ArticleLocalization sourceLocalization,
    required ArticleLocalization targetLocalization,
    required ArticleLocalizationToken sourceToken,
    required List<ArticleLocalizationToken> targetTokens,
  }) {
    final canonicalTokenId = _canonicalTokenIdForSourceToken(
      bundle,
      sourceLocalization: sourceLocalization,
      sourceTokenId: sourceToken.id,
    );
    if (canonicalTokenId == null || canonicalTokenId.isEmpty) {
      return null;
    }

    final targetTokenId = _targetTokenIdForCanonical(
      bundle,
      targetLocalization: targetLocalization,
      canonicalTokenId: canonicalTokenId,
    );
    if (targetTokenId == null || targetTokenId.isEmpty) {
      return null;
    }

    for (final token in targetTokens) {
      if (token.id != targetTokenId) {
        continue;
      }
      return token;
    }
    return null;
  }

  String? _canonicalTokenIdForSourceToken(
    ArticleBundle bundle, {
    required ArticleLocalization sourceLocalization,
    required String sourceTokenId,
  }) {
    if (sourceLocalization.id == bundle.canonicalLocalization.id) {
      return sourceTokenId;
    }
    final reverseEdges = _tokenAlignmentsForTarget(
      bundle,
      sourceLocalization.id,
    );
    ArticleTokenAlignment? best;
    for (final edge in reverseEdges) {
      if (edge.targetTokenId != sourceTokenId) {
        continue;
      }
      if (best == null || (edge.score ?? 0) > (best.score ?? 0)) {
        best = edge;
      }
    }
    return best?.canonicalTokenId;
  }

  String? _targetTokenIdForCanonical(
    ArticleBundle bundle, {
    required ArticleLocalization targetLocalization,
    required String canonicalTokenId,
  }) {
    if (targetLocalization.id == bundle.canonicalLocalization.id) {
      return canonicalTokenId;
    }
    final forwardEdges = _tokenAlignmentsForTarget(
      bundle,
      targetLocalization.id,
    );
    ArticleTokenAlignment? best;
    for (final edge in forwardEdges) {
      if (edge.canonicalTokenId != canonicalTokenId) {
        continue;
      }
      if (best == null || (edge.score ?? 0) > (best.score ?? 0)) {
        best = edge;
      }
    }
    return best?.targetTokenId;
  }

  List<ArticleTokenAlignment> _tokenAlignmentsForTarget(
    ArticleBundle bundle,
    String targetLocalizationId,
  ) {
    if (targetLocalizationId == bundle.topLocalization.id) {
      return bundle.tokenAlignmentsToTop;
    }
    if (targetLocalizationId == bundle.bottomLocalization.id) {
      return bundle.tokenAlignmentsToBottom;
    }
    return const [];
  }

  ArticleLocalizationToken? _tokenForTap(
    List<ArticleLocalizationToken> tokens, {
    required int start,
    required int end,
    required int maxDistance,
  }) {
    if (tokens.isEmpty) {
      return null;
    }
    final tapCenter = ((start + end) / 2).round();

    ArticleLocalizationToken? bestNearby;
    var bestDistance = 1 << 30;
    for (final token in tokens) {
      if (token.startUtf16 >= end) {
        if (token.startUtf16 - end > maxDistance) {
          break;
        }
      }
      final overlaps = token.endUtf16 > start && token.startUtf16 < end;
      final containsCenter = token.containsOffset(tapCenter);
      if (containsCenter || overlaps) {
        return token;
      }
      final distance = _distanceToRange(
        tapCenter,
        token.startUtf16,
        token.endUtf16,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestNearby = token;
      }
    }
    return bestDistance <= maxDistance ? bestNearby : null;
  }

  int _distanceToRange(int value, int start, int end) {
    if (value < start) {
      return start - value;
    }
    if (value > end) {
      return value - end;
    }
    return 0;
  }

  VocabForm? _formForLanguage(List<VocabForm> forms, String lang) {
    final normalizedLang = _normalizeLangCode(lang, fallback: lang);
    for (final form in forms) {
      if (_normalizeLangCode(form.lang, fallback: form.lang) ==
          normalizedLang) {
        return form;
      }
    }
    return forms.isEmpty ? null : forms.first;
  }

  String _normalizeLangCode(String value, {required String fallback}) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return fallback;
    }
    if (_langCodeToLabel.containsKey(normalized)) {
      return normalized;
    }
    return _langLabelToCode[normalized] ?? fallback;
  }

  String _labelForCode(String code) {
    return _langCodeToLabel[code.toLowerCase()] ?? code.toUpperCase();
  }

  String _fallbackBottom(String topCode) {
    return topCode == 'en' ? 'sv' : 'en';
  }

  String _cleanLanguage(String value) {
    return value.replaceAll('Learning:', '').replaceAll('Native:', '').trim();
  }
}

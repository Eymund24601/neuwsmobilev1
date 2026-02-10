import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_data.dart';
import '../models/article_bundle.dart';
import '../models/article_detail.dart';
import '../models/vocab_models.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import 'article_page.dart';

class ArticleEntryPage extends ConsumerWidget {
  const ArticleEntryPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleDetailBySlugProvider(slug));
    final uiLanguage =
        ref.watch(settingsProvider).valueOrNull?.readingLanguage ?? 'English';

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

        final request = ArticleBundleRequest(
          slug: slug,
          topLang: _cleanLanguage(detail.languageTop),
          bottomLang: _cleanLanguage(detail.languageBottom),
          uiLang: uiLanguage,
        );
        final bundleAsync = ref.watch(articleBundleBySlugProvider(request));
        final bundle = bundleAsync.valueOrNull;
        final article = _toArticleContent(detail, bundle);
        final vocabPairs = bundle == null
            ? const <ArticleVocabPair>[]
            : _toVocabPairs(bundle);

        return ArticlePage(
          article: article,
          vocabPairs: vocabPairs,
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
        );
      },
    );
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
      readTime: detail.readTime,
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

  VocabForm? _formForLanguage(List<VocabForm> forms, String lang) {
    for (final form in forms) {
      if (form.lang.toLowerCase() == lang.toLowerCase()) {
        return form;
      }
    }
    return forms.isEmpty ? null : forms.first;
  }

  String _cleanLanguage(String value) {
    return value.replaceAll('Learning:', '').replaceAll('Native:', '').trim();
  }
}

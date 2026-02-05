import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import 'article_page.dart';

class ArticleEntryPage extends ConsumerWidget {
  const ArticleEntryPage({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleAsync = ref.watch(articleDetailBySlugProvider(slug));

    return articleAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
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
        return ArticlePage(article: detail.toArticleContent());
      },
    );
  }
}

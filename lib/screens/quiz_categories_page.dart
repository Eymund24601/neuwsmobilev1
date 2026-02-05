import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';

class QuizCategoriesPage extends ConsumerWidget {
  const QuizCategoriesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final repository = ref.watch(gamesRepositoryProvider);
    final categoriesAsync = ref.watch(quizCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Categories')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load quiz categories: $error'),
          ),
        ),
        data: (categories) {
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final category = categories[index];
              return Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: ListTile(
                  title: Text(category, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(
                    'Quiz set based on recent stories',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () async {
                    final quizzes = await repository.getQuizzesByCategory(category);
                    if (!context.mounted || quizzes.isEmpty) {
                      return;
                    }
                    context.pushNamed(
                      AppRouteName.quizPlay,
                      pathParameters: {'quizId': quizzes.first.id},
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

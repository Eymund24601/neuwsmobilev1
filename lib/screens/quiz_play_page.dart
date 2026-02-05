import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class QuizPlayPage extends ConsumerWidget {
  const QuizPlayPage({super.key, required this.quizId});

  final String quizId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final quizAsync = ref.watch(quizByIdProvider(quizId));

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load quiz: $error'),
          ),
        ),
        data: (quiz) {
          if (quiz == null) {
            return const Center(child: Text('Quiz not found.'));
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Text(quiz.title, style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 30)),
              const SizedBox(height: 8),
              Text(
                '${quiz.category} · ${quiz.difficulty} · ${quiz.estimatedMinutes} min',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Text(
                  'Quiz interaction scaffold is ready. Backend attempt saving will connect in the Supabase phase.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back to categories'),
              ),
            ],
          );
        },
      ),
    );
  }
}

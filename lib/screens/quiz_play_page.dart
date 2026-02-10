import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';

class QuizPlayPage extends ConsumerStatefulWidget {
  const QuizPlayPage({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizPlayPage> createState() => _QuizPlayPageState();
}

class _QuizPlayPageState extends ConsumerState<QuizPlayPage> {
  int _index = 0;
  int? _selected;
  int _correct = 0;
  bool _submitting = false;
  bool _finished = false;
  late final DateTime _startedAt;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
  }

  Future<void> _submitAttempt(int maxScore) async {
    if (_submitting) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref
          .read(gamesRepositoryProvider)
          .submitQuizAttempt(
            quizId: widget.quizId,
            score: _correct,
            maxScore: maxScore,
            duration: DateTime.now().difference(_startedAt),
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Quiz attempt submitted.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '$error';
      if (message.toLowerCase().contains('sign in required')) {
        context.pushNamed(AppRouteName.signIn);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit attempt: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final quizAsync = ref.watch(quizByIdProvider(widget.quizId));
    final lessonAsync = ref.watch(lessonProvider(widget.quizId));

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
          return lessonAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Could not load quiz questions: $error'),
              ),
            ),
            data: (lesson) {
              if (lesson == null || lesson.questions.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'No quiz questions are published for this quiz yet.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                  ),
                );
              }

              if (_finished) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Quiz complete',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Score: $_correct / ${lesson.questions.length}',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.muted),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _submitting
                              ? null
                              : () async {
                                  await _submitAttempt(lesson.questions.length);
                                },
                          child: Text(
                            _submitting ? 'Submitting...' : 'Submit Attempt',
                          ),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Back to categories'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final question = lesson.questions[_index];
              final progress = (_index + 1) / lesson.questions.length;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  Text(
                    quiz.title,
                    style: Theme.of(
                      context,
                    ).textTheme.displayMedium?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${quiz.category} | ${quiz.difficulty} | ${quiz.estimatedMinutes} min',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: palette.progressBg,
                      valueColor: AlwaysStoppedAnimation(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    question.prompt,
                    style: Theme.of(
                      context,
                    ).textTheme.headlineSmall?.copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < question.options.length; i++) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          side: BorderSide(
                            color: _selected == i
                                ? Theme.of(context).colorScheme.primary
                                : palette.border,
                          ),
                        ),
                        onPressed: () {
                          setState(() => _selected = i);
                        },
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(question.options[i]),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _selected == null
                        ? null
                        : () {
                            if (_selected == question.correctIndex) {
                              _correct++;
                            }

                            if (_index >= lesson.questions.length - 1) {
                              setState(() => _finished = true);
                            } else {
                              setState(() {
                                _index++;
                                _selected = null;
                              });
                            }
                          },
                    child: Text(
                      _index >= lesson.questions.length - 1
                          ? 'Finish Quiz'
                          : 'Next',
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

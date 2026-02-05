import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class LessonPage extends ConsumerStatefulWidget {
  const LessonPage({super.key, required this.lessonId});

  final String lessonId;

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;
  bool _finished = false;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final lessonAsync = ref.watch(lessonProvider(widget.lessonId));

    return Scaffold(
      appBar: AppBar(title: const Text('Lesson')),
      body: lessonAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load lesson: $error'),
          ),
        ),
        data: (lesson) {
          if (lesson == null) {
            return const Center(child: Text('Lesson not found.'));
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
                    Text('Lesson complete', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Text(
                      'You got $_correctCount / ${lesson.questions.length} correct.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Back to track'),
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
              Text(lesson.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: palette.progressBg,
                  valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
                ),
              ),
              const SizedBox(height: 20),
              Text(question.prompt, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 30)),
              const SizedBox(height: 16),
              for (var i = 0; i < question.options.length; i++) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      side: BorderSide(
                        color: _selected == i ? Theme.of(context).colorScheme.primary : palette.border,
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
                          _correctCount++;
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
                child: Text(_index >= lesson.questions.length - 1 ? 'Finish' : 'Next'),
              ),
            ],
          );
        },
      ),
    );
  }
}

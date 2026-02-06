import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../models/game_round.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_top_bar.dart';

class GamesPage extends ConsumerStatefulWidget {
  const GamesPage({super.key});

  @override
  ConsumerState<GamesPage> createState() => _GamesPageState();
}

class _GamesPageState extends ConsumerState<GamesPage> {
  int _selectedSkill = 1;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final sudokuAsync = ref.watch(sudokuSkillRoundsProvider);
    final eurodleAsync = ref.watch(eurodleRoundProvider);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        children: [
          const PrimaryTopBar(title: 'Puzzles'),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Text(
              'Backend-driven games',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontSize: 22),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _SudokuSection(
              selectedSkill: _selectedSkill,
              sudokuAsync: sudokuAsync,
              onSelectSkill: (value) => setState(() => _selectedSkill = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: _EurodleSection(eurodleAsync: eurodleAsync),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: FilledButton.tonalIcon(
              onPressed: () => context.pushNamed(AppRouteName.quizCategories),
              icon: const Icon(Icons.quiz_outlined),
              label: const Text('Open Quiz Categories'),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Text(
                'Sudoku and Eurodle now load from backend game rounds.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SudokuSection extends StatelessWidget {
  const _SudokuSection({
    required this.selectedSkill,
    required this.sudokuAsync,
    required this.onSelectSkill,
  });

  final int selectedSkill;
  final AsyncValue<List<SudokuRound>> sudokuAsync;
  final ValueChanged<int> onSelectSkill;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: sudokuAsync.when(
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => SizedBox(
          height: 120,
          child: Center(child: Text('Sudoku unavailable: $error')),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const SizedBox(
              height: 120,
              child: Center(child: Text('No Sudoku rounds available.')),
            );
          }
          final current = rounds.firstWhere(
            (round) => round.skillPoint == selectedSkill,
            orElse: () => rounds.first,
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sudoku', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Choose a skill point and load the active backend round.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rounds
                    .map(
                      (round) => ChoiceChip(
                        label: Text('S${round.skillPoint}'),
                        selected: round.skillPoint == current.skillPoint,
                        onSelected: (_) => onSelectSkill(round.skillPoint),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              _SudokuGridPreview(puzzle: current.puzzleGrid),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Difficulty: ${current.difficulty}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Loaded ${current.roundKey} from backend',
                          ),
                        ),
                      );
                    },
                    child: const Text('Play'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SudokuGridPreview extends StatelessWidget {
  const _SudokuGridPreview({required this.puzzle});

  final String puzzle;

  @override
  Widget build(BuildContext context) {
    final cleaned = puzzle.length >= 81
        ? puzzle.substring(0, 81)
        : puzzle.padRight(81, '0');
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return SizedBox(
      height: 210,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemCount: 81,
        itemBuilder: (context, index) {
          final char = cleaned[index];
          final value = char == '0' ? '' : char;
          return Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}

class _EurodleSection extends StatelessWidget {
  const _EurodleSection({required this.eurodleAsync});

  final AsyncValue<EurodleRound?> eurodleAsync;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: eurodleAsync.when(
        loading: () => const SizedBox(
          height: 110,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => SizedBox(
          height: 110,
          child: Center(child: Text('Eurodle unavailable: $error')),
        ),
        data: (round) {
          if (round == null) {
            return const SizedBox(
              height: 110,
              child: Center(child: Text('No Eurodle round available.')),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Eurodle', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${round.wordLength} letters · ${round.maxAttempts} attempts',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 10),
              Text(round.hint, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    'Round: ${round.roundKey}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Loaded ${round.roundKey} from backend',
                          ),
                        ),
                      );
                    },
                    child: const Text('Play'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

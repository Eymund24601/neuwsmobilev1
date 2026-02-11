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
      child: RefreshIndicator(
        onRefresh: _refreshRounds,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
          children: [
            const PrimaryTopBar(title: 'Puzzles'),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: _HeroCard(
                sudokuAsync: sudokuAsync,
                eurodleAsync: eurodleAsync,
                onPlaySudoku: () {
                  context.pushNamed(
                    AppRouteName.sudokuPlay,
                    queryParameters: {'skill': '$_selectedSkill'},
                  );
                },
                onPlayEurodle: () =>
                    context.pushNamed(AppRouteName.eurodlePlay),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: _SudokuLaunchCard(
                sudokuAsync: sudokuAsync,
                selectedSkill: _selectedSkill,
                onSelectSkill: (value) {
                  setState(() => _selectedSkill = value);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: _EurodleLaunchCard(eurodleAsync: eurodleAsync),
            ),
            const SizedBox(height: 10),
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
                  'Rounds are loaded from backend game tables and launched in dedicated play screens with session save/resume.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshRounds() async {
    await Future.wait([
      ref.read(sudokuSkillRoundsProvider.notifier).refresh(),
      ref.read(eurodleRoundProvider.notifier).refresh(),
    ]);
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.sudokuAsync,
    required this.eurodleAsync,
    required this.onPlaySudoku,
    required this.onPlayEurodle,
  });

  final AsyncValue<List<SudokuRound>> sudokuAsync;
  final AsyncValue<EurodleRound?> eurodleAsync;
  final VoidCallback onPlaySudoku;
  final VoidCallback onPlayEurodle;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final sudokuReady = sudokuAsync.valueOrNull?.isNotEmpty == true;
    final eurodleReady = eurodleAsync.valueOrNull != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
            palette.surfaceCard,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Puzzle Lab',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'Sharper gameplay with save/resume and dedicated puzzle screens.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: sudokuReady ? onPlaySudoku : null,
                  icon: const Icon(Icons.grid_4x4_rounded),
                  label: const Text('Play Sudoku'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: eurodleReady ? onPlayEurodle : null,
                  icon: const Icon(Icons.spellcheck),
                  label: const Text('Play Eurodle'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SudokuLaunchCard extends StatelessWidget {
  const _SudokuLaunchCard({
    required this.sudokuAsync,
    required this.selectedSkill,
    required this.onSelectSkill,
  });

  final AsyncValue<List<SudokuRound>> sudokuAsync;
  final int selectedSkill;
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
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => SizedBox(
          height: 110,
          child: Center(child: Text('Sudoku unavailable: $error')),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const SizedBox(
              height: 110,
              child: Center(child: Text('No Sudoku rounds available.')),
            );
          }
          final current = rounds.firstWhere(
            (round) => round.skillPoint == selectedSkill,
            orElse: () => rounds.first,
          );
          final skills =
              rounds.map((round) => round.skillPoint).toSet().toList()..sort();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sudoku', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Select a skill point and launch a full 9x9 playable board.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: skills.map((skill) {
                  return ChoiceChip(
                    label: Text('S$skill'),
                    selected: skill == current.skillPoint,
                    onSelected: (_) => onSelectSkill(skill),
                  );
                }).toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaChip(label: current.difficulty.toUpperCase()),
                  const SizedBox(width: 8),
                  _MetaChip(label: current.roundKey),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      context.pushNamed(
                        AppRouteName.sudokuPlay,
                        queryParameters: {'skill': '${current.skillPoint}'},
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

class _EurodleLaunchCard extends StatelessWidget {
  const _EurodleLaunchCard({required this.eurodleAsync});

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
                '${round.wordLength} letters • ${round.maxAttempts} attempts',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 10),
              Text(
                round.hint.isEmpty ? 'No hint provided.' : round.hint,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MetaChip(label: round.difficulty.toUpperCase()),
                  const SizedBox(width: 8),
                  _MetaChip(label: round.roundKey),
                  const Spacer(),
                  FilledButton(
                    onPressed: () =>
                        context.pushNamed(AppRouteName.eurodlePlay),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

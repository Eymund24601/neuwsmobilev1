import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_round.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../services/games/sudoku_engine.dart';
import '../theme/app_theme.dart';

class SudokuPlayPage extends ConsumerStatefulWidget {
  const SudokuPlayPage({super.key, this.initialSkillPoint = 1});

  final int initialSkillPoint;

  @override
  ConsumerState<SudokuPlayPage> createState() => _SudokuPlayPageState();
}

class _SudokuPlayPageState extends ConsumerState<SudokuPlayPage> {
  static const _saveDebounceDelay = Duration(milliseconds: 900);

  late int _selectedSkill;
  SudokuRound? _activeRound;
  List<int> _puzzle = List<int>.filled(SudokuEngine.cellCount, 0);
  List<int> _solution = List<int>.filled(SudokuEngine.cellCount, 0);
  List<int> _board = List<int>.filled(SudokuEngine.cellCount, 0);
  int _selectedIndex = 0;
  int _movesCount = 0;
  bool _completed = false;
  bool _hydratingSession = false;
  String? _sessionId;
  DateTime _startedAt = DateTime.now();
  Timer? _ticker;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
    _selectedSkill = _normalizeSkill(widget.initialSkillPoint);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _saveDebounce?.cancel();
    unawaited(_persistProgress(complete: false));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roundsAsync = ref.watch(sudokuSkillRoundsProvider);
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sudoku'),
        actions: [
          IconButton(
            tooltip: 'Reset board',
            onPressed: _completed ? null : _resetBoard,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: roundsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load Sudoku round: $error'),
          ),
        ),
        data: (rounds) {
          if (rounds.isEmpty) {
            return const Center(child: Text('No Sudoku rounds available.'));
          }

          final availableSkills =
              rounds.map((round) => round.skillPoint).toSet().toList()..sort();
          if (!availableSkills.contains(_selectedSkill)) {
            _selectedSkill = availableSkills.first;
          }
          final round = rounds.firstWhere(
            (candidate) => candidate.skillPoint == _selectedSkill,
            orElse: () => rounds.first,
          );
          _ensureRound(round);

          final filled = SudokuEngine.filledCount(_board);
          final progress = filled / SudokuEngine.cellCount;
          final related = SudokuEngine.relatedIndices(_selectedIndex);
          final selectedValue =
              (_selectedIndex >= 0 && _selectedIndex < _board.length)
              ? _board[_selectedIndex]
              : 0;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.18),
                      palette.surfaceCard,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Skill S${round.skillPoint} • ${round.difficulty.toUpperCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _completed
                          ? 'Puzzle solved. Great pace.'
                          : _hydratingSession
                          ? 'Restoring saved progress...'
                          : 'Fill every cell with no row, column, or box duplicates.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: progress,
                        backgroundColor: palette.progressBg,
                        valueColor: AlwaysStoppedAnimation(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '$filled/81 filled',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                        const Spacer(),
                        Text(
                          _formatElapsed(_elapsed),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: availableSkills.map((skill) {
                  return ChoiceChip(
                    label: Text('S$skill'),
                    selected: skill == _selectedSkill,
                    onSelected: _completed || _hydratingSession
                        ? null
                        : (_) {
                            setState(() {
                              _selectedSkill = skill;
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                padding: const EdgeInsets.all(10),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: SudokuEngine.cellCount,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 9,
                        ),
                    itemBuilder: (context, index) {
                      final row = index ~/ 9;
                      final col = index % 9;
                      final value = _board[index];
                      final fixed = SudokuEngine.isFixedCell(
                        puzzle: _puzzle,
                        index: index,
                      );
                      final selected = _selectedIndex == index;
                      final linked = related.contains(index);
                      final conflict = SudokuEngine.hasConflict(
                        board: _board,
                        index: index,
                      );
                      final isCorrect =
                          _completed &&
                          value > 0 &&
                          index < _solution.length &&
                          value == _solution[index];

                      Color background = palette.surface;
                      if (linked) {
                        background = palette.surfaceAlt;
                      }
                      if (selected) {
                        background = Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.22);
                      }
                      if (!selected && conflict && value > 0) {
                        background = Colors.red.withValues(alpha: 0.18);
                      }
                      if (!selected && isCorrect) {
                        background = Colors.green.withValues(alpha: 0.14);
                      }

                      final borderColor = conflict && value > 0
                          ? Colors.red.withValues(alpha: 0.8)
                          : palette.border;
                      final topWidth = row == 0
                          ? 1.5
                          : (row % 3 == 0 ? 1.2 : 0.45);
                      final leftWidth = col == 0
                          ? 1.5
                          : (col % 3 == 0 ? 1.2 : 0.45);
                      final rightWidth = col == 8
                          ? 1.5
                          : (col % 3 == 2 ? 1.2 : 0.45);
                      final bottomWidth = row == 8
                          ? 1.5
                          : (row % 3 == 2 ? 1.2 : 0.45);

                      return InkWell(
                        onTap: _completed
                            ? null
                            : () {
                                setState(() {
                                  _selectedIndex = index;
                                });
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: background,
                            border: Border(
                              top: BorderSide(
                                color: borderColor,
                                width: topWidth,
                              ),
                              left: BorderSide(
                                color: borderColor,
                                width: leftWidth,
                              ),
                              right: BorderSide(
                                color: borderColor,
                                width: rightWidth,
                              ),
                              bottom: BorderSide(
                                color: borderColor,
                                width: bottomWidth,
                              ),
                            ),
                          ),
                          child: Text(
                            value == 0 ? '' : '$value',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: fixed
                                      ? FontWeight.w800
                                      : FontWeight.w600,
                                  color: fixed
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(
                                          context,
                                        ).textTheme.bodyLarge?.color,
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: _checkBoard,
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: const Text('Check'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _completed ? null : _clearSelectedCell,
                      icon: const Icon(Icons.backspace_outlined),
                      label: const Text('Clear'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var value = 1; value <= 9; value++)
                    SizedBox(
                      width: 60,
                      height: 48,
                      child: FilledButton(
                        onPressed: _completed
                            ? null
                            : () => _setSelectedCellValue(value),
                        style: FilledButton.styleFrom(
                          backgroundColor: selectedValue == value
                              ? Theme.of(context).colorScheme.primary
                              : palette.surfaceCard,
                          foregroundColor: selectedValue == value
                              ? Colors.black
                              : Theme.of(context).textTheme.bodyLarge?.color,
                          side: BorderSide(color: palette.border),
                        ),
                        child: Text('$value'),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _ensureRound(SudokuRound round) {
    if (_activeRound?.id == round.id) {
      return;
    }

    _saveDebounce?.cancel();
    _activeRound = round;
    _puzzle = SudokuEngine.decodeGrid(round.puzzleGrid);
    _solution = SudokuEngine.decodeGrid(round.solutionGrid);
    _board = List<int>.from(_puzzle);
    _selectedIndex = _firstEditableIndex(_puzzle);
    _movesCount = 0;
    _completed = false;
    _sessionId = null;
    _hydratingSession = true;
    _startedAt = DateTime.now();
    unawaited(_hydrateSessionForRound(round));
  }

  Future<void> _hydrateSessionForRound(SudokuRound round) async {
    try {
      final session = await ref
          .read(gamesRepositoryProvider)
          .startOrResumeGameSession(
            gameSlug: 'sudoku',
            roundId: round.id,
            initialState: _buildSessionState(),
          );

      if (!mounted || _activeRound?.id != round.id) {
        return;
      }

      if (session != null) {
        _sessionId = session.id;
        final state = session.state;
        final boardRaw = state['board'];
        if (boardRaw is String && boardRaw.isNotEmpty) {
          final decoded = SudokuEngine.decodeGrid(boardRaw);
          _board = _mergedBoardWithPuzzle(decoded);
        }

        _movesCount = _coerceInt(
          state['moves_count'],
          fallback: session.movesCount,
        );
        final elapsedMs = _coerceInt(
          state['elapsed_ms'],
          fallback: session.durationMs,
        );
        _startedAt = DateTime.now().subtract(
          Duration(milliseconds: elapsedMs < 0 ? 0 : elapsedMs),
        );
        _completed = SudokuEngine.isSolved(board: _board, solution: _solution);
      }
    } catch (_) {
      // Keep the puzzle playable even if session restore fails.
    } finally {
      if (mounted && _activeRound?.id == round.id) {
        setState(() {
          _hydratingSession = false;
        });
      }
    }
  }

  List<int> _mergedBoardWithPuzzle(List<int> candidate) {
    final merged = List<int>.from(_puzzle);
    final limit = candidate.length < merged.length
        ? candidate.length
        : merged.length;
    for (var i = 0; i < limit; i++) {
      if (_puzzle[i] == 0) {
        merged[i] = candidate[i];
      }
    }
    return merged;
  }

  void _setSelectedCellValue(int value) {
    if (_completed || _hydratingSession) {
      return;
    }
    if (_selectedIndex < 0 || _selectedIndex >= _board.length) {
      return;
    }
    if (SudokuEngine.isFixedCell(puzzle: _puzzle, index: _selectedIndex)) {
      return;
    }

    setState(() {
      _board[_selectedIndex] = value;
      _movesCount += 1;
    });

    if (SudokuEngine.isSolved(board: _board, solution: _solution)) {
      unawaited(_finishPuzzle());
      return;
    }
    _scheduleProgressPersist();
  }

  void _clearSelectedCell() {
    if (_selectedIndex < 0 || _selectedIndex >= _board.length) {
      return;
    }
    if (SudokuEngine.isFixedCell(puzzle: _puzzle, index: _selectedIndex)) {
      return;
    }
    setState(() {
      _board[_selectedIndex] = 0;
      _movesCount += 1;
    });
    _scheduleProgressPersist();
  }

  void _resetBoard() {
    setState(() {
      _board = List<int>.from(_puzzle);
      _selectedIndex = _firstEditableIndex(_puzzle);
      _movesCount = 0;
      _completed = false;
      _startedAt = DateTime.now();
    });
    _scheduleProgressPersist();
  }

  Future<void> _finishPuzzle() async {
    if (_completed) {
      return;
    }
    setState(() {
      _completed = true;
    });
    await _persistProgress(complete: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Sudoku solved. Session saved.')),
    );
  }

  void _checkBoard() {
    if (_completed) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sudoku already solved.')));
      return;
    }
    if (SudokuEngine.hasAnyConflict(_board)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('There are conflicting numbers.')),
      );
      return;
    }
    final remaining = SudokuEngine.cellCount - SudokuEngine.filledCount(_board);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$remaining cells left. Keep going.')),
    );
  }

  void _scheduleProgressPersist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(_saveDebounceDelay, () {
      unawaited(_persistProgress(complete: false));
    });
  }

  Future<void> _persistProgress({required bool complete}) async {
    final sessionId = _sessionId;
    if (sessionId == null || sessionId.isEmpty) {
      return;
    }
    final elapsed = _elapsed;
    final state = _buildSessionState();
    if (complete) {
      final maxScore = 1000;
      final penalty = elapsed.inSeconds + (_movesCount * 2);
      var score = maxScore - penalty;
      if (score < 100) {
        score = 100;
      }
      await ref
          .read(gamesRepositoryProvider)
          .completeGameSession(
            sessionId: sessionId,
            score: score,
            maxScore: maxScore,
            movesCount: _movesCount,
            elapsed: elapsed,
            state: state,
          );
      return;
    }

    await ref
        .read(gamesRepositoryProvider)
        .saveGameSessionProgress(
          sessionId: sessionId,
          movesCount: _movesCount,
          elapsed: elapsed,
          state: state,
        );
  }

  Map<String, dynamic> _buildSessionState() {
    return {
      'board': SudokuEngine.encodeGrid(_board),
      'moves_count': _movesCount,
      'elapsed_ms': _elapsed.inMilliseconds,
      'selected_skill': _selectedSkill,
      'round_key': _activeRound?.roundKey ?? '',
      'completed': _completed,
    };
  }

  Duration get _elapsed {
    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed.isNegative) {
      return Duration.zero;
    }
    return elapsed;
  }

  int _firstEditableIndex(List<int> puzzle) {
    for (var i = 0; i < puzzle.length; i++) {
      if (puzzle[i] == 0) {
        return i;
      }
    }
    return 0;
  }

  int _normalizeSkill(int raw) {
    if (raw < 1) {
      return 1;
    }
    if (raw > 5) {
      return 5;
    }
    return raw;
  }

  int _coerceInt(Object? raw, {required int fallback}) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.toInt();
    }
    if (raw is String) {
      return int.tryParse(raw) ?? fallback;
    }
    return fallback;
  }

  String _formatElapsed(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

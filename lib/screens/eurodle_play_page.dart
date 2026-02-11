import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/game_round.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../services/games/eurodle_engine.dart';
import '../theme/app_theme.dart';

class EurodlePlayPage extends ConsumerStatefulWidget {
  const EurodlePlayPage({super.key});

  @override
  ConsumerState<EurodlePlayPage> createState() => _EurodlePlayPageState();
}

class _EurodlePlayPageState extends ConsumerState<EurodlePlayPage> {
  static const _saveDebounceDelay = Duration(milliseconds: 700);
  static const List<String> _rowOne = [
    'q',
    'w',
    'e',
    'r',
    't',
    'y',
    'u',
    'i',
    'o',
    'p',
  ];
  static const List<String> _rowTwo = [
    'a',
    's',
    'd',
    'f',
    'g',
    'h',
    'j',
    'k',
    'l',
  ];
  static const List<String> _rowThree = ['z', 'x', 'c', 'v', 'b', 'n', 'm'];

  EurodleRound? _activeRound;
  List<EurodleGuessFeedback> _history = const [];
  String _draftGuess = '';
  Map<String, EurodleLetterState> _keyboardState = const {};
  bool _finished = false;
  bool _won = false;
  bool _hydratingSession = false;
  String? _sessionId;
  DateTime _startedAt = DateTime.now();
  Timer? _ticker;
  Timer? _saveDebounce;

  @override
  void initState() {
    super.initState();
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
    final roundAsync = ref.watch(eurodleRoundProvider);
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Eurodle'),
        actions: [
          IconButton(
            tooltip: 'Restart',
            onPressed: _activeRound == null || _hydratingSession
                ? null
                : _restartRound,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: roundAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load Eurodle round: $error'),
          ),
        ),
        data: (round) {
          if (round == null) {
            return const Center(child: Text('No Eurodle round available.'));
          }
          _ensureRound(round);

          final attemptsUsed = _history.length;
          final attemptsLeft = round.maxAttempts - attemptsUsed;
          final progress = round.maxAttempts == 0
              ? 0.0
              : attemptsUsed / round.maxAttempts;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
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
                      '${round.wordLength} letters • ${round.maxAttempts} attempts',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      round.hint.isEmpty ? 'No hint provided.' : round.hint,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
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
                          attemptsLeft < 0
                              ? '0 attempts left'
                              : '$attemptsLeft attempts left',
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
              _StatusCard(
                text: _statusText(round),
                finished: _finished,
                won: _won,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: List<Widget>.generate(round.maxAttempts, (row) {
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: row == round.maxAttempts - 1 ? 0 : 6,
                      ),
                      child: _GuessRow(
                        letters: _lettersForRow(round, row),
                        states: _statesForRow(round, row),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              _KeyboardRow(
                letters: _rowOne,
                keyboardState: _keyboardState,
                onLetter: _appendLetter,
              ),
              const SizedBox(height: 6),
              _KeyboardRow(
                letters: _rowTwo,
                keyboardState: _keyboardState,
                onLetter: _appendLetter,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  SizedBox(
                    width: 74,
                    child: FilledButton(
                      onPressed: _finished || _hydratingSession
                          ? null
                          : () => _submitGuess(round),
                      child: const Text('Enter'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _KeyboardRow(
                      letters: _rowThree,
                      keyboardState: _keyboardState,
                      onLetter: _appendLetter,
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 64,
                    child: FilledButton.tonal(
                      onPressed: _finished || _hydratingSession
                          ? null
                          : _removeLetter,
                      child: const Icon(Icons.backspace_outlined),
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

  void _ensureRound(EurodleRound round) {
    if (_activeRound?.id == round.id) {
      return;
    }

    _saveDebounce?.cancel();
    _activeRound = round;
    _history = const [];
    _draftGuess = '';
    _keyboardState = const {};
    _finished = false;
    _won = false;
    _sessionId = null;
    _hydratingSession = true;
    _startedAt = DateTime.now();
    unawaited(_hydrateSession(round));
  }

  Future<void> _hydrateSession(EurodleRound round) async {
    try {
      final session = await ref
          .read(gamesRepositoryProvider)
          .startOrResumeGameSession(
            gameSlug: 'eurodle',
            roundId: round.id,
            initialState: _buildSessionState(),
          );
      if (!mounted || _activeRound?.id != round.id) {
        return;
      }
      if (session != null) {
        _sessionId = session.id;
        final state = session.state;

        final restoredHistory = <EurodleGuessFeedback>[];
        final guessesRaw = state['guesses'];
        if (guessesRaw is List) {
          for (final raw in guessesRaw) {
            final guess = EurodleEngine.normalizeWord('$raw');
            if (!EurodleEngine.isAlphabeticWord(
              guess,
              expectedLength: round.wordLength,
            )) {
              continue;
            }
            restoredHistory.add(
              EurodleEngine.evaluateGuess(
                guess: guess,
                targetWord: round.targetWord,
              ),
            );
          }
        }
        _history = restoredHistory;

        final draftRaw = state['draft_guess'];
        if (draftRaw is String &&
            EurodleEngine.normalizeWord(draftRaw).length <= round.wordLength) {
          _draftGuess = EurodleEngine.normalizeWord(draftRaw);
        }

        final keyboardRaw = state['keyboard_state'];
        if (keyboardRaw is Map) {
          final next = <String, EurodleLetterState>{};
          for (final entry in keyboardRaw.entries) {
            final key = EurodleEngine.normalizeWord('${entry.key}');
            if (key.length != 1) {
              continue;
            }
            next[key] = _letterStateFromString('${entry.value}');
          }
          _keyboardState = next;
        } else {
          var next = <String, EurodleLetterState>{};
          for (final feedback in _history) {
            next = EurodleEngine.mergeKeyboardState(
              current: next,
              feedback: feedback,
            );
          }
          _keyboardState = next;
        }

        final elapsedMs = _coerceInt(
          state['elapsed_ms'],
          fallback: session.durationMs,
        );
        _startedAt = DateTime.now().subtract(
          Duration(milliseconds: elapsedMs < 0 ? 0 : elapsedMs),
        );

        _won = _history.any((feedback) => feedback.isWin);
        _finished =
            _won ||
            _history.length >= round.maxAttempts ||
            (state['finished'] == true);
      }
    } catch (_) {
      // Keep gameplay responsive if restore fails.
    } finally {
      if (mounted && _activeRound?.id == round.id) {
        setState(() {
          _hydratingSession = false;
        });
      }
    }
  }

  List<String> _lettersForRow(EurodleRound round, int row) {
    if (row < _history.length) {
      return _history[row].guess.split('');
    }
    if (!_finished && row == _history.length) {
      final chars = _draftGuess.split('');
      while (chars.length < round.wordLength) {
        chars.add('');
      }
      return chars;
    }
    return List<String>.filled(round.wordLength, '');
  }

  List<EurodleLetterState> _statesForRow(EurodleRound round, int row) {
    if (row < _history.length) {
      return _history[row].states;
    }
    return List<EurodleLetterState>.filled(
      round.wordLength,
      EurodleLetterState.unknown,
    );
  }

  String _statusText(EurodleRound round) {
    if (_hydratingSession) {
      return 'Restoring saved progress...';
    }
    if (_finished && _won) {
      return 'Solved in ${_history.length} attempt${_history.length == 1 ? '' : 's'}.';
    }
    if (_finished && !_won) {
      return 'Round failed. The target word was "${round.targetWord.toUpperCase()}".';
    }
    return 'Type a ${round.wordLength}-letter guess, then press Enter.';
  }

  void _appendLetter(String letter) {
    final round = _activeRound;
    if (round == null || _finished || _hydratingSession) {
      return;
    }
    if (_draftGuess.length >= round.wordLength) {
      return;
    }
    if (!RegExp(r'^[a-z]$').hasMatch(letter)) {
      return;
    }
    setState(() {
      _draftGuess = '$_draftGuess${letter.toLowerCase()}';
    });
    _schedulePersist();
  }

  void _removeLetter() {
    if (_finished || _hydratingSession || _draftGuess.isEmpty) {
      return;
    }
    setState(() {
      _draftGuess = _draftGuess.substring(0, _draftGuess.length - 1);
    });
    _schedulePersist();
  }

  Future<void> _submitGuess(EurodleRound round) async {
    if (_finished || _hydratingSession) {
      return;
    }
    final guess = EurodleEngine.normalizeWord(_draftGuess);
    if (!EurodleEngine.isAlphabeticWord(
      guess,
      expectedLength: round.wordLength,
    )) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guess must be ${round.wordLength} letters.')),
      );
      return;
    }

    if (_shouldEnforceAllowedWords(round) &&
        !round.allowedWords.contains(guess)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Word not in allowed list for this round.'),
        ),
      );
      return;
    }

    final feedback = EurodleEngine.evaluateGuess(
      guess: guess,
      targetWord: round.targetWord,
    );
    final updatedKeyboard = EurodleEngine.mergeKeyboardState(
      current: _keyboardState,
      feedback: feedback,
    );
    final updatedHistory = [..._history, feedback];
    final isWin = feedback.isWin;
    final finished = isWin || updatedHistory.length >= round.maxAttempts;

    setState(() {
      _history = updatedHistory;
      _keyboardState = updatedKeyboard;
      _draftGuess = '';
      _won = isWin;
      _finished = finished;
    });

    if (finished) {
      await _persistProgress(complete: true);
      if (!mounted) {
        return;
      }
      final message = isWin
          ? 'Eurodle solved.'
          : 'Round finished. Word: ${round.targetWord.toUpperCase()}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    _schedulePersist();
  }

  bool _shouldEnforceAllowedWords(EurodleRound round) {
    if (round.allowedWords.length < 12) {
      return false;
    }
    return true;
  }

  void _restartRound() {
    final round = _activeRound;
    if (round == null) {
      return;
    }
    setState(() {
      _history = const [];
      _draftGuess = '';
      _keyboardState = const {};
      _finished = false;
      _won = false;
      _startedAt = DateTime.now();
    });
    _schedulePersist();
  }

  void _schedulePersist() {
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
      final maxScore = 500;
      final attemptPenalty = (_history.length - 1).clamp(0, 10) * 40;
      final timePenalty = elapsed.inSeconds ~/ 2;
      var score = _won ? (maxScore - attemptPenalty - timePenalty) : 0;
      if (_won && score < 60) {
        score = 60;
      }

      await ref
          .read(gamesRepositoryProvider)
          .completeGameSession(
            sessionId: sessionId,
            score: score,
            maxScore: maxScore,
            movesCount: _history.length,
            elapsed: elapsed,
            state: state,
          );
      return;
    }

    await ref
        .read(gamesRepositoryProvider)
        .saveGameSessionProgress(
          sessionId: sessionId,
          movesCount: _history.length,
          elapsed: elapsed,
          state: state,
        );
  }

  Map<String, dynamic> _buildSessionState() {
    return {
      'guesses': _history.map((item) => item.guess).toList(),
      'draft_guess': _draftGuess,
      'keyboard_state': _keyboardState.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'elapsed_ms': _elapsed.inMilliseconds,
      'finished': _finished,
      'won': _won,
      'round_key': _activeRound?.roundKey ?? '',
    };
  }

  Duration get _elapsed {
    final elapsed = DateTime.now().difference(_startedAt);
    if (elapsed.isNegative) {
      return Duration.zero;
    }
    return elapsed;
  }

  String _formatElapsed(Duration elapsed) {
    final totalSeconds = elapsed.inSeconds;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  EurodleLetterState _letterStateFromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    for (final state in EurodleLetterState.values) {
      if (state.name == normalized) {
        return state;
      }
    }
    return EurodleLetterState.unknown;
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
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.text,
    required this.finished,
    required this.won,
  });

  final String text;
  final bool finished;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final color = !finished
        ? palette.surfaceCard
        : won
        ? Colors.green.withValues(alpha: 0.15)
        : Colors.red.withValues(alpha: 0.15);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Text(text),
    );
  }
}

class _GuessRow extends StatelessWidget {
  const _GuessRow({required this.letters, required this.states});

  final List<String> letters;
  final List<EurodleLetterState> states;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Row(
      children: List<Widget>.generate(letters.length, (index) {
        final state = index < states.length
            ? states[index]
            : EurodleLetterState.unknown;
        Color bg = palette.surface;
        Color fg = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
        if (state == EurodleLetterState.correct) {
          bg = const Color(0xFF4CAF50).withValues(alpha: 0.86);
          fg = Colors.white;
        } else if (state == EurodleLetterState.present) {
          bg = const Color(0xFFF29D38).withValues(alpha: 0.9);
          fg = Colors.black;
        } else if (state == EurodleLetterState.absent) {
          bg = const Color(0xFF5F5F5F).withValues(alpha: 0.72);
          fg = Colors.white;
        }
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: index == letters.length - 1 ? 0 : 6),
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              letters[index].toUpperCase(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _KeyboardRow extends StatelessWidget {
  const _KeyboardRow({
    required this.letters,
    required this.keyboardState,
    required this.onLetter,
  });

  final List<String> letters;
  final Map<String, EurodleLetterState> keyboardState;
  final ValueChanged<String> onLetter;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Row(
      children: letters.map((letter) {
        final state = keyboardState[letter] ?? EurodleLetterState.unknown;
        Color bg = palette.surfaceCard;
        Color fg = Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white;
        if (state == EurodleLetterState.correct) {
          bg = const Color(0xFF4CAF50).withValues(alpha: 0.82);
          fg = Colors.white;
        } else if (state == EurodleLetterState.present) {
          bg = const Color(0xFFF29D38).withValues(alpha: 0.9);
          fg = Colors.black;
        } else if (state == EurodleLetterState.absent) {
          bg = const Color(0xFF707070).withValues(alpha: 0.68);
          fg = Colors.white;
        }
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: letter == letters.last ? 0 : 4),
            child: SizedBox(
              height: 44,
              child: FilledButton(
                onPressed: () => onLetter(letter),
                style: FilledButton.styleFrom(
                  backgroundColor: bg,
                  foregroundColor: fg,
                  side: BorderSide(color: palette.border),
                ),
                child: Text(letter.toUpperCase()),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

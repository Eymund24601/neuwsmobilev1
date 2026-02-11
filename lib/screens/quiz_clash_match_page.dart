import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_routes.dart';
import '../models/quiz_clash_models.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';

class QuizClashMatchPage extends ConsumerStatefulWidget {
  const QuizClashMatchPage({super.key, required this.matchId});

  final String matchId;

  @override
  ConsumerState<QuizClashMatchPage> createState() => _QuizClashMatchPageState();
}

class _QuizClashMatchPageState extends ConsumerState<QuizClashMatchPage> {
  final _client = Supabase.instance.client;
  static const Set<String> _knownBotUsernames = {
    'annameyer',
    'lukasbrenner',
    'leanovak',
    'miguelsousa',
    'sofiarosen',
  };

  RealtimeChannel? _matchChannel;
  Timer? _realtimeDebounce;
  Timer? _questionTimer;
  Timer? _botPollTimer;

  int _currentQuestionIndex = 0;
  int _secondsLeft = 20;
  DateTime? _questionStartedAt;
  List<int?> _answers = const [];
  List<int> _durationsMs = const [];
  bool _submitting = false;
  String? _selectedCategoryId;
  String _questionSessionKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bindRealtime();
    });
  }

  @override
  void dispose() {
    _questionTimer?.cancel();
    _botPollTimer?.cancel();
    _realtimeDebounce?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(quizClashTurnStateProvider(widget.matchId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Clash Match'),
        actions: [
          IconButton(
            onPressed: _submitting ? null : _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load match: $error'),
          ),
        ),
        data: (turnState) {
          if (turnState == null) {
            return const Center(child: Text('Match not found.'));
          }

          _syncQuestionState(turnState);
          _syncBotPolling(turnState);

          final now = DateTime.now();
          final deadlineExpired =
              turnState.turnDeadlineAt != null &&
              now.isAfter(turnState.turnDeadlineAt!);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _HeaderCard(
                  turnState: turnState,
                  deadlineLabel: _deadlineLabel(turnState.turnDeadlineAt),
                  onMessage: turnState.canMessageOpponent
                      ? () => _openMessageThread(turnState)
                      : null,
                ),
                const SizedBox(height: 12),
                if (turnState.status != 'active')
                  _InfoCard(
                    text:
                        'Match finished with status: ${turnState.status.toUpperCase()}.',
                  )
                else if (!turnState.isMyTurn) ...[
                  _InfoCard(
                    text: deadlineExpired
                        ? 'Turn timed out. Claim forfeit now.'
                        : 'Waiting for ${turnState.opponentDisplayName} to play.',
                  ),
                  if (deadlineExpired) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _submitting ? null : _claimForfeit,
                      icon: const Icon(Icons.gavel_outlined),
                      label: Text(
                        _submitting ? 'Claiming...' : 'Claim Forfeit',
                      ),
                    ),
                  ],
                ] else if (turnState.isAwaitingCategoryPick)
                  _buildCategoryPick(turnState)
                else if (turnState.isAwaitingAnswerSubmission)
                  _buildQuestionFlow(turnState)
                else
                  const _InfoCard(
                    text: 'Waiting for round state update. Pull to refresh.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCategoryPick(QuizClashTurnState turnState) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${turnState.roundIndex}/${turnState.totalRounds} | Pick category',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Choose one category to generate 3 questions for both players.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: turnState.categoryOptions
                .map(
                  (category) => ChoiceChip(
                    label: Text(category.name),
                    selected: _selectedCategoryId == category.id,
                    onSelected: (_) {
                      setState(() => _selectedCategoryId = category.id);
                    },
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _selectedCategoryId == null || _submitting
                ? null
                : _pickCategory,
            child: Text(_submitting ? 'Starting...' : 'Start Round'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionFlow(QuizClashTurnState turnState) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    if (turnState.questions.isEmpty) {
      return const _InfoCard(text: 'No questions found for this round.');
    }

    if (_currentQuestionIndex >= turnState.questions.length) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit Round',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Answers are locked after submission.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submitting ? null : () => _submitAnswers(turnState),
              icon: const Icon(Icons.lock_outline),
              label: Text(_submitting ? 'Submitting...' : 'Submit Turn'),
            ),
          ],
        ),
      );
    }

    final question = turnState.questions[_currentQuestionIndex];
    final selectedAnswer = _answers[_currentQuestionIndex];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Round ${turnState.roundIndex}/${turnState.totalRounds} | ${turnState.selectedCategoryName ?? 'Category'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value:
                        (_currentQuestionIndex + 1) /
                        turnState.questions.length,
                    minHeight: 6,
                    backgroundColor: palette.progressBg,
                    valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$_secondsLeft s',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _secondsLeft <= 5
                      ? Colors.redAccent
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(question.prompt, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (var i = 0; i < question.options.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () {
                  setState(() => _answers[_currentQuestionIndex] = i + 1);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  side: BorderSide(
                    color: selectedAnswer == i + 1
                        ? Theme.of(context).colorScheme.primary
                        : palette.border,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(question.options[i]),
                ),
              ),
            ),
          ],
          const SizedBox(height: 4),
          FilledButton(
            onPressed: _submitting ? null : _nextQuestion,
            child: Text(
              _currentQuestionIndex >= turnState.questions.length - 1
                  ? 'Review Answers'
                  : 'Next Question',
            ),
          ),
        ],
      ),
    );
  }

  void _syncQuestionState(QuizClashTurnState turnState) {
    if (!turnState.isAwaitingAnswerSubmission || turnState.questions.isEmpty) {
      _questionTimer?.cancel();
      _questionSessionKey = '';
      return;
    }

    final nextKey =
        '${turnState.roundIndex}:${turnState.selectedCategoryId}:${turnState.isPickerTurn}';
    final expectedLength = turnState.questions.length;
    if (_questionSessionKey != nextKey ||
        _answers.length != expectedLength ||
        _durationsMs.length != expectedLength) {
      _questionSessionKey = nextKey;
      _answers = List<int?>.filled(expectedLength, null);
      _durationsMs = List<int>.filled(expectedLength, 0);
      _currentQuestionIndex = 0;
      _startQuestionTimer();
      return;
    }

    if (_questionTimer == null || !_questionTimer!.isActive) {
      _startQuestionTimer();
    }
  }

  void _syncBotPolling(QuizClashTurnState turnState) {
    final shouldPoll =
        turnState.status == 'active' &&
        !turnState.isMyTurn &&
        _isLikelyBotOpponent(turnState);

    if (!shouldPoll) {
      _botPollTimer?.cancel();
      _botPollTimer = null;
      return;
    }

    if (_botPollTimer != null && _botPollTimer!.isActive) {
      return;
    }

    _botPollTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_submitting) {
        return;
      }
      _refresh();
    });
  }

  bool _isLikelyBotOpponent(QuizClashTurnState turnState) {
    final username = turnState.opponentUsername.trim().toLowerCase();
    return _knownBotUsernames.contains(username);
  }

  void _startQuestionTimer() {
    _questionTimer?.cancel();
    _secondsLeft = 20;
    _questionStartedAt = DateTime.now();
    _questionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        timer.cancel();
        _nextQuestion();
        return;
      }
      setState(() => _secondsLeft -= 1);
    });
  }

  void _nextQuestion() {
    final started = _questionStartedAt;
    if (started != null && _currentQuestionIndex < _durationsMs.length) {
      _durationsMs[_currentQuestionIndex] = DateTime.now()
          .difference(started)
          .inMilliseconds;
    }

    if (_currentQuestionIndex >= _answers.length - 1) {
      _questionTimer?.cancel();
      setState(() => _currentQuestionIndex = _answers.length);
      return;
    }

    setState(() => _currentQuestionIndex += 1);
    _startQuestionTimer();
  }

  Future<void> _pickCategory() async {
    final selectedCategory = _selectedCategoryId;
    final turnState = ref
        .read(quizClashTurnStateProvider(widget.matchId))
        .valueOrNull;
    if (turnState == null || selectedCategory == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(gamesRepositoryProvider)
          .pickQuizClashCategory(
            matchId: turnState.matchId,
            roundIndex: turnState.roundIndex,
            selectedCategoryId: selectedCategory,
          );
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not pick category: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitAnswers(QuizClashTurnState turnState) async {
    if (_submitting) {
      return;
    }

    final answers = _answers.map((value) => value ?? 0).toList();
    final durations = _durationsMs
        .map((value) => value <= 0 ? 1 : value)
        .toList();

    setState(() => _submitting = true);
    try {
      if (turnState.isPickerTurn) {
        await ref
            .read(gamesRepositoryProvider)
            .submitQuizClashPickerTurn(
              matchId: turnState.matchId,
              roundIndex: turnState.roundIndex,
              answers: answers,
              answerDurationsMs: durations,
            );
      } else {
        await ref
            .read(gamesRepositoryProvider)
            .submitQuizClashResponderTurn(
              matchId: turnState.matchId,
              roundIndex: turnState.roundIndex,
              answers: answers,
              answerDurationsMs: durations,
            );
      }
      if (!mounted) {
        return;
      }
      _questionTimer?.cancel();
      _answers = const [];
      _durationsMs = const [];
      _questionSessionKey = '';
      _currentQuestionIndex = 0;
      _selectedCategoryId = null;
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit answers: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _openMessageThread(QuizClashTurnState turnState) async {
    try {
      final threadId = await ref
          .read(communityRepositoryProvider)
          .createOrGetDmThread(turnState.opponentUserId);
      if (!mounted) {
        return;
      }
      if (threadId == null || threadId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open conversation.')),
        );
        return;
      }
      context.pushNamed(
        AppRouteName.messageThread,
        pathParameters: {'threadId': threadId},
        extra: turnState.opponentDisplayName,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open messages: $error')),
      );
    }
  }

  Future<void> _claimForfeit() async {
    setState(() => _submitting = true);
    try {
      await ref
          .read(gamesRepositoryProvider)
          .claimQuizClashTimeoutForfeit(widget.matchId);
      if (!mounted) {
        return;
      }
      await _refresh();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not claim forfeit: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _refresh() async {
    await ref
        .read(quizClashTurnStateProvider(widget.matchId).notifier)
        .refresh();
    await ref.read(quizClashMatchesProvider.notifier).refresh();
    await ref.read(quizClashInvitesProvider.notifier).refresh();
  }

  String _deadlineLabel(DateTime? deadlineAt) {
    if (deadlineAt == null) {
      return 'No deadline';
    }
    final diff = deadlineAt.difference(DateTime.now());
    if (diff.isNegative) {
      return 'Expired';
    }
    if (diff.inHours >= 1) {
      return '${diff.inHours}h left';
    }
    final mins = diff.inMinutes;
    if (mins > 0) {
      return '${mins}m left';
    }
    return 'Less than 1m';
  }

  void _bindRealtime() {
    if (_matchChannel != null || _client.auth.currentSession == null) {
      return;
    }

    _matchChannel = _client
        .channel('public:quiz_clash:${widget.matchId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: widget.matchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_rounds',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'match_id',
            value: widget.matchId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .subscribe();
  }

  void _unbindRealtime() {
    final channel = _matchChannel;
    if (channel != null) {
      _client.removeChannel(channel);
      _matchChannel = null;
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      _refresh();
    });
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.turnState,
    required this.deadlineLabel,
    required this.onMessage,
  });

  final QuizClashTurnState turnState;
  final String deadlineLabel;
  final VoidCallback? onMessage;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  turnState.opponentDisplayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: turnState.isMyTurn
                      ? Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.14)
                      : palette.surfaceAlt,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  turnState.isMyTurn ? 'Your turn' : 'Waiting',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Round ${turnState.roundIndex}/${turnState.totalRounds} | Score ${turnState.scoreMe}/${turnState.totalRounds * 3} vs ${turnState.scoreOpponent}/${turnState.totalRounds * 3}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Turn deadline: $deadlineLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onMessage,
            icon: const Icon(Icons.chat_bubble_outline),
            label: Text(
              onMessage == null
                  ? 'Message Locked (mutual follow required)'
                  : 'Message Opponent',
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Text(text),
    );
  }
}

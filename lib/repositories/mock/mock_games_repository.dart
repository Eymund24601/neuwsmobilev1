import 'dart:math';

import '../../models/game_round.dart';
import '../../models/game_session.dart';
import '../../models/quiz_clash_models.dart';
import '../../models/quiz_summary.dart';
import '../games_repository.dart';

class MockGamesRepository implements GamesRepository {
  static final Random _random = Random();
  static const List<QuizClashCategoryOption> _defaultCategoryOptions = [
    QuizClashCategoryOption(
      id: 'cat-geography',
      slug: 'geography',
      name: 'Geography',
    ),
    QuizClashCategoryOption(
      id: 'cat-science',
      slug: 'science',
      name: 'Science',
    ),
    QuizClashCategoryOption(
      id: 'cat-politics',
      slug: 'politics',
      name: 'Politics',
    ),
  ];
  static const List<_MockBotProfile> _mockBots = [
    _MockBotProfile(
      userId: 'u-bot-anna',
      displayName: 'Anna Meyer',
      username: 'annameyer',
    ),
    _MockBotProfile(
      userId: 'u-bot-lukas',
      displayName: 'Lukas Brenner',
      username: 'lukasbrenner',
    ),
    _MockBotProfile(
      userId: 'u-bot-lea',
      displayName: 'Lea Novak',
      username: 'leanovak',
    ),
    _MockBotProfile(
      userId: 'u-bot-miguel',
      displayName: 'Miguel Sousa',
      username: 'miguelsousa',
    ),
    _MockBotProfile(
      userId: 'u-bot-sofia',
      displayName: 'Sofia Rosen',
      username: 'sofiarosen',
    ),
  ];

  static const _questionBankByCategory = {
    'cat-geography': [
      QuizClashQuestion(
        id: 'q-geo-1',
        prompt: 'What is the capital of Canada?',
        options: ['Toronto', 'Ottawa', 'Vancouver', 'Montreal'],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-geo-2',
        prompt: 'Which river runs through Paris?',
        options: ['Danube', 'Thames', 'Seine', 'Rhine'],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-geo-3',
        prompt: 'Which country has the city of Porto?',
        options: ['Spain', 'Portugal', 'Italy', 'Belgium'],
        timeLimitSeconds: 20,
      ),
    ],
    'cat-science': [
      QuizClashQuestion(
        id: 'q-sci-1',
        prompt: 'Which planet is called the Red Planet?',
        options: ['Venus', 'Mars', 'Jupiter', 'Mercury'],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-sci-2',
        prompt: 'What gas do humans primarily breathe in?',
        options: ['Nitrogen', 'Carbon Dioxide', 'Oxygen', 'Hydrogen'],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-sci-3',
        prompt: 'How many bones are in the adult human body?',
        options: ['206', '186', '226', '196'],
        timeLimitSeconds: 20,
      ),
    ],
    'cat-politics': [
      QuizClashQuestion(
        id: 'q-pol-1',
        prompt: 'Which institution proposes EU legislation?',
        options: ['Commission', 'Parliament', 'Council', 'Court'],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-pol-2',
        prompt: 'How often are EU Parliament elections held?',
        options: [
          'Every 2 years',
          'Every 3 years',
          'Every 4 years',
          'Every 5 years',
        ],
        timeLimitSeconds: 20,
      ),
      QuizClashQuestion(
        id: 'q-pol-3',
        prompt: 'Which city hosts many EU institutions?',
        options: ['Brussels', 'Madrid', 'Prague', 'Oslo'],
        timeLimitSeconds: 20,
      ),
    ],
  };

  static const _quizzes = [
    QuizSummary(
      id: 'quiz-1',
      title: 'Capitals Sprint',
      category: 'Geography',
      difficulty: 'Easy',
      estimatedMinutes: 3,
      isPremium: false,
    ),
    QuizSummary(
      id: 'quiz-2',
      title: 'EU Institutions Blitz',
      category: 'Politics',
      difficulty: 'Medium',
      estimatedMinutes: 5,
      isPremium: false,
    ),
    QuizSummary(
      id: 'quiz-3',
      title: 'Nordic Culture Connections',
      category: 'Culture',
      difficulty: 'Hard',
      estimatedMinutes: 6,
      isPremium: true,
    ),
  ];

  static const _sudokuRounds = [
    SudokuRound(
      id: 'sudoku-1',
      roundKey: 'sudoku-s1-base',
      skillPoint: 1,
      difficulty: 'easy',
      puzzleGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419600340286179',
      solutionGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      publishedAt: null,
    ),
    SudokuRound(
      id: 'sudoku-2',
      roundKey: 'sudoku-s2-base',
      skillPoint: 2,
      difficulty: 'easy',
      puzzleGrid:
          '534678912672195348198342567859761423426853791713924856961530284287419600340286179',
      solutionGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      publishedAt: null,
    ),
    SudokuRound(
      id: 'sudoku-3',
      roundKey: 'sudoku-s3-base',
      skillPoint: 3,
      difficulty: 'medium',
      puzzleGrid:
          '530678912672195300198342567859761423426803791713924856961537284287419600305286179',
      solutionGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      publishedAt: null,
    ),
    SudokuRound(
      id: 'sudoku-4',
      roundKey: 'sudoku-s4-base',
      skillPoint: 4,
      difficulty: 'hard',
      puzzleGrid:
          '530070912672190300198302567859761023426803701703924856901537204287410635305086179',
      solutionGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      publishedAt: null,
    ),
    SudokuRound(
      id: 'sudoku-5',
      roundKey: 'sudoku-s5-base',
      skillPoint: 5,
      difficulty: 'hard',
      puzzleGrid:
          '530070000600195000098000060800060003400803001700020006060000280000419005000080079',
      solutionGrid:
          '534678912672195348198342567859761423426853791713924856961537284287419635345286179',
      publishedAt: null,
    ),
  ];

  static const _eurodleRound = EurodleRound(
    id: 'eurodle-1',
    roundKey: 'eurodle-base-001',
    difficulty: 'medium',
    targetWord: 'union',
    wordLength: 5,
    maxAttempts: 6,
    allowedWords: ['union', 'voter', 'euros', 'treat', 'eurox'],
    hint: 'Shared political and economic project.',
    publishedAt: null,
  );

  static final _inviteSeed = [
    QuizClashInviteSummary(
      id: 'clash-invite-1',
      opponentUserId: 'u2',
      opponentDisplayName: 'Lukas Brenner',
      opponentUsername: 'LukasBrenner',
      status: 'pending',
      isIncoming: true,
      createdAt: DateTime.now().subtract(const Duration(minutes: 20)),
      expiresAt: DateTime.now().add(const Duration(hours: 36)),
    ),
  ];

  static final _matchSeed = [
    QuizClashMatchSummary(
      id: 'clash-match-1',
      status: 'active',
      currentRoundIndex: 2,
      totalRounds: 6,
      scoreMe: 3,
      scoreOpponent: 2,
      isMyTurn: true,
      turnDeadlineAt: DateTime.now().add(const Duration(hours: 31)),
      opponentUserId: 'u2',
      opponentDisplayName: 'Lukas Brenner',
      opponentUsername: 'LukasBrenner',
      canMessageOpponent: true,
    ),
    QuizClashMatchSummary(
      id: 'clash-match-2',
      status: 'completed',
      currentRoundIndex: 6,
      totalRounds: 6,
      scoreMe: 12,
      scoreOpponent: 11,
      isMyTurn: false,
      turnDeadlineAt: null,
      opponentUserId: 'u1',
      opponentDisplayName: 'Marta Keller',
      opponentUsername: 'MartaKeller',
      canMessageOpponent: false,
    ),
  ];

  static final Map<String, QuizClashTurnState> _turnStateByMatch = {
    'clash-match-1': QuizClashTurnState(
      matchId: 'clash-match-1',
      status: 'active',
      roundIndex: 2,
      totalRounds: 6,
      scoreMe: 3,
      scoreOpponent: 2,
      isMyTurn: true,
      turnDeadlineAt: DateTime.now().add(const Duration(hours: 31)),
      isPickerTurn: true,
      canMessageOpponent: true,
      opponentUserId: 'u2',
      opponentDisplayName: 'Lukas Brenner',
      opponentUsername: 'LukasBrenner',
      categoryOptions: [
        QuizClashCategoryOption(
          id: 'cat-geography',
          slug: 'geography',
          name: 'Geography',
        ),
        QuizClashCategoryOption(
          id: 'cat-science',
          slug: 'science',
          name: 'Science',
        ),
        QuizClashCategoryOption(
          id: 'cat-politics',
          slug: 'politics',
          name: 'Politics',
        ),
      ],
      selectedCategoryId: null,
      selectedCategoryName: null,
      questions: const [],
    ),
  };
  static final Set<String> _botMatchIds = {'clash-match-1'};
  static final Map<String, DateTime> _botReadyAtByMatch = {};
  static final Map<String, GameSessionSnapshot> _gameSessionsById = {};

  @override
  Future<List<String>> getQuizCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _quizzes.map((quiz) => quiz.category).toSet().toList()..sort();
  }

  @override
  Future<QuizSummary?> getQuizById(String quizId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final quiz in _quizzes) {
      if (quiz.id == quizId) {
        return quiz;
      }
    }
    return null;
  }

  @override
  Future<List<QuizSummary>> getQuizzesByCategory(String category) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _quizzes.where((quiz) => quiz.category == category).toList();
  }

  @override
  Future<void> submitQuizAttempt({
    required String quizId,
    required int score,
    required int maxScore,
    required Duration duration,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  @override
  Future<List<QuizClashInviteSummary>> getQuizClashInvites() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return List<QuizClashInviteSummary>.from(_inviteSeed);
  }

  @override
  Future<List<QuizClashMatchSummary>> getQuizClashMatches() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _advanceMockBotsIfReady();
    for (final entry in _turnStateByMatch.entries) {
      _syncMatchSummaryFromState(entry.key, entry.value);
    }
    return List<QuizClashMatchSummary>.from(_matchSeed);
  }

  @override
  Future<QuizClashTurnState?> getQuizClashTurnState(String matchId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _advanceMockBotsIfReady();
    return _turnStateByMatch[matchId];
  }

  @override
  Future<String?> sendQuizClashInvite({
    String? opponentUserId,
    bool random = false,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (random) {
      final bot = _mockBots[_random.nextInt(_mockBots.length)];
      final matchId =
          'clash-match-bot-${DateTime.now().millisecondsSinceEpoch}';
      final turnState = QuizClashTurnState(
        matchId: matchId,
        status: 'active',
        roundIndex: 1,
        totalRounds: 6,
        scoreMe: 0,
        scoreOpponent: 0,
        isMyTurn: true,
        turnDeadlineAt: DateTime.now().add(const Duration(hours: 48)),
        isPickerTurn: true,
        canMessageOpponent: false,
        opponentUserId: bot.userId,
        opponentDisplayName: bot.displayName,
        opponentUsername: bot.username,
        categoryOptions: _defaultCategoryOptions,
        selectedCategoryId: null,
        selectedCategoryName: null,
        questions: const [],
      );
      _turnStateByMatch[matchId] = turnState;
      _botMatchIds.add(matchId);
      _matchSeed.insert(
        0,
        QuizClashMatchSummary(
          id: matchId,
          status: turnState.status,
          currentRoundIndex: turnState.roundIndex,
          totalRounds: turnState.totalRounds,
          scoreMe: turnState.scoreMe,
          scoreOpponent: turnState.scoreOpponent,
          isMyTurn: turnState.isMyTurn,
          turnDeadlineAt: turnState.turnDeadlineAt,
          opponentUserId: turnState.opponentUserId,
          opponentDisplayName: turnState.opponentDisplayName,
          opponentUsername: turnState.opponentUsername,
          canMessageOpponent: false,
        ),
      );
      return matchId;
    }

    final id = 'mock-invite-${DateTime.now().millisecondsSinceEpoch}';
    _inviteSeed.insert(
      0,
      QuizClashInviteSummary(
        id: id,
        opponentUserId: opponentUserId ?? 'u3',
        opponentDisplayName: opponentUserId == null
            ? 'Random Player'
            : 'Lukas Brenner',
        opponentUsername: opponentUserId == null
            ? 'RandomPlayer'
            : 'LukasBrenner',
        status: 'pending',
        isIncoming: false,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 48)),
      ),
    );
    return id;
  }

  @override
  Future<String?> respondToQuizClashInvite({
    required String inviteId,
    required bool accept,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    _inviteSeed.removeWhere((invite) => invite.id == inviteId);
    if (!accept) {
      return null;
    }
    return 'clash-match-1';
  }

  @override
  Future<void> submitQuizClashPickerTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final current = _turnStateByMatch[matchId];
    if (current == null) {
      return;
    }
    _turnStateByMatch[matchId] = QuizClashTurnState(
      matchId: current.matchId,
      status: current.status,
      roundIndex: current.roundIndex,
      totalRounds: current.totalRounds,
      scoreMe: current.scoreMe + _mockCorrectCount(answers),
      scoreOpponent: current.scoreOpponent,
      isMyTurn: false,
      turnDeadlineAt: DateTime.now().add(const Duration(hours: 48)),
      isPickerTurn: false,
      canMessageOpponent: current.canMessageOpponent,
      opponentUserId: current.opponentUserId,
      opponentDisplayName: current.opponentDisplayName,
      opponentUsername: current.opponentUsername,
      categoryOptions: current.categoryOptions,
      selectedCategoryId: current.selectedCategoryId,
      selectedCategoryName: current.selectedCategoryName,
      questions: current.questions,
    );
    _scheduleBotTurnIfNeeded(matchId);
  }

  @override
  Future<void> pickQuizClashCategory({
    required String matchId,
    required int roundIndex,
    required String selectedCategoryId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final current = _turnStateByMatch[matchId];
    if (current == null) {
      return;
    }
    final selectedCategory = current.categoryOptions.firstWhere(
      (option) => option.id == selectedCategoryId,
      orElse: () => const QuizClashCategoryOption(
        id: 'cat-geography',
        slug: 'geography',
        name: 'Geography',
      ),
    );
    _turnStateByMatch[matchId] = QuizClashTurnState(
      matchId: current.matchId,
      status: current.status,
      roundIndex: current.roundIndex,
      totalRounds: current.totalRounds,
      scoreMe: current.scoreMe,
      scoreOpponent: current.scoreOpponent,
      isMyTurn: true,
      turnDeadlineAt: current.turnDeadlineAt,
      isPickerTurn: true,
      canMessageOpponent: current.canMessageOpponent,
      opponentUserId: current.opponentUserId,
      opponentDisplayName: current.opponentDisplayName,
      opponentUsername: current.opponentUsername,
      categoryOptions: current.categoryOptions,
      selectedCategoryId: selectedCategory.id,
      selectedCategoryName: selectedCategory.name,
      questions: _questionBankByCategory[selectedCategory.id] ?? const [],
    );
  }

  @override
  Future<void> submitQuizClashResponderTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final current = _turnStateByMatch[matchId];
    if (current == null) {
      return;
    }
    final nextRound = current.roundIndex + 1;
    final nextIsCompleted = nextRound > current.totalRounds;
    _turnStateByMatch[matchId] = QuizClashTurnState(
      matchId: current.matchId,
      status: nextIsCompleted ? 'completed' : 'active',
      roundIndex: nextIsCompleted ? current.totalRounds : nextRound,
      totalRounds: current.totalRounds,
      scoreMe: current.scoreMe + _mockCorrectCount(answers),
      scoreOpponent: current.scoreOpponent,
      isMyTurn: !nextIsCompleted,
      turnDeadlineAt: nextIsCompleted
          ? null
          : DateTime.now().add(const Duration(hours: 48)),
      isPickerTurn: !nextIsCompleted,
      canMessageOpponent: current.canMessageOpponent,
      opponentUserId: current.opponentUserId,
      opponentDisplayName: current.opponentDisplayName,
      opponentUsername: current.opponentUsername,
      categoryOptions: current.categoryOptions,
      selectedCategoryId: null,
      selectedCategoryName: null,
      questions: const [],
    );
    _scheduleBotTurnIfNeeded(matchId);
  }

  @override
  Future<void> claimQuizClashTimeoutForfeit(String matchId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    final current = _turnStateByMatch[matchId];
    if (current == null) {
      return;
    }
    _turnStateByMatch[matchId] = QuizClashTurnState(
      matchId: current.matchId,
      status: 'forfeit_timeout',
      roundIndex: current.roundIndex,
      totalRounds: current.totalRounds,
      scoreMe: current.scoreMe,
      scoreOpponent: current.scoreOpponent,
      isMyTurn: false,
      turnDeadlineAt: null,
      isPickerTurn: false,
      canMessageOpponent: current.canMessageOpponent,
      opponentUserId: current.opponentUserId,
      opponentDisplayName: current.opponentDisplayName,
      opponentUsername: current.opponentUsername,
      categoryOptions: current.categoryOptions,
      selectedCategoryId: current.selectedCategoryId,
      selectedCategoryName: current.selectedCategoryName,
      questions: current.questions,
    );
  }

  @override
  Future<EurodleRound?> getActiveEurodleRound() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _eurodleRound;
  }

  @override
  Future<SudokuRound?> getSudokuRoundBySkillPoint(int skillPoint) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    for (final round in _sudokuRounds) {
      if (round.skillPoint == skillPoint) {
        return round;
      }
    }
    return null;
  }

  @override
  Future<List<SudokuRound>> getSudokuSkillRounds() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _sudokuRounds;
  }

  @override
  Future<GameSessionSnapshot?> getInProgressGameSession({
    required String gameSlug,
    required String roundId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final existing =
        _gameSessionsById.values
            .where(
              (session) =>
                  session.roundId == roundId &&
                  session.gameId == 'mock-$gameSlug' &&
                  session.status == 'in_progress',
            )
            .toList()
          ..sort((a, b) {
            final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
    if (existing.isEmpty) {
      return null;
    }
    return existing.first;
  }

  @override
  Future<GameSessionSnapshot?> startOrResumeGameSession({
    required String gameSlug,
    required String roundId,
    required Map<String, dynamic> initialState,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final existing = await getInProgressGameSession(
      gameSlug: gameSlug,
      roundId: roundId,
    );
    if (existing != null) {
      return existing;
    }

    final now = DateTime.now();
    final id = 'mock-game-session-${now.microsecondsSinceEpoch}';
    final created = GameSessionSnapshot(
      id: id,
      userId: 'mock-user',
      gameId: 'mock-$gameSlug',
      roundId: roundId,
      status: 'in_progress',
      score: 0,
      maxScore: null,
      movesCount: 0,
      durationMs: 0,
      state: Map<String, dynamic>.from(initialState),
      startedAt: now,
      completedAt: null,
      updatedAt: now,
    );
    _gameSessionsById[id] = created;
    return created;
  }

  @override
  Future<void> saveGameSessionProgress({
    required String sessionId,
    required int movesCount,
    required Duration elapsed,
    required Map<String, dynamic> state,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final existing = _gameSessionsById[sessionId];
    if (existing == null) {
      return;
    }
    _gameSessionsById[sessionId] = GameSessionSnapshot(
      id: existing.id,
      userId: existing.userId,
      gameId: existing.gameId,
      roundId: existing.roundId,
      status: existing.status,
      score: existing.score,
      maxScore: existing.maxScore,
      movesCount: movesCount < 0 ? 0 : movesCount,
      durationMs: elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds,
      state: Map<String, dynamic>.from(state),
      startedAt: existing.startedAt,
      completedAt: existing.completedAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> completeGameSession({
    required String sessionId,
    required int score,
    required int maxScore,
    required int movesCount,
    required Duration elapsed,
    required Map<String, dynamic> state,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
    final existing = _gameSessionsById[sessionId];
    if (existing == null) {
      return;
    }
    final now = DateTime.now();
    _gameSessionsById[sessionId] = GameSessionSnapshot(
      id: existing.id,
      userId: existing.userId,
      gameId: existing.gameId,
      roundId: existing.roundId,
      status: 'completed',
      score: score < 0 ? 0 : score,
      maxScore: maxScore < 0 ? 0 : maxScore,
      movesCount: movesCount < 0 ? 0 : movesCount,
      durationMs: elapsed.inMilliseconds < 0 ? 0 : elapsed.inMilliseconds,
      state: Map<String, dynamic>.from(state),
      startedAt: existing.startedAt,
      completedAt: now,
      updatedAt: now,
    );
  }

  int _mockCorrectCount(List<int> answers) {
    var total = 0;
    for (final answer in answers) {
      if (answer == 1) {
        total++;
      }
    }
    return total;
  }

  void _syncMatchSummaryFromState(String matchId, QuizClashTurnState state) {
    final existingIndex = _matchSeed.indexWhere((match) => match.id == matchId);
    final existing = existingIndex >= 0 ? _matchSeed[existingIndex] : null;
    final summary = QuizClashMatchSummary(
      id: matchId,
      status: state.status,
      currentRoundIndex: state.roundIndex,
      totalRounds: state.totalRounds,
      scoreMe: state.scoreMe,
      scoreOpponent: state.scoreOpponent,
      isMyTurn: state.isMyTurn,
      turnDeadlineAt: state.turnDeadlineAt,
      opponentUserId: state.opponentUserId,
      opponentDisplayName: state.opponentDisplayName,
      opponentUsername: state.opponentUsername,
      canMessageOpponent: existing?.canMessageOpponent ?? false,
    );
    if (existingIndex >= 0) {
      _matchSeed[existingIndex] = summary;
      return;
    }
    _matchSeed.insert(0, summary);
  }

  void _scheduleBotTurnIfNeeded(String matchId) {
    final state = _turnStateByMatch[matchId];
    if (state == null ||
        state.status != 'active' ||
        state.isMyTurn ||
        !_botMatchIds.contains(matchId)) {
      _botReadyAtByMatch.remove(matchId);
      return;
    }
    _botReadyAtByMatch[matchId] = DateTime.now().add(
      Duration(seconds: 3 + _random.nextInt(3)),
    );
  }

  void _advanceMockBotsIfReady() {
    final now = DateTime.now();
    final dueMatchIds = _botReadyAtByMatch.entries
        .where((entry) => !entry.value.isAfter(now))
        .map((entry) => entry.key)
        .toList();
    for (final matchId in dueMatchIds) {
      _botReadyAtByMatch.remove(matchId);
      _playMockBotTurn(matchId);
    }
  }

  void _playMockBotTurn(String matchId) {
    final current = _turnStateByMatch[matchId];
    if (current == null || current.status != 'active' || current.isMyTurn) {
      return;
    }

    final options = current.categoryOptions.isEmpty
        ? _defaultCategoryOptions
        : current.categoryOptions;
    final selectedCategory = options[_random.nextInt(options.length)];
    final selectedQuestions =
        _questionBankByCategory[selectedCategory.id] ??
        const <QuizClashQuestion>[];

    if (current.selectedCategoryId == null || current.questions.isEmpty) {
      final botCorrect = 1 + _random.nextInt(3);
      _turnStateByMatch[matchId] = QuizClashTurnState(
        matchId: current.matchId,
        status: current.status,
        roundIndex: current.roundIndex,
        totalRounds: current.totalRounds,
        scoreMe: current.scoreMe,
        scoreOpponent: current.scoreOpponent + botCorrect,
        isMyTurn: true,
        turnDeadlineAt: DateTime.now().add(const Duration(hours: 48)),
        isPickerTurn: false,
        canMessageOpponent: current.canMessageOpponent,
        opponentUserId: current.opponentUserId,
        opponentDisplayName: current.opponentDisplayName,
        opponentUsername: current.opponentUsername,
        categoryOptions: options,
        selectedCategoryId: selectedCategory.id,
        selectedCategoryName: selectedCategory.name,
        questions: selectedQuestions,
      );
      return;
    }

    final currentRoundBotCorrect = 1 + _random.nextInt(3);
    final nextRound = current.roundIndex + 1;
    final completed = nextRound > current.totalRounds;
    if (completed) {
      _turnStateByMatch[matchId] = QuizClashTurnState(
        matchId: current.matchId,
        status: 'completed',
        roundIndex: current.totalRounds,
        totalRounds: current.totalRounds,
        scoreMe: current.scoreMe,
        scoreOpponent: current.scoreOpponent + currentRoundBotCorrect,
        isMyTurn: false,
        turnDeadlineAt: null,
        isPickerTurn: false,
        canMessageOpponent: current.canMessageOpponent,
        opponentUserId: current.opponentUserId,
        opponentDisplayName: current.opponentDisplayName,
        opponentUsername: current.opponentUsername,
        categoryOptions: options,
        selectedCategoryId: current.selectedCategoryId,
        selectedCategoryName: current.selectedCategoryName,
        questions: current.questions,
      );
      return;
    }

    final nextRoundBotCorrect = 1 + _random.nextInt(3);
    _turnStateByMatch[matchId] = QuizClashTurnState(
      matchId: current.matchId,
      status: 'active',
      roundIndex: nextRound,
      totalRounds: current.totalRounds,
      scoreMe: current.scoreMe,
      scoreOpponent:
          current.scoreOpponent + currentRoundBotCorrect + nextRoundBotCorrect,
      isMyTurn: true,
      turnDeadlineAt: DateTime.now().add(const Duration(hours: 48)),
      isPickerTurn: false,
      canMessageOpponent: current.canMessageOpponent,
      opponentUserId: current.opponentUserId,
      opponentDisplayName: current.opponentDisplayName,
      opponentUsername: current.opponentUsername,
      categoryOptions: options,
      selectedCategoryId: selectedCategory.id,
      selectedCategoryName: selectedCategory.name,
      questions: selectedQuestions,
    );
  }
}

class _MockBotProfile {
  const _MockBotProfile({
    required this.userId,
    required this.displayName,
    required this.username,
  });

  final String userId;
  final String displayName;
  final String username;
}

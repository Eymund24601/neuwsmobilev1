import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/game_session.dart';
import '../../models/game_round.dart';
import '../../models/quiz_clash_models.dart';
import '../../models/quiz_summary.dart';
import '../games_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseGamesRepository implements GamesRepository {
  const SupabaseGamesRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<String>> getQuizCategories() async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('quiz_sets')
          .select('topic')
          .eq('is_published', true);
    } on PostgrestException {
      rows = await _client
          .from('quizzes')
          .select('category')
          .eq('is_published', true);
    }

    final categories = rows
        .map<String>((dynamic row) {
          final map = row as Map<String, dynamic>;
          return SupabaseMappingUtils.stringValue(map, const [
            'topic',
            'category',
          ], fallback: 'General');
        })
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  @override
  Future<QuizSummary?> getQuizById(String quizId) async {
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('quiz_sets')
          .select('''
            id,
            title,
            topic,
            difficulty,
            estimated_minutes,
            estimatedMinutes,
            is_premium,
            is_published
            ''')
          .eq('id', quizId)
          .eq('is_published', true)
          .maybeSingle();
    } on PostgrestException {
      row = await _client
          .from('quizzes')
          .select('''
            id,
            title,
            category,
            difficulty,
            estimated_minutes,
            estimatedMinutes,
            is_premium
            ''')
          .eq('id', quizId)
          .eq('is_published', true)
          .maybeSingle();
    }
    if (row == null) {
      return null;
    }
    return _mapQuiz(row);
  }

  @override
  Future<List<QuizSummary>> getQuizzesByCategory(String category) async {
    List<dynamic> rows;
    try {
      rows = await _client
          .from('quiz_sets')
          .select('''
            id,
            title,
            topic,
            difficulty,
            estimated_minutes,
            estimatedMinutes,
            is_premium
            ''')
          .eq('is_published', true)
          .eq('topic', category)
          .order('title', ascending: true);
    } on PostgrestException {
      rows = await _client
          .from('quizzes')
          .select('''
            id,
            title,
            category,
            difficulty,
            estimated_minutes,
            estimatedMinutes,
            is_premium
            ''')
          .eq('is_published', true)
          .eq('category', category)
          .order('title', ascending: true);
    }

    return rows
        .map<QuizSummary>(
          (dynamic row) => _mapQuiz(row as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<void> submitQuizAttempt({
    required String quizId,
    required int score,
    required int maxScore,
    required Duration duration,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sign in required to submit quiz attempts.');
    }

    try {
      await _client.from('quiz_attempts').insert({
        'quiz_set_id': quizId,
        'user_id': userId,
        'score': score,
        'max_score': maxScore,
        'duration_ms': duration.inMilliseconds,
        'started_at': DateTime.now().subtract(duration).toIso8601String(),
        'completed_at': DateTime.now().toIso8601String(),
      });
    } on PostgrestException catch (error) {
      throw StateError('Could not submit quiz attempt: ${error.message}');
    }
  }

  @override
  Future<List<QuizClashInviteSummary>> getQuizClashInvites() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    final rows = await _client
        .from('quiz_clash_invites')
        .select('''
          id,
          sender_user_id,
          recipient_user_id,
          status,
          created_at,
          expires_at
        ''')
        .or('sender_user_id.eq.$userId,recipient_user_id.eq.$userId')
        .eq('status', 'pending')
        .order('created_at', ascending: false)
        .limit(80);

    if (rows.isEmpty) {
      return const [];
    }

    final opponentIds = <String>{};
    for (final dynamic row in rows) {
      final map = row as Map<String, dynamic>;
      final senderId = SupabaseMappingUtils.stringValue(map, const [
        'sender_user_id',
      ]);
      final recipientId = SupabaseMappingUtils.stringValue(map, const [
        'recipient_user_id',
      ]);
      final opponentId = senderId == userId ? recipientId : senderId;
      if (opponentId.isNotEmpty) {
        opponentIds.add(opponentId);
      }
    }

    final profilesById = await _profilesById(opponentIds.toList());

    return rows.map<QuizClashInviteSummary>((dynamic row) {
      final map = row as Map<String, dynamic>;
      final senderId = SupabaseMappingUtils.stringValue(map, const [
        'sender_user_id',
      ]);
      final recipientId = SupabaseMappingUtils.stringValue(map, const [
        'recipient_user_id',
      ]);
      final incoming = recipientId == userId;
      final opponentId = incoming ? senderId : recipientId;
      final profile = profilesById[opponentId] ?? const <String, dynamic>{};
      return QuizClashInviteSummary(
        id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
        opponentUserId: opponentId,
        opponentDisplayName: SupabaseMappingUtils.stringValue(profile, const [
          'display_name',
          'username',
        ], fallback: 'Player'),
        opponentUsername: SupabaseMappingUtils.stringValue(profile, const [
          'username',
        ], fallback: ''),
        status: SupabaseMappingUtils.stringValue(map, const [
          'status',
        ], fallback: 'pending'),
        isIncoming: incoming,
        createdAt: SupabaseMappingUtils.dateTimeValue(map, const [
          'created_at',
        ]),
        expiresAt: SupabaseMappingUtils.dateTimeValue(map, const [
          'expires_at',
        ]),
      );
    }).toList();
  }

  @override
  Future<List<QuizClashMatchSummary>> getQuizClashMatches() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const [];
    }

    await _progressQuizClashBotMatches();

    final rows = await _client
        .from('quiz_clash_matches')
        .select('''
          id,
          player_a_user_id,
          player_b_user_id,
          status,
          current_round_index,
          total_rounds,
          current_turn_user_id,
          score_player_a,
          score_player_b,
          turn_deadline_at,
          updated_at
        ''')
        .or('player_a_user_id.eq.$userId,player_b_user_id.eq.$userId')
        .order('updated_at', ascending: false)
        .limit(60);

    if (rows.isEmpty) {
      return const [];
    }

    final opponentIds = <String>{};
    for (final dynamic row in rows) {
      final map = row as Map<String, dynamic>;
      final playerA = SupabaseMappingUtils.stringValue(map, const [
        'player_a_user_id',
      ]);
      final playerB = SupabaseMappingUtils.stringValue(map, const [
        'player_b_user_id',
      ]);
      final opponent = playerA == userId ? playerB : playerA;
      if (opponent.isNotEmpty) {
        opponentIds.add(opponent);
      }
    }

    final profilesById = await _profilesById(opponentIds.toList());
    final mutualFollowByOpponent = await _mutualFollowMap(userId, opponentIds);

    return rows.map<QuizClashMatchSummary>((dynamic row) {
      final map = row as Map<String, dynamic>;
      final playerA = SupabaseMappingUtils.stringValue(map, const [
        'player_a_user_id',
      ]);
      final playerB = SupabaseMappingUtils.stringValue(map, const [
        'player_b_user_id',
      ]);
      final isPlayerA = playerA == userId;
      final opponent = isPlayerA ? playerB : playerA;
      final profile = profilesById[opponent] ?? const <String, dynamic>{};
      return QuizClashMatchSummary(
        id: SupabaseMappingUtils.stringValue(map, const ['id'], fallback: ''),
        status: SupabaseMappingUtils.stringValue(map, const [
          'status',
        ], fallback: 'active'),
        currentRoundIndex: SupabaseMappingUtils.intValue(map, const [
          'current_round_index',
        ], fallback: 1),
        totalRounds: SupabaseMappingUtils.intValue(map, const [
          'total_rounds',
        ], fallback: 6),
        scoreMe: isPlayerA
            ? SupabaseMappingUtils.intValue(map, const ['score_player_a'])
            : SupabaseMappingUtils.intValue(map, const ['score_player_b']),
        scoreOpponent: isPlayerA
            ? SupabaseMappingUtils.intValue(map, const ['score_player_b'])
            : SupabaseMappingUtils.intValue(map, const ['score_player_a']),
        isMyTurn:
            SupabaseMappingUtils.stringValue(map, const [
              'current_turn_user_id',
            ]) ==
            userId,
        turnDeadlineAt: SupabaseMappingUtils.dateTimeValue(map, const [
          'turn_deadline_at',
        ]),
        opponentUserId: opponent,
        opponentDisplayName: SupabaseMappingUtils.stringValue(profile, const [
          'display_name',
          'username',
        ], fallback: 'Player'),
        opponentUsername: SupabaseMappingUtils.stringValue(profile, const [
          'username',
        ], fallback: ''),
        canMessageOpponent: mutualFollowByOpponent[opponent] ?? false,
      );
    }).toList();
  }

  @override
  Future<QuizClashTurnState?> getQuizClashTurnState(String matchId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || matchId.trim().isEmpty) {
      return null;
    }

    await _advanceQuizClashBotTurn(matchId);

    final matchRow = await _client
        .from('quiz_clash_matches')
        .select('''
          id,
          player_a_user_id,
          player_b_user_id,
          status,
          current_round_index,
          total_rounds,
          current_turn_user_id,
          current_picker_user_id,
          score_player_a,
          score_player_b,
          turn_deadline_at
        ''')
        .eq('id', matchId)
        .maybeSingle();
    if (matchRow == null) {
      return null;
    }

    final playerA = SupabaseMappingUtils.stringValue(matchRow, const [
      'player_a_user_id',
    ]);
    final playerB = SupabaseMappingUtils.stringValue(matchRow, const [
      'player_b_user_id',
    ]);
    if (userId != playerA && userId != playerB) {
      return null;
    }

    final isPlayerA = playerA == userId;
    final opponentId = isPlayerA ? playerB : playerA;
    final currentRoundIndex = SupabaseMappingUtils.intValue(matchRow, const [
      'current_round_index',
    ], fallback: 1);

    final roundRow = await _client
        .from('quiz_clash_rounds')
        .select('''
          round_index,
          picker_user_id,
          category_option_ids,
          selected_category_id,
          question_ids
        ''')
        .eq('match_id', matchId)
        .eq('round_index', currentRoundIndex)
        .maybeSingle();

    final categoryOptionIds = _uuidList(roundRow, 'category_option_ids');
    final selectedCategoryId = roundRow == null
        ? null
        : SupabaseMappingUtils.stringValue(roundRow, const [
            'selected_category_id',
          ], fallback: '');
    final questionIds = _uuidList(roundRow, 'question_ids');

    final categoryRows = categoryOptionIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('quiz_clash_categories')
              .select('id,slug,name')
              .inFilter('id', categoryOptionIds);
    final categoriesById = <String, Map<String, dynamic>>{};
    for (final dynamic row in categoryRows) {
      final map = row as Map<String, dynamic>;
      final id = SupabaseMappingUtils.stringValue(map, const ['id']);
      if (id.isNotEmpty) {
        categoriesById[id] = map;
      }
    }

    final questionRows = questionIds.isEmpty
        ? const <dynamic>[]
        : await _client
              .from('quiz_clash_questions')
              .select('id,prompt,option_a,option_b,option_c,option_d')
              .inFilter('id', questionIds);
    final questionsById = <String, Map<String, dynamic>>{};
    for (final dynamic row in questionRows) {
      final map = row as Map<String, dynamic>;
      final id = SupabaseMappingUtils.stringValue(map, const ['id']);
      if (id.isNotEmpty) {
        questionsById[id] = map;
      }
    }

    final profile = await _profileById(opponentId);
    final canMessage = await _isMutualFollow(userId, opponentId);
    final pickerUserId = roundRow == null
        ? SupabaseMappingUtils.stringValue(matchRow, const [
            'current_picker_user_id',
          ])
        : SupabaseMappingUtils.stringValue(roundRow, const ['picker_user_id']);

    final selectedCategoryMap =
        (selectedCategoryId == null || selectedCategoryId.isEmpty)
        ? null
        : categoriesById[selectedCategoryId];

    return QuizClashTurnState(
      matchId: SupabaseMappingUtils.stringValue(matchRow, const ['id']),
      status: SupabaseMappingUtils.stringValue(matchRow, const [
        'status',
      ], fallback: 'active'),
      roundIndex: currentRoundIndex,
      totalRounds: SupabaseMappingUtils.intValue(matchRow, const [
        'total_rounds',
      ], fallback: 6),
      scoreMe: isPlayerA
          ? SupabaseMappingUtils.intValue(matchRow, const ['score_player_a'])
          : SupabaseMappingUtils.intValue(matchRow, const ['score_player_b']),
      scoreOpponent: isPlayerA
          ? SupabaseMappingUtils.intValue(matchRow, const ['score_player_b'])
          : SupabaseMappingUtils.intValue(matchRow, const ['score_player_a']),
      isMyTurn:
          SupabaseMappingUtils.stringValue(matchRow, const [
            'current_turn_user_id',
          ]) ==
          userId,
      turnDeadlineAt: SupabaseMappingUtils.dateTimeValue(matchRow, const [
        'turn_deadline_at',
      ]),
      isPickerTurn: pickerUserId == userId,
      canMessageOpponent: canMessage,
      opponentUserId: opponentId,
      opponentDisplayName: SupabaseMappingUtils.stringValue(profile, const [
        'display_name',
        'username',
      ], fallback: 'Player'),
      opponentUsername: SupabaseMappingUtils.stringValue(profile, const [
        'username',
      ], fallback: ''),
      categoryOptions: categoryOptionIds.map((id) {
        final row = categoriesById[id] ?? const <String, dynamic>{};
        return QuizClashCategoryOption(
          id: id,
          slug: SupabaseMappingUtils.stringValue(row, const [
            'slug',
          ], fallback: 'category'),
          name: SupabaseMappingUtils.stringValue(row, const [
            'name',
          ], fallback: 'Category'),
        );
      }).toList(),
      selectedCategoryId:
          (selectedCategoryId == null || selectedCategoryId.isEmpty)
          ? null
          : selectedCategoryId,
      selectedCategoryName: selectedCategoryMap == null
          ? null
          : SupabaseMappingUtils.stringValue(selectedCategoryMap, const [
              'name',
            ]),
      questions: questionIds.map((id) {
        final row = questionsById[id] ?? const <String, dynamic>{};
        return QuizClashQuestion(
          id: id,
          prompt: SupabaseMappingUtils.stringValue(row, const [
            'prompt',
          ], fallback: 'Question'),
          options: [
            SupabaseMappingUtils.stringValue(row, const [
              'option_a',
            ], fallback: 'A'),
            SupabaseMappingUtils.stringValue(row, const [
              'option_b',
            ], fallback: 'B'),
            SupabaseMappingUtils.stringValue(row, const [
              'option_c',
            ], fallback: 'C'),
            SupabaseMappingUtils.stringValue(row, const [
              'option_d',
            ], fallback: 'D'),
          ],
          timeLimitSeconds: 20,
        );
      }).toList(),
    );
  }

  @override
  Future<String?> sendQuizClashInvite({
    String? opponentUserId,
    bool random = false,
  }) async {
    final result = await _client.rpc(
      'quiz_clash_send_invite',
      params: {'p_opponent_user_id': opponentUserId, 'p_random': random},
    );
    if (result is String && result.trim().isNotEmpty) {
      return result;
    }
    if (result is Map<String, dynamic>) {
      final id = SupabaseMappingUtils.stringValue(result, const ['id']);
      if (id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  @override
  Future<String?> respondToQuizClashInvite({
    required String inviteId,
    required bool accept,
  }) async {
    final result = await _client.rpc(
      'quiz_clash_respond_invite',
      params: {'p_invite_id': inviteId, 'p_accept': accept},
    );
    if (result == null) {
      return null;
    }
    if (result is String && result.trim().isNotEmpty) {
      return result;
    }
    if (result is Map<String, dynamic>) {
      final id = SupabaseMappingUtils.stringValue(result, const ['id']);
      if (id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  @override
  Future<void> submitQuizClashPickerTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  }) async {
    await _client.rpc(
      'quiz_clash_submit_picker_answers',
      params: {
        'p_match_id': matchId,
        'p_round_index': roundIndex,
        'p_answers': answers,
        'p_answer_durations_ms': answerDurationsMs,
      },
    );
  }

  @override
  Future<void> pickQuizClashCategory({
    required String matchId,
    required int roundIndex,
    required String selectedCategoryId,
  }) async {
    await _client.rpc(
      'quiz_clash_pick_category',
      params: {
        'p_match_id': matchId,
        'p_round_index': roundIndex,
        'p_selected_category_id': selectedCategoryId,
      },
    );
  }

  @override
  Future<void> submitQuizClashResponderTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  }) async {
    await _client.rpc(
      'quiz_clash_submit_responder_turn',
      params: {
        'p_match_id': matchId,
        'p_round_index': roundIndex,
        'p_answers': answers,
        'p_answer_durations_ms': answerDurationsMs,
      },
    );
  }

  @override
  Future<void> claimQuizClashTimeoutForfeit(String matchId) async {
    await _client.rpc(
      'quiz_clash_claim_timeout_forfeit',
      params: {'p_match_id': matchId},
    );
  }

  @override
  Future<EurodleRound?> getActiveEurodleRound() async {
    final gameId = await _getGameIdBySlug('eurodle');
    if (gameId == null) {
      return null;
    }

    final row = await _client
        .from('game_rounds')
        .select('''
          id,
          round_key,
          difficulty,
          compact_payload,
          published_at
        ''')
        .eq('game_id', gameId)
        .eq('is_active', true)
        .order('published_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return _mapEurodleRound(row);
  }

  @override
  Future<SudokuRound?> getSudokuRoundBySkillPoint(int skillPoint) async {
    final gameId = await _getGameIdBySlug('sudoku');
    if (gameId == null) {
      return null;
    }

    final row = await _client
        .from('game_rounds')
        .select('''
          id,
          round_key,
          difficulty,
          skill_point,
          compact_payload,
          published_at
        ''')
        .eq('game_id', gameId)
        .eq('is_active', true)
        .eq('skill_point', skillPoint)
        .order('published_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    return _mapSudokuRound(row);
  }

  @override
  Future<List<SudokuRound>> getSudokuSkillRounds() async {
    final gameId = await _getGameIdBySlug('sudoku');
    if (gameId == null) {
      return const [];
    }

    final rows = await _client
        .from('game_rounds')
        .select('''
          id,
          round_key,
          difficulty,
          skill_point,
          compact_payload,
          published_at
        ''')
        .eq('game_id', gameId)
        .eq('is_active', true)
        .gte('skill_point', 1)
        .lte('skill_point', 5)
        .order('skill_point', ascending: true)
        .order('published_at', ascending: false);

    final pickedBySkill = <int, SudokuRound>{};
    for (final dynamic row in rows) {
      final mapped = _mapSudokuRound(row as Map<String, dynamic>);
      pickedBySkill.putIfAbsent(mapped.skillPoint, () => mapped);
    }

    return pickedBySkill.values.toList()
      ..sort((a, b) => a.skillPoint.compareTo(b.skillPoint));
  }

  @override
  Future<GameSessionSnapshot?> getInProgressGameSession({
    required String gameSlug,
    required String roundId,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || roundId.trim().isEmpty) {
      return null;
    }

    final row = await _client
        .from('user_game_sessions')
        .select('''
          id,
          user_id,
          game_id,
          round_id,
          status,
          score,
          max_score,
          moves_count,
          duration_ms,
          state_json,
          started_at,
          completed_at,
          updated_at
        ''')
        .eq('user_id', userId)
        .eq('round_id', roundId)
        .eq('status', 'in_progress')
        .order('updated_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }
    return _mapGameSession(row);
  }

  @override
  Future<GameSessionSnapshot?> startOrResumeGameSession({
    required String gameSlug,
    required String roundId,
    required Map<String, dynamic> initialState,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || roundId.trim().isEmpty) {
      return null;
    }

    final existing = await getInProgressGameSession(
      gameSlug: gameSlug,
      roundId: roundId,
    );
    if (existing != null) {
      return existing;
    }

    final gameId = await _getGameIdBySlug(gameSlug);
    if (gameId == null) {
      return null;
    }

    final nowIso = DateTime.now().toIso8601String();
    final row = await _client
        .from('user_game_sessions')
        .insert({
          'user_id': userId,
          'game_id': gameId,
          'round_id': roundId,
          'status': 'in_progress',
          'score': 0,
          'moves_count': 0,
          'duration_ms': 0,
          'state_json': initialState,
          'started_at': nowIso,
        })
        .select('''
          id,
          user_id,
          game_id,
          round_id,
          status,
          score,
          max_score,
          moves_count,
          duration_ms,
          state_json,
          started_at,
          completed_at,
          updated_at
        ''')
        .single();

    final session = _mapGameSession(row);
    try {
      await _client.from('user_game_events').insert({
        'session_id': session.id,
        'user_id': userId,
        'event_type': 'session_started',
        'event_at': nowIso,
        'payload_json': {'game_slug': gameSlug, 'round_id': roundId},
      });
    } on PostgrestException {
      // Do not fail gameplay if event logging is unavailable.
    }
    return session;
  }

  @override
  Future<void> saveGameSessionProgress({
    required String sessionId,
    required int movesCount,
    required Duration elapsed,
    required Map<String, dynamic> state,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || sessionId.trim().isEmpty) {
      return;
    }

    await _client
        .from('user_game_sessions')
        .update({
          'moves_count': movesCount < 0 ? 0 : movesCount,
          'duration_ms': elapsed.inMilliseconds < 0
              ? 0
              : elapsed.inMilliseconds,
          'state_json': state,
        })
        .eq('id', sessionId)
        .eq('user_id', userId)
        .eq('status', 'in_progress');
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
    final userId = _client.auth.currentUser?.id;
    if (userId == null || sessionId.trim().isEmpty) {
      return;
    }

    final nowIso = DateTime.now().toIso8601String();
    await _client
        .from('user_game_sessions')
        .update({
          'status': 'completed',
          'score': score < 0 ? 0 : score,
          'max_score': maxScore < 0 ? 0 : maxScore,
          'moves_count': movesCount < 0 ? 0 : movesCount,
          'duration_ms': elapsed.inMilliseconds < 0
              ? 0
              : elapsed.inMilliseconds,
          'state_json': state,
          'completed_at': nowIso,
        })
        .eq('id', sessionId)
        .eq('user_id', userId);

    try {
      await _client.from('user_game_events').insert({
        'session_id': sessionId,
        'user_id': userId,
        'event_type': 'session_completed',
        'event_at': nowIso,
        'payload_json': {
          'score': score,
          'max_score': maxScore,
          'moves_count': movesCount,
          'duration_ms': elapsed.inMilliseconds,
        },
      });
    } on PostgrestException {
      // Do not fail gameplay if event logging is unavailable.
    }
  }

  QuizSummary _mapQuiz(Map<String, dynamic> row) {
    return QuizSummary(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Untitled quiz'),
      category: SupabaseMappingUtils.stringValue(row, const [
        'topic',
        'category',
      ], fallback: 'General'),
      difficulty: SupabaseMappingUtils.stringValue(row, const [
        'difficulty',
      ], fallback: 'Mixed'),
      estimatedMinutes: SupabaseMappingUtils.intValue(row, const [
        'estimated_minutes',
        'estimatedMinutes',
      ], fallback: 4),
      isPremium: SupabaseMappingUtils.boolValue(row, const [
        'is_premium',
      ], fallback: false),
    );
  }

  Future<String?> _getGameIdBySlug(String slug) async {
    final row = await _client
        .from('game_catalog')
        .select('id')
        .eq('slug', slug)
        .eq('is_active', true)
        .maybeSingle();
    if (row == null) {
      return null;
    }
    final id = SupabaseMappingUtils.stringValue(row, const [
      'id',
    ], fallback: '');
    if (id.isEmpty) {
      return null;
    }
    return id;
  }

  SudokuRound _mapSudokuRound(Map<String, dynamic> row) {
    final payloadRaw = row['compact_payload'];
    final payload = payloadRaw is Map<String, dynamic>
        ? payloadRaw
        : const <String, dynamic>{};
    return SudokuRound(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      roundKey: SupabaseMappingUtils.stringValue(row, const [
        'round_key',
      ], fallback: ''),
      skillPoint: SupabaseMappingUtils.intValue(
        row,
        const ['skill_point'],
        fallback: SupabaseMappingUtils.intValue(payload, const [
          'skill_point',
        ], fallback: 1),
      ),
      difficulty: SupabaseMappingUtils.stringValue(row, const [
        'difficulty',
      ], fallback: 'easy'),
      puzzleGrid: SupabaseMappingUtils.stringValue(payload, const [
        'puzzle_grid',
      ], fallback: ''),
      solutionGrid: SupabaseMappingUtils.stringValue(payload, const [
        'solution_grid',
      ], fallback: ''),
      publishedAt: SupabaseMappingUtils.dateTimeValue(row, const [
        'published_at',
      ]),
    );
  }

  EurodleRound _mapEurodleRound(Map<String, dynamic> row) {
    final payloadRaw = row['compact_payload'];
    final payload = payloadRaw is Map<String, dynamic>
        ? payloadRaw
        : const <String, dynamic>{};
    final allowedRaw = payload['allowed_words'];
    return EurodleRound(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      roundKey: SupabaseMappingUtils.stringValue(row, const [
        'round_key',
      ], fallback: ''),
      difficulty: SupabaseMappingUtils.stringValue(row, const [
        'difficulty',
      ], fallback: 'medium'),
      targetWord: SupabaseMappingUtils.stringValue(payload, const [
        'target_word',
      ], fallback: ''),
      wordLength: SupabaseMappingUtils.intValue(payload, const [
        'word_length',
      ], fallback: 5),
      maxAttempts: SupabaseMappingUtils.intValue(payload, const [
        'max_attempts',
      ], fallback: 6),
      allowedWords: allowedRaw is List
          ? allowedRaw.whereType<String>().toList()
          : const [],
      hint: SupabaseMappingUtils.stringValue(payload, const [
        'hint',
      ], fallback: ''),
      publishedAt: SupabaseMappingUtils.dateTimeValue(row, const [
        'published_at',
      ]),
    );
  }

  GameSessionSnapshot _mapGameSession(Map<String, dynamic> row) {
    final stateRaw = row['state_json'];
    return GameSessionSnapshot(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      userId: SupabaseMappingUtils.stringValue(row, const [
        'user_id',
      ], fallback: ''),
      gameId: SupabaseMappingUtils.stringValue(row, const [
        'game_id',
      ], fallback: ''),
      roundId: SupabaseMappingUtils.stringValue(row, const [
        'round_id',
      ], fallback: ''),
      status: SupabaseMappingUtils.stringValue(row, const [
        'status',
      ], fallback: 'in_progress'),
      score: SupabaseMappingUtils.intValue(row, const ['score']),
      maxScore: row['max_score'] == null
          ? null
          : SupabaseMappingUtils.intValue(row, const ['max_score']),
      movesCount: SupabaseMappingUtils.intValue(row, const ['moves_count']),
      durationMs: SupabaseMappingUtils.intValue(row, const ['duration_ms']),
      state: stateRaw is Map<String, dynamic>
          ? stateRaw
          : const <String, dynamic>{},
      startedAt: SupabaseMappingUtils.dateTimeValue(row, const ['started_at']),
      completedAt: SupabaseMappingUtils.dateTimeValue(row, const [
        'completed_at',
      ]),
      updatedAt: SupabaseMappingUtils.dateTimeValue(row, const ['updated_at']),
    );
  }

  List<String> _uuidList(Map<String, dynamic>? row, String key) {
    if (row == null) {
      return const [];
    }
    final raw = row[key];
    if (raw is! List) {
      return const [];
    }
    return raw
        .map((item) => '$item'.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<Map<String, Map<String, dynamic>>> _profilesById(
    List<String> ids,
  ) async {
    if (ids.isEmpty) {
      return const {};
    }
    final rows = await _client
        .from('profiles')
        .select('id,display_name,username')
        .inFilter('id', ids);
    final map = <String, Map<String, dynamic>>{};
    for (final dynamic row in rows) {
      final profile = row as Map<String, dynamic>;
      final id = SupabaseMappingUtils.stringValue(profile, const ['id']);
      if (id.isNotEmpty) {
        map[id] = profile;
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> _profileById(String id) async {
    if (id.isEmpty) {
      return const {};
    }
    final row = await _client
        .from('profiles')
        .select('id,display_name,username')
        .eq('id', id)
        .maybeSingle();
    return row ?? const <String, dynamic>{};
  }

  Future<Map<String, bool>> _mutualFollowMap(
    String userId,
    Set<String> opponentIds,
  ) async {
    if (opponentIds.isEmpty) {
      return const {};
    }

    final rows = await _client
        .from('user_follows')
        .select('follower_user_id,followed_user_id')
        .or('follower_user_id.eq.$userId,followed_user_id.eq.$userId')
        .inFilter('follower_user_id', <String>[userId, ...opponentIds])
        .inFilter('followed_user_id', <String>[userId, ...opponentIds]);

    final following = <String>{};
    final followers = <String>{};
    for (final dynamic row in rows) {
      final map = row as Map<String, dynamic>;
      final follower = SupabaseMappingUtils.stringValue(map, const [
        'follower_user_id',
      ]);
      final followed = SupabaseMappingUtils.stringValue(map, const [
        'followed_user_id',
      ]);
      if (follower == userId && opponentIds.contains(followed)) {
        following.add(followed);
      }
      if (followed == userId && opponentIds.contains(follower)) {
        followers.add(follower);
      }
    }

    final result = <String, bool>{};
    for (final id in opponentIds) {
      result[id] = following.contains(id) && followers.contains(id);
    }
    return result;
  }

  Future<bool> _isMutualFollow(String userId, String opponentUserId) async {
    final map = await _mutualFollowMap(userId, {opponentUserId});
    return map[opponentUserId] ?? false;
  }

  Future<void> _progressQuizClashBotMatches() async {
    try {
      await _client.rpc('quiz_clash_progress_bot_matches');
    } on PostgrestException {
      // Keep compatibility with environments that have not applied bot migration yet.
    }
  }

  Future<void> _advanceQuizClashBotTurn(String matchId) async {
    try {
      await _client.rpc(
        'quiz_clash_advance_bot_turn',
        params: {'p_match_id': matchId, 'p_force': false},
      );
    } on PostgrestException {
      // Keep compatibility with environments that have not applied bot migration yet.
    }
  }
}

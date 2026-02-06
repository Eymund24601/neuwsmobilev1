import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/game_round.dart';
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
}

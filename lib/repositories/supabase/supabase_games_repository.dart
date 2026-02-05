import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/quiz_summary.dart';
import '../games_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseGamesRepository implements GamesRepository {
  const SupabaseGamesRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<List<String>> getQuizCategories() async {
    final rows = await _client
        .from('quizzes')
        .select('category')
        .eq('is_published', true);

    final categories = rows
        .map<String>((dynamic row) {
          final map = row as Map<String, dynamic>;
          return SupabaseMappingUtils.stringValue(map, const [
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
    final row = await _client
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
    if (row == null) {
      return null;
    }
    return _mapQuiz(row);
  }

  @override
  Future<List<QuizSummary>> getQuizzesByCategory(String category) async {
    final rows = await _client
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

    return rows
        .map<QuizSummary>(
          (dynamic row) => _mapQuiz(row as Map<String, dynamic>),
        )
        .toList();
  }

  QuizSummary _mapQuiz(Map<String, dynamic> row) {
    return QuizSummary(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      title: SupabaseMappingUtils.stringValue(row, const [
        'title',
      ], fallback: 'Untitled quiz'),
      category: SupabaseMappingUtils.stringValue(row, const [
        'category',
      ], fallback: 'General'),
      difficulty: SupabaseMappingUtils.stringValue(row, const [
        'difficulty',
      ], fallback: 'Easy'),
      estimatedMinutes: SupabaseMappingUtils.intValue(row, const [
        'estimated_minutes',
        'estimatedMinutes',
      ], fallback: 3),
      isPremium: SupabaseMappingUtils.boolValue(row, const [
        'is_premium',
      ], fallback: false),
    );
  }
}

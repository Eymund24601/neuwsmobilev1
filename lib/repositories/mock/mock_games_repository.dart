import '../../models/quiz_summary.dart';
import '../games_repository.dart';

class MockGamesRepository implements GamesRepository {
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

  @override
  Future<List<String>> getQuizCategories() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return _quizzes.map((quiz) => quiz.category).toSet().toList();
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
}

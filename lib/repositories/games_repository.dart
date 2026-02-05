import '../models/quiz_summary.dart';

abstract class GamesRepository {
  Future<List<String>> getQuizCategories();
  Future<List<QuizSummary>> getQuizzesByCategory(String category);
  Future<QuizSummary?> getQuizById(String quizId);
}

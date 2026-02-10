import '../models/game_round.dart';
import '../models/quiz_summary.dart';

abstract class GamesRepository {
  Future<List<String>> getQuizCategories();
  Future<List<QuizSummary>> getQuizzesByCategory(String category);
  Future<QuizSummary?> getQuizById(String quizId);
  Future<void> submitQuizAttempt({
    required String quizId,
    required int score,
    required int maxScore,
    required Duration duration,
  });
  Future<List<SudokuRound>> getSudokuSkillRounds();
  Future<SudokuRound?> getSudokuRoundBySkillPoint(int skillPoint);
  Future<EurodleRound?> getActiveEurodleRound();
}

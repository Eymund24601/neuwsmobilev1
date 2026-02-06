import '../models/game_round.dart';
import '../models/quiz_summary.dart';

abstract class GamesRepository {
  Future<List<String>> getQuizCategories();
  Future<List<QuizSummary>> getQuizzesByCategory(String category);
  Future<QuizSummary?> getQuizById(String quizId);
  Future<List<SudokuRound>> getSudokuSkillRounds();
  Future<SudokuRound?> getSudokuRoundBySkillPoint(int skillPoint);
  Future<EurodleRound?> getActiveEurodleRound();
}

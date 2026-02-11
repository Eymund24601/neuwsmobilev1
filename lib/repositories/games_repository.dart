import '../models/game_session.dart';
import '../models/game_round.dart';
import '../models/quiz_clash_models.dart';
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

  Future<List<QuizClashInviteSummary>> getQuizClashInvites();
  Future<List<QuizClashMatchSummary>> getQuizClashMatches();
  Future<QuizClashTurnState?> getQuizClashTurnState(String matchId);
  Future<String?> sendQuizClashInvite({
    String? opponentUserId,
    bool random = false,
  });
  Future<String?> respondToQuizClashInvite({
    required String inviteId,
    required bool accept,
  });
  Future<void> pickQuizClashCategory({
    required String matchId,
    required int roundIndex,
    required String selectedCategoryId,
  });
  Future<void> submitQuizClashPickerTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  });
  Future<void> submitQuizClashResponderTurn({
    required String matchId,
    required int roundIndex,
    required List<int> answers,
    required List<int> answerDurationsMs,
  });
  Future<void> claimQuizClashTimeoutForfeit(String matchId);

  Future<List<SudokuRound>> getSudokuSkillRounds();
  Future<SudokuRound?> getSudokuRoundBySkillPoint(int skillPoint);
  Future<EurodleRound?> getActiveEurodleRound();

  Future<GameSessionSnapshot?> getInProgressGameSession({
    required String gameSlug,
    required String roundId,
  });
  Future<GameSessionSnapshot?> startOrResumeGameSession({
    required String gameSlug,
    required String roundId,
    required Map<String, dynamic> initialState,
  });
  Future<void> saveGameSessionProgress({
    required String sessionId,
    required int movesCount,
    required Duration elapsed,
    required Map<String, dynamic> state,
  });
  Future<void> completeGameSession({
    required String sessionId,
    required int score,
    required int maxScore,
    required int movesCount,
    required Duration elapsed,
    required Map<String, dynamic> state,
  });
}

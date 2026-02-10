import '../../models/game_round.dart';
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
}

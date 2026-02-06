class SudokuRound {
  const SudokuRound({
    required this.id,
    required this.roundKey,
    required this.skillPoint,
    required this.difficulty,
    required this.puzzleGrid,
    required this.solutionGrid,
    required this.publishedAt,
  });

  final String id;
  final String roundKey;
  final int skillPoint;
  final String difficulty;
  final String puzzleGrid;
  final String solutionGrid;
  final DateTime? publishedAt;

  factory SudokuRound.fromJson(Map<String, dynamic> json) {
    return SudokuRound(
      id: json['id'] as String,
      roundKey: json['roundKey'] as String,
      skillPoint: json['skillPoint'] as int,
      difficulty: json['difficulty'] as String,
      puzzleGrid: json['puzzleGrid'] as String,
      solutionGrid: json['solutionGrid'] as String,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundKey': roundKey,
      'skillPoint': skillPoint,
      'difficulty': difficulty,
      'puzzleGrid': puzzleGrid,
      'solutionGrid': solutionGrid,
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }
}

class EurodleRound {
  const EurodleRound({
    required this.id,
    required this.roundKey,
    required this.difficulty,
    required this.targetWord,
    required this.wordLength,
    required this.maxAttempts,
    required this.allowedWords,
    required this.hint,
    required this.publishedAt,
  });

  final String id;
  final String roundKey;
  final String difficulty;
  final String targetWord;
  final int wordLength;
  final int maxAttempts;
  final List<String> allowedWords;
  final String hint;
  final DateTime? publishedAt;

  factory EurodleRound.fromJson(Map<String, dynamic> json) {
    return EurodleRound(
      id: json['id'] as String,
      roundKey: json['roundKey'] as String,
      difficulty: json['difficulty'] as String,
      targetWord: json['targetWord'] as String,
      wordLength: json['wordLength'] as int,
      maxAttempts: json['maxAttempts'] as int,
      allowedWords: (json['allowedWords'] as List<dynamic>).cast<String>(),
      hint: json['hint'] as String,
      publishedAt: json['publishedAt'] == null
          ? null
          : DateTime.tryParse(json['publishedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'roundKey': roundKey,
      'difficulty': difficulty,
      'targetWord': targetWord,
      'wordLength': wordLength,
      'maxAttempts': maxAttempts,
      'allowedWords': allowedWords,
      'hint': hint,
      'publishedAt': publishedAt?.toIso8601String(),
    };
  }
}

class GameSessionSnapshot {
  const GameSessionSnapshot({
    required this.id,
    required this.userId,
    required this.gameId,
    required this.roundId,
    required this.status,
    required this.score,
    required this.maxScore,
    required this.movesCount,
    required this.durationMs,
    required this.state,
    required this.startedAt,
    required this.completedAt,
    required this.updatedAt,
  });

  final String id;
  final String userId;
  final String gameId;
  final String roundId;
  final String status;
  final int score;
  final int? maxScore;
  final int movesCount;
  final int durationMs;
  final Map<String, dynamic> state;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? updatedAt;
}

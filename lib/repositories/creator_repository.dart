class CreatorStudioSnapshot {
  const CreatorStudioSnapshot({
    required this.drafts,
    required this.publishedThisMonth,
    required this.estimatedEarnings,
  });

  final int drafts;
  final int publishedThisMonth;
  final String estimatedEarnings;
}

abstract class CreatorRepository {
  Future<CreatorStudioSnapshot> getStudioSnapshot();
}

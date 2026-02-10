import '../creator_repository.dart';

class MockCreatorRepository implements CreatorRepository {
  @override
  Future<CreatorStudioSnapshot> getStudioSnapshot() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const CreatorStudioSnapshot(
      drafts: 4,
      publishedThisMonth: 3,
      estimatedEarnings: 'EUR 184',
    );
  }

  @override
  Future<void> saveDraft({
    required String headline,
    required String topic,
    required String body,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }
}

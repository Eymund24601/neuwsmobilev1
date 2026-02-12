import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/repositories/mock/mock_article_repository.dart';

void main() {
  test('mock article bundle exposes token payloads', () async {
    final repo = MockArticleRepository();
    final bundle = await repo.getArticleBundleBySlug(
      'europe-social-club',
      'en',
      'sv',
      'en',
    );

    expect(bundle, isNotNull);
    expect(bundle!.canonicalTokens, isNotEmpty);
    expect(bundle.topTokens, isNotEmpty);
    expect(bundle.bottomTokens, isNotEmpty);
    expect(bundle.tokenAlignmentsToBottom, isNotEmpty);
  });
}

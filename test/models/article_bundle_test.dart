import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/models/article_bundle.dart';

void main() {
  group('ArticleBundle token graph payload', () {
    test('fromJson keeps backward compatibility without token fields', () {
      final bundle = ArticleBundle.fromJson(_baseBundleJson());

      expect(bundle.canonicalTokens, isEmpty);
      expect(bundle.topTokens, isEmpty);
      expect(bundle.bottomTokens, isEmpty);
      expect(bundle.tokenAlignmentsToTop, isEmpty);
      expect(bundle.tokenAlignmentsToBottom, isEmpty);
    });

    test('fromJson parses token graph fields when provided', () {
      final json = _baseBundleJson()
        ..addAll({
          'canonicalTokens': [
            {
              'id': 'ct-1',
              'articleId': 'a1',
              'localizationId': 'loc-c',
              'tokenIndex': 1,
              'startUtf16': 0,
              'endUtf16': 4,
              'surface': 'home',
              'normalizedSurface': 'home',
              'primaryVocabItemId': 'v1',
            },
          ],
          'topTokens': [
            {
              'id': 'tt-1',
              'articleId': 'a1',
              'localizationId': 'loc-t',
              'tokenIndex': 1,
              'startUtf16': 0,
              'endUtf16': 4,
              'surface': 'home',
              'normalizedSurface': 'home',
              'primaryVocabItemId': 'v1',
            },
          ],
          'bottomTokens': [
            {
              'id': 'bt-1',
              'articleId': 'a1',
              'localizationId': 'loc-b',
              'tokenIndex': 1,
              'startUtf16': 0,
              'endUtf16': 5,
              'surface': 'hemma',
              'normalizedSurface': 'hemma',
              'primaryVocabItemId': 'v1',
            },
          ],
          'tokenAlignmentsToBottom': [
            {
              'canonicalTokenId': 'ct-1',
              'targetLocalizationId': 'loc-b',
              'targetTokenId': 'bt-1',
              'score': 0.94,
              'algoVersion': 'seed',
            },
          ],
        });

      final bundle = ArticleBundle.fromJson(json);

      expect(bundle.canonicalTokens, hasLength(1));
      expect(bundle.canonicalTokens.first.id, equals('ct-1'));
      expect(bundle.bottomTokens.first.surface, equals('hemma'));
      expect(bundle.tokenAlignmentsToBottom, hasLength(1));
      expect(
        bundle.tokenAlignmentsToBottom.first.targetTokenId,
        equals('bt-1'),
      );
    });
  });
}

Map<String, dynamic> _baseBundleJson() {
  return {
    'articleId': 'a1',
    'slug': 'story',
    'canonicalLang': 'en',
    'canonicalLocalization': {
      'id': 'loc-c',
      'articleId': 'a1',
      'lang': 'en',
      'title': 't',
      'excerpt': 'e',
      'body': 'home',
      'contentHash': '',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'topLocalization': {
      'id': 'loc-t',
      'articleId': 'a1',
      'lang': 'en',
      'title': 't',
      'excerpt': 'e',
      'body': 'home',
      'contentHash': '',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'bottomLocalization': {
      'id': 'loc-b',
      'articleId': 'a1',
      'lang': 'sv',
      'title': 't',
      'excerpt': 'e',
      'body': 'hemma',
      'contentHash': '',
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
    },
    'alignmentToTop': null,
    'alignmentToBottom': null,
    'focusVocab': {'articleId': 'a1', 'items': []},
  };
}

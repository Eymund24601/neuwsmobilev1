import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/services/polyglot/word_token_utils.dart';

void main() {
  group('PolyglotWordTokenUtils', () {
    test('normalizeToken keeps native letters and strips punctuation', () {
      expect(
        PolyglotWordTokenUtils.normalizeToken('\u0046\u00F6reningar!'),
        equals('f\u00F6reningar'),
      );
      expect(
        PolyglotWordTokenUtils.normalizeToken('\u010Cesk\u00FD-k\u00F3d'),
        equals('\u010Desk\u00FDk\u00F3d'),
      );
      expect(
        PolyglotWordTokenUtils.normalizeToken('  coop\u00E9ration  '),
        equals('coop\u00E9ration'),
      );
    });

    test('trimEdgePunctuation keeps token body', () {
      expect(
        PolyglotWordTokenUtils.trimEdgePunctuation(
          '\u201Cf\u00F6reningar,\u201D',
        ),
        equals('f\u00F6reningar'),
      );
      expect(
        PolyglotWordTokenUtils.trimEdgePunctuation('...co-op...'),
        equals('co-op'),
      );
    });

    test('isWordCharacter supports extended latin letters', () {
      expect(PolyglotWordTokenUtils.isWordCharacter('\u00F6'), isTrue);
      expect(PolyglotWordTokenUtils.isWordCharacter('\u010D'), isTrue);
      expect(PolyglotWordTokenUtils.isWordCharacter('-'), isTrue);
      expect(PolyglotWordTokenUtils.isWordCharacter('.'), isFalse);
    });
  });
}

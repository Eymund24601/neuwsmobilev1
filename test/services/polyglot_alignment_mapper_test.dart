import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/services/polyglot/alignment_mapper.dart';

void main() {
  group('PolyglotAlignmentMapper', () {
    test('rejects coarse low-granularity alignment packs for word taps', () {
      final units = <PolyglotAlignmentUnit>[
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 0, end: 90),
          target: PolyglotTextRange(start: 0, end: 90),
          score: 0.93,
        ),
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 90, end: 180),
          target: PolyglotTextRange(start: 90, end: 180),
          score: 0.9,
        ),
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 180, end: 4200),
          target: PolyglotTextRange(start: 180, end: 4400),
          score: 0.87,
        ),
      ];

      final mapped = PolyglotAlignmentMapper.mapRange(
        units: units,
        input: const PolyglotTextRange(start: 197, end: 207),
        fromCanonical: false,
      );

      expect(mapped, isNull);
    });

    test('maps with fine-grained nearby units', () {
      final units = <PolyglotAlignmentUnit>[
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 170, end: 190),
          target: PolyglotTextRange(start: 178, end: 198),
          score: 0.9,
        ),
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 190, end: 210),
          target: PolyglotTextRange(start: 198, end: 218),
          score: 0.92,
        ),
      ];

      final mapped = PolyglotAlignmentMapper.mapRange(
        units: units,
        input: const PolyglotTextRange(start: 201, end: 209),
        fromCanonical: false,
      );

      expect(mapped, isNotNull);
      expect(mapped!.start, inInclusiveRange(190, 205));
      expect(mapped.end, inInclusiveRange(191, 212));
    });

    test('skips far-away units with no overlap', () {
      final units = <PolyglotAlignmentUnit>[
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 0, end: 20),
          target: PolyglotTextRange(start: 0, end: 20),
          score: 0.9,
        ),
      ];

      final mapped = PolyglotAlignmentMapper.mapRange(
        units: units,
        input: const PolyglotTextRange(start: 220, end: 230),
        fromCanonical: false,
      );

      expect(mapped, isNull);
    });

    test('ignores units outside current text bounds', () {
      final units = <PolyglotAlignmentUnit>[
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 500, end: 540),
          target: PolyglotTextRange(start: 1200, end: 1240),
          score: 0.91,
        ),
      ];

      final mapped = PolyglotAlignmentMapper.mapRange(
        units: units,
        input: const PolyglotTextRange(start: 1210, end: 1220),
        fromCanonical: false,
        canonicalTextLength: 180,
        targetTextLength: 260,
      );

      expect(mapped, isNull);
    });

    test('keeps mapping when at least one bounded unit is valid', () {
      final units = <PolyglotAlignmentUnit>[
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 500, end: 540),
          target: PolyglotTextRange(start: 1200, end: 1240),
          score: 0.91,
        ),
        const PolyglotAlignmentUnit(
          canonical: PolyglotTextRange(start: 20, end: 40),
          target: PolyglotTextRange(start: 30, end: 50),
          score: 0.95,
        ),
      ];

      final mapped = PolyglotAlignmentMapper.mapRange(
        units: units,
        input: const PolyglotTextRange(start: 34, end: 39),
        fromCanonical: false,
        canonicalTextLength: 180,
        targetTextLength: 260,
      );

      expect(mapped, isNotNull);
      expect(mapped!.start, inInclusiveRange(20, 40));
      expect(mapped.end, inInclusiveRange(mapped.start + 1, 41));
    });
  });
}

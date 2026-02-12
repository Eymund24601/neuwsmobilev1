class PolyglotTextRange {
  const PolyglotTextRange({required this.start, required this.end});

  final int start;
  final int end;

  int get length => (end - start).clamp(0, 1 << 30).toInt();

  bool get isValid => end >= start;
}

class PolyglotAlignmentUnit {
  const PolyglotAlignmentUnit({
    required this.canonical,
    required this.target,
    required this.score,
  });

  final PolyglotTextRange canonical;
  final PolyglotTextRange target;
  final double? score;
}

class PolyglotAlignmentMapper {
  PolyglotAlignmentMapper._();

  static const int _maxWordTapUnitLength = 64;
  static const int _maxPhraseTapUnitLength = 220;
  static const int _maxWordTapDistance = 32;
  static const int _maxPhraseTapDistance = 80;
  static const double _minUnitScore = 0.2;

  static PolyglotTextRange? mapRange({
    required List<PolyglotAlignmentUnit> units,
    required PolyglotTextRange input,
    required bool fromCanonical,
    int? canonicalTextLength,
    int? targetTextLength,
  }) {
    if (units.isEmpty || !input.isValid || input.length <= 0) {
      return null;
    }

    final isWordTap = input.length <= 40;
    if (isWordTap && _looksCoarse(units, fromCanonical: fromCanonical)) {
      return null;
    }

    final center = ((input.start + input.end) / 2).round();
    _Candidate? best;

    for (final unit in units) {
      if (!_rangeWithinBounds(unit.canonical, canonicalTextLength) ||
          !_rangeWithinBounds(unit.target, targetTextLength)) {
        continue;
      }

      final fromRange = fromCanonical ? unit.canonical : unit.target;
      final toRange = fromCanonical ? unit.target : unit.canonical;
      if (!fromRange.isValid || !toRange.isValid) {
        continue;
      }
      if (fromRange.length <= 0 || toRange.length <= 0) {
        continue;
      }

      final score = unit.score;
      if (score != null && score < _minUnitScore) {
        continue;
      }

      final overlap = _overlapLength(input, fromRange);
      final distance = _distanceToRange(center, fromRange);
      final maxAllowedLength = isWordTap
          ? _maxWordTapUnitLength
          : _maxPhraseTapUnitLength;
      final isTooCoarse =
          fromRange.length > maxAllowedLength &&
          fromRange.length > (input.length * 8);

      if (isTooCoarse) {
        continue;
      }

      final maxAllowedDistance = isWordTap
          ? _maxWordTapDistance
          : _maxPhraseTapDistance;
      if (overlap <= 0 && distance > maxAllowedDistance) {
        continue;
      }

      final effectiveScore =
          overlap * 1000 -
          distance * 8 -
          fromRange.length +
          (((score ?? 0.6) * 100).round());
      if (best == null || effectiveScore > best.effectiveScore) {
        best = _Candidate(
          fromRange: fromRange,
          toRange: toRange,
          effectiveScore: effectiveScore,
        );
      }
    }

    if (best == null) {
      return null;
    }

    final fromRange = best.fromRange;
    final toRange = best.toRange;
    final ratio =
        (center - fromRange.start).clamp(0, fromRange.length).toDouble() /
        fromRange.length.toDouble();
    final mappedCenter = toRange.start + (toRange.length * ratio).round();
    final scaledLength = ((input.length / fromRange.length) * toRange.length)
        .round()
        .clamp(1, toRange.length);
    final mappedStart = (mappedCenter - (scaledLength ~/ 2))
        .clamp(toRange.start, toRange.end)
        .toInt();
    final mappedEnd = (mappedStart + scaledLength)
        .clamp(mappedStart + 1, toRange.end + 1)
        .toInt();
    return PolyglotTextRange(start: mappedStart, end: mappedEnd);
  }

  static bool _rangeWithinBounds(PolyglotTextRange range, int? textLength) {
    if (textLength == null) {
      return true;
    }
    if (textLength < 0) {
      return false;
    }
    return range.start >= 0 && range.end <= textLength;
  }

  static bool _looksCoarse(
    List<PolyglotAlignmentUnit> units, {
    required bool fromCanonical,
  }) {
    if (units.length > 4) {
      return false;
    }

    final lengths = units
        .map(
          (unit) => fromCanonical ? unit.canonical.length : unit.target.length,
        )
        .where((length) => length > 0)
        .toList();
    if (lengths.isEmpty) {
      return true;
    }
    final sum = lengths.fold<int>(0, (acc, item) => acc + item);
    final average = sum / lengths.length;
    return average >= 64;
  }

  static int _overlapLength(PolyglotTextRange a, PolyglotTextRange b) {
    final start = a.start > b.start ? a.start : b.start;
    final end = a.end < b.end ? a.end : b.end;
    return (end - start).clamp(0, 1 << 30).toInt();
  }

  static int _distanceToRange(int offset, PolyglotTextRange range) {
    if (offset < range.start) {
      return range.start - offset;
    }
    if (offset > range.end) {
      return offset - range.end;
    }
    return 0;
  }
}

class _Candidate {
  const _Candidate({
    required this.fromRange,
    required this.toRange,
    required this.effectiveScore,
  });

  final PolyglotTextRange fromRange;
  final PolyglotTextRange toRange;
  final int effectiveScore;
}

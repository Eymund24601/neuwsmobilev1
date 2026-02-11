class SudokuEngine {
  static const int size = 9;
  static const int cellCount = size * size;

  const SudokuEngine._();

  static List<int> decodeGrid(String raw) {
    final source = raw.trim();
    final values = List<int>.filled(cellCount, 0);
    final limit = source.length < cellCount ? source.length : cellCount;
    for (var i = 0; i < limit; i++) {
      final value = int.tryParse(source[i]) ?? 0;
      values[i] = _normalize(value);
    }
    return values;
  }

  static String encodeGrid(List<int> values) {
    final buffer = StringBuffer();
    for (var i = 0; i < cellCount; i++) {
      final value = i < values.length ? _normalize(values[i]) : 0;
      buffer.write(value);
    }
    return buffer.toString();
  }

  static bool isFixedCell({required List<int> puzzle, required int index}) {
    if (index < 0 || index >= cellCount || index >= puzzle.length) {
      return false;
    }
    return _normalize(puzzle[index]) > 0;
  }

  static bool hasConflict({required List<int> board, required int index}) {
    if (index < 0 || index >= board.length || index >= cellCount) {
      return false;
    }
    final value = _normalize(board[index]);
    if (value == 0) {
      return false;
    }

    final row = index ~/ size;
    final col = index % size;

    for (var c = 0; c < size; c++) {
      final candidateIndex = row * size + c;
      if (candidateIndex == index || candidateIndex >= board.length) {
        continue;
      }
      if (_normalize(board[candidateIndex]) == value) {
        return true;
      }
    }

    for (var r = 0; r < size; r++) {
      final candidateIndex = r * size + col;
      if (candidateIndex == index || candidateIndex >= board.length) {
        continue;
      }
      if (_normalize(board[candidateIndex]) == value) {
        return true;
      }
    }

    final boxRowStart = (row ~/ 3) * 3;
    final boxColStart = (col ~/ 3) * 3;
    for (var r = boxRowStart; r < boxRowStart + 3; r++) {
      for (var c = boxColStart; c < boxColStart + 3; c++) {
        final candidateIndex = r * size + c;
        if (candidateIndex == index || candidateIndex >= board.length) {
          continue;
        }
        if (_normalize(board[candidateIndex]) == value) {
          return true;
        }
      }
    }

    return false;
  }

  static bool isSolved({
    required List<int> board,
    required List<int> solution,
  }) {
    if (solution.length < cellCount || board.length < cellCount) {
      return false;
    }
    for (var i = 0; i < cellCount; i++) {
      if (_normalize(board[i]) != _normalize(solution[i])) {
        return false;
      }
    }
    return true;
  }

  static bool hasAnyConflict(List<int> board) {
    final limit = board.length < cellCount ? board.length : cellCount;
    for (var i = 0; i < limit; i++) {
      if (hasConflict(board: board, index: i)) {
        return true;
      }
    }
    return false;
  }

  static int filledCount(List<int> board) {
    final limit = board.length < cellCount ? board.length : cellCount;
    var count = 0;
    for (var i = 0; i < limit; i++) {
      if (_normalize(board[i]) > 0) {
        count++;
      }
    }
    return count;
  }

  static Set<int> relatedIndices(int index) {
    if (index < 0 || index >= cellCount) {
      return const {};
    }
    final row = index ~/ size;
    final col = index % size;
    final related = <int>{};

    for (var c = 0; c < size; c++) {
      related.add(row * size + c);
    }
    for (var r = 0; r < size; r++) {
      related.add(r * size + col);
    }

    final boxRowStart = (row ~/ 3) * 3;
    final boxColStart = (col ~/ 3) * 3;
    for (var r = boxRowStart; r < boxRowStart + 3; r++) {
      for (var c = boxColStart; c < boxColStart + 3; c++) {
        related.add(r * size + c);
      }
    }

    return related;
  }

  static int _normalize(int value) {
    if (value < 1 || value > 9) {
      return 0;
    }
    return value;
  }
}

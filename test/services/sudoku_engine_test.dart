import 'package:flutter_test/flutter_test.dart';
import 'package:neuws_mobile_v1/services/games/sudoku_engine.dart';

void main() {
  test('decode and encode keep 81-cell shape', () {
    const raw =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    final decoded = SudokuEngine.decodeGrid(raw);
    expect(decoded.length, 81);
    expect(SudokuEngine.encodeGrid(decoded), raw);
  });

  test('detects row, column, and box conflicts', () {
    final board = List<int>.filled(81, 0);

    board[0] = 5;
    board[1] = 5;
    expect(SudokuEngine.hasConflict(board: board, index: 0), isTrue);
    expect(SudokuEngine.hasConflict(board: board, index: 1), isTrue);

    board[1] = 0;
    board[9] = 5;
    expect(SudokuEngine.hasConflict(board: board, index: 0), isTrue);
    expect(SudokuEngine.hasConflict(board: board, index: 9), isTrue);

    board[9] = 0;
    board[10] = 5;
    expect(SudokuEngine.hasConflict(board: board, index: 0), isTrue);
    expect(SudokuEngine.hasConflict(board: board, index: 10), isTrue);
  });

  test('isSolved validates against solution grid', () {
    const solution =
        '534678912672195348198342567859761423426853791713924856961537284287419635345286179';
    final solved = SudokuEngine.decodeGrid(solution);
    final wrong = List<int>.from(solved)..[80] = 8;
    expect(SudokuEngine.isSolved(board: solved, solution: solved), isTrue);
    expect(SudokuEngine.isSolved(board: wrong, solution: solved), isFalse);
  });

  test('relatedIndices returns row/col/box peers including self', () {
    final related = SudokuEngine.relatedIndices(40);
    expect(related.length, 21);
    expect(related.contains(40), isTrue);
    expect(related.contains(36), isTrue); // same row
    expect(related.contains(4), isTrue); // same column
    expect(related.contains(30), isTrue); // same box
  });
}

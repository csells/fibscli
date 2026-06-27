import 'package:fibsboard/fibsboard.dart' as fb;
import 'package:test/test.dart';

void main() {
  test('fibsboard', () {
    final lines = fb.linesFromString('''
+13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
|             O  O | O |    O  O        O |   |
|             O    |   |       O        O |   |
|             O    |   |                O |   |
|             O    |   |                O |   |
|             O    |   |                O |   |
|                  |   |                  |   |
|                  |   | 9                | 6 |
|                  |   | X                | X |
|                  |   | X                | X |
|                  |   | X                | X |
|                  |   | X                | X |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final lines2 = fb.linesFromBoard(board);

    expect(lines2.length, lines.length);
    for (var i = 0; i != 13; ++i) {
      expect(lines[i], lines2[i]);
    }

    final board2 = fb.boardFromLines(lines2);
    expect(board2.length, board.length);
    for (var i = 0; i != 26; ++i) {
      expect(board2[i].length, board[i].length);
      for (var j = 0; j != board[i].length; ++j) {
        expect(board[i][j], board2[i][j]);
      }
    }
  });
}

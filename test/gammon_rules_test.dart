import 'package:flutter_test/flutter_test.dart';
import 'package:fibscli/model.dart';
import 'package:fibsboard/fibsboard.dart' as fb;

void main() {
  test('simple legal move from open', () {
    final lines = fb.linesFromString('''
+13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
| X           O    |   | O              X |   |
| X           O    |   | O              X |   |
| X           O    |   | O                |   |
| X                |   | O                |   |
| X                |   | O                |   |
|                  |   |                  |   |
| O                |   | X                |   |
| O                |   | X                |   |
| O           X    |   | X                |   |
| O           X    |   | X              O |   |
| O           X    |   | X              O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(player: Player.one, fromPipNo: 6, toPipNo: 5, hops: [1]);
    final result = GammonRules.legalMove(move, board);
    expect(result, isNotEmpty);
  });
  
}

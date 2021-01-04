import 'package:flutter_test/flutter_test.dart';
import 'package:fibscli/model.dart';
import 'package:fibsboard/fibsboard.dart' as fb;

// rules from https://www.bkgm.com/rules.html
void main() {
  test('one-hop move from open', () {
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 5);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(1));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 6);
    expect(deltasForHops[0][0].toPipNo, 5);
  });

  test('one-hop move from open (white)', () {
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
    final move = GammonMove(fromPipNo: 1, toPipNo: 5);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(1));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 1);
    expect(deltasForHops[0][0].toPipNo, 5);
  });

  test('two-hop move from open', () {
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
    final move = GammonMove(fromPipNo: 13, toPipNo: 5, hops: [-6, -2]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(2));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 13);
    expect(deltasForHops[0][0].toPipNo, 7);
    expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[1][0].fromPipNo, 7);
    expect(deltasForHops[1][0].toPipNo, 5);
  });

  test('three-hop move from open', () {
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
    final move = GammonMove(fromPipNo: 13, toPipNo: 7, hops: [-2, -2, -2]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(3));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 13);
    expect(deltasForHops[0][0].toPipNo, 11);
    expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[1][0].fromPipNo, 11);
    expect(deltasForHops[1][0].toPipNo, 9);
    expect(deltasForHops[2][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[2][0].fromPipNo, 9);
    expect(deltasForHops[2][0].toPipNo, 7);
  });

  test('four-hop move from open', () {
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
    final move = GammonMove(fromPipNo: 13, toPipNo: 5, hops: [-2, -2, -2, -2]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(4));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 13);
    expect(deltasForHops[0][0].toPipNo, 11);
    expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[1][0].fromPipNo, 11);
    expect(deltasForHops[1][0].toPipNo, 9);
    expect(deltasForHops[2][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[2][0].fromPipNo, 9);
    expect(deltasForHops[2][0].toPipNo, 7);
    expect(deltasForHops[3][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[3][0].fromPipNo, 7);
    expect(deltasForHops[3][0].toPipNo, 5);
  });

  test('one-hop illegal move from open', () {
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 1);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });

  test('one-hop illegal move from open (white)', () {
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
    final move = GammonMove(fromPipNo: 1, toPipNo: 6);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });

  test('two-hop illegal move from open', () {
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-1, -4]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });

  test('three-hop illegal move from open', () {
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
    final move = GammonMove(fromPipNo: 24, toPipNo: 6, hops: [-6, -6, -6]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });

  test('four-hop illegal move from open', () {
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
    final move = GammonMove(fromPipNo: 19, toPipNo: 7, hops: [-3, -3, -3, -3]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });

  test('one-hop hit', () {
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
| O           X    |   | X                |   |
| O           X    |   | X           O  O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(fromPipNo: 6, toPipNo: 2);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(1));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.hit);
    expect(deltasForHops[0][0].fromPipNo, 6);
    expect(deltasForHops[0][0].toPipNo, 2);
    expect(deltasForHops[0][1].kind, GammonDeltaKind.bar);
    expect(deltasForHops[0][1].fromPipNo, 2);
    expect(deltasForHops[0][1].toPipNo, 0);
  });

  test('two-hop hit', () {
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
| O           X    |   | X                |   |
| O           X    |   | X           O  O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(fromPipNo: 6, toPipNo: 2, hops: [-1, -3]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(2));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 6);
    expect(deltasForHops[0][0].toPipNo, 5);
    expect(deltasForHops[1][0].kind, GammonDeltaKind.hit);
    expect(deltasForHops[1][0].fromPipNo, 5);
    expect(deltasForHops[1][0].toPipNo, 2);
    expect(deltasForHops[1][1].kind, GammonDeltaKind.bar);
    expect(deltasForHops[1][1].fromPipNo, 2);
    expect(deltasForHops[1][1].toPipNo, 0);
  });

  test('two hops, two hits', () {
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
| O           X    |   | X                |   |
| O           X    |   | X           O  O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-4, -1]);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(2));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.hit);
    expect(deltasForHops[0][0].fromPipNo, 6);
    expect(deltasForHops[0][0].toPipNo, 2);
    expect(deltasForHops[0][1].kind, GammonDeltaKind.bar);
    expect(deltasForHops[0][1].fromPipNo, 2);
    expect(deltasForHops[0][1].toPipNo, 0);
    expect(deltasForHops[1][0].kind, GammonDeltaKind.hit);
    expect(deltasForHops[1][0].fromPipNo, 2);
    expect(deltasForHops[1][0].toPipNo, 1);
    expect(deltasForHops[1][1].kind, GammonDeltaKind.bar);
    expect(deltasForHops[1][1].fromPipNo, 1);
    expect(deltasForHops[1][1].toPipNo, 0);
  });

  test('one coming off the bar', () {
    final lines = fb.linesFromString('''
+13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
| X           O    |   | O              X |   |
| X           O    |   | O              X |   |
| X           O    |   | O                |   |
| X                |   | O                |   |
| X                |   | O                |   |
|                  |   |                  |   |
| O                |   |                  |   |
| O                |   | X                |   |
| O           X    |   | X                |   |
| O           X    |   | X              O |   |
| O           X    | X | X              O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(fromPipNo: 25, toPipNo: 23);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isNotEmpty);
    expect(deltasForHops, hasLength(1));
    expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
    expect(deltasForHops[0][0].fromPipNo, 25);
    expect(deltasForHops[0][0].toPipNo, 23);
  });

  test('illegal move w/ one on the bar', () {
    final lines = fb.linesFromString('''
+13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
| X           O    |   | O              X |   |
| X           O    |   | O              X |   |
| X           O    |   | O                |   |
| X                |   | O                |   |
| X                |   | O                |   |
|                  |   |                  |   |
| O                |   |                  |   |
| O                |   | X                |   |
| O           X    |   | X                |   |
| O           X    |   | X              O |   |
| O           X    | X | X              O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final move = GammonMove(fromPipNo: 6, toPipNo: 2);
    final deltasForHops = GammonRules.checkLegalMove(board, move);
    expect(deltasForHops, isEmpty);
  });


  test('ensure no illegal moves available w/ one on the bar', () {
    final lines = fb.linesFromString('''
+13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
| X           O    |   | O              X |   |
| X           O    |   | O              X |   |
| X           O    |   | O                |   |
| X                |   | O                |   |
| X                |   | O                |   |
|                  |   |                  |   |
| O                |   |                  |   |
| O                |   | X                |   |
| O           X    |   | X                |   |
| O           X    |   | X              O |   |
| O           X    | X | X              O |   |
+12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
''');

    final board = fb.boardFromLines(lines);
    final moves = GammonRules.getAllLegalMoves(board, Player.one, [4]);
    expect(moves, hasLength(1));
  });
}

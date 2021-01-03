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
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(1));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 6);
    expect(deltas[0].toPipNo, 5);
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
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(1));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 1);
    expect(deltas[0].toPipNo, 5);
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
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(2));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 13);
    expect(deltas[0].toPipNo, 7);
    expect(deltas[1].kind, GammonDeltaKind.move);
    expect(deltas[1].fromPipNo, 7);
    expect(deltas[1].toPipNo, 5);
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
    final move = GammonMove(fromPipNo: 13, toPipNo: 4, hops: [-2, -2, -2]);
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(3));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 13);
    expect(deltas[0].toPipNo, 11);
    expect(deltas[1].kind, GammonDeltaKind.move);
    expect(deltas[1].fromPipNo, 11);
    expect(deltas[1].toPipNo, 9);
    expect(deltas[2].kind, GammonDeltaKind.move);
    expect(deltas[2].fromPipNo, 9);
    expect(deltas[2].toPipNo, 7);
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
    final move = GammonMove(fromPipNo: 13, toPipNo: 4, hops: [-2, -2, -2, -2]);
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(4));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 13);
    expect(deltas[0].toPipNo, 11);
    expect(deltas[1].kind, GammonDeltaKind.move);
    expect(deltas[1].fromPipNo, 11);
    expect(deltas[1].toPipNo, 9);
    expect(deltas[2].kind, GammonDeltaKind.move);
    expect(deltas[2].fromPipNo, 9);
    expect(deltas[2].toPipNo, 7);
    expect(deltas[3].kind, GammonDeltaKind.move);
    expect(deltas[3].fromPipNo, 7);
    expect(deltas[3].toPipNo, 5);
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
    final result = GammonRules.legalMove(move, board);
    expect(result, isEmpty);
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
    final result = GammonRules.legalMove(move, board);
    expect(result, isEmpty);
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
    final result = GammonRules.legalMove(move, board);
    expect(result, isEmpty);
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-6, -6, -6]);
    final result = GammonRules.legalMove(move, board);
    expect(result, isEmpty);
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-4, -4, -4, -4]);
    final result = GammonRules.legalMove(move, board);
    expect(result, isEmpty);
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
    final move = GammonMove(fromPipNo: 6, toPipNo: 5);
    final deltas = GammonRules.legalMove(move, board);
    expect(deltas, isNotEmpty);
    expect(deltas, hasLength(1));
    expect(deltas[0].kind, GammonDeltaKind.move);
    expect(deltas[0].fromPipNo, 6);
    expect(deltas[0].toPipNo, 5);
  });
}

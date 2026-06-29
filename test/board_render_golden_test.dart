// Structural golden tests for the board renderer. Rather than pixel goldens
// (font/AA-fragile across machines), we snapshot the deterministic geometry
// PieceLayout.getLayouts produces -- every checker's pip, id, on-screen offset
// and edge flag -- for a few canonical boards. This pins down exactly where the
// board draws each checker (the layer the FIBS highlight/coordinate bugs lived
// in) and fails loudly if that ever shifts.
//
// Regenerate after an intentional layout change:
//   GOLDEN_WRITE=1 flutter test test/board_render_golden_test.dart

import 'dart:io';

import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

// a deterministic, human-diffable dump of a board's checker layouts
String _render(List<List<int>> board) {
  final layouts = PieceLayout.getLayouts(board).toList()
    ..sort((a, b) {
      final byPip = a.pipNo.compareTo(b.pipNo);
      return byPip != 0 ? byPip : a.pieceID.compareTo(b.pieceID);
    });
  String line(PieceLayout l) {
    final dx = l.offset!.dx.toStringAsFixed(1);
    final dy = l.offset!.dy.toStringAsFixed(1);
    return 'pip=${l.pipNo} id=${l.pieceID} off=($dx,$dy) '
        'edge=${l.edge} label="${l.label}"';
  }

  return layouts.map(line).join('\n');
}

// the standard opening, plus a hand-built position exercising bar + borne-off
// trays (where the trickier layout code -- and past FIBS bugs -- live).
List<List<int>> _barAndOffBoard() {
  final board = List<List<int>>.generate(26, (_) => <int>[]);
  board[6].addAll([-1, -2, -3]); // three player1 checkers on point 6
  board[13].addAll([1, 2, 3, 4, 5, 6]); // six player2 checkers on point 13
  board[25].addAll([-4, -5]); // two player1 checkers on the bar
  board[0].addAll([7, 8]); // two player2 checkers on the bar
  board[0].addAll([-6, -7]); // two player1 checkers borne off
  board[25].addAll([9, 10, 11]); // three player2 checkers borne off
  return board;
}

void _golden(String name, List<List<int>> board) {
  final rendered = _render(board);
  final file = File('test/goldens/$name.txt');
  if (Platform.environment['GOLDEN_WRITE'] == '1') {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync('$rendered\n');
    return;
  }
  expect(
    file.existsSync(),
    isTrue,
    reason: 'missing golden test/goldens/$name.txt; run with GOLDEN_WRITE=1',
  );
  expect(rendered, file.readAsStringSync().trimRight());
}

void main() {
  test('the opening board renders to its golden layout', () {
    _golden('board_opening', GammonRules.initialBoard());
  });

  test('a bar + borne-off board renders to its golden layout', () {
    _golden('board_bar_and_off', _barAndOffBoard());
  });
}

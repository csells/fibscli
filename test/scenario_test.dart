import 'package:fibsboard/fibsboard.dart' as fb;
import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/race_eval.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

// Full-board scenario tests authored as readable ASCII diagrams via fibsboard
// (the partial-position rule tests use board_builder instead, since fibsboard's
// checkBoard requires a complete 15-checker-per-side position).
void main() {
  group('fibsboard scenarios', () {
    test('the standard opening parses to the engine initial board', () {
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
      final expected = GammonRules.initialBoard();

      // same checker count on every pip as the engine's starting position
      for (var pip = 0; pip != 26; ++pip) {
        expect(board[pip].length, expected[pip].length, reason: 'pip $pip');
      }

      // and it plays like the opening: a 3-1 can make the five point
      final moves = GammonRules.getAllLegalMoves(board, GammonPlayer.one, [
        3,
        1,
      ]);
      expect(moves[8]!.any((m) => m.toPipNo == 5), isTrue);
      expect(moves[6]!.any((m) => m.toPipNo == 5), isTrue);
    });

    test('a full bear-off race round-trips through ASCII and is scored', () {
      // a full 15-vs-15 no-contact position
      final board = makeBoard({
        6: -3, 5: -3, 4: -3, 3: -2, 2: -2, 1: -2, //
        19: 3, 20: 3, 21: 3, 22: 2, 23: 2, 24: 2,
      });

      // render to an ASCII diagram and parse it back unchanged
      final parsed = fb.boardFromLines(fb.linesFromBoard(board));
      for (var pip = 0; pip != 26; ++pip) {
        expect(parsed[pip].length, board[pip].length, reason: 'pip $pip');
      }
      expect(GammonRules.isRace(parsed), isTrue);

      // A full 15-vs-15 race is past the exact solver's size cap (the race2.c
      // method only suits "relatively small positions"), so RaceEval bails to
      // null and the model uses the pip-count heuristic. Either way the player
      // gets a sensible win estimate.
      expect(RaceEval.winProbabilityOrNull(parsed, GammonPlayer.one), isNull);

      final game = GammonState.from(
        board: parsed,
        dice: [DieState(3), DieState(1)],
        turnPlayer: GammonPlayer.one,
      );
      final p = game.winProbabilityFor(GammonPlayer.one);
      expect(p, greaterThan(0));
      expect(p, lessThan(1));
    });

    test('a small parsed-by-ASCII race is solved exactly', () {
      // A full 15-vs-15 board with all checkers tightly stacked on two points
      // per side: small enough for the exact solver, and with no pile over 9 so
      // fibsboard can render it. The position is a mirror image, so the player
      // on roll is the favorite.
      final board = makeBoard({
        1: -8, 2: -7, //   player1 home, 1 and 2 points
        24: 8, 23: 7, //   player2 home, mirror of player1
      });
      final parsed = fb.boardFromLines(fb.linesFromBoard(board));
      for (var pip = 0; pip != 26; ++pip) {
        expect(parsed[pip].length, board[pip].length, reason: 'pip $pip');
      }

      expect(GammonRules.isRace(parsed), isTrue);
      final p = RaceEval.winProbabilityOrNull(parsed, GammonPlayer.one);
      expect(p, isNotNull); // small enough: solved exactly, not the heuristic
      expect(p, greaterThan(0.5)); // on roll in a symmetric race -> favored
      expect(p, lessThan(1.0));
    });
  });
}

import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('GammonRules.isRace (issue #11)', () {
    test('initial board is still in contact', () {
      expect(GammonRules.isRace(GammonRules.initialBoard()), isFalse);
    });

    test('separated positions are a pure race', () {
      // all player1 in their home (1..6), all player2 in their home (19..24)
      final board = makeBoard({
        6: -8,
        3: -7,
        19: 8,
        22: 7,
      });
      expect(GammonRules.isRace(board), isTrue);
    });

    test('interleaved positions are not a race', () {
      final board = makeBoard({13: -1, 8: 1});
      expect(GammonRules.isRace(board), isFalse);
    });

    test('a checker on the bar means contact', () {
      final board = makeBoard({25: -1, 1: -14, 24: 15});
      expect(GammonRules.isRace(board), isFalse);
    });
  });

  group('GammonRules.greedyMoveForDie (issue #11)', () {
    test('bears off from the highest point when the die allows', () {
      final board = makeBoard({6: -1, 3: -1});
      final move = GammonRules.greedyMoveForDie(board, GammonPlayer.one, 6);
      expect(move, isNotNull);
      expect(move!.fromPipNo, 6);
      expect(move.toPipNo, GammonRules.offPipNoFor(GammonPlayer.one)); // 0
    });

    test('advances the rearmost checker when no bear-off is possible', () {
      final board = makeBoard({6: -1, 3: -1});
      // a 2 cannot bear anything off; greedy advances the rearmost (pip 6)
      final move = GammonRules.greedyMoveForDie(board, GammonPlayer.one, 2);
      expect(move, isNotNull);
      expect(move!.fromPipNo, 6);
      expect(move.toPipNo, 4);
    });

    test('returns null when the die has no legal play', () {
      // player1 on the bar; the entry point for a 1 (pip 24) is blocked
      final board = makeBoard({25: -1, 24: 2});
      expect(GammonRules.greedyMoveForDie(board, GammonPlayer.one, 1), isNull);
    });
  });

  group('GammonState.autoBearOff (issue #11)', () {
    test('plays a pure race to completion', () {
      final board = makeBoard({
        6: -3,
        5: -3,
        4: -3,
        3: -2,
        2: -2,
        1: -2,
        19: 3,
        20: 3,
        21: 3,
        22: 2,
        23: 2,
        24: 2,
      });
      final game = GammonState.from(
        board: board,
        dice: [DieState(3), DieState(1)],
        turnPlayer: GammonPlayer.one,
      );

      expect(game.canAutoBearOff, isTrue);
      game.autoBearOff();

      expect(game.gameOver, isTrue);
      final off1 = game.board[0]
          .where((id) => GammonRules.playerFor(id) == GammonPlayer.one)
          .length;
      final off2 = game.board[25]
          .where((id) => GammonRules.playerFor(id) == GammonPlayer.two)
          .length;
      expect(off1 == 15 || off2 == 15, isTrue);
    });
  });
}

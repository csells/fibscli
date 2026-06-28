import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('RaceEval.winProbability — exact expectimax (issue #14)', () {
    test('returns null for a contact position', () {
      expect(
        RaceEval.winProbabilityOrNull(
          GammonRules.initialBoard(),
          GammonPlayer.one,
        ),
        isNull,
      );
    });

    test('a checker on the ace point wins for sure on roll', () {
      // player1 one checker on pip 1 bears off with any roll; player2 far back
      final board = makeBoard({1: -1, 20: 1, 21: 1});
      expect(
        RaceEval.winProbabilityOrNull(board, GammonPlayer.one),
        closeTo(1.0, 1e-9),
      );
    });

    test('the textbook 27/36 race is exactly 0.75', () {
      // player1: one checker on pip 6 -> bears off this turn on 27 of 36 rolls.
      // player2: one checker on pip 24 (their ace point) -> bears off for sure
      // next turn, so player1 loses whenever it fails to bear off.
      final board = makeBoard({6: -1, 24: 1});
      expect(GammonRules.isRace(board), isTrue);
      expect(
        RaceEval.winProbabilityOrNull(board, GammonPlayer.one),
        closeTo(27 / 36, 1e-9),
      );
    });

    test('a symmetric race favors whoever is on roll, equally', () {
      // both players a single checker on their six point (mirror image)
      final board = makeBoard({6: -1, 19: 1});
      final p1 = RaceEval.winProbabilityOrNull(board, GammonPlayer.one)!;
      final p2 = RaceEval.winProbabilityOrNull(board, GammonPlayer.two)!;
      expect(p1, greaterThan(0.5)); // the player on roll is favored
      expect(p1, closeTo(p2, 1e-9)); // symmetric, so the edge is the same
    });
  });

  group('RaceEval.cubeAction — exact cube decision (issue #14)', () {
    test('returns null for a contact position', () {
      expect(
        RaceEval.cubeActionOrNull(
          GammonRules.initialBoard(),
          GammonPlayer.one,
          null,
        ),
        isNull,
      );
    });

    test('a strong favorite should double', () {
      // player1 about to bear off its last checkers, player2 well behind
      final board = makeBoard({6: -1, 21: 1, 22: 1, 23: 1});
      final action = RaceEval.cubeActionOrNull(board, GammonPlayer.one, null);
      expect(action, isNotNull);
      expect(action, isNot(CubeAction.noDouble));
    });

    test('the trailing player should not double', () {
      // player1 (on roll) has two checkers to bear off, player2 only one, so
      // player1 is the underdog and must not double
      final board = makeBoard({6: -1, 3: -1, 19: 1});
      expect(
        RaceEval.cubeActionOrNull(board, GammonPlayer.one, null),
        CubeAction.noDouble,
      );
    });
  });
}

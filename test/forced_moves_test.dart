import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('GammonRules.maxPlayableDice (issue #4)', () {
    test('opening 3-1 from the initial board can use both dice', () {
      final board = GammonRules.initialBoard();
      expect(GammonRules.maxPlayableDice(board, GammonPlayer.one, [3, 1]), 2);
    });

    test('only one die playable when both end on a blocked point', () {
      // single player1 checker on 13; both dice combine onto blocked pip 2.
      final board = makeBoard({13: -1, 2: 2});
      expect(GammonRules.maxPlayableDice(board, GammonPlayer.one, [6, 5]), 1);
    });

    test('doubles: must play as many of the four numbers as possible', () {
      // rules.html: "In the case of doubles, when all four numbers cannot be
      // played, the player must play as many numbers as he can." Two checkers
      // on the ace point with 6-6-6-6 can only bear off twice.
      final board = makeBoard({1: -2});
      expect(
        GammonRules.maxPlayableDice(board, GammonPlayer.one, [6, 6, 6, 6]),
        2,
      );
    });

    test('no dice playable when fully blocked from the bar', () {
      // player1 on the bar (pip 25); all entry points 19..24 blocked.
      final board = makeBoard({
        25: -1,
        19: 2,
        20: 2,
        21: 2,
        22: 2,
        23: 2,
        24: 2,
      });
      expect(GammonRules.maxPlayableDice(board, GammonPlayer.one, [6, 1]), 0);
    });
  });

  group('GammonRules.getForcedLegalMoves (issue #4)', () {
    test('must play the larger die when only one die can be played', () {
      final board = makeBoard({13: -1, 2: 2});
      final forced = GammonRules.getForcedLegalMoves(board, GammonPlayer.one, [
        6,
        5,
      ]);
      final from13 = forced[13] ?? const <GammonMove>[];
      // the larger die (6): 13->7 must be offered
      expect(from13.any((m) => m.toPipNo == 7), isTrue);
      // the smaller die (5): 13->8 must be forbidden
      expect(from13.any((m) => m.toPipNo == 8), isFalse);
    });

    test('drops a single-die play that strands the other die', () {
      // one checker on pip 6, all home; dice 6 and 1.
      // 6->off uses only the 6 and strands the 1, but 6->5 then 5->off uses
      // both, so the bare 6 bearoff must be disallowed.
      final board = makeBoard({6: -1});
      expect(GammonRules.maxPlayableDice(board, GammonPlayer.one, [6, 1]), 2);

      final forced = GammonRules.getForcedLegalMoves(board, GammonPlayer.one, [
        6,
        1,
      ]);
      final from6 = forced[6] ?? const <GammonMove>[];

      // the 1-play (6->5) that keeps both dice alive must be offered
      expect(from6.any((m) => m.toPipNo == 5), isTrue);
      // the bare 6 bearoff (hops == [-6]) must be excluded
      expect(
        from6.any((m) => m.hops.length == 1 && m.hops.first == -6),
        isFalse,
      );
    });
  });
}

import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('GammonRules.preferredHops (issue #9)', () {
    test('prefers the hop ordering that hits an opponent blot', () {
      // player1 piece on pip 8; opponent blot only on pip 5.
      // With dice 3 and 1, reaching pip 4 can go 8->5->4 (hits at 5) or
      // 8->7->4 (no hit). We must pick the hitting path.
      final board = makeBoard({8: -1, 5: 1});
      final moves = GammonRules.getLegalMoves(board, 8, GammonPlayer.one, [
        3,
        1,
      ]);

      final hops = GammonRules.preferredHops(
        board,
        moves,
        fromPipNo: 8,
        toPipNo: 4,
      );

      expect(hops, isNotNull);
      // first hop must land on pip 5 (the blot): 8 + (-3) == 5
      expect(hops!.first, -3);
      expect(hops, [-3, -1]);
    });

    test('returns matching hops even when no hit is available', () {
      final board = makeBoard({8: -1});
      final moves = GammonRules.getLegalMoves(board, 8, GammonPlayer.one, [
        3,
        1,
      ]);

      final hops = GammonRules.preferredHops(
        board,
        moves,
        fromPipNo: 8,
        toPipNo: 4,
      );

      expect(hops, isNotNull);
      expect(hops!.reduce((a, b) => a + b), -4);
    });

    test('returns null when no move matches the destination', () {
      final board = makeBoard({8: -1});
      final moves = GammonRules.getLegalMoves(board, 8, GammonPlayer.one, [
        3,
        1,
      ]);

      final hops = GammonRules.preferredHops(
        board,
        moves,
        fromPipNo: 8,
        toPipNo: 1,
      );

      expect(hops, isNull);
    });
  });
}

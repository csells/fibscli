import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('GammonRules baseline', () {
    test('initial board has 15 pieces per player', () {
      final board = GammonRules.initialBoard();
      var p1 = 0;
      var p2 = 0;
      for (final pip in board) {
        for (final id in pip) {
          if (GammonRules.playerFor(id) == GammonPlayer.one) {
            ++p1;
          } else {
            ++p2;
          }
        }
      }
      expect(p1, 15);
      expect(p2, 15);
    });

    test('player1 opening 3-1 can make the 5 point', () {
      final board = GammonRules.initialBoard();
      final moves =
          GammonRules.getAllLegalMoves(board, GammonPlayer.one, [3, 1]);
      // 8->5 (3) and 6->5 (1) both reach pip 5
      expect(moves[8]!.any((m) => m.toPipNo == 5), isTrue);
      expect(moves[6]!.any((m) => m.toPipNo == 5), isTrue);
    });

    test('makeBoard helper produces requested layout', () {
      final board = makeBoard({6: -2, 13: 3});
      expect(board[6].length, 2);
      expect(
          board[6].every((id) => GammonRules.playerFor(id) == GammonPlayer.one),
          isTrue);
      expect(board[13].length, 3);
      expect(
          board[13]
              .every((id) => GammonRules.playerFor(id) == GammonPlayer.two),
          isTrue);
    });
  });
}

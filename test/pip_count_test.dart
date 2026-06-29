import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

// Build a 26-cell engine board (index 0 = player1 off / player2 bar; 1..24 =
// points; 25 = player1 bar / player2 off) from signed piece ids.
List<List<int>> _emptyBoard() => List<List<int>>.generate(26, (_) => <int>[]);

void main() {
  group('GammonState.pipCountFor', () {
    test('the standard opening is 167 pips a side', () {
      final game = GammonState();
      expect(game.pipCountFor(GammonPlayer.one), 167);
      expect(game.pipCountFor(GammonPlayer.two), 167);
    });

    test('borne-off checkers are zero pips (not counted as on the bar)', () {
      // player one: 14 checkers off (index 0), 1 left on point 3 -> 3 pips.
      // The old pipCount counted each off checker as 24 phantom pips.
      final board = _emptyBoard();
      board[0].addAll([for (var i = 1; i <= 14; i++) -i]); // 14 off
      board[3].add(-15); // last checker, 3 pips to go
      board[13].addAll([for (var i = 1; i <= 15; i++) i]); // player two
      final game = GammonState.from(
        board: board,
        dice: [DieState(3), DieState(1)],
        turnPlayer: GammonPlayer.one,
      );
      expect(game.pipCountFor(GammonPlayer.one), 3);
    });

    test('a checker on the bar counts a full 25 pips', () {
      // player one: 1 on the bar (index 25) + 14 home on the ace point.
      final board = _emptyBoard();
      board[25].add(-1); // on the bar
      board[1].addAll([for (var i = 2; i <= 15; i++) -i]); // 14 on point 1
      board[13].addAll([for (var i = 1; i <= 15; i++) i]); // player two
      final game = GammonState.from(
        board: board,
        dice: [DieState(6), DieState(2)],
        turnPlayer: GammonPlayer.one,
      );
      expect(game.pipCountFor(GammonPlayer.one), 25 + 14);
    });
  });
}

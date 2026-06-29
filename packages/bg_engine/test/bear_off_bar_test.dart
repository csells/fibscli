import 'package:bg_engine/src/rules.dart';
import 'package:test/test.dart';

List<List<int>> _empty() => List<List<int>>.generate(26, (_) => <int>[]);

void main() {
  group('bear-off is illegal while a checker is on the bar', () {
    test('player one: a checker on the bar (pip 25) blocks bear-off', () {
      final board = _empty();
      board[25].add(-1); // player1 (negative) on the bar
      board[6].addAll([-2, -3, -4, -5, -6]); // the rest at home (pips 1-6)
      board[5].addAll([-7, -8, -9, -10, -11]);
      board[1].addAll([-12, -13, -14, -15]);

      expect(GammonRules.canBearOff(board, GammonPlayer.one, 6, 0), isFalse);
      expect(GammonRules.canBearOff(board, GammonPlayer.one, 5, 0), isFalse);
    });

    test('player two: a checker on the bar (pip 0) blocks bear-off', () {
      final board = _empty();
      board[0].add(1); // player2 (positive) on the bar
      board[19].addAll([2, 3, 4, 5, 6]); // the rest at home (pips 19-24)
      board[24].addAll([7, 8, 9, 10, 11, 12, 13, 14, 15]);

      expect(GammonRules.canBearOff(board, GammonPlayer.two, 19, 25), isFalse);
    });

    test('forced moves offer only bar entry, never a home bear-off', () {
      final board = _empty();
      board[25].add(-1); // player1 on the bar
      board[6].addAll([-2, -3, -4, -5, -6]);
      board[5].addAll([-7, -8, -9, -10, -11]);
      board[1].addAll([-12, -13, -14, -15]);

      final moves = GammonRules.getForcedLegalMoves(
        board,
        GammonPlayer.one,
        [5, 3], // would bear off from 5/3 if the bar were (wrongly) ignored
      );
      for (final list in moves.values) {
        for (final move in list) {
          expect(
            move.fromPipNo,
            25,
            reason: 'must enter from the bar before any other move',
          );
        }
      }
    });
  });
}

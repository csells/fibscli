import 'package:bg_engine/bg_engine.dart'; // exports copyBoard via turn_search
import 'package:test/test.dart';

Position _afterMove(List<List<int>> board, GammonMove move) {
  final next = copyBoard(board);
  GammonRules.applyMove(next, move);
  return Position.fromBoard(next);
}

void main() {
  group('boardMovements', () {
    test('no change yields no movements', () {
      expect(boardMovements(Position.standard(), Position.standard()), isEmpty);
    });

    test('a single checker move yields one movement', () {
      final board = GammonRules.initialBoard();
      final from = Position.fromBoard(board);
      final to = _afterMove(
        board,
        GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
      );
      expect(boardMovements(from, to), [
        const Movement(GammonPlayer.one, 24, 23),
      ]);
    });

    test('a hit also moves the victim to its bar', () {
      // player1 on point 24; a lone player2 blot on point 23 (engine frame)
      final board = GammonRules.initialBoard();
      board[23]
        ..clear()
        ..add(7); // a single player2 checker (a blot) on point 23
      final from = Position.fromBoard(board);
      final to = _afterMove(
        board,
        GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
      );

      final moves = boardMovements(from, to);
      expect(moves, contains(const Movement(GammonPlayer.one, 24, 23)));
      // player2's hit checker goes to its bar (engine pip 0)
      expect(moves, contains(const Movement(GammonPlayer.two, 23, 0)));
    });

    test('a bear-off moves a checker to the off tray', () {
      // a single player1 checker on the ace point -> bear off with a 1
      final board = List<List<int>>.generate(26, (_) => <int>[]);
      board[1].add(-1); // player1 ace point
      final from = Position.fromBoard(board);
      final to = _afterMove(
        board,
        GammonMove(
          fromPipNo: 1,
          toPipNo: 0,
          hops: const [-1],
        ), // off (engine pip 0)
      );
      expect(boardMovements(from, to), [
        const Movement(GammonPlayer.one, 1, 0),
      ]);
    });
  });
}

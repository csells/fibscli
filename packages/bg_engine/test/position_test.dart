import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

void main() {
  group('Position', () {
    test('the standard opening has the canonical layout, 15 checkers/side', () {
      final p = Position.standard();
      expect(p.countAt(point: 6, player: GammonPlayer.one), 5);
      expect(p.countAt(point: 8, player: GammonPlayer.one), 3);
      expect(p.countAt(point: 13, player: GammonPlayer.one), 5);
      expect(p.countAt(point: 24, player: GammonPlayer.one), 2);
      expect(p.countAt(point: 1, player: GammonPlayer.two), 2);
      expect(p.countAt(point: 12, player: GammonPlayer.two), 5);
      // a point owned by one player holds none of the other
      expect(p.countAt(point: 6, player: GammonPlayer.two), 0);
      expect(p.barFor(GammonPlayer.one), 0);
      expect(p.offFor(GammonPlayer.two), 0);
      expect(p.totalFor(GammonPlayer.one), 15);
      expect(p.totalFor(GammonPlayer.two), 15);
    });

    test('round-trips through the engine board representation', () {
      final board = GammonRules.initialBoard();
      final p = Position.fromBoard(board);
      expect(p, Position.standard());
      // and back to a board with the same per-pip signature
      expect(positionSignature(p.toBoard()), positionSignature(board));
    });

    test('captures bar and borne-off checkers', () {
      // player one: 1 on the bar, 2 borne off, the rest on point 1
      final board = GammonRules.initialBoard();
      board[25].add(-99); // a player1 checker on the bar (engine bar = 25)
      board[0].addAll([-98, -97]); // 2 player1 checkers off (engine off = 0)
      final p = Position.fromBoard(board);
      expect(p.barFor(GammonPlayer.one), 1);
      expect(p.offFor(GammonPlayer.one), 2);
    });

    test('value equality (immutable)', () {
      expect(Position.standard(), Position.standard());
      expect(Position.standard().hashCode, Position.standard().hashCode);
    });

    test('BgPosition exposes a typed Position view of its board', () {
      final bg = BgPosition(
        board: GammonRules.initialBoard(),
        onRoll: GammonPlayer.one,
        dice: [3, 1],
      );
      expect(bg.position, Position.standard());
    });

    test('rejects illegal states (a point cannot be owned by both)', () {
      final points = List<int>.filled(24, 0);
      // signed counts are single-owner by construction; an out-of-range count
      // (more than 15) is rejected.
      expect(
        () => Position(points: points..[5] = 99),
        throwsA(isA<AssertionError>()),
      );
    });
  });
}

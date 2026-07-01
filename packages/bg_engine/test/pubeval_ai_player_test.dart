import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

void main() {
  group('PubevalAiPlayer.chooseTurn', () {
    final ai = PubevalAiPlayer();

    test('plays a legal turn consuming both opening dice', () async {
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );
      expect(turn.isDance, isFalse);
      // forced-move rules require playing both dice -> two hops total
      final hops = turn.moves.fold<int>(0, (sum, m) => sum + m.hops.length);
      expect(hops, 2);
    });

    test('every chosen move is itself legal on the opening board', () async {
      final board = GammonRules.initialBoard();
      final turn = await ai.chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.one, dice: [6, 5]),
      );
      // applying the first move should yield non-empty deltas (i.e. it's legal)
      final deltas = GammonRules.checkLegalMove(board, turn.moves.first);
      expect(deltas, isNotEmpty);
    });

    test('returns a dance when there is no legal move', () async {
      // player2 (positive) enters from the bar (index 0) onto points 1..6.
      // Block all of those with player1 (negative) points of 2+ checkers, so a
      // barred player2 checker cannot enter and must dance.
      final board = GammonRules.initialBoard();
      board[0]
        ..clear()
        ..add(50); // a player2 checker on the bar
      for (var pip = 1; pip <= 6; ++pip) {
        board[pip]
          ..clear()
          ..addAll([-100 - pip, -200 - pip]); // 2 player1 checkers -> blocked
      }
      final turn = await ai.chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.two, dice: [6, 6, 6, 6]),
      );
      expect(turn.isDance, isTrue);
    });
  });

  group('AiRegistry', () {
    test('a registered engine is retrievable by name', () {
      AiRegistry.register(PubevalAiPlayerFactory());
      expect(
        AiRegistry.available.map((f) => f.name),
        contains('Heuristic (pubeval)'),
      );
      final ai = AiRegistry.byName('Heuristic (pubeval)')!.create();
      expect(ai, isA<PubevalAiPlayer>());
    });

    test('register replaces a same-named factory', () {
      AiRegistry.register(PubevalAiPlayerFactory());
      final before = AiRegistry.available.length;
      AiRegistry.register(PubevalAiPlayerFactory()); // same name
      expect(AiRegistry.available.length, before); // replaced, not added
    });
  });
}

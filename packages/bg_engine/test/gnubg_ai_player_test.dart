import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// A scripted gnubg client: returns the given plays (best first) regardless of
// the position, so the adapter's notation->turn matching can be tested offline.
class _FakeGnubgClient implements GnubgClient {
  _FakeGnubgClient(this.plays);
  final List<String> plays;

  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async => [
    for (var i = 0; i < plays.length; i++)
      GnubgRankedMove(play: plays[i], equity: -0.1 * i),
  ];

  @override
  void dispose() {}
}

// A client that always fails -- a down/slow service or a dropped connection.
class _FailingGnubgClient implements GnubgClient {
  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async =>
      throw Exception('connection refused');

  @override
  void dispose() {}
}

void main() {
  group('GnubgAiPlayer', () {
    test(
      'player one: matches "8/5 6/5" to the make-the-5-point turn',
      () async {
        final ai = GnubgAiPlayer(_FakeGnubgClient(['8/5 6/5']));
        final turn = await ai.chooseTurn(
          BgPosition(
            board: GammonRules.initialBoard(),
            onRoll: GammonPlayer.one,
            dice: [3, 1],
          ),
        );
        expect(
          turn.moves.any((m) => m.fromPipNo == 8 && m.toPipNo == 5),
          isTrue,
        );
        expect(
          turn.moves.any((m) => m.fromPipNo == 6 && m.toPipNo == 5),
          isTrue,
        );
      },
    );

    test('player two: maps notation from its own perspective', () async {
      // For player two, notation pip N is engine pip 25-N. So "24/23 13/9"
      // is engine 1->2 and 12->16 (dice 1 and 4).
      final ai = GnubgAiPlayer(_FakeGnubgClient(['24/23 13/9']));
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.two,
          dice: [1, 4],
        ),
      );
      expect(turn.moves.any((m) => m.fromPipNo == 1 && m.toPipNo == 2), isTrue);
      expect(
        turn.moves.any((m) => m.fromPipNo == 12 && m.toPipNo == 16),
        isTrue,
      );
    });

    test('skips an unmatchable play and uses the next ranked one', () async {
      // first play is illegal/garbage; the adapter falls through to 8/5 6/5
      final ai = GnubgAiPlayer(_FakeGnubgClient(['99/1', '8/5 6/5']));
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );
      expect(turn.moves.any((m) => m.fromPipNo == 8 && m.toPipNo == 5), isTrue);
    });

    test(
      'falls back to a legal turn when gnubg returns nothing usable',
      () async {
        final ai = GnubgAiPlayer(_FakeGnubgClient(const []));
        final turn = await ai.chooseTurn(
          BgPosition(
            board: GammonRules.initialBoard(),
            onRoll: GammonPlayer.one,
            dice: [3, 1],
          ),
        );
        // still a legal, both-dice turn (so the game never stalls)
        final hops = turn.moves.fold<int>(0, (s, m) => s + m.hops.length);
        expect(hops, 2);
      },
    );

    test(
      'a failed service request falls back to a legal turn (no stall)',
      () async {
        // a network/timeout/HTTP error must NOT throw out of chooseTurn and
        // stall the game -- it degrades to a legal play like a no-match does.
        final ai = GnubgAiPlayer(_FailingGnubgClient());
        final turn = await ai.chooseTurn(
          BgPosition(
            board: GammonRules.initialBoard(),
            onRoll: GammonPlayer.one,
            dice: [3, 1],
          ),
        );
        final hops = turn.moves.fold<int>(0, (s, m) => s + m.hops.length);
        expect(hops, 2, reason: 'a legal, both-dice turn despite the failure');
      },
    );

    test('a dance is returned without ever calling the service', () async {
      // no legal move -> a dance; don't waste a request (or risk its failure).
      final board = GammonRules.initialBoard();
      board[0]
        ..clear()
        ..add(50); // a player2 checker on the bar
      for (var pip = 1; pip <= 6; ++pip) {
        board[pip]
          ..clear()
          ..addAll([-1, -2]); // player1 blocks every entry point
      }
      final ai = GnubgAiPlayer(_FailingGnubgClient());
      final turn = await ai.chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.two, dice: [3, 1]),
      );
      expect(turn.isDance, isTrue);
    });

    test('registers as an engine via its factory', () {
      final factory = GnubgAiPlayerFactory(() => _FakeGnubgClient(const []));
      expect(factory.create(), isA<GnubgAiPlayer>());
    });
  });
}

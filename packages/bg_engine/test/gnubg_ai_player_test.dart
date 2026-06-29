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

// A client that fails its first [failures] calls, then serves [plays]. With
// failures large it models a down service; with failures==1 a transient blip.
class _FlakyGnubgClient implements GnubgClient {
  _FlakyGnubgClient({this.failures = 1 << 30, this.plays = const []});
  int failures;
  final List<String> plays;
  int calls = 0;

  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw Exception('connection refused');
    }
    return [
      for (var i = 0; i < plays.length; i++)
        GnubgRankedMove(play: plays[i], equity: -0.1 * i),
    ];
  }

  @override
  void dispose() {}
}

// no retry delay so the failure tests run instantly
GnubgAiPlayer _player(GnubgClient client) =>
    GnubgAiPlayer(client, retryDelay: Duration.zero);

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
      'throws (never fabricates) when gnubg returns nothing usable',
      () async {
        // service answered but with no matchable play: we must NOT substitute
        // a local move and pass it off as gnubg's -- surface the failure.
        final ai = _player(_FakeGnubgClient(const []));
        await expectLater(
          ai.chooseTurn(
            BgPosition(
              board: GammonRules.initialBoard(),
              onRoll: GammonPlayer.one,
              dice: [3, 1],
            ),
          ),
          throwsA(isA<GnubgUnavailableException>()),
        );
      },
    );

    test(
      'an unavailable service throws after retrying -- never a faked move',
      () async {
        // the endpoint is down: retry, then report it. We must NOT play a
        // local move dressed up as gnubg's.
        final client = _FlakyGnubgClient(); // always fails
        final ai = _player(client);
        await expectLater(
          ai.chooseTurn(
            BgPosition(
              board: GammonRules.initialBoard(),
              onRoll: GammonPlayer.one,
              dice: [3, 1],
            ),
          ),
          throwsA(isA<GnubgUnavailableException>()),
        );
        expect(client.calls, 3, reason: '1 try + 2 retries');
      },
    );

    test('a transient blip is retried and then succeeds', () async {
      // one failure, then a good response -> gnubg's move, no error
      final ai = _player(_FlakyGnubgClient(failures: 1, plays: ['8/5 6/5']));
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );
      expect(turn.moves.any((m) => m.fromPipNo == 8 && m.toPipNo == 5), isTrue);
    });

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
      final client = _FlakyGnubgClient(); // would fail if called
      final turn = await _player(client).chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.two, dice: [3, 1]),
      );
      expect(turn.isDance, isTrue);
      expect(client.calls, 0, reason: 'a dance needs no service call');
    });

    test('registers as an engine via its factory', () {
      final factory = GnubgAiPlayerFactory(() => _FakeGnubgClient(const []));
      expect(factory.create(), isA<GnubgAiPlayer>());
    });
  });
}

import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// A ranked move as the service reports it: the hops carry the play (the
// notation string is diagnostic only, so these fixtures leave it empty).
GnubgRankedMove _move(List<GnubgHop> hops, {double equity = 0}) =>
    GnubgRankedMove(play: '', hops: hops, equity: equity);

// A scripted gnubg client: returns the given ranked moves (best first)
// regardless of the position, so the adapter's hops->turn matching can be
// tested offline. Only the move path is exercised here (cube/resign live in
// gnubg_ai_cube_resign_test.dart), so those members reject if reached.
class _FakeGnubgClient implements GnubgClient {
  _FakeGnubgClient(this.moves);
  final List<GnubgRankedMove> moves;

  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async => moves;

  @override
  Future<GnubgCubeDecision> cubeDecision(BgPosition position) =>
      throw StateError('not exercised by the move-path tests');

  @override
  Future<GnubgResignDecision> resignDecision(
    BgPosition position, {
    int offered = 0,
  }) => throw StateError('not exercised by the move-path tests');

  @override
  void dispose() {}
}

// A client that fails its first [failures] calls, then serves [moves]. With
// failures large it models a down service; with failures==1 a transient blip.
class _FlakyGnubgClient implements GnubgClient {
  _FlakyGnubgClient({this.failures = 1 << 30, this.moves = const []});
  int failures;
  final List<GnubgRankedMove> moves;
  int calls = 0;

  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw Exception('connection refused');
    }
    return moves;
  }

  @override
  Future<GnubgCubeDecision> cubeDecision(BgPosition position) =>
      throw StateError('not exercised by the move-path tests');

  @override
  Future<GnubgResignDecision> resignDecision(
    BgPosition position, {
    int offered = 0,
  }) => throw StateError('not exercised by the move-path tests');

  @override
  void dispose() {}
}

// no retry delay so the failure tests run instantly
GnubgAiPlayer _player(GnubgClient client) =>
    GnubgAiPlayer(client, retryDelay: Duration.zero);

// gnubg's "8/5 6/5" (make the 5-point) as hops, mover-perspective.
List<GnubgHop> _makeFivePoint() => const [
  GnubgHop(from: 8, to: 5),
  GnubgHop(from: 6, to: 5),
];

void main() {
  group('GnubgAiPlayer', () {
    test('player one: hops 8/5 6/5 select the make-the-5-point turn', () async {
      final ai = GnubgAiPlayer(_FakeGnubgClient([_move(_makeFivePoint())]));
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );
      expect(turn.moves.any((m) => m.fromPipNo == 8 && m.toPipNo == 5), isTrue);
      expect(turn.moves.any((m) => m.fromPipNo == 6 && m.toPipNo == 5), isTrue);
    });

    test('player two: hops are mapped from the mover perspective', () async {
      // Hops number the points from the mover's side, so for player two
      // point N is engine pip 25-N: 24/23 13/9 is engine 1->2 and 12->16
      // (dice 1 and 4).
      final ai = GnubgAiPlayer(
        _FakeGnubgClient([
          _move(const [GnubgHop(from: 24, to: 23), GnubgHop(from: 13, to: 9)]),
        ]),
      );
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

    test('a collapsed bar-entry hop (25 = bar) matches the two-die '
        'turn', () async {
      // gnubg collapses "bar/20" on a 4-1 into the single hop 25->20; the
      // adapter must land on the locally-enumerated bar-entry turn that
      // reaches the same position.
      final board = GammonRules.initialBoard();
      final checker = board[24].removeLast(); // a player1 checker to the bar
      board[25].add(checker); // engine pip 25 = player1 bar
      final ai = GnubgAiPlayer(
        _FakeGnubgClient([
          _move(const [GnubgHop(from: 25, to: 20)]),
        ]),
      );
      final turn = await ai.chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.one, dice: [4, 1]),
      );
      expect(turn.moves.first.fromPipNo, 25, reason: 'enters from the bar');
      expect(turn.moves.last.toPipNo, 20, reason: 'ends on the 20-point');
    });

    test('a bear-off hop (0 = off) matches the bear-off turn', () async {
      // Player one's home board: checkers on the 4- and 1-points, both borne
      // off with the 4-1 (gnubg's "4/off 1/off": hops to 0).
      final board = List.generate(26, (_) => <int>[]);
      board[4].add(-1);
      board[1].add(-2);
      board[19].addAll([50, 51]); // opponent checkers, out of play
      final ai = GnubgAiPlayer(
        _FakeGnubgClient([
          _move(const [GnubgHop(from: 4, to: 0), GnubgHop(from: 1, to: 0)]),
        ]),
      );
      final turn = await ai.chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.one, dice: [4, 1]),
      );
      expect(turn.moves, hasLength(2));
      expect(turn.moves.every((m) => m.toPipNo == 0), isTrue);
    });

    test('skips an unmatchable move and uses the next ranked one', () async {
      // the first ranked move's hops don't reach any legal turn (nothing on
      // the 20-point); the adapter falls through to 8/5 6/5
      final ai = GnubgAiPlayer(
        _FakeGnubgClient([
          _move(const [GnubgHop(from: 20, to: 17)]),
          _move(_makeFivePoint(), equity: -0.1),
        ]),
      );
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
        // service answered but with no matchable move: we must NOT substitute
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
      final ai = _player(
        _FlakyGnubgClient(failures: 1, moves: [_move(_makeFivePoint())]),
      );
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

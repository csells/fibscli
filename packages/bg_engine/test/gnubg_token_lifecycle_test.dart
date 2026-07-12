import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// A client that records prepare() calls and can fail play calls with either a
// permanent error (the service refused: a rejected attestation, a bad key, a
// blown quota) or a transient one (a network blip).
class _RecordingClient implements GnubgClient {
  _RecordingClient({this.failWith});

  /// Thrown by every play call, when set.
  final Exception? failWith;

  int prepareCalls = 0;
  int moveCalls = 0;

  @override
  Future<void> prepare() async => prepareCalls++;

  @override
  Future<GnubgPlayedMove> playMove(BgPosition position) async {
    moveCalls++;
    final failure = failWith;
    if (failure != null) throw failure;
    return const GnubgPlayedMove(
      play: '8/5 6/5',
      hops: [GnubgHop(from: 8, to: 5), GnubgHop(from: 6, to: 5)],
    );
  }

  @override
  Future<bool> playCube(BgPosition position) async => false;

  @override
  Future<bool> playTake(BgPosition position) async => true;

  @override
  Future<GnubgResignStake> playResign(BgPosition position) async =>
      GnubgResignStake.none;

  @override
  void dispose() {}
}

BgPosition _opening() => BgPosition(
  board: GammonRules.initialBoard(),
  onRoll: GammonPlayer.one,
  dice: const [3, 1],
);

void main() {
  group('GnubgAiPlayer.prepare', () {
    test('warms the client credentials at a natural pause', () async {
      final client = _RecordingClient();
      await GnubgAiPlayer(client).prepare();
      expect(client.prepareCalls, 1);
      expect(client.moveCalls, 0, reason: 'pre-warm plays nothing');
    });
  });

  group('GnubgAiPlayer retry policy', () {
    test('a transient failure is retried', () async {
      final client = _RecordingClient(failWith: Exception('connection reset'));
      final ai = GnubgAiPlayer(client, retryDelay: Duration.zero);
      await expectLater(
        ai.chooseTurn(_opening()),
        throwsA(isA<GnubgUnavailableException>()),
      );
      expect(client.moveCalls, 3, reason: '1 attempt + 2 retries');
    });

    test('a permanent failure is NOT retried -- a rejected attestation must '
        'not stack Turnstile challenges', () async {
      final client = _RecordingClient(
        failWith: GnubgUnavailableException('attestation rejected'),
      );
      final ai = GnubgAiPlayer(client, retryDelay: Duration.zero);
      await expectLater(
        ai.chooseTurn(_opening()),
        throwsA(isA<GnubgUnavailableException>()),
      );
      expect(
        client.moveCalls,
        1,
        reason: 'the player retries by hand; we never re-challenge in a loop',
      );
    });
  });
}

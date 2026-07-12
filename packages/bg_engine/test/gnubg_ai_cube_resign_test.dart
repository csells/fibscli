import 'package:bg_engine/bg_engine.dart';
import 'package:test/test.dart';

// A scripted gnubg client for the cube/take/resign paths: answers every cube
// call with [doubles], every take call with [takes], and every resign call
// with [resigns], after failing the first [failures] calls (to model a down
// service or a transient blip). The move path rejects if reached -- these
// tests never play checkers.
class _ScriptedClient implements GnubgClient {
  _ScriptedClient({
    this.doubles = false,
    this.takes = true,
    this.resigns = GnubgResignStake.none,
    this.failures = 0,
  });

  final bool doubles;
  final bool takes;
  final GnubgResignStake resigns;
  int failures;
  int cubeCalls = 0;
  int takeCalls = 0;
  int resignCalls = 0;

  void _maybeFail() {
    if (failures > 0) {
      failures--;
      throw Exception('connection refused');
    }
  }

  @override
  Future<GnubgPlayedMove> playMove(BgPosition position) =>
      throw StateError('not exercised by the cube/resign tests');

  @override
  Future<bool> playCube(BgPosition position) async {
    cubeCalls++;
    _maybeFail();
    return doubles;
  }

  @override
  Future<bool> playTake(BgPosition position) async {
    takeCalls++;
    _maybeFail();
    return takes;
  }

  @override
  Future<GnubgResignStake> playResign(BgPosition position) async {
    resignCalls++;
    _maybeFail();
    return resigns;
  }

  @override
  Future<void> prepare() async {}

  @override
  void dispose() {}
}

// no retry delay so the failure tests run instantly
GnubgAiPlayer _player(GnubgClient client) =>
    GnubgAiPlayer(client, retryDelay: Duration.zero);

BgPosition _opening({int cubeValue = 1, GammonPlayer? cubeOwner}) => BgPosition(
  board: GammonRules.initialBoard(),
  onRoll: GammonPlayer.one,
  dice: const [3, 1],
  cubeValue: cubeValue,
  cubeOwner: cubeOwner,
);

// player one (onRoll) all but home, player two stacked far back: a position
// where the LOCAL CubePolicy would scream "double" -- used to prove the gnubg
// adapter never falls back to it.
BgPosition _dominatingRace() => BgPosition(
  board: Position(
    points: const [
      -1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, //
      15, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    ],
    oneOff: 14,
  ).toBoard(),
  onRoll: GammonPlayer.one,
  dice: const [],
);

void main() {
  group('GnubgAiPlayer.cubeDecision', () {
    test('offers a double when the leveled opponent doubles', () async {
      final ai = _player(_ScriptedClient(doubles: true));
      expect(await ai.cubeDecision(_opening()), BgCubeAction.offerDouble);
    });

    test('rolls on when the leveled opponent does not double', () async {
      final ai = _player(_ScriptedClient());
      expect(await ai.cubeDecision(_opening()), BgCubeAction.noDouble);
    });

    test('does not consult the service when the opponent owns the '
        'cube', () async {
      final client = _ScriptedClient(doubles: true);
      final ai = _player(client);
      final action = await ai.cubeDecision(
        _opening(cubeValue: 2, cubeOwner: GammonPlayer.two),
      );
      expect(action, BgCubeAction.noDouble);
      expect(client.cubeCalls, 0, reason: 'an unplayable double needs no eval');
    });

    test('does not consult the service when the cube is maxed', () async {
      final client = _ScriptedClient(doubles: true);
      final ai = _player(client);
      final action = await ai.cubeDecision(
        _opening(cubeValue: 64, cubeOwner: GammonPlayer.one),
      );
      expect(action, BgCubeAction.noDouble);
      expect(client.cubeCalls, 0);
    });

    test('surfaces GnubgUnavailableException when the service is down -- '
        'never the local heuristic', () async {
      // In this position CubePolicy says double; a silent fallback would
      // return offerDouble here instead of throwing.
      final client = _ScriptedClient(failures: 1 << 30);
      final ai = _player(client);
      await expectLater(
        ai.cubeDecision(_dominatingRace()),
        throwsA(isA<GnubgUnavailableException>()),
      );
      expect(client.cubeCalls, 3, reason: '1 attempt + 2 retries');
    });

    test('retries a transient failure and answers', () async {
      final client = _ScriptedClient(doubles: true, failures: 1);
      final ai = _player(client);
      expect(await ai.cubeDecision(_opening()), BgCubeAction.offerDouble);
      expect(client.cubeCalls, 2);
    });
  });

  group('GnubgAiPlayer.respondToDouble', () {
    test('takes when the leveled opponent takes', () async {
      final ai = _player(_ScriptedClient(takes: true));
      expect(await ai.respondToDouble(_opening()), BgCubeAction.take);
    });

    test('passes when the leveled opponent drops', () async {
      final ai = _player(_ScriptedClient(takes: false));
      expect(await ai.respondToDouble(_opening()), BgCubeAction.pass);
    });

    test('surfaces GnubgUnavailableException when the service is down -- '
        'never the local heuristic', () async {
      // The doubler dominates: CubePolicy would answer pass; a silent
      // fallback would return that instead of throwing.
      final ai = _player(_ScriptedClient(failures: 1 << 30));
      await expectLater(
        ai.respondToDouble(_dominatingRace()),
        throwsA(isA<GnubgUnavailableException>()),
      );
    });
  });

  group('GnubgAiPlayer.resignDecision', () {
    test('plays on when the leveled opponent does not resign', () async {
      final ai = _player(_ScriptedClient());
      expect(await ai.resignDecision(_opening()), BgResignDecision.playOn);
    });

    test('maps each resignation stake to its decision', () async {
      const stakeToDecision = {
        GnubgResignStake.single: BgResignDecision.resignSingle,
        GnubgResignStake.gammon: BgResignDecision.resignGammon,
        GnubgResignStake.backgammon: BgResignDecision.resignBackgammon,
      };
      for (final entry in stakeToDecision.entries) {
        final ai = _player(_ScriptedClient(resigns: entry.key));
        expect(
          await ai.resignDecision(_opening()),
          entry.value,
          reason: 'stake ${entry.key}',
        );
      }
    });

    test('surfaces GnubgUnavailableException when the service is down -- '
        'never resigns (or plays on) locally', () async {
      final client = _ScriptedClient(failures: 1 << 30);
      final ai = _player(client);
      await expectLater(
        ai.resignDecision(_opening()),
        throwsA(isA<GnubgUnavailableException>()),
      );
      expect(client.resignCalls, 3, reason: '1 attempt + 2 retries');
    });

    test('retries a transient failure and answers', () async {
      final client = _ScriptedClient(
        resigns: GnubgResignStake.single,
        failures: 1,
      );
      final ai = _player(client);
      expect(
        await ai.resignDecision(_opening()),
        BgResignDecision.resignSingle,
      );
      expect(client.resignCalls, 2);
    });
  });

  group('BgAiPlayer.resignDecision (default policy)', () {
    test('a moves-only engine never resigns', () async {
      final ai = PubevalAiPlayer();
      expect(
        await ai.resignDecision(_dominatingRace()),
        BgResignDecision.playOn,
      );
    });
  });
}

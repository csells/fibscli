import 'dart:convert';

import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/session_gnubg_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnubg_service/gnubg_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// The opening position's GNUBG Position ID (player one on roll); the Match ID
// varies with the dice/cube, so expectations compose it with gnubgMatchId --
// the id builders themselves are pinned bit-exact in bg_engine's
// gnubg_id_test.dart.
const _openingPositionId = '4HPwATDgc/ABMA';

/// A scripted service: answers each path from its response queue (in order)
/// and records every request. Paths not scripted are a test bug — fail loud.
class _FakeService {
  _FakeService(this.responses);

  final Map<String, List<http.Response>> responses;
  final requests = <http.Request>[];

  http.Client get client => MockClient((request) async {
    requests.add(request);
    final queue = responses[request.url.path];
    if (queue == null || queue.isEmpty) {
      throw StateError('unexpected request: ${request.method} ${request.url}');
    }
    return queue.removeAt(0);
  });

  List<http.Request> get mints =>
      requests.where((r) => r.url.path == '/v1/token').toList();
  List<http.Request> get dataCalls =>
      requests.where((r) => r.url.path != '/v1/token').toList();
}

http.Response _mintOk() => http.Response(
  jsonEncode({'token': 'bg_tk_fake', 'expires_in': 3600, 'budget': 2000}),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _ok(Map<String, Object?> body) => http.Response(
  jsonEncode(body),
  200,
  headers: {'content-type': 'application/json'},
);

http.Response _err(int code, String message) => http.Response(
  jsonEncode({'error': message}),
  code,
  headers: {'content-type': 'application/json'},
);

SessionGnubgClient _client(_FakeService svc, {int level = 3, int? seed = 42}) =>
    SessionGnubgClient(
      GnubgSession(
        baseUrl: 'http://svc.test',
        publishableKey: 'bg_pk_example_public',
        attest: () async => 'fake-turnstile-response',
        httpClient: svc.client,
      ),
      level: level,
      seed: seed,
    );

BgPosition _opening({
  List<int> dice = const [3, 1],
  int cubeValue = 1,
  GammonPlayer? cubeOwner,
}) => BgPosition(
  board: GammonRules.initialBoard(),
  onRoll: GammonPlayer.one,
  dice: dice,
  cubeValue: cubeValue,
  cubeOwner: cubeOwner,
);

void main() {
  group('SessionGnubgClient.playMove', () {
    test('sends the in-roll id, level, and seed under a minted '
        'bearer token', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/move': [
          _ok({
            'play': '8/5 6/5',
            'hops': [
              {'from': 8, 'to': 5},
              {'from': 6, 'to': 5},
            ],
            'level': 3,
          }),
        ],
      });
      final client = _client(svc);
      final played = await client.playMove(_opening());

      expect(svc.mints, hasLength(1), reason: 'one lazy token mint');
      final call = svc.dataCalls.single;
      expect(call.url.path, '/v1/play/move');
      expect(
        call.url.queryParameters['id'],
        '$_openingPositionId:${gnubgMatchId(die0: 3, die1: 1)}',
      );
      expect(call.url.queryParameters['level'], '3');
      expect(call.url.queryParameters['seed'], '42');
      expect(call.headers['Authorization'], 'Bearer bg_tk_fake');

      expect(played.play, '8/5 6/5');
      expect(played.hops, const [
        GnubgHop(from: 8, to: 5),
        GnubgHop(from: 6, to: 5),
      ]);
      client.dispose();
    });

    test('maps a dancing roll to a null play with no hops', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/move': [
          _ok({'play': null, 'hops': <Object>[], 'level': 3}),
        ],
      });
      final client = _client(svc);
      final played = await client.playMove(_opening());
      expect(played.play, isNull);
      expect(played.hops, isEmpty);
      client.dispose();
    });

    test('omits the seed parameter when constructed without one', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/move': [
          _ok({'play': null, 'hops': <Object>[], 'level': 7}),
        ],
      });
      final client = _client(svc, level: 7, seed: null);
      await client.playMove(_opening());
      expect(
        svc.dataCalls.single.url.queryParameters.containsKey('seed'),
        isFalse,
      );
      client.dispose();
    });
  });

  group('SessionGnubgClient.playCube', () {
    test('sends the pre-roll id (dice 0,0 + cube state) and maps '
        'double', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/cube': [
          _ok({'double': true, 'level': 3}),
        ],
      });
      final client = _client(svc);
      final doubles = await client.playCube(
        _opening(cubeValue: 2, cubeOwner: GammonPlayer.one),
      );
      expect(doubles, isTrue);
      final call = svc.dataCalls.single;
      expect(call.url.path, '/v1/play/cube');
      expect(
        call.url.queryParameters['id'],
        '$_openingPositionId:'
        '${gnubgMatchId(die0: 0, die1: 0, cubeValue: 2, cubeOwner: 0)}',
      );
      client.dispose();
    });
  });

  group('SessionGnubgClient.playTake', () {
    test('maps take', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/take': [
          _ok({'take': false, 'level': 3}),
        ],
      });
      final client = _client(svc);
      expect(await client.playTake(_opening()), isFalse);
      expect(svc.dataCalls.single.url.path, '/v1/play/take');
      client.dispose();
    });
  });

  group('SessionGnubgClient.playResign', () {
    test('maps each stake', () async {
      for (final entry in const {
        'none': GnubgResignStake.none,
        'single': GnubgResignStake.single,
        'gammon': GnubgResignStake.gammon,
        'backgammon': GnubgResignStake.backgammon,
      }.entries) {
        final svc = _FakeService({
          '/v1/token': [_mintOk()],
          '/v1/play/resign': [
            _ok({'resign': entry.key, 'level': 3}),
          ],
        });
        final client = _client(svc);
        expect(
          await client.playResign(_opening()),
          entry.value,
          reason: 'stake ${entry.key}',
        );
        client.dispose();
      }
    });
  });

  group('SessionGnubgClient errors', () {
    test('lets key-level ApiExceptions propagate (never swallows)', () async {
      final svc = _FakeService({
        '/v1/token': [_mintOk()],
        '/v1/play/move': [_err(429, 'quota exceeded')],
      });
      final client = _client(svc);
      await expectLater(
        client.playMove(_opening()),
        throwsA(isA<ApiException>()),
      );
      client.dispose();
    });
  });
}

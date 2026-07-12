import 'dart:convert';

import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/ai_engines.dart';
import 'package:fibscli/session_gnubg_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnubg_service/gnubg_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A scripted service that counts mints and data calls.
class _FakeService {
  _FakeService({this.dataStatus = 200});
  static const _moveOk =
      '{"play":"8/5 6/5", "hops":[{"from":8,"to":5},{"from":6,"to":5}], '
      '"level":3}';

  final int dataStatus;
  int mints = 0;
  int dataCalls = 0;

  http.Client get client => MockClient((request) async {
    if (request.url.path == '/v1/token') {
      mints++;
      return http.Response(
        jsonEncode({'token': 'bg_tk_fake', 'expires_in': 3600, 'budget': 2000}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    dataCalls++;
    return http.Response(
      dataStatus == 200 ? _moveOk : jsonEncode({'error': 'nope'}),
      dataStatus,
      headers: {'content-type': 'application/json'},
    );
  });

  GnubgSession session() => GnubgSession(
    baseUrl: 'http://svc.test',
    publishableKey: 'bg_pk_example_public',
    attest: () async => 'fake-turnstile-response',
    httpClient: client,
  );
}

BgPosition _opening() => BgPosition(
  board: GammonRules.initialBoard(),
  onRoll: GammonPlayer.one,
  dice: const [3, 1],
);

void main() {
  group('SessionGnubgClient.prepare', () {
    test('mints the token up front, without playing anything', () async {
      final svc = _FakeService();
      final client = SessionGnubgClient(svc.session(), level: 3, seed: 1);
      await client.prepare();
      expect(svc.mints, 1, reason: 'the challenge is answered at the pause');
      expect(svc.dataCalls, 0, reason: 'pre-warm plays no move');
      client.dispose();
    });
  });

  group('SessionGnubgClient error classification', () {
    test('a refused credential is permanent: it surfaces as '
        'GnubgUnavailableException, not a bare ApiException', () async {
      for (final status in [401, 403, 429]) {
        final svc = _FakeService(dataStatus: status);
        final client = SessionGnubgClient(svc.session(), level: 3, seed: 1);
        await expectLater(
          client.playMove(_opening()),
          throwsA(isA<GnubgUnavailableException>()),
          reason: 'status $status',
        );
        client.dispose();
      }
    });

    test('a service outage stays retryable (an ApiException, which the '
        'adapter retries)', () async {
      final svc = _FakeService(dataStatus: 503);
      final client = SessionGnubgClient(svc.session(), level: 3, seed: 1);
      await expectLater(
        client.playMove(_opening()),
        throwsA(isA<ApiException>()),
      );
      client.dispose();
    });
  });

  group('ComputerOpponentsFactory session sharing', () {
    test('every Gary shares ONE session, so a token is minted once, not '
        'once per game', () async {
      final svc = _FakeService();
      var built = 0;
      final factory = ComputerOpponentsFactory(
        sessionFor: () {
          built++;
          return svc.session();
        },
      );

      final gary1 = factory.create(level: '3');
      await gary1.prepare();
      await gary1.chooseTurn(_opening());
      gary1.dispose(); // a finished game must NOT close the shared session

      final gary2 = factory.create(level: '5');
      await gary2.prepare();
      await gary2.chooseTurn(_opening());
      gary2.dispose();

      expect(built, 1, reason: 'one app-scoped session');
      expect(svc.mints, 1, reason: 'the second game reuses the live token');
      expect(svc.dataCalls, 2, reason: 'both games still played');
    });
  });
}

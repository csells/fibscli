import 'dart:async';
import 'dart:convert';

import 'package:bg_engine/bg_engine.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('HttpGnubgClient', () {
    test('posts the encoded gnubg_id + dice and parses ranked moves', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/v1/eval');
        expect(request.headers['x-api-key'], 'secret');
        return Response(
          jsonEncode({
            'moves': [
              {'play': '8/5 6/5', 'equity': -0.01},
              {'play': '24/23 13/9', 'equity': -0.05},
            ],
            'cubeless_equity': -0.02,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        apiKey: 'secret',
        httpClient: mock,
      );

      final moves = await client.evalMoves(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );

      // request carried the verified opening Position ID + a 3,1 Match ID
      final id = sentBody['gnubg_id'] as String;
      expect(id, startsWith('4HPwATDgc/ABMA:'));
      expect(moves.map((m) => m.play), ['8/5 6/5', '24/23 13/9']);
      expect(moves.first.equity, -0.01);

      client.dispose();
    });

    test('throws GnubgServiceError on a non-200 response', () async {
      final mock = MockClient((request) async => Response('nope', 503));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.evalMoves(
          BgPosition(
            board: GammonRules.initialBoard(),
            onRoll: GammonPlayer.one,
            dice: [3, 1],
          ),
        ),
        throwsA(isA<GnubgServiceError>()),
      );
    });

    BgPosition opening() => BgPosition(
      board: GammonRules.initialBoard(),
      onRoll: GammonPlayer.one,
      dice: const [3, 1],
    );

    // A hung service must not leave the request awaiting forever (freezing the
    // AI turn). The retry loop only catches thrown Exceptions and a hang throws
    // nothing, so a bounded timeout turns it into a catchable TimeoutException.
    test('a hung service times out instead of hanging forever', () async {
      final mock = MockClient(
        (_) => Completer<Response>().future,
      ); // never done
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        client.evalMoves(opening()),
        throwsA(isA<TimeoutException>()),
      );
    });

    // A valid-HTTP-but-wrong-shape body must surface as a catchable Exception,
    // not a raw TypeError (an Error) that would escape the adapter's
    // `on Exception catch` retry/unavailable path.
    test('a malformed 200 body throws an Exception, not a raw Error', () async {
      final mock = MockClient(
        (_) async => Response(
          jsonEncode({
            'moves': [
              {'equity': 0.1}, // 'play' missing
            ],
          }),
          200,
        ),
      );
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(client.evalMoves(opening()), throwsA(isA<Exception>()));
    });

    // The response is schema-validated: a wrong-shape body fails with a message
    // that NAMES the offending field, not an opaque cast TypeError text.
    Future<void> expectSchemaError(Object body, Matcher message) async {
      final mock = MockClient((_) async => Response(jsonEncode(body), 200));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.evalMoves(opening()),
        throwsA(
          isA<GnubgServiceError>().having((e) => e.body, 'body', message),
        ),
      );
    }

    test('names "moves" when it is not a list', () async {
      await expectSchemaError({'moves': 'nope'}, contains('"moves"'));
    });

    test('names "play" when a move is missing it', () async {
      await expectSchemaError({
        'moves': [
          {'equity': 0.1},
        ],
      }, contains('play'));
    });

    test('names "equity" when it is the wrong type', () async {
      await expectSchemaError({
        'moves': [
          {'play': '8/5 6/5', 'equity': 'high'},
        ],
      }, contains('equity'));
    });
  });
}

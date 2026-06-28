import 'dart:convert';

import 'package:bg_engine/bg_engine.dart';
import 'package:bg_engine/src/ai/http_gnubg_client.dart';
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
  });
}

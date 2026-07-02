import 'dart:async';
import 'dart:convert';

import 'package:bg_engine/bg_engine.dart';
import 'package:bg_engine/src/ai/gnubg_id.dart';
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
        expect(request.headers['authorization'], 'Bearer secret');
        expect(request.headers.containsKey('x-api-key'), isFalse);
        // The service's real /v1/eval response shape: each ranked move
        // carries the notation "play", the structured "hops" the adapter
        // plays by, and outcome "probabilities" (not consumed) plus the
        // echoed "plies"; the parser must tolerate the extras.
        return Response(
          jsonEncode({
            'moves': [
              {
                'play': '8/5 6/5',
                'hops': [
                  {'from': 8, 'to': 5},
                  {'from': 6, 'to': 5},
                ],
                'equity': -0.01,
                'probabilities': {
                  'win': 0.55,
                  'win_gammon': 0.15,
                  'win_backgammon': 0.01,
                  'lose_gammon': 0.12,
                  'lose_backgammon': 0.005,
                },
              },
              {
                'play': '24/23 13/9',
                'hops': [
                  {'from': 24, 'to': 23},
                  {'from': 13, 'to': 9},
                ],
                'equity': -0.05,
                'probabilities': {
                  'win': 0.53,
                  'win_gammon': 0.14,
                  'win_backgammon': 0.01,
                  'lose_gammon': 0.13,
                  'lose_backgammon': 0.006,
                },
              },
            ],
            'plies': 2,
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
      // (cube centred at 1: the BgPosition defaults)
      final id = sentBody['gnubg_id'] as String;
      expect(id, '4HPwATDgc/ABMA:${gnubgMatchId(die0: 3, die1: 1)}');
      expect(moves.map((m) => m.play), ['8/5 6/5', '24/23 13/9']);
      expect(moves.first.equity, -0.01);
      expect(moves.first.hops, const [
        GnubgHop(from: 8, to: 5),
        GnubgHop(from: 6, to: 5),
      ]);
      expect(moves.last.hops, const [
        GnubgHop(from: 24, to: 23),
        GnubgHop(from: 13, to: 9),
      ]);

      client.dispose();
    });

    test('carries the position cube state in the match id', () async {
      late String sentId;
      final mock = MockClient((request) async {
        sentId =
            (jsonDecode(request.body) as Map<String, dynamic>)['gnubg_id']
                as String;
        return Response(jsonEncode({'moves': <Object>[]}), 200);
      });
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );

      // The mover holds the cube at 2: seat 0 in the id (the on-roll seat).
      await client.evalMoves(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.two,
          dice: const [5, 2],
          cubeValue: 2,
          cubeOwner: GammonPlayer.two,
        ),
      );
      expect(
        sentId.split(':')[1],
        gnubgMatchId(die0: 5, die1: 2, cubeValue: 2, cubeOwner: 0),
      );

      // The opponent holds the cube at 4: seat 1.
      await client.evalMoves(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.two,
          dice: const [5, 2],
          cubeValue: 4,
          cubeOwner: GammonPlayer.one,
        ),
      );
      expect(
        sentId.split(':')[1],
        gnubgMatchId(die0: 5, die1: 2, cubeValue: 4, cubeOwner: 1),
      );

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
          {
            'play': '8/5 6/5',
            'hops': [
              {'from': 8, 'to': 5},
              {'from': 6, 'to': 5},
            ],
            'equity': 'high',
          },
        ],
      }, contains('equity'));
    });

    test('names "hops" when a move is missing it', () async {
      await expectSchemaError({
        'moves': [
          {'play': '8/5 6/5', 'equity': 0.1},
        ],
      }, contains('"hops"'));
    });

    test('names "hops" when it is not a list', () async {
      await expectSchemaError({
        'moves': [
          {'play': '8/5 6/5', 'hops': '8/5', 'equity': 0.1},
        ],
      }, contains('"hops"'));
    });

    test('names the hop field when "from"/"to" is malformed', () async {
      await expectSchemaError({
        'moves': [
          {
            'play': '8/5 6/5',
            'hops': [
              {'from': 'bar', 'to': 5},
            ],
            'equity': 0.1,
          },
        ],
      }, contains('"from"'));
      await expectSchemaError({
        'moves': [
          {
            'play': '8/5 6/5',
            'hops': [
              {'from': 8},
            ],
            'equity': 0.1,
          },
        ],
      }, contains('"to"'));
    });
  });

  group('HttpGnubgClient.cubeDecision', () {
    // The opening as a cube-decision point: the dice the position happens to
    // carry are NOT part of a cube request (gnubg judges the cube pre-roll).
    BgPosition opening({int cubeValue = 1, GammonPlayer? cubeOwner}) =>
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: const [3, 1],
          cubeValue: cubeValue,
          cubeOwner: cubeOwner,
        );

    // The service's real /v1/cube response shape (values captured from gnubg
    // 1.08.003 via the service's own wire test fixture).
    Map<String, Object> cubeBody(String action) => {
      'action': action,
      'cubeless_equity': -0.15921363234519958,
      'cubeful_nodouble': -0.2184544801712036,
      'cubeful_double_take': -0.6932543516159058,
      'cubeful_double_pass': 1.0,
      'plies': 2,
    };

    test(
      'posts a pre-roll gnubg_id to /v1/cube and parses the reply',
      () async {
        late Map<String, dynamic> sentBody;
        final mock = MockClient((request) async {
          sentBody = jsonDecode(request.body) as Map<String, dynamic>;
          expect(request.url.path, '/v1/cube');
          expect(request.headers['authorization'], 'Bearer secret');
          return Response(jsonEncode(cubeBody('no_double')), 200);
        });
        final client = HttpGnubgClient(
          baseUrl: Uri.parse('https://gnubg.example'),
          apiKey: 'secret',
          httpClient: mock,
        );

        final decision = await client.cubeDecision(opening());

        // pre-roll match id (dice 0,0), centred cube at 1
        final id = sentBody['gnubg_id'] as String;
        expect(id, '4HPwATDgc/ABMA:${gnubgMatchId(die0: 0, die1: 0)}');
        expect(sentBody['plies'], 2);
        expect(decision.action, GnubgCubeAction.noDouble);
        expect(decision.cubelessEquity, -0.15921363234519958);
        expect(decision.cubefulNoDouble, -0.2184544801712036);
        expect(decision.cubefulDoubleTake, -0.6932543516159058);
        expect(decision.cubefulDoublePass, 1.0);

        client.dispose();
      },
    );

    test('carries the cube state in the pre-roll match id', () async {
      late String sentId;
      final mock = MockClient((request) async {
        sentId =
            (jsonDecode(request.body) as Map<String, dynamic>)['gnubg_id']
                as String;
        return Response(jsonEncode(cubeBody('no_double')), 200);
      });
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );

      // The mover holds the cube at 2: seat 0 in the id (the on-roll seat).
      await client.cubeDecision(
        opening(cubeValue: 2, cubeOwner: GammonPlayer.one),
      );
      expect(
        sentId.split(':')[1],
        gnubgMatchId(die0: 0, die1: 0, cubeValue: 2, cubeOwner: 0),
      );

      client.dispose();
    });

    test('maps each of the four service actions', () async {
      const wireToAction = {
        'no_double': GnubgCubeAction.noDouble,
        'double_take': GnubgCubeAction.doubleTake,
        'double_pass': GnubgCubeAction.doublePass,
        'too_good_to_double': GnubgCubeAction.tooGoodToDouble,
      };
      for (final entry in wireToAction.entries) {
        final mock = MockClient(
          (_) async => Response(jsonEncode(cubeBody(entry.key)), 200),
        );
        final client = HttpGnubgClient(
          baseUrl: Uri.parse('https://gnubg.example'),
          httpClient: mock,
        );
        final decision = await client.cubeDecision(opening());
        expect(decision.action, entry.value, reason: entry.key);
        client.dispose();
      }
    });

    test('throws GnubgServiceError on a non-200 response', () async {
      final mock = MockClient((_) async => Response('nope', 503));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.cubeDecision(opening()),
        throwsA(isA<GnubgServiceError>()),
      );
    });

    test('a hung service times out instead of hanging forever', () async {
      final mock = MockClient((_) => Completer<Response>().future);
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
        timeout: const Duration(milliseconds: 50),
      );
      await expectLater(
        client.cubeDecision(opening()),
        throwsA(isA<TimeoutException>()),
      );
    });

    Future<void> expectCubeSchemaError(Object body, Matcher message) async {
      final mock = MockClient((_) async => Response(jsonEncode(body), 200));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.cubeDecision(opening()),
        throwsA(
          isA<GnubgServiceError>().having((e) => e.body, 'body', message),
        ),
      );
    }

    test('names "action" when it is missing or unrecognized', () async {
      await expectCubeSchemaError(
        cubeBody('no_double')..remove('action'),
        contains('"action"'),
      );
      await expectCubeSchemaError(cubeBody('beavers!'), contains('"action"'));
    });

    test('names the equity field when it is the wrong type', () async {
      await expectCubeSchemaError(
        cubeBody('no_double')..['cubeful_double_take'] = 'high',
        contains('cubeful_double_take'),
      );
    });
  });

  group('HttpGnubgClient.resignDecision', () {
    BgPosition opening() => BgPosition(
      board: GammonRules.initialBoard(),
      onRoll: GammonPlayer.one,
      dice: const [3, 1],
    );

    // The service's real /v1/resign response shape: advice-only (offered = 0)
    // replies omit the accept verdict and the resigner equities.
    Map<String, Object> adviceBody(int advice) => {
      'resign_advice': advice,
      'probabilities': {
        'win': 0.02,
        'win_gammon': 0.0,
        'win_backgammon': 0.0,
        'lose_gammon': 0.6,
        'lose_backgammon': 0.1,
      },
      'equity_play_on': -1.66,
      'offered': 0,
      'plies': 2,
    };

    test('posts a pre-roll gnubg_id to /v1/resign and parses the '
        'advice', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        expect(request.url.path, '/v1/resign');
        expect(request.headers['authorization'], 'Bearer secret');
        return Response(jsonEncode(adviceBody(2)), 200);
      });
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        apiKey: 'secret',
        httpClient: mock,
      );

      final decision = await client.resignDecision(opening());

      final id = sentBody['gnubg_id'] as String;
      expect(id, '4HPwATDgc/ABMA:${gnubgMatchId(die0: 0, die1: 0)}');
      expect(sentBody['plies'], 2);
      expect(sentBody['offered'], 0);
      expect(decision.resignAdvice, 2);
      expect(decision.equityPlayOn, -1.66);
      expect(decision.accept, isNull);

      client.dispose();
    });

    test('passes offered through and parses the accept verdict', () async {
      late Map<String, dynamic> sentBody;
      final mock = MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return Response(
          jsonEncode({
            ...adviceBody(0),
            'offered': 1,
            'accept': true,
            'resigner_equity_play_on': -0.95,
            'resigner_equity_resigned': -1.0,
          }),
          200,
        );
      });
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );

      final decision = await client.resignDecision(opening(), offered: 1);
      expect(sentBody['offered'], 1);
      expect(decision.accept, isTrue);

      client.dispose();
    });

    test('throws GnubgServiceError on a non-200 response', () async {
      final mock = MockClient((_) async => Response('nope', 429));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.resignDecision(opening()),
        throwsA(isA<GnubgServiceError>()),
      );
    });

    Future<void> expectResignSchemaError(Object body, Matcher message) async {
      final mock = MockClient((_) async => Response(jsonEncode(body), 200));
      final client = HttpGnubgClient(
        baseUrl: Uri.parse('https://gnubg.example'),
        httpClient: mock,
      );
      await expectLater(
        client.resignDecision(opening()),
        throwsA(
          isA<GnubgServiceError>().having((e) => e.body, 'body', message),
        ),
      );
    }

    test('names "resign_advice" when missing or out of range', () async {
      await expectResignSchemaError(
        adviceBody(0)..remove('resign_advice'),
        contains('"resign_advice"'),
      );
      await expectResignSchemaError(
        adviceBody(0)..['resign_advice'] = 7,
        contains('"resign_advice"'),
      );
    });

    test('names "accept" when it is the wrong type', () async {
      await expectResignSchemaError({
        ...adviceBody(0),
        'accept': 'sure',
      }, contains('"accept"'));
    });
  });
}

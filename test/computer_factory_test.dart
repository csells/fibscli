import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/ai_engines.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gnubg_service/gnubg_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

GnubgSession _fakeSession() => GnubgSession(
  baseUrl: 'http://svc.test',
  publishableKey: 'bg_pk_example_public',
  attest: () async => 'fake-turnstile-response',
  httpClient: MockClient(
    (request) async => http.Response('{"error":"unused"}', 500),
  ),
);

void main() {
  group('ComputerOpponentsFactory with Gary available', () {
    final factory = ComputerOpponentsFactory(sessionFor: _fakeSession);

    test('is the single "Computer" engine with levels 0..7', () {
      expect(factory.name, 'Computer');
      expect(factory.levels, ['0', '1', '2', '3', '4', '5', '6', '7']);
      expect(
        factory.levels.every(factory.isLevelEnabled),
        isTrue,
        reason: 'every level playable when a session supplier exists',
      );
    });

    test('level 0 is Harry Heuristic, the offline pubeval persona', () {
      final harry = factory.create(level: '0');
      expect(harry, isA<PubevalAiPlayer>());
      expect(harry.name, 'Harry Heuristic');
      expect(harry.description, 'ELO 1450 · offline');
    });

    test('levels 1-7 are Gary Gammon with the calibrated tier names', () {
      const tiers = {
        '1': 'novice',
        '2': 'beginner',
        '3': 'casual',
        '4': 'intermediate',
        '5': 'advanced',
        '6': 'expert',
        '7': 'world-class',
      };
      for (final entry in tiers.entries) {
        final gary = factory.create(level: entry.key);
        expect(gary, isA<GnubgAiPlayer>(), reason: 'level ${entry.key}');
        expect(gary.name, 'Gary Gammon');
        expect(gary.description, entry.value);
        gary.dispose();
      }
    });

    test('labels levels with their persona and tier', () {
      expect(factory.levelLabel('0'), 'Harry Heuristic — ELO 1450 · offline');
      expect(factory.levelLabel('3'), 'Gary Gammon — casual');
      expect(factory.levelLabel('7'), 'Gary Gammon — world-class');
    });

    test('an out-of-range level throws rather than guessing', () {
      expect(() => factory.create(level: '8'), throwsArgumentError);
      expect(() => factory.create(level: 'x'), throwsArgumentError);
    });
  });

  group('ComputerOpponentsFactory without Gary (no session supplier)', () {
    final factory = ComputerOpponentsFactory(sessionFor: null);

    test('still lists the full ladder but only Harry is enabled', () {
      expect(factory.levels, hasLength(8));
      expect(factory.isLevelEnabled('0'), isTrue);
      for (var n = 1; n <= 7; n++) {
        expect(factory.isLevelEnabled('$n'), isFalse, reason: 'level $n');
      }
    });

    test('Harry still plays', () {
      expect(factory.create(level: '0'), isA<PubevalAiPlayer>());
    });

    test('creating Gary fails loudly instead of substituting Harry', () {
      expect(() => factory.create(level: '3'), throwsStateError);
    });
  });
}

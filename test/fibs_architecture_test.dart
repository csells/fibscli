import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FIBS architecture guards', () {
    test('cookie routing has one protocol dispatch surface', () {
      expect(File('lib/fibs_protocol_routing.dart').existsSync(), isFalse);
      expect(
        File('lib/fibs_state.dart').readAsStringSync(),
        isNot(contains('fibsProtocolRouteFor')),
      );
    });

    test('protocol receive dispatch is table-driven', () {
      expect(
        File('lib/fibs_protocol.dart').readAsStringSync(),
        isNot(
          contains(
            'FibsProtocolTransition receive(CookieMessage cm) => '
            'switch',
          ),
        ),
      );
    });

    test('session reducer owns session-cookie classification', () {
      final protocol = File('lib/fibs_protocol.dart').readAsStringSync();

      expect(protocol, isNot(contains('_sessionCookieHandlers')));
      expect(protocol, isNot(contains('FibsCookie.FIBS_YouRoll')));
    });

    test(
      'resume coordinator does not encode state as mode plus nullable data',
      () {
        final resume = File(
          'lib/fibs_resume_coordinator.dart',
        ).readAsStringSync();

        expect(resume, isNot(contains('final String? _pendingOpponent')));
        expect(resume, isNot(contains('const _pendingOpponentUnchanged')));
        expect(resume, isNot(contains('FibsResumeMode? mode')));
      },
    );

    test('live browser e2e does not click fixed coordinates', () {
      expect(
        File('tool/browser_e2e/fibs_e2e.mjs').readAsStringSync(),
        isNot(contains('page.mouse.click')),
      );
    });

    test('e2e probe does not change production reconnect wiring', () {
      expect(
        File('lib/main.dart').readAsStringSync(),
        isNot(contains("bool.fromEnvironment('fibs_e2e_probe')")),
      );
    });
  });
}

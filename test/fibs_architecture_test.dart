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
  });
}

import 'dart:convert';

import 'package:fibscli/http_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  test(
    'httpErrorSink POSTs the error, stack, context and time as JSON',
    () async {
      Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return Response('', 200);
      });
      final sink = httpErrorSink(
        Uri.parse('https://crash.example/report'),
        apiKey: 'k',
        httpClient: mock,
        now: () => DateTime.utc(2026, 7, 1, 12),
      );

      sink(StateError('boom'), StackTrace.current, 'fibs stream');
      await Future<void>.delayed(
        Duration.zero,
      ); // let the fire-and-forget POST run

      expect(captured, isNotNull);
      expect(captured!.url.path, '/report');
      expect(captured!.headers['x-api-key'], 'k');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['context'], 'fibs stream');
      expect(body['error'], contains('boom'));
      expect(body['stack'], isNotNull);
      expect(body['time'], startsWith('2026-07-01'));
    },
  );

  test(
    'a failing POST is swallowed (a reporter must not crash the app)',
    () async {
      final mock = MockClient((_) async => throw StateError('network down'));
      final sink = httpErrorSink(Uri.parse('https://x/y'), httpClient: mock);

      // must not throw into the caller (reportError), synchronously or async
      expect(() => sink(StateError('boom'), null, 'ctx'), returnsNormally);
      await Future<void>.delayed(Duration.zero);
    },
  );
}

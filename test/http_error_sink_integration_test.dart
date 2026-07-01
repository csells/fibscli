@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fibscli/http_error_sink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // End-to-end over a real socket (not a MockClient): the sink must actually
  // deliver a well-formed POST to a listening HTTP server, proving a deployer
  // who sets crash_report_url gets real reports.
  test('httpErrorSink delivers a real POST to a listening server', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final got = Completer<Map<String, dynamic>>();
    server.listen((req) async {
      final body = await utf8.decodeStream(req);
      req.response.statusCode = 200;
      await req.response.close();
      if (!got.isCompleted) {
        got.complete(jsonDecode(body) as Map<String, dynamic>);
      }
    });

    final url = Uri.parse('http://${server.address.host}:${server.port}/crash');
    final sink = httpErrorSink(url, apiKey: 'secret');
    sink(StateError('real boom'), StackTrace.current, 'integration');

    final payload = await got.future.timeout(const Duration(seconds: 5));
    await server.close(force: true);

    expect(payload['context'], 'integration');
    expect(payload['error'], contains('real boom'));
    expect(payload['stack'], isNotNull);
    expect(payload['time'], isNotNull);
  });
}

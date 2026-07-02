import 'dart:convert';

import 'package:fibscli/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  test('AppAnalytics POSTs a sanitized app event', () async {
    Request? captured;
    final mock = MockClient((request) async {
      captured = request;
      return Response('', 204);
    });
    final analytics = AppAnalytics.http(
      Uri.parse('https://proxy.example.com/analytics'),
      environment: 'test',
      version: 'unit',
      platform: 'web',
      httpClient: mock,
    );

    analytics.track(
      'app_fibs_lobby_ready',
      screen: 'fibs_lobby',
      whoInfoCount: 12,
      availableBotCount: 3,
      watchableBotCount: 2,
      savedMatchCount: 1,
      messageCount: 0,
    );
    await Future<void>.delayed(Duration.zero);

    expect(captured, isNotNull);
    expect(captured!.url.path, '/analytics');
    expect(captured!.headers['content-type'], 'application/json');
    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['event'], 'app_fibs_lobby_ready');
    expect(body['environment'], 'test');
    expect(body['version'], 'unit');
    expect(body['platform'], 'web');
    expect(body['whoInfoCount'], 12);
    expect(body.containsKey('user'), isFalse);
    expect(body.containsKey('password'), isFalse);
  });

  test('AppAnalytics.disabled emits nothing', () async {
    final analytics = AppAnalytics.disabled();

    analytics.track('app_start', screen: 'landing');
    await Future<void>.delayed(Duration.zero);

    expect(analytics.enabled, isFalse);
  });

  test('AppAnalytics swallows POST failures', () async {
    final mock = MockClient((_) async => throw StateError('network down'));
    final analytics = AppAnalytics.http(
      Uri.parse('https://proxy.example.com/analytics'),
      environment: 'test',
      version: 'unit',
      httpClient: mock,
    );

    expect(() => analytics.track('app_start'), returnsNormally);
    await Future<void>.delayed(Duration.zero);
  });
}

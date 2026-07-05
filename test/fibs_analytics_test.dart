import 'dart:convert';

import 'package:fibscli/analytics.dart';
import 'package:fibscli/fibs_analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';

void main() {
  test('FibsAnalyticsCounts forwards the selected sanitized counts', () async {
    Request? captured;
    final analytics = AppAnalytics.http(
      Uri.parse('https://proxy.example.com/analytics'),
      environment: 'test',
      version: 'unit',
      platform: 'web',
      httpClient: MockClient((request) async {
        captured = request;
        return Response('', 204);
      }),
    );
    const counts = FibsAnalyticsCounts(
      whoInfoCount: 12,
      availableBotCount: 3,
      watchableBotCount: 2,
      savedMatchCount: 1,
      messageCount: 5,
    );

    analytics.trackFibs(
      'app_fibs_invite',
      screen: 'fibs_lobby',
      mode: 'match_3',
      counts: counts,
      includeMessageCount: false,
    );
    await Future<void>.delayed(Duration.zero);

    final body = jsonDecode(captured!.body) as Map<String, dynamic>;
    expect(body['event'], 'app_fibs_invite');
    expect(body['screen'], 'fibs_lobby');
    expect(body['mode'], 'match_3');
    expect(body['whoInfoCount'], 12);
    expect(body['availableBotCount'], 3);
    expect(body['watchableBotCount'], 2);
    expect(body['savedMatchCount'], 1);
    expect(body.containsKey('messageCount'), isFalse);
    expect(body.containsKey('user'), isFalse);
    expect(body.containsKey('password'), isFalse);
  });
}

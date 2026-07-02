import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AppAnalytics {
  AppAnalytics.disabled()
    : _url = null,
      _client = null,
      environment = 'disabled',
      version = 'unknown',
      platform = _platform;

  AppAnalytics.http(
    Uri url, {
    required this.environment,
    required this.version,
    String? platform,
    http.Client? httpClient,
  }) : _url = url,
       _client = httpClient ?? http.Client(),
       platform = platform ?? _platform;

  final Uri? _url;
  final http.Client? _client;
  final String environment;
  final String version;
  final String platform;

  bool get enabled => _url != null;

  void track(
    String event, {
    String? screen,
    String? mode,
    String result = 'accepted',
    int? whoInfoCount,
    int? availableBotCount,
    int? watchableBotCount,
    int? savedMatchCount,
    int? messageCount,
  }) {
    final url = _url;
    final client = _client;
    if (url == null || client == null) return;
    assert(event.startsWith('app_'));
    unawaited(
      _post(client, url, {
        'event': event,
        'environment': environment,
        'version': version,
        'platform': platform,
        'result': result,
        if (screen != null) 'screen': screen,
        if (mode != null) 'mode': mode,
        if (whoInfoCount != null) 'whoInfoCount': whoInfoCount,
        if (availableBotCount != null) 'availableBotCount': availableBotCount,
        if (watchableBotCount != null) 'watchableBotCount': watchableBotCount,
        if (savedMatchCount != null) 'savedMatchCount': savedMatchCount,
        if (messageCount != null) 'messageCount': messageCount,
      }),
    );
  }

  static String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;
}

Future<void> _post(
  http.Client client,
  Uri url,
  Map<String, Object> body,
) async {
  try {
    await client
        .post(
          url,
          headers: const {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 5));
  } on Object {
    // Analytics is best-effort. Telemetry failures must not affect gameplay.
  }
}

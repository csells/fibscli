import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'logging.dart';

/// Builds an opt-in [ErrorSink] that POSTs each reported error to [url] as JSON
/// (`context`, `error`, `stack`, `time`), so a production deployment can
/// observe crashes off-device. Install it from bootstrap when a crash-report
/// URL is configured; the default is none, so nothing is sent unless a deployer
/// opts in.
///
/// Fire-and-forget and failure-tolerant: a reporting failure must NEVER crash
/// the app or re-enter [reportError] (which would loop), so the POST is
/// unawaited, bounded by a timeout, and its errors are swallowed.
ErrorSink httpErrorSink(
  Uri url, {
  String? apiKey,
  http.Client? httpClient,
  DateTime Function()? now,
}) {
  final client = httpClient ?? http.Client();
  final clock = now ?? DateTime.now;
  return (error, stack, context) =>
      unawaited(_post(client, url, apiKey, clock(), error, stack, context));
}

Future<void> _post(
  http.Client client,
  Uri url,
  String? apiKey,
  DateTime time,
  Object error,
  StackTrace? stack,
  String context,
) async {
  try {
    await client
        .post(
          url,
          headers: {
            'content-type': 'application/json',
            if (apiKey != null) 'x-api-key': apiKey,
          },
          body: jsonEncode({
            'context': context,
            'error': '$error',
            'stack': stack?.toString(),
            'time': time.toUtc().toIso8601String(),
          }),
        )
        .timeout(const Duration(seconds: 10));
  } on Object {
    // Swallow: reporting the failure of the reporter would loop, and a crash
    // reporter that can itself crash the app is worse than no reporter.
  }
}

import 'package:fibscli/logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  // setupLogging is idempotent: a second call is a no-op, so it can run in
  // main() (giving the FlutterError handler a sink) and again in bootstrap
  // without double-logging. (Fresh test file => first setup in the isolate.)
  test('setupLogging attaches exactly one sink even if called twice', () async {
    var first = 0;
    var second = 0;
    setupLogging(sink: (_) => first++);
    setupLogging(sink: (_) => second++); // must be a no-op
    Logger('t').severe('x');
    await Future<void>.delayed(Duration.zero); // let onRecord dispatch

    expect(first, 1); // the first sink received the record
    expect(second, 0); // the second call did not attach a duplicate sink
  });

  // Uncaught errors are reported through ONE centralized seam
  // (package:logging), carrying the operation context, error, and stack -- so
  // the FlutterError handler and the zone handler format identically and a
  // single sink sees every crash.
  test(
    'reportError routes error + context + stack to package:logging',
    () async {
      Logger.root.level = Level.ALL;
      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      final stack = StackTrace.current;

      reportError(StateError('boom'), stack, context: 'saving prefs');
      await Future<void>.delayed(Duration.zero); // let onRecord dispatch
      await sub.cancel();

      expect(records, hasLength(1));
      final r = records.single;
      expect(r.level, Level.SEVERE); // reported at severe
      expect(r.message, 'saving prefs'); // the operation context
      expect(r.error, isA<StateError>()); // the error object
      expect(r.stackTrace, same(stack)); // and its stack
    },
  );

  // Uncaught errors are shown to the user, not just the dev console:
  // reportError posts a user-facing AppError to appErrors with the context and
  // enough detail (the error text) to act on -- retry, or copy into a report.
  test(
    'reportError surfaces a user-facing AppError with actionable detail',
    () {
      appErrors.value = null;
      reportError(
        StateError('websocket died'),
        StackTrace.current,
        context: 'login',
      );

      final surfaced = appErrors.value;
      expect(surfaced, isNotNull);
      expect(surfaced!.message, contains('login')); // what the user was doing
      expect(surfaced.detail, contains('websocket died')); // the cause
      expect(surfaced.clipboardText, contains('websocket died')); // copyable
    },
  );

  // Crashes are retained (they survive the transient SnackBar) and bounded, so
  // the user can review recent failures.
  test('reportError retains a bounded error history', () {
    errorHistory.clear();
    for (var i = 0; i < 55; i++) {
      reportError(StateError('boom $i'), null, context: 'op');
    }
    expect(errorHistory.length, 50); // capped
    expect(errorHistory.first.detail, contains('boom 5')); // oldest dropped
    expect(errorHistory.last.detail, contains('boom 54')); // newest kept
  });

  // A production deployment can observe failures off-device via a remote sink.
  test('reportError forwards to the installed remote errorSink', () {
    Object? seenError;
    String? seenContext;
    errorSink = (error, stack, context) {
      seenError = error;
      seenContext = context;
    };
    addTearDown(() => errorSink = null);

    final err = StateError('connection reset');
    reportError(err, StackTrace.current, context: 'fibs stream');

    expect(seenError, same(err));
    expect(seenContext, 'fibs stream');
  });
}

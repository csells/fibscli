import 'package:fibscli/logging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

void main() {
  // Regression: setupLogging() attached a new Logger.root listener on every
  // call, so calling it in main() (moved there so the FlutterError handler has
  // a sink) AND again in bootstrap would double-log every record. It's now
  // idempotent -- the second call is a no-op. (Fresh test file => fresh module
  // state, so this is the first setup in the isolate.)
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

  // #3: uncaught errors are reported through ONE centralized seam
  // (package:logging), carrying the operation context, the error, and the
  // stack -- so the FlutterError handler and the zone handler format
  // identically and a single sink sees every crash.
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

  // #1 (reframed): the user must SEE uncaught errors, not just the dev console.
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
}

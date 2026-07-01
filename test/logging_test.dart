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
}

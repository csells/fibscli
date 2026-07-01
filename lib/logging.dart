import 'dart:developer' as dev;

import 'package:logging/logging.dart';

// Route package:logging records to the dev console. Using leveled, named
// loggers (instead of bare dev.log/print) lets verbose tracing sit at FINE —
// off by default — while warnings and errors always surface with context.
//
// Idempotent: safe to call early in main() (so the log sink exists before the
// FlutterError handler is wired) AND again in bootstrap without double-logging.
var _loggingSetUp = false;
void setupLogging() {
  if (_loggingSetUp) return;
  _loggingSetUp = true;
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((r) {
    dev.log(
      r.message,
      name: r.loggerName,
      level: r.level.value,
      time: r.time,
      error: r.error,
      stackTrace: r.stackTrace,
    );
  });
}

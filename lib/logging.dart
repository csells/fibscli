import 'dart:developer' as dev;

import 'package:logging/logging.dart';

final _crashLog = Logger('crash');

/// The ONE place uncaught errors are reported. Both global handlers (the
/// Flutter framework error handler and the runZonedGuarded zone handler) route
/// here, so every crash is formatted identically and reported through the
/// centralized package:logging sink -- carrying the operation [context], the
/// [error], and its [stack]. Today the sink is the dev console (see
/// [setupLogging]); a remote reporter can be added by attaching another
/// Logger.root.onRecord listener, with no change to call sites.
void reportError(
  Object error,
  StackTrace? stack, {
  String context = 'uncaught error',
}) => _crashLog.severe(context, error, stack);

// Route package:logging records to the dev console. Using leveled, named
// loggers (instead of bare dev.log/print) lets verbose tracing sit at FINE —
// off by default — while warnings and errors always surface with context.
//
// Idempotent: safe to call early in main() (so the log sink exists before the
// FlutterError handler is wired) AND again in bootstrap without double-logging.
// [sink] is injectable so the idempotency is testable; it defaults to dev.log.
var _loggingSetUp = false;
void setupLogging({void Function(LogRecord record)? sink}) {
  if (_loggingSetUp) return;
  _loggingSetUp = true;
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen(sink ?? _logToDevConsole);
}

void _logToDevConsole(LogRecord r) => dev.log(
  r.message,
  name: r.loggerName,
  level: r.level.value,
  time: r.time,
  error: r.error,
  stackTrace: r.stackTrace,
);

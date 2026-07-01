import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

final _crashLog = Logger('crash');

/// A surfaced, user-facing error. [message] is a short line the user reads;
/// [detail] is the underlying cause. [clipboardText] is what the "Copy" action
/// puts on the clipboard so the user has enough to act on it (retry, or paste
/// it into a bug report).
@immutable
class AppError {
  const AppError(this.message, {this.detail});

  final String message;
  final String? detail;

  String get clipboardText => detail == null ? message : '$message\n\n$detail';

  @override
  bool operator ==(Object other) =>
      other is AppError && other.message == message && other.detail == detail;

  @override
  int get hashCode => Object.hash(message, detail);
}

/// The most recently surfaced error; the app root listens to this and shows it
/// to the user. A [ValueNotifier] (not a BuildContext) so [reportError] can
/// post from anywhere -- including the Flutter/zone global handlers, which have
/// no context of their own.
final appErrors = ValueNotifier<AppError?>(null);

/// The ONE place uncaught errors are reported. Both global handlers (the
/// Flutter framework error handler and the runZonedGuarded zone handler) route
/// here, so every crash is (1) logged through the centralized package:logging
/// sink with the operation [context], [error], and [stack], AND (2) surfaced to
/// the user via [appErrors] with enough detail to act on -- rather than
/// vanishing into the console where only a developer would ever see it.
void reportError(
  Object error,
  StackTrace? stack, {
  String context = 'uncaught error',
}) {
  _crashLog.severe(context, error, stack);
  appErrors.value = AppError(
    'Something went wrong ($context). Please try again.',
    detail: '$error',
  );
}

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

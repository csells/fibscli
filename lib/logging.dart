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

/// A bounded history of surfaced errors (oldest first), so a crash survives its
/// transient SnackBar and the user can review or export it later -- production
/// observability without shipping data off-device by default.
final errorHistory = <AppError>[];

/// The most recent errors survive here even as [appErrors] is overwritten.
const _maxErrorHistory = 50;

/// A remote error sink. A production deployment can install one (e.g. an HTTP
/// POST to a crash service) to observe failures off-device; the default is
/// none, so nothing leaves the device unless a deployer opts in.
typedef ErrorSink =
    void Function(Object error, StackTrace? stack, String context);
ErrorSink? errorSink;

/// The ONE place uncaught errors are reported. Both global handlers (the
/// Flutter framework error handler and the runZonedGuarded zone handler) route
/// here, so every crash is (1) logged through the centralized package:logging
/// sink, (2) surfaced to the user via [appErrors] + retained in [errorHistory],
/// and (3) forwarded to the optional remote [errorSink] -- rather than
/// vanishing into the console where only a developer would ever see it.
void reportError(
  Object error,
  StackTrace? stack, {
  String context = 'uncaught error',
}) {
  _crashLog.severe(context, error, stack);
  final appError = AppError(
    'Something went wrong ($context). Please try again.',
    detail: '$error',
  );
  appErrors.value = appError;
  errorHistory.add(appError);
  if (errorHistory.length > _maxErrorHistory) errorHistory.removeAt(0);
  errorSink?.call(error, stack, context);
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

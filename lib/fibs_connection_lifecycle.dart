import 'dart:async';

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:logging/logging.dart';

import 'fibs_transport.dart';

final _log = Logger('fibs.connection');

class FibsConnectionLifecycle {
  FibsConnectionLifecycle({
    required FibsTransport Function() makeTransport,
    required Duration loginTimeout,
  }) : this._(makeTransport, loginTimeout);

  FibsConnectionLifecycle._(this._makeTransport, this._loginTimeout);

  final FibsTransport Function() _makeTransport;
  final Duration _loginTimeout;

  FibsTransport? _conn;
  StreamSubscription<CookieMessage>? _sub;

  bool get connected => _conn?.connected ?? false;

  void send(String command) => sendAll([command]);

  void sendAll(Iterable<String> commands) {
    final pending = commands.toList(growable: false);
    if (pending.isEmpty) return;
    final conn = _conn;
    if (conn == null || !conn.connected) {
      throw StateError('not connected to FIBS');
    }
    pending.forEach(conn.send);
  }

  Future<FibsCookie> login({
    required String user,
    required String pass,
    required void Function(CookieMessage) onCookie,
    required void Function(Object, StackTrace) onError,
    required void Function() onDone,
  }) async {
    await _sub?.cancel();
    final conn = _makeTransport();
    _conn = conn;
    _sub = conn.stream.listen(onCookie, onError: onError, onDone: onDone);
    return conn
        .login(user, pass)
        .timeout(_loginTimeout, onTimeout: () => FibsCookie.FIBS_Timeout);
  }

  Future<void> createAccount({
    required String user,
    required String pass,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    await _sub?.cancel();
    _sub = null;
    final conn = _makeTransport();
    _conn = conn;
    try {
      await conn.createAccount(user, pass).timeout(timeout);
    } finally {
      await closeCurrent();
    }
  }

  Future<void> closeCurrent({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final conn = _conn;
    final sub = _sub;
    _conn = null;
    _sub = null;
    try {
      final cancel = sub?.cancel();
      if (cancel != null) await cancel.timeout(timeout);
    } on Object catch (ex, st) {
      _log.warning('FIBS subscription cancel did not complete', ex, st);
    }
    try {
      final close = conn?.close();
      if (close != null) await close.timeout(timeout);
    } on Object catch (ex, st) {
      _log.warning('FIBS transport close did not complete', ex, st);
    }
  }
}

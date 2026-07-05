import 'package:fibscli_lib/fibscli_lib.dart';

// The bit of the FIBS connection that FibsState depends on. Abstracting it lets
// tests inject a fake transport (feed scripted cookies, capture sent commands)
// to drive the UI without a live server.
abstract interface class FibsTransport {
  Future<FibsCookie> login(String user, String pass);
  Future<void> createAccount(String user, String pass);
  void send(String s);
  void sendBatch(Iterable<String> commands);
  Stream<CookieMessage> get stream;
  Future<void> close();
  bool get connected;
}

// The real transport: a thin adapter over the vendored FibsConnection.
class FibsConnectionTransport implements FibsTransport {
  FibsConnectionTransport(this._conn);
  final FibsConnection _conn;

  @override
  Future<FibsCookie> login(String user, String pass) => _conn.login(user, pass);
  @override
  Future<void> createAccount(String user, String pass) =>
      _conn.createAccount(user, pass);
  @override
  void send(String s) => _conn.send(s);
  @override
  void sendBatch(Iterable<String> commands) => _conn.sendBatch(commands);
  @override
  Stream<CookieMessage> get stream => _conn.stream;
  @override
  Future<void> close() => _conn.close();
  @override
  bool get connected => _conn.connected;
}

import 'dart:async';

import 'package:fibscli/fibs_transport.dart';
import 'package:fibscli_lib/fibscli_lib.dart';

// A scripted transport: feed raw FIBS lines in (parsed to cookies), capture the
// commands sent out. Lets tests drive FibsState with no live server.
class FakeTransport implements FibsTransport {
  FakeTransport({this.loginResult = FibsCookie.CLIP_WELCOME});

  // the cookie login() resolves with; override to simulate a rejected login
  final FibsCookie loginResult;

  final _ctrl = StreamController<CookieMessage>.broadcast();
  final sent = <String>[];
  var _connected = false;

  @override
  Future<FibsCookie> login(String user, String pass) async {
    _connected = true;
    return loginResult;
  }

  @override
  void send(String s) => sent.add(s);
  @override
  Stream<CookieMessage> get stream => _ctrl.stream;
  @override
  Future<void> close() async => _connected = false;
  @override
  bool get connected => _connected;

  // feed a raw FIBS line as if it arrived from the server; defaults to run
  // state, but a login-handshake line can be fed with FIBS_LOGIN_STATE
  void feed(
    String raw, {
    CookieMonsterState state = CookieMonsterState.FIBS_RUN_STATE,
  }) {
    final m = CookieMonster()..messageState = state;
    _ctrl.add(m.eatCookie(raw));
  }

  // simulate a mid-session transport failure on the cookie stream
  void feedError(Object error, [StackTrace? st]) => _ctrl.addError(error, st);
}

// A transport with PRODUCTION-like semantics: a SINGLE-subscription stream and
// a close() that actually closes it -- the traits the broadcast/no-op
// [FakeTransport] hides. A closed instance can't be re-listened, so this must
// be built fresh per login (via FibsState.withTransportFactory) to exercise
// reconnect / re-login. [loginResult] is what login() resolves with.
class StrictFakeTransport implements FibsTransport {
  StrictFakeTransport(this.loginResult);
  final FibsCookie loginResult;

  final _ctrl = StreamController<CookieMessage>(); // single-subscription
  var _connected = false;

  @override
  Future<FibsCookie> login(String user, String pass) async {
    _connected = true;
    return loginResult;
  }

  @override
  void send(String s) {}
  @override
  Stream<CookieMessage> get stream => _ctrl.stream;
  @override
  Future<void> close() async {
    _connected = false;
    await _ctrl.close(); // real close, like FibsConnection
  }

  @override
  bool get connected => _connected;
}

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

  // feed a raw FIBS line as if it arrived from the server (run state)
  void feed(String raw) {
    final m = CookieMonster()..messageState = CookieMonsterState.FIBS_RUN_STATE;
    _ctrl.add(m.eatCookie(raw));
  }
}

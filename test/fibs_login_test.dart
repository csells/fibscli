import 'dart:async';

import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/fibs_transport.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

class _HangingLoginTransport implements FibsTransport {
  final StreamController<CookieMessage> _ctrl =
      StreamController<CookieMessage>();
  var _connected = false;
  bool closed = false;

  @override
  Future<FibsCookie> login(String user, String pass) {
    _connected = true;
    return Completer<FibsCookie>().future;
  }

  @override
  Future<void> createAccount(String user, String pass) async {
    _connected = true;
  }

  @override
  void send(String s) {}

  @override
  Stream<CookieMessage> get stream => _ctrl.stream;

  @override
  Future<void> close() async {
    closed = true;
    _connected = false;
    await _ctrl.close();
  }

  @override
  bool get connected => _connected;
}

void main() {
  // Authentication failures must surface (not silently leave a half-connected
  // state) and must not expose the raw credential in the message.
  test('a rejected login throws and stays logged out', () async {
    final fake = FakeTransport(loginResult: FibsCookie.FIBS_FailedLogin);
    final fibs = FibsState.withTransport(fake);

    await expectLater(
      () => fibs.login(user: 'joe', pass: 'wrongpass'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          allOf(contains('invalid'), isNot(contains('wrongpass'))),
        ),
      ),
    );
    expect(fibs.loggedIn, isFalse); // not left half-connected
  });

  test('a successful login connects', () async {
    final fake = FakeTransport(); // defaults to CLIP_WELCOME
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');
    expect(fibs.loggedIn, isTrue);
  });

  test('a hung login times out and closes the transport', () async {
    final fake = _HangingLoginTransport();
    final fibs = FibsState.withTransport(
      fake,
      loginTimeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      fibs.login(user: 'joe', pass: 'right'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('unable to connect'),
        ),
      ),
    );
    expect(fake.closed, isTrue);
    expect(fibs.loggedIn, isFalse);
  });

  test('login turns on the FIBS double prompt when it is off', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');

    fake.feed(
      '2 joe 1 1 0 0 0 0 1 0 2396 0 1 0 1 1500.00 0 0 0 0 0 UTC',
      state: CookieMonsterState.FIBS_LOGIN_STATE,
    );
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, contains('toggle double'));
  });

  test('login turns on FIBS moreboards when it is off', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');

    fake.feed(
      '2 joe 1 1 0 0 0 0 1 1 2396 0 0 0 1 1500.00 0 0 0 0 0 UTC',
      state: CookieMonsterState.FIBS_LOGIN_STATE,
    );
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, contains('toggle moreboards'));
  });

  test('duplicate off packets only request one double prompt toggle', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');

    for (var i = 0; i < 2; i += 1) {
      fake.feed(
        '2 joe 1 1 0 0 0 0 1 0 2396 0 1 0 1 1500.00 0 0 0 0 0 UTC',
        state: CookieMonsterState.FIBS_LOGIN_STATE,
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent.where((cmd) => cmd == 'toggle double'), hasLength(1));
  });

  test('duplicate off packets only request one moreboards toggle', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');

    for (var i = 0; i < 2; i += 1) {
      fake.feed(
        '2 joe 1 1 0 0 0 0 1 1 2396 0 0 0 1 1500.00 0 0 0 0 0 UTC',
        state: CookieMonsterState.FIBS_LOGIN_STATE,
      );
    }
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent.where((cmd) => cmd == 'toggle moreboards'), hasLength(1));
  });

  test(
    'login leaves the FIBS double prompt alone when it is already on',
    () async {
      final fake = FakeTransport();
      final fibs = FibsState.withTransport(fake);
      await fibs.login(user: 'joe', pass: 'right');

      fake.feed(
        '2 joe 1 1 0 0 0 0 1 1 2396 0 1 0 1 1500.00 0 0 0 0 0 UTC',
        state: CookieMonsterState.FIBS_LOGIN_STATE,
      );
      await Future<void>.delayed(Duration.zero);

      expect(fake.sent.where((cmd) => cmd == 'toggle double'), isEmpty);
    },
  );

  test('login leaves FIBS moreboards alone when it is already on', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'right');

    fake.feed(
      '2 joe 1 1 0 0 0 0 1 1 2396 0 1 0 1 1500.00 0 0 0 0 0 UTC',
      state: CookieMonsterState.FIBS_LOGIN_STATE,
    );
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent.where((cmd) => cmd == 'toggle moreboards'), isEmpty);
  });

  test('creating an account uses a guest session and closes it', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);

    await fibs.createAccount(user: 'new_user', pass: 'hunter2');

    expect(fake.createdAccounts, {'new_user': 'hunter2'});
    expect(fake.connected, isFalse);
    expect(fibs.loggedIn, isFalse);
  });
}

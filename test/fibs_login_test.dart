import 'package:fibscli/fibs_state.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

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

  test('creating an account uses a guest session and closes it', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);

    await fibs.createAccount(user: 'new_user', pass: 'hunter2');

    expect(fake.createdAccounts, {'new_user': 'hunter2'});
    expect(fake.connected, isFalse);
    expect(fibs.loggedIn, isFalse);
  });
}

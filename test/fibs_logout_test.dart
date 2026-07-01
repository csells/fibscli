import 'package:fibscli/fibs_state.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// FibsState owns the connection lifecycle. Logout must actually tear the
// connection down (not just reset local state) and run any injected cleanup,
// and a mid-session stream error must be handled, not left unhandled.
void main() {
  test('logout closes the transport so no connection lingers', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'pw');
    expect(fibs.loggedIn, isTrue);

    await fibs.logout();

    expect(fibs.loggedIn, isFalse); // the socket was actually closed
    expect(fake.connected, isFalse);
    expect(fake.sent, contains('bye')); // courtesy bye still sent
  });

  test('logout runs the injected onLogout hook (no global grab)', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    var ran = false;
    fibs.onLogout = () async => ran = true;
    await fibs.login(user: 'joe', pass: 'pw');

    await fibs.logout();

    expect(ran, isTrue);
  });

  test(
    'a mid-session stream error resets the session, not unhandled',
    () async {
      final fake = FakeTransport();
      final fibs = FibsState.withTransport(fake);
      await fibs.login(user: 'joe', pass: 'pw');
      expect(fibs.user, 'joe');

      fake.feedError(StateError('socket died'));
      await Future<void>.delayed(Duration.zero);

      expect(fibs.user, isNull); // _reset ran via onError; no unhandled error
    },
  );

  // logout tears the connection down even if the onLogout hook (a
  // secure-storage delete) throws -- a hook failure must not skip
  // cancel/close/reset and orphan the FIBS socket.
  test('logout tears down even if the onLogout hook throws', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe', pass: 'pw');
    expect(fibs.loggedIn, isTrue);

    fibs.onLogout = () async => throw StateError('keychain locked');

    await fibs.logout(); // must NOT throw
    expect(fibs.loggedIn, isFalse); // connection torn down despite hook failure
    expect(fake.connected, isFalse);
  });

  // A FibsConnection can't be reused once closed (single-sub stream + real
  // close), so FibsState creates a fresh transport per login -- retry-after-
  // failed-login and login-after-logout both work. StrictFakeTransport
  // reproduces the real single-subscription semantics (a broadcast/no-op
  // FakeTransport wouldn't exercise them).
  test(
    're-login works after a failed login (production-like transport)',
    () async {
      final results = <FibsCookie>[
        FibsCookie.FIBS_FailedLogin, // first attempt: wrong password
        FibsCookie.CLIP_WELCOME, // retry: success
      ];
      var i = 0;
      final fibs = FibsState.withTransportFactory(
        () => StrictFakeTransport(results[i++]),
      );

      await expectLater(
        fibs.login(user: 'me', pass: 'wrong'),
        throwsA(isA<Exception>()),
      );
      expect(fibs.loggedIn, isFalse);

      // the retry must NOT throw "Stream has already been listened to"
      await fibs.login(user: 'me', pass: 'right');
      expect(fibs.loggedIn, isTrue);
    },
  );
}

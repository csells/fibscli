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

  // Regression: logout awaited the onLogout hook (App.creds.forget ->
  // secure-storage delete) BEFORE tearing the connection down. A storage
  // failure escaped logout() and skipped cancel/close/reset -- orphaning the
  // FIBS socket and leaving the session reporting live.
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

  // Regression: a FibsConnection can't be reused once closed (single-sub stream
  // + real close), but FibsState reused one for the app's lifetime, so retry-
  // after-failed-login (and login-after-logout) threw "Stream has already been
  // listened to". A fresh transport per login fixes it. The broadcast/no-op
  // FakeTransport hid this; StrictFakeTransport reproduces the real semantics.
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

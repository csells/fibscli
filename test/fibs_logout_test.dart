import 'package:fibscli/fibs_state.dart';
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
}

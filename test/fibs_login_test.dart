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
}

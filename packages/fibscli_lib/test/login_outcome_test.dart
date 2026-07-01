import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:test/test.dart';

void main() {
  // The sentcred handshake picks the login outcome by precedence, never
  // `.single` -- one websocket frame can carry several matching cookies (a
  // failed login sends bogus "** ..." lines plus a re-`login:` prompt), and a
  // throw there would escape the stream callback so the login completer never
  // completes and the caller waits out its 3s timeout.
  test('a multi-match failed-login frame is picked, not thrown on', () {
    final outcome = FibsConnection.loginOutcome([
      FibsCookie.FIBS_FailedLogin,
      FibsCookie.FIBS_LoginPrompt, // the re-prompt that comes with a failure
    ]);
    expect(outcome, FibsCookie.FIBS_FailedLogin);
  });

  test('welcome wins over a re-prompt in the same frame', () {
    expect(
      FibsConnection.loginOutcome([
        FibsCookie.FIBS_LoginPrompt,
        FibsCookie.CLIP_WELCOME,
      ]),
      FibsCookie.CLIP_WELCOME,
    );
  });

  test('no outcome cookie -> null (keep waiting)', () {
    expect(FibsConnection.loginOutcome([FibsCookie.FIBS_Empty]), isNull);
  });
}

import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:test/test.dart';

void main() {
  // Regression: the sentcred handshake used found.single, which THREW when one
  // websocket frame carried several matching cookies (a failed login sends
  // bogus "** ..." lines plus a re-`login:` prompt). The throw escaped into the
  // stream callback, so the login completer never completed and the caller
  // waited out its 3s timeout reporting a bogus "unable to connect".
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

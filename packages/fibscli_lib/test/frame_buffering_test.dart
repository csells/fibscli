import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:test/test.dart';

int whoCount(List<CookieMessage> cms) =>
    cms.where((cm) => cm.cookie == FibsCookie.CLIP_WHO_INFO).length;

void main() {
  // Regression: _receive decided whether to buffer the incomplete trailing line
  // from the state at the START of the frame. A single frame can cross the
  // MOTD_END -> RUN transition, after which an incomplete who-list line must be
  // held for the next frame -- but buffering was still off, so the partial line
  // was mis-parsed and its continuation (arriving prefix-less next frame) lost.
  test('a who-line split across MOTD_END is buffered, not lost', () {
    final conn = FibsConnection('localhost', 8080);

    // Frame 1 (starting in MOTD): motd text, MOTD_END ('4'), one complete
    // who-line, then a SECOND who-line split by the frame boundary (no \n).
    final f1 = conn.receiveFrame(
      'some motd\n'
      '4\n'
      '5 alice - - 1 0 1500.00 0 0 0 host CLIENT a@x\n'
      '5 bob - - 1 0 1500.00 0 0 0 host CLIENT', // partial: missing email
      asState: CookieMonsterState.FIBS_MOTD_STATE,
    );
    expect(whoCount(f1), 1, reason: 'only the complete (alice) line so far');

    // Frame 2 completes bob's line.
    final f2 = conn.receiveFrame(' b@x\n');
    expect(
      whoCount(f2),
      1,
      reason: "bob's line completed and parsed, not lost",
    );
  });
}

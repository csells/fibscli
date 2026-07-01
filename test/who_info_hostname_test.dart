import 'package:fibscli/fibs_lobby.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Parse a real who-info line end-to-end so the test pins the exact crumb key
  // the parser emits (the CLIP who-info regex names its host group `hostName`).
  test('WhoInfo.from populates hostname from a parsed who-info line', () {
    final monster = CookieMonster()
      ..messageState = CookieMonsterState.FIBS_RUN_STATE;

    // fields: name opp watching ready away rating exp idle login host client
    final cm = monster.eatCookie(
      '5 BlunderBot_III - - 1 0 1500.00 100 5 1049300000 '
      'fibs.com ParlorBot bot@example.com',
    );
    expect(cm.cookie, FibsCookie.CLIP_WHO_INFO);

    final who = WhoInfo.from(cm);
    expect(who.hostname, 'fibs.com');
  });

  // The typed crumb boundary: a missing/mis-named required crumb now fails
  // LOUDLY with a MissingCrumbError naming the cookie+key at the parse
  // boundary, instead of a bare null-check crash (a TypeError) at a distant use
  // site -- the failure mode that let the hostName bug hide.
  test('a missing required crumb throws a clear MissingCrumbError', () {
    final cm = CookieMessage(
      FibsCookie.CLIP_WHO_INFO,
      'raw',
      {'name': 'bob'}, // deliberately missing the rest
      CookieMonsterState.FIBS_RUN_STATE,
    );
    expect(cm.crumb('name'), 'bob');
    expect(
      () => WhoInfo.from(cm),
      throwsA(
        isA<MissingCrumbError>().having(
          (e) => e.toString(),
          'message',
          contains('opponent'),
        ),
      ),
    );
  });
}

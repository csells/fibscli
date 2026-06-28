import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// Drive FibsState's resume support with scripted FIBS messages. Resuming saved
// matches matters for good citizenship (finish what you start) and for
// recovering when the telnet connection drops mid-game.
Future<FibsState> _loggedIn(FakeTransport fake) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  return fibs;
}

void main() {
  test(
    'login does not send junk commands (FIBS lists saved games itself)',
    () async {
      final fake = FakeTransport();
      await _loggedIn(fake);
      // FIBS auto-reports saved games at login; we must not invent a command
      expect(fake.sent, isNot(contains('show savedgames')));
    },
  );

  test('a saved-games listing populates savedMatches', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    // a `show savedgames` listing: "  opponent  score1  score2  - matchlength"
    fake.feed('  BlunderBot 0 0 - 1');
    fake.feed('  wildbg 2 1 - 5');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.savedMatches, containsAll(<String>['BlunderBot', 'wildbg']));
  });

  test('no saved games clears the list', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);
    fake.feed('  BlunderBot 0 0 - 1');
    fake.feed('no saved games');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.savedMatches, isEmpty);
  });

  test('resumeSavedMatch invites the opponent to reload the match', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);
    fibs.resumeSavedMatch('BlunderBot');
    expect(fake.sent, contains('invite BlunderBot'));
  });

  test('an opponent resume request is surfaced and join accepts it', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('BlunderBot wants to resume a saved match with you.');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.resumeRequestFrom, 'BlunderBot');

    fibs.joinGame();
    expect(fake.sent, contains('join'));
    expect(fibs.resumeRequestFrom, isNull);
  });

  test("a 'type join' prompt sets mustJoin until we join", () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed(
      "Type 'join' if you want to play the next game, type 'leave' "
      "if you don't.",
    );
    await Future<void>.delayed(Duration.zero);
    expect(fibs.mustJoin, isTrue);

    fibs.joinGame();
    expect(fibs.mustJoin, isFalse);
  });
}

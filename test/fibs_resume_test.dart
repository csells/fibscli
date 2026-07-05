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

String boardLine({String opponent = 'BlunderBot'}) =>
    'board:You:$opponent:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0'
    ':-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:1:6:3:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

WhoInfo _who(
  String user, {
  String opponent = '',
  bool ready = true,
  String client = 'ParlorBot',
}) => WhoInfo(
  user: user,
  opponent: opponent,
  watching: '',
  ready: ready,
  away: false,
  rating: 1500,
  experience: 1000,
  lastActive: DateTime(2020),
  lastLogin: DateTime(2020),
  hostname: '',
  client: client,
  email: '',
);

void main() {
  test(
    'login requests the saved-games list (FIBS does not volunteer it)',
    () async {
      final fake = FakeTransport();
      await _loggedIn(fake);
      // FIBS only lists saved games when asked; without this the lobby can't
      // ever offer to resume an unfinished match.
      expect(fake.sent, contains('show savedgames'));
    },
  );

  test('a saved-games listing populates savedMatches', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    // a `show savedgames` listing: "  opponent  score1  score2  - matchlength"
    fake.feed('  BlunderBot 0 0 - 1');
    fake.feed(' *wildbg 2 1 - 5');
    fake.feed('**ReadyBot 3 2 - 7');
    await Future<void>.delayed(Duration.zero);

    expect(
      fibs.savedMatches,
      containsAll(<String>['BlunderBot', 'wildbg', 'ReadyBot']),
    );
    expect(fibs.savedMatchInfos.first.opponent, 'ReadyBot');
    expect(
      fibs.savedMatchInfos.first.availability,
      SavedMatchAvailability.ready,
    );
    expect(fibs.savedMatchInfos.first.scoreLabel, '3-2 to 7');
  });

  test('no saved games clears the list', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);
    fake.feed('  BlunderBot 0 0 - 1');
    fake.feed('no saved games');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.savedMatches, isEmpty);
  });

  test(
    'active who-list games remain resumable after an empty saved list',
    () async {
      final fake = FakeTransport();
      final fibs = await _loggedIn(fake);

      fake.feed('**BlunderBot 0 0 - 1');
      fibs.lobby.upsert(_who('BlunderBot', opponent: 'joe_grammer'));
      fake.feed('no saved games');
      await Future<void>.delayed(Duration.zero);

      expect(fibs.savedMatches, contains('BlunderBot'));
      expect(
        fibs.savedMatchInfos.single.availability,
        SavedMatchAvailability.ready,
      );
    },
  );

  test('resumeSavedMatch invites the opponent to reload the match', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);
    fibs.resumeSavedMatch('BlunderBot');
    expect(fake.sent, contains('invite BlunderBot'));
    expect(fibs.resumePendingFor('BlunderBot'), isTrue);
  });

  test('resumeSavedMatch joins when the opponent has invited us', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('BlunderBot wants to resume a saved match with you.');
    await Future<void>.delayed(Duration.zero);

    fibs.resumeSavedMatch('BlunderBot');

    expect(fake.sent, contains('join BlunderBot'));
    expect(fake.sent, isNot(contains('invite BlunderBot')));
    expect(fibs.resumePendingFor('BlunderBot'), isTrue);
  });

  test('resumeSavedMatch still invites when the who-list says the '
      'opponent is playing us', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fibs.lobby.upsert(_who('BlunderBot', opponent: 'joe_grammer'));
    fibs.resumeSavedMatch('BlunderBot');

    expect(fake.sent, contains('invite BlunderBot'));
    expect(fake.sent, isNot(contains('join BlunderBot')));
    expect(fibs.resumePendingFor('BlunderBot'), isTrue);
  });

  test('a named join prompt caused by resumeSavedMatch is accepted', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('  BlunderBot 0 0 - 1');
    fibs.resumeSavedMatch('BlunderBot');
    fake.feed("Type 'join BlunderBot' to accept.");
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, contains('invite BlunderBot'));
    expect(fake.sent, contains('join BlunderBot'));
    expect(fibs.resumePendingFor('BlunderBot'), isTrue);
  });

  test('an unsolicited named join prompt waits for explicit resume', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('  BlunderBot 0 0 - 1');
    fake.feed("Type 'join BlunderBot' to accept.");
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, isNot(contains('join BlunderBot')));
    expect(
      fibs.savedMatchInfos.single.availability,
      SavedMatchAvailability.ready,
    );

    fibs.resumeSavedMatch('BlunderBot');

    expect(fake.sent, contains('join BlunderBot'));
    expect(fake.sent, isNot(contains('invite BlunderBot')));
  });

  test('already-playing-with-us replies clear resume pending', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('  BlunderBot 0 0 - 1');
    fibs.resumeSavedMatch('BlunderBot');
    fake.feed('** BlunderBot is already playing with joe_grammer.');
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, contains('invite BlunderBot'));
    expect(fake.sent, isNot(contains('board')));
    expect(fake.sent, isNot(contains('join BlunderBot')));
    expect(fibs.resumePendingFor('BlunderBot'), isFalse);
  });

  test(
    'already-playing-with-someone-else replies clear resume pending',
    () async {
      final fake = FakeTransport();
      final fibs = await _loggedIn(fake);

      fibs.resumeSavedMatch('BlunderBot');
      fake.feed('** BlunderBot is already playing with another_player.');
      await Future<void>.delayed(Duration.zero);

      expect(fake.sent, isNot(contains('join BlunderBot')));
      expect(fibs.resumePendingFor('BlunderBot'), isFalse);
    },
  );

  for (final entry in {
    'opponent joined':
        'BlunderBot has joined you. Your running match was loaded',
    'you are now playing':
        'You are now playing with BlunderBot. Your running match was loaded',
  }.entries) {
    test('a resume acknowledgement requests the board: ${entry.key}', () async {
      final fake = FakeTransport();
      final fibs = await _loggedIn(fake);

      fibs.resumeSavedMatch('BlunderBot');
      fake.feed(entry.value);
      await Future<void>.delayed(Duration.zero);

      expect(fake.sent, contains('invite BlunderBot'));
      expect(fake.sent, contains('board'));
      expect(fibs.resumePendingFor('BlunderBot'), isTrue);
    });
  }

  test('a resumed board clears the pending resume marker', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fibs.resumeSavedMatch('BlunderBot');
    expect(fibs.resumePendingFor('BlunderBot'), isTrue);

    fake.feed(boardLine());
    await Future<void>.delayed(Duration.zero);

    expect(fibs.resumePendingFor('BlunderBot'), isFalse);
  });

  test('a delayed resume reply clears the pending resume marker', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fibs.resumeSavedMatch('BlunderBot');
    fake.feed('12 BlunderBot I will not attempt to resume for 5 minutes.');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.resumePendingFor('BlunderBot'), isFalse);
    expect(fibs.resumeDelayFor('BlunderBot'), isNotNull);
  });

  test('a rejected resume reply clears the pending resume marker', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fibs.resumeSavedMatch('BlunderBot');
    fake.feed("** There's no saved match with BlunderBot.");
    await Future<void>.delayed(Duration.zero);

    expect(fibs.resumePendingFor('BlunderBot'), isFalse);
  });

  test('a not-playing resume reply clears the pending resume marker', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fibs.lobby.upsert(_who('BlunderBot', opponent: 'joe_grammer'));
    fibs.resumeSavedMatch('BlunderBot');
    fake.feed("** You're not playing.");
    await Future<void>.delayed(Duration.zero);

    expect(fibs.resumePendingFor('BlunderBot'), isFalse);
  });

  test('a resume-delay message is retained until the match loads', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('12 BlunderBot I will not attempt to resume for 5 minutes.');
    await Future<void>.delayed(Duration.zero);

    final delay = fibs.resumeDelayFor('BlunderBot');
    expect(delay, isNotNull);
    expect(delay!.minutes, 5);
    expect(
      delay.sentence,
      'BlunderBot will not attempt to resume for 5 minutes.',
    );

    fake.feed('BlunderBot has joined you. Your running match was loaded');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.resumeDelayFor('BlunderBot'), isNull);
  });

  test(
    'an unsolicited login board stays in the lobby as a saved match',
    () async {
      final fake = FakeTransport();
      final fibs = await _loggedIn(fake);

      fake.feed(boardLine());
      await Future<void>.delayed(Duration.zero);

      expect(fibs.board, isNull);
      expect(fibs.gameState, isNull);
      expect(fibs.savedMatches, contains('BlunderBot'));
      expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));
      expect(fake.sent.where((cmd) => cmd == 'show savedgames'), hasLength(2));

      fake.feed(boardLine());
      await Future<void>.delayed(Duration.zero);

      expect(fibs.board, isNull);
      expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));

      fake.feed(
        'You are now playing with BlunderBot. Your running match was loaded',
      );
      await Future<void>.delayed(Duration.zero);

      expect(fibs.board, isNull);
      expect(fibs.resumePendingFor('BlunderBot'), isFalse);
      expect(fake.sent, isNot(contains('board')));
      expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));
      expect(fake.sent.where((cmd) => cmd == 'show savedgames'), hasLength(2));

      fibs.resumeSavedMatch('BlunderBot');
      fake.feed(boardLine());
      await Future<void>.delayed(Duration.zero);

      expect(fibs.board, isNotNull);
      expect(fibs.board!.opponentNameFor(fibs.user), 'BlunderBot');
    },
  );

  for (final entry in {
    'opponent joined':
        'BlunderBot has joined you. Your running match was loaded',
    'you are now playing':
        'You are now playing with BlunderBot. Your running match was loaded',
  }.entries) {
    test(
      'a login-time resume acknowledgement stays in the lobby: ${entry.key}',
      () async {
        final fake = FakeTransport();
        final fibs = await _loggedIn(fake);

        fake.feed('**BlunderBot 0 0 - 1');
        fake.feed(entry.value);
        await Future<void>.delayed(Duration.zero);

        expect(fibs.board, isNull);
        expect(fibs.gameState, isNull);
        expect(fibs.savedMatches, contains('BlunderBot'));
        expect(fibs.resumePendingFor('BlunderBot'), isFalse);
        expect(fake.sent, isNot(contains('board')));
        expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));
        expect(
          fake.sent.where((cmd) => cmd == 'show savedgames'),
          hasLength(2),
        );

        fake.feed(boardLine());
        await Future<void>.delayed(Duration.zero);

        expect(fibs.board, isNull);
        expect(fibs.resumePendingFor('BlunderBot'), isFalse);
      },
    );
  }

  test('an opponent resume request waits for an explicit join', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed('BlunderBot wants to resume a saved match with you.');
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, isNot(contains('join')));
    expect(fibs.resumeRequestFrom, 'BlunderBot');
    expect(fibs.savedMatches, contains('BlunderBot'));
    expect(
      fibs.savedMatchInfos.single.availability,
      SavedMatchAvailability.ready,
    );

    fibs.joinGame();
    expect(fake.sent, contains('join'));
    expect(fibs.resumeRequestFrom, isNull);
  });

  test("a 'type join' prompt auto-joins the next game", () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);

    fake.feed(
      "Type 'join' if you want to play the next game, type 'leave' "
      "if you don't.",
    );
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent, contains('join'));
    expect(fibs.mustJoin, isFalse);
  });

  test('leaveGame saves locally and refreshes the saved-games list', () async {
    final fake = FakeTransport();
    final fibs = await _loggedIn(fake);
    fibs.resumeSavedMatch('BlunderBot');

    fake.feed(boardLine());
    await Future<void>.delayed(Duration.zero);

    fibs.leaveGame();

    expect(fake.sent, contains('leave'));
    expect(fake.sent.where((cmd) => cmd == 'show savedgames'), hasLength(2));
    expect(fake.sent, isNot(contains('resign n')));
    expect(fibs.savedMatches, contains('BlunderBot'));
    expect(fibs.board, isNull);

    fake.feed(boardLine());
    await Future<void>.delayed(Duration.zero);

    expect(
      fibs.board,
      isNull,
      reason: 'queued boards after leave stay ignored',
    );
    expect(fake.sent.where((cmd) => cmd == 'leave'), hasLength(1));
  });
}

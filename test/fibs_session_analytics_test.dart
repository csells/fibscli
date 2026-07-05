import 'package:fibscli/fibs_protocol.dart';
import 'package:fibscli/fibs_session.dart';
import 'package:fibscli/fibs_session_analytics.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

CookieMessage _cookie(String raw) {
  final monster = CookieMonster()
    ..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return monster.eatCookie(raw);
}

String _boardLine() =>
    'board:me:BlunderBot:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0'
    ':-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:1:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

FibsSession _playingSession() => const FibsProtocolState()
    .loggedInAs('me')
    .state
    .inviteBot('BlunderBot', matchLength: 1)
    .state
    .receiveBoard(_cookie(_boardLine()))
    .state
    .session;

void main() {
  test('session analytics reports playing and watching starts', () {
    final playing = fibsSessionAnalyticsEvents(
      before: const FibsSession(),
      after: _playingSession(),
    );
    final watching = fibsSessionAnalyticsEvents(
      before: const FibsSession(),
      after: _playingSession().copyWith(user: null),
    );

    expect(playing.single.name, 'app_fibs_game_start');
    expect(playing.single.screen, 'fibs_play');
    expect(playing.single.mode, 'playing');
    expect(watching.single.screen, 'fibs_watch');
    expect(watching.single.mode, 'watching');
  });

  test('session analytics reports a game result only once', () {
    final before = _playingSession();
    final after = before.copyWith(gameEnded: true, iWon: false);

    final first = fibsSessionAnalyticsEvents(before: before, after: after);
    final alreadyEnded = fibsSessionAnalyticsEvents(
      before: after,
      after: after,
    );

    expect(first.single.name, 'app_fibs_game_end');
    expect(first.single.screen, 'fibs_play');
    expect(first.single.result, 'loss');
    expect(alreadyEnded, isEmpty);
  });
}

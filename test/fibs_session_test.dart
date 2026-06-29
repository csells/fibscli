import 'package:fibscli/fibs_session.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

// our own game; player1 is the literal "You" (player1Color 1 == O). turn '1'
// is our turn, '-1' the opponent's. p1dice '0:0' => no dice yet.
String _boardLine({String p1dice = '0:0', String turn = '1'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

// run a single raw FIBS line through the cookie monster (RUN state) so we get a
// real CookieMessage with parsed crumbs, exactly like the live stream.
CookieMessage _cookie(String raw) {
  final monster = CookieMonster()
    ..messageState = CookieMonsterState.FIBS_RUN_STATE;
  return monster.eatCookie(raw);
}

// a synthetic cookie for the cookies whose raw FIBS format we don't replay here
CookieMessage _synthetic(FibsCookie cookie, Map<String, String> crumbs) =>
    CookieMessage(cookie, '', crumbs, CookieMonsterState.FIBS_RUN_STATE);

// the session as it is once we're logged in as "You" (player1 == "You")
const _loggedIn = FibsSession(user: 'joe');

void main() {
  group('FibsSession.reduce', () {
    test('a board cookie populates the derived game state', () {
      final s = _loggedIn.reduce(_cookie(_boardLine()));
      expect(s.board, isNotNull);
      expect(s.gameState, isNotNull);
      expect(s.isMyTurn, isTrue); // turn '1' == our turn
    });

    test('our turn with no dice => canRoll, not canMoveNow', () {
      final s = _loggedIn.reduce(_cookie(_boardLine()));
      expect(s.canRoll, isTrue);
      expect(s.canMoveNow, isFalse);
      expect(s.effectiveDice, isEmpty);
    });

    test('YouRoll captures our dice and enables a move', () {
      final s = _loggedIn
          .reduce(_cookie(_boardLine()))
          .reduce(_cookie('You roll 1 and 6'));
      expect(s.effectiveDice, [1, 6]);
      expect(s.canMoveNow, isTrue);
      expect(s.canRoll, isFalse);
    });

    test('YouRoll doubles produce four dice', () {
      final s = _loggedIn
          .reduce(_cookie(_boardLine()))
          .reduce(_cookie('You roll 3 and 3'));
      expect(s.effectiveDice, [3, 3, 3, 3]);
    });

    test('YouRoll reconciles the turn when the board shows the opponent', () {
      // the last board still says it's the opponent's turn (turn '-1'), but a
      // YouRoll proves it's ours -- the session must flip the turn to us so the
      // move generator plays OUR checkers, not the opponent's.
      final s = _loggedIn
          .reduce(_cookie(_boardLine(turn: '-1')))
          .reduce(_cookie('You roll 5 and 2'));
      expect(s.isMyTurn, isTrue);
      expect(s.canMoveNow, isTrue);
    });

    test('a fresh board clears stale rolled dice (must roll again)', () {
      // after rolling, a brand-new "our turn, no dice" board is authoritative:
      // the captured dice must be dropped or we'd try to move without rolling.
      final s = _loggedIn
          .reduce(_cookie(_boardLine()))
          .reduce(_cookie('You roll 6 and 4'))
          .reduce(_cookie(_boardLine())); // fresh no-dice board
      expect(s.myDice, isEmpty);
      expect(s.canRoll, isTrue);
      expect(s.canMoveNow, isFalse);
    });

    test('AcceptRejectDouble sets doubleOffered; a board clears it', () {
      final offered = _loggedIn.reduce(
        _synthetic(FibsCookie.FIBS_AcceptRejectDouble, {'raw': 'x'}),
      );
      expect(offered.doubleOffered, isTrue);
      final cleared = offered.reduce(_cookie(_boardLine()));
      expect(cleared.doubleOffered, isFalse);
    });

    test(
      'saved matches accumulate, resume-ack removes, NoSavedGames clears',
      () {
        final withTwo = _loggedIn
            .reduce(_synthetic(FibsCookie.FIBS_SavedMatch, {'player1': 'botA'}))
            .reduce(
              _synthetic(FibsCookie.FIBS_SavedMatch, {'player1': 'botB'}),
            );
        expect(withTwo.savedMatches, {'botA', 'botB'});

        final resumed = withTwo.reduce(
          _synthetic(FibsCookie.FIBS_ResumeMatchAck0, {'opponent': 'botA'}),
        );
        expect(resumed.savedMatches, {'botB'});

        final none = resumed.reduce(
          _synthetic(FibsCookie.FIBS_NoSavedGames, {'raw': 'x'}),
        );
        expect(none.savedMatches, isEmpty);
      },
    );

    test(
      'resume request + join prompt set their flags; a board clears them',
      () {
        final pending = _loggedIn
            .reduce(
              _synthetic(FibsCookie.FIBS_ResumeMatchRequest, {'name': 'bot'}),
            )
            .reduce(_synthetic(FibsCookie.FIBS_JoinNextGame, {'raw': 'x'}));
        expect(pending.resumeRequestFrom, 'bot');
        expect(pending.mustJoin, isTrue);

        final inGame = pending.reduce(_cookie(_boardLine()));
        expect(inGame.resumeRequestFrom, isNull);
        expect(inGame.mustJoin, isFalse);
      },
    );

    test('an unhandled cookie leaves the session unchanged', () {
      final s = _loggedIn.reduce(_cookie(_boardLine()));
      expect(identical(s.reduce(_cookie('5 some unhandled line')), s), isTrue);
    });
  });
}

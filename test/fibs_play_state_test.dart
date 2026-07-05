import 'package:fibscli/fibs_play.dart';
import 'package:fibscli/fibs_protocol.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game; player1 is the literal "You" (player1Color 1 == O). turn '1'
// is our turn, '-1' the opponent's. p1dice '0:0' => no dice yet.
String boardLine({
  String p1dice = '0:0',
  String turn = '1',
  String player1MayDouble = '1',
}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:$player1MayDouble:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

const rollOrDoubleLine = "It's your turn to roll or double.";

Future<FibsState> _inGame(
  FakeTransport fake, {
  String p1dice = '0:0',
  String turn = '1',
  String player1MayDouble = '1',
  bool promptRoll = false,
}) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fibs.resumeSavedMatch('wildbg');
  fake.feed(
    boardLine(p1dice: p1dice, turn: turn, player1MayDouble: player1MayDouble),
  );
  if (promptRoll) fake.feed(rollOrDoubleLine);
  await Future<void>.delayed(Duration.zero);
  return fibs;
}

// a finished game: player1 ("You" = X) has borne off all 15, turnColor 0.
String gameOverLine({int xOff = 15, int oOff = 0}) => [
  'board', 'You', 'bot', '1', '0', '0',
  List.filled(26, 0).join(':'),
  '0', // turnColor 0 = game over
  '0:0', '0:0', '1', '1', '1', '0',
  '-1', '-1', '0', '25',
  '$xOff', '$oOff', '0', '0', '0', '0', '0', '0',
].join(':');

void main() {
  test(
    'a game-over board surfaces the result; returnToLobby clears it',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake); // in a game
      fake.feed(gameOverLine(xOff: 15)); // we (You=X) bore off all 15
      await Future<void>.delayed(Duration.zero);

      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isTrue);
      expect(fibs.gameState, isNotNull); // still showing the final board

      fibs.returnToLobby();
      expect(fibs.gameState, isNull); // back to the lobby
      expect(fibs.isGameOver, isFalse);
    },
  );

  test('a game the opponent won reports didIWin false', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed(gameOverLine(xOff: 0, oOff: 15)); // opponent (O) bore off all 15
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isGameOver, isTrue);
    expect(fibs.didIWin, isFalse);
  });

  // FIBS announces the result as a text message, not a 15-off board.
  test('a "you win the game" message ends the game (we won)', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed('You win the game and get 1 point.');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isGameOver, isTrue);
    expect(fibs.didIWin, isTrue);
  });

  test(
    'a "player wins the game" message ends the game (opponent won)',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake);
      fake.feed('MonteCarlo wins the game and gets 1 point. Sorry.');
      await Future<void>.delayed(Duration.zero);

      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isFalse);
    },
  );

  test(
    'resigning (opponent accepts and wins) ends the game as a loss',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake);
      fake.feed('MonteCarlo accepts and wins 1 point.');
      await Future<void>.delayed(Duration.zero);

      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isFalse);
    },
  );

  test('the opponent resigning (we win) ends the game as a win', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed('MonteCarlo gives up. You win 1 points.');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isGameOver, isTrue);
    expect(fibs.didIWin, isTrue);
  });

  test('winning the match ends the game as a win', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed('You win the 1 point match 1-0 .');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isGameOver, isTrue);
    expect(fibs.didIWin, isTrue);
    expect(fibs.gameResultMessage, 'You win the 1 point match 1-0.');
  });

  test('losing the match ends the game as a loss', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed('MonteCarlo wins the 1 point match 1-0 .');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isGameOver, isTrue);
    expect(fibs.didIWin, isFalse);
    expect(fibs.gameResultMessage, 'MonteCarlo wins the 1 point match 1-0.');
  });

  test('a watched game finishing drops back to the lobby', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    expect(fibs.gameState, isNotNull);

    // no ". Sorry" -> a WatchGameWins line (we were spectating)
    fake.feed('BlunderBot wins the game and gets 1 points.');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.gameState, isNull); // dropped to the lobby
  });

  test('the next game board clears a prior result (mid-match)', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fake.feed('You win the game and get 1 point.');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.isGameOver, isTrue);

    fake.feed(boardLine(turn: '1')); // the next game's in-progress board
    await Future<void>.delayed(Duration.zero);
    expect(fibs.isGameOver, isFalse); // result cleared -> back to play
    expect(fibs.gameResultMessage, isNull);
  });

  test('turn text reconciles the board and requests a fresh board', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, turn: '-1');

    fake.feed('turn: joe_grammer.');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isMyTurn, isTrue);
    expect(fibs.canMoveNow, isFalse);
    expect(fibs.canRoll, isFalse);
    expect(fake.sent.last, 'board');
  });

  test('an "already logged in" warning surfaces a notice', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fibs.messages.clear();

    // this warning arrives during the login handshake (login state)
    fake.feed(
      '** Warning: You are already logged in.',
      state: CookieMonsterState.FIBS_LOGIN_STATE,
    );
    await Future<void>.delayed(Duration.zero);

    expect(fibs.messages.last.message, contains('already logged in'));
  });

  test('an unexpected connection drop surfaces a notice', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    expect(fibs.messages, isEmpty);

    fake.feedError(StateError('socket reset')); // server kick / network loss
    await Future<void>.delayed(Duration.zero);

    expect(fibs.messages.length, 1);
    expect(fibs.messages.last.message, contains('connection'));
    expect(fibs.gameState, isNull); // the session was reset
  });

  test('a deliberate logout surfaces no connection notice', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    await fibs.logout();
    expect(fibs.messages, isEmpty); // logout is expected, not a drop
  });

  test('an unexpected drop auto-reconnects once via the hook', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    var reconnects = 0;
    fibs.onReconnect = () async => reconnects++;

    fake.feedError(StateError('drop')); // unexpected
    await Future<void>.delayed(Duration.zero);

    expect(reconnects, 1);
    expect(fibs.messages.last.message, contains('Reconnecting'));
  });

  test('a reconnect that also drops does not loop', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    var reconnects = 0;
    // the hook here doesn't re-login (never reaches CLIP_WELCOME), so the guard
    // stays spent -- a second drop must NOT trigger another reconnect
    fibs.onReconnect = () async => reconnects++;

    fake.feedError(StateError('drop 1'));
    await Future<void>.delayed(Duration.zero);
    fake.feedError(StateError('drop 2'));
    await Future<void>.delayed(Duration.zero);

    expect(reconnects, 1, reason: 'one reconnect per established session');
    expect(fibs.messages.last.message, contains('log in again'));
  });

  test('a no-dice board does not allow roll until FIBS prompts', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake); // our turn, no dice
    expect(fibs.canRoll, isFalse);
    expect(fibs.canMoveNow, isFalse);

    fake.feed(rollOrDoubleLine);
    await Future<void>.delayed(Duration.zero);
    expect(fibs.canRoll, isTrue);
  });

  test('a move prompt without known dice requests a fresh board', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, turn: '-1');
    expect(fibs.canMoveNow, isFalse);

    fake.feed("It's your turn to move.");
    await Future<void>.delayed(Duration.zero);

    expect(fibs.isMyTurn, isTrue);
    expect(fibs.canMoveNow, isFalse);
    expect(fake.sent.where((cmd) => cmd == 'board'), hasLength(1));
  });

  test('opponent move text requests a fresh board', () async {
    final fake = FakeTransport();
    await _inGame(fake, turn: '-1');

    fake.feed('wildbg moves 19-23 19-23 .');
    await Future<void>.delayed(Duration.zero);

    expect(fake.sent.where((cmd) => cmd == 'board'), hasLength(1));
  });

  test('a local dance disables the turn and requests a fresh board', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true);
    fibs.roll();
    fake.feed('You roll 6 and 4');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.canMoveNow, isTrue);

    fake.feed("You can't move.");
    await Future<void>.delayed(Duration.zero);

    expect(fibs.canMoveNow, isFalse);
    expect(fake.sent.where((cmd) => cmd == 'board'), hasLength(1));
  });

  test('double is available only when the board permits it', () async {
    final allowed = FakeTransport();
    final fibsAllowed = await _inGame(allowed, promptRoll: true);
    expect(fibsAllowed.canRoll, isTrue);
    expect(fibsAllowed.canOfferDouble, isTrue);

    final forbidden = FakeTransport();
    final fibsForbidden = await _inGame(
      forbidden,
      player1MayDouble: '0',
      promptRoll: true,
    );
    expect(fibsForbidden.canRoll, isTrue);
    expect(fibsForbidden.canOfferDouble, isFalse);
    expect(fibsForbidden.offerDouble, throwsA(isA<FibsStateError>()));
  });

  test('after roll, canRoll is false and a second roll throws', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true); // our turn, no dice
    expect(fibs.canRoll, isTrue);

    fibs.roll();
    expect(fake.sent, contains('roll'));
    // FIBS has moreboards off and won't echo a board; canRoll must flip off
    // immediately so we don't roll again
    expect(fibs.canRoll, isFalse);
    expect(fibs.roll, throwsA(isA<FibsStateError>()));
  });

  test('a refresh board after we roll does not let us roll again', () async {
    // FIBS may resend an "our turn, no dice" board while we await YouRoll; it
    // must not reset _rolling, or we'd roll a second time ("already rolled").
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true); // our turn, no dice
    fibs.roll();
    expect(fibs.canRoll, isFalse);

    fake.feed(boardLine(turn: '1')); // same state, still no dice
    await Future<void>.delayed(Duration.zero);
    expect(fibs.canRoll, isFalse); // still awaiting our dice -> no second roll
    expect(fibs.roll, throwsA(isA<FibsStateError>()));
  });

  test('our dice arriving (FIBS_YouRoll) enables exactly one move', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true);
    fibs.roll();
    fake.feed('You roll 1 and 6');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.canRoll, isFalse);
    expect(fibs.canMoveNow, isTrue);

    // the caller (here standing in for FibsBotPlayer) picks the turn...
    final cmd = FibsPlay.bestTurnCommand(fibs.board!, dice: fibs.activeDice);
    expect(cmd, isNotNull);
    // ...and hands the command to FibsState to send + commit
    fibs.commitTurnCommand(cmd!);
    // committing the whole turn flips canMoveNow off until the next board, so a
    // second move can't be sent into a turn we already played
    expect(fibs.canMoveNow, isFalse);
    expect(
      () => fibs.commitTurnCommand('move 1-2'),
      throwsA(isA<FibsStateError>()),
    );
  });

  test('submitTurn sends the whole turn at once and commits', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true);
    fibs.roll();
    fake.feed('You roll 4 and 2');
    await Future<void>.delayed(Duration.zero);
    expect(fibs.canMoveNow, isTrue);

    // the moves the player built locally on the shared board (viewer pips)
    fibs.submitTurn([
      GammonMove(fromPipNo: 8, toPipNo: 4, hops: const [-4]),
      GammonMove(fromPipNo: 6, toPipNo: 4, hops: const [-2]),
    ]);
    expect(fake.sent, contains('move 8-4 6-4')); // one command, whole turn
    // committing flips canMoveNow off until the next board
    expect(fibs.canMoveNow, isFalse);
  });

  test(
    'a rejected move is surfaced and makes the turn editable again',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake, promptRoll: true);
      fibs.roll();
      fake.feed('You roll 4 and 2');
      await Future<void>.delayed(Duration.zero);

      fibs.submitTurn([
        GammonMove(fromPipNo: 8, toPipNo: 4, hops: const [-4]),
      ]);
      expect(fibs.canMoveNow, isFalse);

      fake.feed('** You must give 2 moves.');
      await Future<void>.delayed(Duration.zero);

      expect(fibs.canMoveNow, isTrue);
      expect(fibs.lastCommandRejected, isTrue);
      expect(fibs.messages.last.from, 'FIBS');
      expect(fibs.messages.last.message, 'You must give 2 moves.');
    },
  );

  test('protocol signals are transition-scoped, not sticky', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true);
    fibs.roll();
    fake.feed('You roll 4 and 2');
    await Future<void>.delayed(Duration.zero);

    fibs.submitTurn([
      GammonMove(fromPipNo: 8, toPipNo: 4, hops: const [-4]),
    ]);
    fake.feed('** You must give 2 moves.');
    await Future<void>.delayed(Duration.zero);
    expect(
      fibs.lastProtocolSignals,
      contains(FibsProtocolSignal.commandRejected),
    );

    fake.feed("** You're not playing.");
    await Future<void>.delayed(Duration.zero);

    expect(fibs.lastProtocolSignals, isEmpty);
    expect(fibs.lastCommandRejected, isFalse);
  });

  test(
    'a fresh our-turn board clears stale rolled dice (must roll again)',
    () async {
      // FIBS often reports the opponent's play as text then jumps straight to
      // our next roll board with NO opponent-turn board in between. The board
      // is authoritative: stale dice from our last turn must be dropped, or
      // we'd try to move ("you have to roll the dice before moving").
      final fake = FakeTransport();
      final fibs = await _inGame(fake, promptRoll: true); // our turn, no dice
      fibs.roll();
      fake.feed('You roll 6 and 4');
      await Future<void>.delayed(Duration.zero);
      fibs.commitTurnCommand(
        FibsPlay.bestTurnCommand(fibs.board!, dice: fibs.activeDice)!,
      );
      expect(fibs.canMoveNow, isFalse); // committed

      // our next turn arrives as a fresh board with no dice
      fake.feed(boardLine(turn: '1'));
      await Future<void>.delayed(Duration.zero);
      expect(fibs.canMoveNow, isFalse); // stale 6,4 dropped -> nothing to move
      expect(fibs.canRoll, isFalse); // waiting for FIBS to prompt

      fake.feed(rollOrDoubleLine);
      await Future<void>.delayed(Duration.zero);
      expect(fibs.canRoll, isTrue); // we must roll fresh
    },
  );

  test('a YouRoll with no fresh board still makes it our turn', () async {
    // FIBS auto-rolls for us after the opponent dances and sends YouRoll
    // WITHOUT a board, leaving the last board showing the opponent on roll.
    final fake = FakeTransport();
    final fibs = await _inGame(fake, turn: '-1'); // board says opponent's turn
    expect(fibs.isMyTurn, isFalse);
    expect(fibs.canMoveNow, isFalse);

    fake.feed('You roll 3 and 1'); // our dice arrive, but no new board
    await Future<void>.delayed(Duration.zero);

    // the roll proves it's our turn: we must be able to move OUR checkers
    expect(fibs.isMyTurn, isTrue);
    expect(fibs.canMoveNow, isTrue);
    final cmd = FibsPlay.bestTurnCommand(fibs.board!, dice: fibs.activeDice);
    expect(cmd, isNotNull);
    fibs.commitTurnCommand(cmd!);
    expect(fibs.canMoveNow, isFalse);
  });

  test(
    'submitting when it is not our turn throws (loud, not a silent no-op)',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake); // our turn but no dice -> can't move
      expect(fibs.canMoveNow, isFalse);
      expect(() => fibs.submitTurn(const []), throwsA(isA<FibsStateError>()));
    },
  );

  test('accepting a double that was never offered throws', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    expect(fibs.acceptDouble, throwsA(isA<FibsStateError>()));
    expect(fibs.rejectDouble, throwsA(isA<FibsStateError>()));
  });

  test('rolled dice (no board carrying them) are visible to the UI', () async {
    // FIBS auto-rolls and sends "You roll 4 and 2" with no fresh board -- the
    // dice must still show in the status (activeDice) AND in the rendered game
    // state (ReadOnlyBoardView renders gameState.dice).
    final fake = FakeTransport();
    final fibs = await _inGame(fake, promptRoll: true); // our turn, no dice
    fibs.roll();
    fake.feed('You roll 4 and 2');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.activeDice, [4, 2]);
    expect(fibs.gameState!.dice.map((d) => d.roll).toList(), [4, 2]);
  });
}

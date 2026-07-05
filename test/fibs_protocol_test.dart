import 'package:fibscli/fibs_protocol.dart';
import 'package:fibscli/fibs_session.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

CookieMessage _cookie(
  String raw, {
  CookieMonsterState state = CookieMonsterState.FIBS_RUN_STATE,
}) {
  final monster = CookieMonster()..messageState = state;
  return monster.eatCookie(raw);
}

CookieMessage _ownInfo({String doublePrompt = '1', String moreboards = '1'}) =>
    _cookie(
      '2 me 1 1 0 0 0 0 1 $doublePrompt 2396 0 $moreboards 0 1 '
      '1500.00 0 0 0 0 0 UTC',
      state: CookieMonsterState.FIBS_LOGIN_STATE,
    );

String _boardLine({
  String player1 = 'me',
  String player2 = 'BlunderBot',
  String turn = '1',
}) =>
    'board:$player1:$player2:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0'
    ':-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

FibsProtocolState _admittedGame({String turn = '1'}) =>
    const FibsProtocolState()
        .loggedInAs('me')
        .state
        .inviteBot('BlunderBot', matchLength: 1)
        .state
        .receiveBoard(_cookie(_boardLine(turn: turn)))
        .state;

void main() {
  test('login transition enters discovery and emits setup commands', () {
    final transition = const FibsProtocolState().loggedInAs('me');

    expect(transition.state.session.user, 'me');
    expect(transition.commands, ['set boardstyle 3', 'who', 'show savedgames']);
  });

  test('login discovery parks an unsolicited board in the lobby', () {
    final loggedIn = const FibsProtocolState().loggedInAs('me').state;

    final transition = loggedIn.receiveBoard(_cookie(_boardLine()));

    expect(transition.state.session.board, isNull);
    expect(transition.state.session.savedMatches, contains('BlunderBot'));
    expect(transition.commands, ['leave', 'show savedgames']);
  });

  test('explicit resume acknowledgement asks FIBS for the board', () {
    final loggedIn = const FibsProtocolState().loggedInAs('me').state;
    final resuming = loggedIn.resumeSavedMatch('BlunderBot').state;

    final transition = resuming.receiveResumeMatchAccepted(
      _cookie('BlunderBot has joined you. Your running match was loaded'),
    );

    expect(transition.state.session.savedMatches, contains('BlunderBot'));
    expect(transition.state.resume.pendingFor('BlunderBot'), isTrue);
    expect(transition.commands, ['board']);
  });

  test('join-next-game prompt emits one bare join command', () {
    final state = FibsProtocolState(
      session: const FibsSession(user: 'me').withSavedOpponent('BlunderBot'),
    );

    final transition = state.applyAndAutoJoin(
      _cookie(
        "Type 'join' if you want to play the next game, "
        "type 'leave' if you don't.",
      ),
    );

    expect(transition.state.session.mustJoin, isFalse);
    expect(transition.commands, ['join']);
  });

  test('resume request uses join while ordinary saved resume uses invite', () {
    final saved = FibsProtocolState(
      session: const FibsSession(user: 'me').withSavedOpponent('BlunderBot'),
    );
    expect(saved.resumeSavedMatch('BlunderBot').commands, [
      'invite BlunderBot',
    ]);

    final requested = saved.receiveResumeMatchRequest(
      _cookie('BlunderBot wants to resume a saved match with you.'),
    );
    expect(requested.state.resumeSavedMatch('BlunderBot').commands, [
      'join BlunderBot',
    ]);
  });

  test('active saved-match resume requests the current board', () {
    final saved = FibsProtocolState(
      session: const FibsSession(user: 'me').withSavedOpponent('BlunderBot'),
    );

    final transition = saved.resumeActiveMatch('BlunderBot');

    expect(transition.commands, ['board']);
    expect(transition.state.resume.pendingFor('BlunderBot'), isTrue);
    expect(transition.state.session.mustJoin, isFalse);
  });

  test('turn text requests a board when turn state is incomplete', () {
    final inGame = _admittedGame(turn: '-1');

    final transition = inGame.receiveTurnText(_cookie('turn: me.'));

    expect(transition.state.session.isMyTurn, isTrue);
    expect(transition.state.session.canRoll, isFalse);
    expect(transition.state.session.canMoveNow, isFalse);
    expect(transition.commands, ['board']);
  });

  test('move prompt requests a board when dice are still unknown', () {
    final inGame = _admittedGame(turn: '-1');

    final transition = inGame.receiveMovePrompt(
      _cookie("It's your turn to move."),
    );

    expect(transition.state.session.isMyTurn, isTrue);
    expect(transition.state.session.canMoveNow, isFalse);
    expect(transition.commands, ['board']);
  });

  test('opponent move text requests a board refresh while in a game', () {
    final inGame = _admittedGame(turn: '-1');

    final transition = inGame.receiveBoardRefreshText(
      _cookie('BlunderBot moves 13-8 6-5'),
    );

    expect(transition.state.session.board, isNotNull);
    expect(transition.commands, ['board']);
  });

  test('cant-move text updates session and requests a board refresh', () {
    final inGame = _admittedGame().receiveTurnText(_cookie('turn: me.')).state;

    final transition = inGame.receiveCantMoveText(_cookie("me can't move."));

    expect(transition.state.session.committedTurn, isTrue);
    expect(transition.commands, ['board']);
  });

  test('own-info turns on the double prompt once when it is off', () {
    final state = const FibsProtocolState().loggedInAs('me').state;

    final first = state.receiveOwnInfo(_ownInfo(doublePrompt: '0'));
    final second = first.state.receiveOwnInfo(_ownInfo(doublePrompt: '0'));

    expect(first.commands, ['toggle double']);
    expect(second.commands, isEmpty);
  });

  test('own-info turns on moreboards once when it is off', () {
    final state = const FibsProtocolState().loggedInAs('me').state;

    final first = state.receiveOwnInfo(_ownInfo(moreboards: '0'));
    final second = first.state.receiveOwnInfo(_ownInfo(moreboards: '0'));

    expect(first.commands, ['toggle moreboards']);
    expect(second.commands, isEmpty);
  });

  test('own-info resets toggle guards when settings are on again', () {
    final state = const FibsProtocolState().loggedInAs('me').state;

    final toggled = state.receiveOwnInfo(
      _ownInfo(doublePrompt: '0', moreboards: '0'),
    );
    final reset = toggled.state.receiveOwnInfo(_ownInfo());
    final offAgain = reset.state.receiveOwnInfo(
      _ownInfo(doublePrompt: '0', moreboards: '0'),
    );

    expect(toggled.commands, ['toggle double', 'toggle moreboards']);
    expect(reset.commands, isEmpty);
    expect(offAgain.commands, ['toggle double', 'toggle moreboards']);
  });

  test('resume-delay chat clears pending resume and records delay', () {
    final state = const FibsProtocolState()
        .loggedInAs('me')
        .state
        .resumeSavedMatch('BlunderBot')
        .state;

    final transition = state.receiveChatMessage(
      _cookie('12 BlunderBot I will not attempt to resume for 5 minutes.'),
    );

    expect(transition.commands, isEmpty);
    expect(transition.state.resume.pendingFor('BlunderBot'), isFalse);
    final delay = transition.state.resume.delayFor('BlunderBot');
    expect(delay, isNotNull);
    expect(delay!.minutes, 5);
  });

  test('explicit protocol commands do not require raw send escape hatches', () {
    const state = FibsProtocolState();

    expect(state.refreshWhoList().commands, ['who']);
    expect(state.inviteBotByName('BlunderBot', matchLength: 1).commands, [
      'invite BlunderBot 1',
    ]);
    expect(state.resignNormalLoss().commands, ['resign n']);
    expect(state.courtesyDisconnect().commands, ['bye']);
  });

  test('prebuilt turn commands only accept FIBS move commands', () {
    const state = FibsProtocolState();
    final canMove = _admittedGame()
        .receive(_cookie("It's your turn to roll or double."))
        .state
        .startRoll()
        .state
        .receive(_cookie('You roll 1 and 6'))
        .state;

    final transition = canMove.commitTurnCommand('move 8-4 bar-22 2-off');

    expect(transition.state.session.committedTurn, isTrue);
    expect(transition.commands, ['move 8-4 bar-22 2-off']);
    expect(() => state.commitTurnCommand('who'), throwsArgumentError);
    expect(
      () => state.commitTurnCommand('invite BlunderBot'),
      throwsArgumentError,
    );
  });

  test('protocol rejects illegal player intents before sending commands', () {
    const state = FibsProtocolState();

    expect(state.startRoll, throwsA(isA<FibsProtocolError>()));
    expect(() => state.submitTurn(const []), throwsA(isA<FibsProtocolError>()));
    expect(
      () => state.commitTurnCommand('move 8-4'),
      throwsA(isA<FibsProtocolError>()),
    );
    expect(state.offerDouble, throwsA(isA<FibsProtocolError>()));
    expect(state.acceptDouble, throwsA(isA<FibsProtocolError>()));
    expect(state.rejectDouble, throwsA(isA<FibsProtocolError>()));
  });

  test('protocol allows legal roll, move, and cube intents', () {
    final canRoll = _admittedGame()
        .receive(_cookie("It's your turn to roll or double."))
        .state;
    final canMove = canRoll
        .startRoll()
        .state
        .receive(_cookie('You roll 1 and 6'))
        .state;
    final doubled = canRoll
        .receive(_cookie("BlunderBot doubles. Type 'accept' or 'reject'."))
        .state;

    expect(canRoll.startRoll().commands, ['roll']);
    expect(canRoll.offerDouble().commands, ['double']);
    expect(canMove.submitTurn(const []).commands, isEmpty);
    expect(canMove.commitTurnCommand('move 8-4').commands, ['move 8-4']);
    expect(doubled.acceptDouble().commands, ['accept']);
    expect(doubled.rejectDouble().commands, ['reject']);
  });

  test('generic receive parks login-discovery boards', () {
    final loggedIn = const FibsProtocolState().loggedInAs('me').state;

    final transition = loggedIn.receive(_cookie(_boardLine()));

    expect(transition.state.session.board, isNull);
    expect(transition.state.session.savedMatches, contains('BlunderBot'));
    expect(transition.commands, ['leave', 'show savedgames']);
  });

  test('generic receive routes turn prompts and settings', () {
    final inGame = _admittedGame(turn: '-1');

    final turn = inGame.receive(_cookie('turn: me.'));
    final settings = turn.state.receive(_ownInfo(doublePrompt: '0'));

    expect(turn.state.session.isMyTurn, isTrue);
    expect(turn.commands, ['board']);
    expect(settings.commands, ['toggle double']);
  });

  test('generic receive routes command rejections through session state', () {
    final inGame = _admittedGame()
        .receive(_cookie("It's your turn to roll or double."))
        .state
        .startRoll()
        .state;

    final transition = inGame.receive(_cookie('** You must give 2 moves.'));

    expect(transition.commands, isEmpty);
    expect(transition.state.session.rolling, isFalse);
  });

  test('generic receive routes resume rejections through resume state', () {
    final state = const FibsProtocolState()
        .loggedInAs('me')
        .state
        .resumeSavedMatch('BlunderBot')
        .state;

    final transition = state.receive(_cookie("** You're not playing."));

    expect(transition.state.resume.pendingFor('BlunderBot'), isFalse);
    expect(transition.commands, isEmpty);
  });

  test('protocol transitions expose typed play signals', () {
    final inGame = _admittedGame();

    expect(
      inGame.receive(_cookie(_boardLine())).signals,
      contains(FibsProtocolSignal.boardFrame),
    );
    expect(
      inGame.receive(_cookie('BlunderBot rolls 4 and 4')).signals,
      contains(FibsProtocolSignal.opponentRolled),
    );
    expect(
      inGame.receive(_cookie('** You must give 2 moves.')).signals,
      contains(FibsProtocolSignal.commandRejected),
    );
  });

  test('protocol transitions expose user-visible messages', () {
    final state = const FibsProtocolState()
        .loggedInAs('me')
        .state
        .resumeSavedMatch('BlunderBot')
        .state;

    final chat = state.receive(
      _cookie('12 BlunderBot I will not attempt to resume for 5 minutes.'),
    );
    final rejected = state.receive(_cookie('** You must give 2 moves.'));
    final system = state.receive(_cookie("** You're not playing."));
    final saved = _admittedGame().receive(
      _cookie('BlunderBot logs out. The game was saved.'),
    );

    expect(chat.messages.single.from, 'BlunderBot');
    expect(
      chat.messages.single.text,
      'I will not attempt to resume for 5 minutes.',
    );
    expect(rejected.messages.single.from, 'FIBS');
    expect(rejected.messages.single.text, 'You must give 2 moves.');
    expect(system.messages.single.from, 'FIBS');
    expect(system.messages.single.text, "You're not playing.");
    expect(saved.messages.single.from, 'FIBS');
    expect(
      saved.messages.single.text,
      'BlunderBot logs out. The game was saved.',
    );
  });

  test('protocol transitions own session-tracking boundaries', () {
    final inGame = _admittedGame();
    final state = const FibsProtocolState().loggedInAs('me').state;

    expect(
      inGame.receive(_cookie(_boardLine())).trackSessionTransition,
      isTrue,
    );
    expect(state.receive(_ownInfo()).trackSessionTransition, isFalse);
    expect(
      state
          .receive(_cookie('12 BlunderBot hello there.'))
          .trackSessionTransition,
      isFalse,
    );
    expect(
      inGame
          .receive(_cookie('** You must give 2 moves.'))
          .trackSessionTransition,
      isFalse,
    );
    expect(
      inGame
          .receive(_cookie('BlunderBot logs out. The game was saved.'))
          .trackSessionTransition,
      isFalse,
    );
  });

  test('match result cookies expose a typed match result', () {
    final inGame = _admittedGame();

    final win = inGame.receive(_cookie('You win the 1 point match 1-0 .'));
    final loss = inGame.receive(
      _cookie('BlunderBot wins the 1 point match 1-0 .'),
    );

    expect(win.matchResult, isNotNull);
    expect(win.matchResult!.didIWin, isTrue);
    expect(win.matchResult!.message, 'You win the 1 point match 1-0.');
    expect(loss.matchResult, isNotNull);
    expect(loss.matchResult!.didIWin, isFalse);
    expect(loss.matchResult!.message, 'BlunderBot wins the 1 point match 1-0.');
  });

  test(
    'watched game finish clears the board and suppresses trailing boards',
    () {
      final watching = const FibsProtocolState()
          .loggedInAs('me')
          .state
          .watch('BlunderBot')
          .state
          .receiveBoard(
            _cookie(_boardLine(player1: 'Alice', player2: 'BlunderBot')),
          )
          .state;

      final finished = watching.receive(
        _cookie('BlunderBot wins the game and gets 1 points.'),
      );
      final trailingBoard = finished.state.receiveBoard(
        _cookie(_boardLine(player1: 'Alice', player2: 'BlunderBot')),
      );

      expect(finished.state.session.board, isNull);
      expect(finished.commands, isEmpty);
      expect(trailingBoard.state.session.board, isNull);
      expect(trailingBoard.commands, isEmpty);
    },
  );

  test('opponent logout saves the match and suppresses trailing boards', () {
    final inGame = _admittedGame();

    final saved = inGame.receive(
      _cookie('BlunderBot logs out. The game was saved.'),
    );
    final trailingBoard = saved.state.receiveBoard(_cookie(_boardLine()));

    expect(saved.state.session.board, isNull);
    expect(saved.state.session.savedMatches, contains('BlunderBot'));
    expect(saved.commands, ['show savedgames']);
    expect(trailingBoard.state.session.board, isNull);
  });

  test('opponent leave saves the match and suppresses trailing boards', () {
    final inGame = _admittedGame();

    final saved = inGame.receive(
      _cookie('** Player BlunderBot has left the game. The game was saved.'),
    );
    final trailingBoard = saved.state.receiveBoard(_cookie(_boardLine()));

    expect(saved.state.session.board, isNull);
    expect(saved.state.session.savedMatches, contains('BlunderBot'));
    expect(saved.commands, ['show savedgames']);
    expect(trailingBoard.state.session.board, isNull);
  });
}

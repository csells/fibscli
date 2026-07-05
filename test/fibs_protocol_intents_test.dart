import 'package:fibscli/fibs_protocol.dart';
import 'package:fibscli/fibs_protocol_intents.dart';
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

String _boardLine({
  String player1 = 'me',
  String player2 = 'BlunderBot',
  String turn = '1',
}) =>
    'board:$player1:$player2:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0'
    ':-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

FibsSession _sessionInGame() => const FibsProtocolState()
    .loggedInAs('me')
    .state
    .inviteBot('BlunderBot', matchLength: 1)
    .state
    .receiveBoard(_cookie(_boardLine()))
    .state
    .session;

void main() {
  test('whole-turn move command validation accepts only move commands', () {
    expect(isFibsWholeTurnMoveCommand('move'), isTrue);
    expect(isFibsWholeTurnMoveCommand('move 8-4 bar-22 2-off'), isTrue);

    expect(isFibsWholeTurnMoveCommand('who'), isFalse);
    expect(isFibsWholeTurnMoveCommand('move 25-24'), isFalse);
    expect(isFibsWholeTurnMoveCommand('move 8-4 now'), isFalse);
  });

  test('player intent plans emit commands and consume local turn state', () {
    final canRoll = FibsProtocolState(
      session: _sessionInGame(),
    ).receive(_cookie("It's your turn to roll or double.")).state.session;
    final rolled = fibsStartRoll(canRoll);

    expect(rolled.commands, ['roll']);
    expect(rolled.session.rolling, isTrue);

    final canMove = FibsProtocolState(
      session: rolled.session,
    ).receive(_cookie('You roll 3 and 1')).state.session;
    final submitted = fibsCommitTurnCommand(canMove, 'move 8-5 5-4');

    expect(submitted.commands, ['move 8-5 5-4']);
    expect(submitted.session.committedTurn, isTrue);
  });
}

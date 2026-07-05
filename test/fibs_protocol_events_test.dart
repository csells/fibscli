import 'package:fibscli/fibs_protocol_events.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter_test/flutter_test.dart';

CookieMessage _cookie(
  String raw, {
  CookieMonsterState state = CookieMonsterState.FIBS_RUN_STATE,
}) {
  final monster = CookieMonster()..messageState = state;
  return monster.eatCookie(raw);
}

void main() {
  test('chat messages use the FIBS sender and message crumbs', () {
    final message = fibsProtocolChatMessage(
      _cookie('12 BlunderBot I will not attempt to resume for 5 minutes.'),
    );

    expect(message.from, 'BlunderBot');
    expect(message.text, 'I will not attempt to resume for 5 minutes.');
  });

  test('system messages strip the FIBS system prefix for display', () {
    final message = fibsProtocolSystemMessage(
      _cookie('** You must give 2 moves.'),
    );

    expect(message.from, 'FIBS');
    expect(message.text, 'You must give 2 moves.');
  });

  test('match result cookies expose normalized win and loss results', () {
    final win = fibsProtocolMatchResult(
      _cookie('You win the 1 point match 1-0 .'),
    );
    final loss = fibsProtocolMatchResult(
      _cookie('BlunderBot wins the 1 point match 1-0 .'),
    );

    expect(win, isNotNull);
    expect(win!.didIWin, isTrue);
    expect(win.message, 'You win the 1 point match 1-0.');
    expect(loss, isNotNull);
    expect(loss!.didIWin, isFalse);
    expect(loss.message, 'BlunderBot wins the 1 point match 1-0.');
  });
}

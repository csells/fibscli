import 'package:fibscli/fibs_play_controller.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// A pure race, our turn (we are player1 "You" = X): X on pips 1..6 (home), O on
// 19..24 (home) -- no contact. [xDice] are our dice for the turn.
String raceLine({required String xDice}) {
  final points = List.filled(26, 0);
  points[1] = -3;
  points[2] = -3;
  points[3] = -3;
  points[4] = -2;
  points[5] = -2;
  points[6] = -2; // 15 X
  points[19] = 3;
  points[20] = 3;
  points[21] = 3;
  points[22] = 2;
  points[23] = 2;
  points[24] = 2; // 15 O
  return [
    'board', 'You', 'bot', '1', '0', '0',
    points.join(':'),
    '-1', // turnColor -1 = X (us) on roll
    xDice, '0:0', // player1Dice (ours), player2Dice
    '1', '1', '1', '0',
    '-1', '-1', // player1Color = X, direction
    '0', '25',
    '0', '0', '0', '0', // off/bar
    '2', // canMove
    '0', '0', '0',
  ].join(':');
}

Future<FibsState> _inRace(FakeTransport fake, {String xDice = '3:1'}) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fake.feed(raceLine(xDice: xDice));
  await Future<void>.delayed(Duration.zero);
  return fibs;
}

int moveCount(FakeTransport fake) =>
    fake.sent.where((c) => c.startsWith('move ')).length;

void main() {
  test('auto bear-off plays and submits the current race turn', () async {
    final fake = FakeTransport();
    final fibs = await _inRace(fake, xDice: '3:1');
    final controller = FibsPlayController(fibs: fibs);
    controller.syncTurn();
    expect(controller.canAutoBearOff, isTrue);

    controller.autoBearOff();
    expect(moveCount(fake), 1, reason: 'the turn was played + submitted');
  });

  test(
    'auto bear-off stays enabled and plays our NEXT race turn on its own',
    () async {
      final fake = FakeTransport();
      final fibs = await _inRace(fake, xDice: '3:1');
      final controller = FibsPlayController(fibs: fibs);
      controller.syncTurn();

      controller.autoBearOff(); // one tap enables the mode + plays this turn
      expect(moveCount(fake), 1);

      // our next race turn arrives -- no second tap; the mode plays it too
      fake.feed(raceLine(xDice: '5:4'));
      await Future<void>.delayed(Duration.zero);
      expect(moveCount(fake), 2, reason: 'the mode continued without a tap');

      controller.dispose();
    },
  );
}

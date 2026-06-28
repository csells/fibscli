import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game, our turn; player1 is the literal "You" (player1Color 1 == O).
// p1dice '0:0' => no dice yet (canRoll); a real roll => canMoveNow.
String boardLine({String p1dice = '0:0'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:1:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

Future<FibsState> _inGame(FakeTransport fake, {String p1dice = '0:0'}) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fake.feed(boardLine(p1dice: p1dice));
  await Future<void>.delayed(Duration.zero);
  return fibs;
}

void main() {
  test('after roll, canRoll is false and a second roll throws', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake); // our turn, no dice
    expect(fibs.canRoll, isTrue);

    fibs.roll();
    expect(fake.sent, contains('roll'));
    // FIBS has moreboards off and won't echo a board; canRoll must flip off
    // immediately so we don't roll again
    expect(fibs.canRoll, isFalse);
    expect(fibs.roll, throwsA(isA<FibsStateError>()));
  });

  test('our dice arriving (FIBS_YouRoll) enables exactly one move', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    fibs.roll();
    fake.feed('You roll 1 and 6');
    await Future<void>.delayed(Duration.zero);

    expect(fibs.canRoll, isFalse);
    expect(fibs.canMoveNow, isTrue);

    final cmd = fibs.playFirstLegalMove();
    expect(cmd, isNotNull);
    // committing the whole turn flips canMoveNow off until the next board, so a
    // second move can't be sent into a turn we already played
    expect(fibs.canMoveNow, isFalse);
    expect(fibs.playFirstLegalMove, throwsA(isA<FibsStateError>()));
  });

  test('moving when it is not our turn throws (loud, not a silent no-op)',
      () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake); // our turn but no dice -> can't move
    expect(fibs.canMoveNow, isFalse);
    expect(() => fibs.move(24, 18), throwsA(isA<FibsStateError>()));
  });

  test('accepting a double that was never offered throws', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    expect(fibs.acceptDouble, throwsA(isA<FibsStateError>()));
    expect(fibs.rejectDouble, throwsA(isA<FibsStateError>()));
  });
}

import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game; player1 is the literal "You" (player1Color 1 == O). turn '1'
// is our turn, '-1' the opponent's. p1dice '0:0' => no dice yet.
String boardLine({String p1dice = '0:0', String turn = '1'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

Future<FibsState> _inGame(
  FakeTransport fake, {
  String p1dice = '0:0',
  String turn = '1',
}) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fake.feed(boardLine(p1dice: p1dice, turn: turn));
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

  test('a refresh board after we roll does not let us roll again', () async {
    // FIBS may resend an "our turn, no dice" board while we await YouRoll; it
    // must not reset _rolling, or we'd roll a second time ("already rolled").
    final fake = FakeTransport();
    final fibs = await _inGame(fake); // our turn, no dice
    fibs.roll();
    expect(fibs.canRoll, isFalse);

    fake.feed(boardLine(turn: '1')); // same state, still no dice
    await Future<void>.delayed(Duration.zero);
    expect(fibs.canRoll, isFalse); // still awaiting our dice -> no second roll
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

  test(
    'a fresh our-turn board clears stale rolled dice (must roll again)',
    () async {
      // FIBS often reports the opponent's play as text then jumps straight to
      // our next roll board with NO opponent-turn board in between. The board
      // is authoritative: stale dice from our last turn must be dropped, or
      // we'd try to move ("you have to roll the dice before moving").
      final fake = FakeTransport();
      final fibs = await _inGame(fake); // our turn, no dice
      fibs.roll();
      fake.feed('You roll 6 and 4');
      await Future<void>.delayed(Duration.zero);
      fibs.playFirstLegalMove();
      expect(fibs.canMoveNow, isFalse); // committed

      // our next turn arrives as a fresh board with no dice
      fake.feed(boardLine(turn: '1'));
      await Future<void>.delayed(Duration.zero);
      expect(fibs.canMoveNow, isFalse); // stale 6,4 dropped -> nothing to move
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
    final cmd = fibs.playFirstLegalMove();
    expect(cmd, isNotNull);
  });

  test(
    'moving when it is not our turn throws (loud, not a silent no-op)',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake); // our turn but no dice -> can't move
      expect(fibs.canMoveNow, isFalse);
      expect(() => fibs.move(24, 18), throwsA(isA<FibsStateError>()));
    },
  );

  test('accepting a double that was never offered throws', () async {
    final fake = FakeTransport();
    final fibs = await _inGame(fake);
    expect(fibs.acceptDouble, throwsA(isA<FibsStateError>()));
    expect(fibs.rejectDouble, throwsA(isA<FibsStateError>()));
  });
}

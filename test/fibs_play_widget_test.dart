import 'package:fibscli/board_view.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game: player1 is the literal "You"; an opening position, our turn (O)
String boardLine({String turn = '1', String p1dice = '6:3'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

Future<FibsState> _startGame(
  WidgetTester tester,
  FakeTransport fake, {
  String dice = '6:3',
}) async {
  App.fibs = FibsState.withTransport(fake);
  await App.fibs.login(user: 'joe_grammer', pass: 'x');
  await tester.pumpWidget(const MaterialApp(home: FibsPage()));
  fake.feed(boardLine(p1dice: dice));
  await tester.pumpAndSettle();
  return App.fibs;
}

void main() {
  testWidgets('play UI renders the interactive board on our turn', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake);

    expect(find.byType(BoardView), findsOneWidget);
    expect(find.textContaining('vs wildbg'), findsOneWidget);
    expect(fibs.canMoveNow, isTrue);
  });

  testWidgets('tap-to-move sends the absolute-coordinate move command', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake);

    // exactly what the board's tap handler invokes: source pip then destination
    fibs.move(24, 18);
    expect(fake.sent, contains('move 24-18'));
  });

  testWidgets('roll button appears on our turn with no dice and sends roll', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0');

    expect(App.fibs.canRoll, isTrue);
    expect(find.text('Roll'), findsOneWidget);

    await tester.tap(find.text('Roll'));
    await tester.pump();
    expect(fake.sent, contains('roll'));
  });

  testWidgets('a double offer shows Take/Pass and Take sends accept', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake);

    fake.feed("wildbg doubles. Type 'accept' or 'reject'.");
    await tester.pumpAndSettle();

    expect(App.fibs.doubleOffered, isTrue);
    expect(find.text('Take'), findsOneWidget);

    await tester.tap(find.text('Take'));
    await tester.pump();
    expect(fake.sent, contains('accept'));
  });
}

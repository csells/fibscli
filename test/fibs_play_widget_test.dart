import 'package:fibscli/board_view.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

// our own game: player1 is the literal "You"; an opening position, our turn (O)
String boardLine({String turn = '1', String p1dice = '6:3'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:$turn:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

// a finished game where we (player1 "You" = X) have borne off all 15.
String gameOverLine() => [
  'board', 'You', 'wildbg', '1', '0', '0',
  List.filled(26, 0).join(':'),
  '0', // turnColor 0 = game over
  '0:0', '0:0', '1', '1', '1', '0',
  '-1', '-1', '0', '25',
  '15', '0', '0', '0', '0', '0', '0', '0', // xOff = 15 (we win)
].join(':');

Future<FibsState> _startGame(
  WidgetTester tester,
  FakeTransport fake, {
  String dice = '6:3',
}) async {
  SharedPreferences.setMockInitialValues({});
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  await tester.pumpWidget(
    MaterialApp(
      home: FibsPage(fibs: fibs, creds: await fakeCreds()),
    ),
  );
  fake.feed(boardLine(p1dice: dice));
  await tester.pumpAndSettle();
  return fibs;
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

  testWidgets('roll button appears on our turn with no dice and sends roll', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake, dice: '0:0');

    expect(fibs.canRoll, isTrue);
    expect(find.text('Roll'), findsOneWidget);

    await tester.tap(find.text('Roll'));
    await tester.pump();
    expect(fake.sent, contains('roll'));
  });

  testWidgets('a double offer shows Take/Pass and Take sends accept', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake);

    fake.feed("wildbg doubles. Type 'accept' or 'reject'.");
    await tester.pumpAndSettle();

    expect(fibs.doubleOffered, isTrue);
    expect(find.text('Take'), findsOneWidget);

    await tester.tap(find.text('Take'));
    await tester.pump();
    expect(fake.sent, contains('accept'));
  });

  testWidgets('a flip-board control reverses the board', (tester) async {
    final fake = FakeTransport();
    await _startGame(tester, fake);

    // FIBS already gives us our own perspective, so no auto-flip by default
    BoardView board() => tester.widget<BoardView>(find.byType(BoardView));
    expect(board().reversed, isFalse, reason: 'no auto-flip by default');

    await tester.tap(find.byTooltip('flip board'));
    await tester.pump();
    expect(board().reversed, isTrue, reason: 'the flip control toggled it');
  });

  testWidgets('move highlights go home (mirror-aware), not backwards', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake); // O on roll, mirrored frame

    // O's checkers are on 24/13/8/6 and must move DOWN toward the 1-point (not
    // up, away from home).
    final byPip = fibs.gameState!.getAllLegalMoves();
    expect(byPip.keys, contains(24));
    for (final moves in byPip.values) {
      for (final m in moves) {
        expect(m.toPipNo, lessThan(m.fromPipNo), reason: 'moves head home');
      }
    }
  });

  testWidgets('a finished game shows the result and a Back to lobby button', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake); // in the play view

    fake.feed(gameOverLine()); // we bear off all 15 -> game over
    await tester.pumpAndSettle();

    // no more "Waiting for opponent…"; the result + escape hatch show instead
    expect(find.text('You win!'), findsOneWidget);
    expect(find.text('Back to lobby'), findsOneWidget);

    await tester.tap(find.text('Back to lobby'));
    await tester.pumpAndSettle();
    expect(find.text('Bots'), findsOneWidget); // back at the lobby
  });

  testWidgets('the lobby has no "Play for me" (cheating on FIBS)', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Play for me'), findsNothing);
  });

  testWidgets('auto bear-off in a pure race submits a bear-off turn', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    // a pure race: O (us) all home on 1-6, X home on 19-24, our roll 6 and 5
    fake.feed(
      'board:You:bot:1:0:0:0:2:2:3:2:3:3:0:0:0:0:0:0:0:0:0:0:0:0:-2:-2:-3:-2'
      ':-3:-3:0:1:6:5:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0',
    );
    await tester.pumpAndSettle();

    // the fast-forward shows in a pure race; tapping it submits the bear-off
    expect(find.byTooltip('auto bear-off'), findsOneWidget);
    await tester.tap(find.byTooltip('auto bear-off'));
    await tester.pumpAndSettle();

    final moves = fake.sent.where((c) => c.startsWith('move '));
    expect(moves, isNotEmpty);
    expect(moves.last, contains('off'), reason: 'it bore checkers off');
  });

  testWidgets('entering the view already on our move shows legal moves', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake); // board+dice arrive together -> our move

    // the working turn must be created on entry (no later notification fires),
    // so the board is interactive with our legal moves highlighted.
    final board = tester.widget<BoardView>(find.byType(BoardView));
    expect(board.ignoring, isFalse, reason: 'interactive on our move');
    expect(board.legalMoves, isNotEmpty, reason: 'legal moves are shown');
  });

  testWidgets('a tap moves the piece LOCALLY -- nothing sent until submit', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake);

    // make one move on the local working board, the way a tap does
    final legal = fibs.gameState!.getAllLegalMoves();
    final from = legal.keys.first;
    final to = legal[from]!.first.toPipNo;
    BoardView board() => tester.widget<BoardView>(find.byType(BoardView));
    board().onTapPip!(from); // select
    await tester.pump();
    board().onTapPip!(to); // move (locally)
    await tester.pumpAndSettle();

    // FIBS must NOT have received a move command -- the turn is built locally
    // and only submitted on a dice tap (this is what was failing before).
    expect(fake.sent.where((c) => c.startsWith('move ')), isEmpty);
  });
}

import 'package:fibscli/board_view.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/game_board.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

// our own game: player1 is the literal "You"; an opening position, our turn (O)
String boardLine({
  String player1 = 'You',
  String player2 = 'wildbg',
  String turn = '1',
  String p1dice = '6:3',
  String player1MayDouble = '1',
}) => [
  'board:$player1:$player2:1:0:0:0',
  '-2:0:0:0:0:5:0:3:0:0:0:-5:5',
  '0:0:0:-3:0:-5:0:0:0:0:2:0',
  '$turn:$p1dice:0:0:1:$player1MayDouble:1:0:1:-1:0:25:0:0:0:0:2:0:0:0',
].join(':');

const rollOrDoubleLine = "It's your turn to roll or double.";

String lateBearOffRaceLine() {
  final points = List.filled(26, 0);
  points[1] = -2;
  points[19] = 3;
  points[20] = 3;
  points[21] = 3;
  points[22] = 2;
  points[23] = 2;
  points[24] = 2;
  return [
    'board',
    'You',
    'bot',
    '1',
    '0',
    '0',
    points.join(':'),
    '-1',
    '5:5',
    '0:0',
    '1',
    '1',
    '1',
    '0',
    '-1',
    '-1',
    '0',
    '25',
    '13',
    '0',
    '0',
    '0',
    '2',
    '0',
    '0',
    '0',
  ].join(':');
}

Future<FibsState> _startGame(
  WidgetTester tester,
  FakeTransport fake, {
  String dice = '6:3',
  String turn = '1',
  String player1MayDouble = '1',
  bool promptRoll = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fibs.resumeSavedMatch('wildbg');
  await tester.pumpWidget(
    MaterialApp(
      home: FibsPage(fibs: fibs, creds: await fakeCreds()),
    ),
  );
  fake.feed(
    boardLine(p1dice: dice, turn: turn, player1MayDouble: player1MayDouble),
  );
  if (promptRoll) fake.feed(rollOrDoubleLine);
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
    final fibs = await _startGame(tester, fake, dice: '0:0', promptRoll: true);

    expect(fibs.canRoll, isTrue);
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text('Double'), findsOneWidget);

    await tester.tap(find.text('Roll'));
    await tester.pump();
    expect(fake.sent, contains('roll'));
  });

  testWidgets('roll and double controls sit beside the board center', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0', promptRoll: true);

    final board = tester.getRect(find.byType(BoardView));
    final roll = tester.getRect(find.widgetWithText(FilledButton, 'Roll'));
    final doubleButton = tester.getRect(
      find.widgetWithText(OutlinedButton, 'Double'),
    );

    expect(roll.center.dy, greaterThan(board.top + board.height * 0.35));
    expect(roll.center.dy, lessThan(board.top + board.height * 0.65));
    expect(roll.center.dx, greaterThan(board.left));
    expect(roll.center.dx, lessThan(board.left + board.width * 0.5));
    expect(
      doubleButton.center.dy,
      greaterThan(board.top + board.height * 0.35),
    );
    expect(doubleButton.center.dy, lessThan(board.top + board.height * 0.65));
    expect(doubleButton.center.dx, greaterThan(board.left));
    expect(doubleButton.center.dx, lessThan(board.left + board.width * 0.5));
  });

  testWidgets('roll controls wait for the FIBS roll-or-double prompt', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake, dice: '0:0');

    expect(fibs.canRoll, isFalse);
    expect(find.text('Roll'), findsNothing);
    expect(find.text('Double'), findsNothing);
    expect(find.textContaining('Waiting for wildbg'), findsOneWidget);

    fake.feed(rollOrDoubleLine);
    await tester.pumpAndSettle();

    expect(fibs.canRoll, isTrue);
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text('Double'), findsOneWidget);
  });

  testWidgets('board size stays fixed when footer controls change', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0');

    final waitingBoard = tester.getRect(find.byType(BoardView));
    fake.feed(rollOrDoubleLine);
    await tester.pumpAndSettle();
    final actionBoard = tester.getRect(find.byType(BoardView));

    fake.feed('You win the 1 point match 1-0 .');
    await tester.pumpAndSettle();
    final resultBoard = tester.getRect(find.byType(BoardView));

    expect(actionBoard.size, waitingBoard.size);
    expect(resultBoard.size, waitingBoard.size);
  });

  testWidgets('waiting for an opponent has a visible leave action', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0', turn: '-1');

    expect(find.textContaining('Waiting for wildbg'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Leave'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Resign'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Leave'));
    await tester.pumpAndSettle();

    expect(fake.sent, contains('leave'));
    expect(fake.sent, isNot(contains('resign n')));
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.text('Bots online'), findsOneWidget);
  });

  testWidgets('waiting status explains a delayed resume attempt', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0', turn: '-1');

    fake.feed('12 wildbg I will not attempt to resume for 5 minutes.');
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        'Waiting for wildbg — will not attempt to resume for 5 minutes.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('waiting for an opponent has a visible resign action', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake, dice: '0:0', turn: '-1');

    await tester.tap(find.widgetWithText(OutlinedButton, 'Resign'));
    await tester.pumpAndSettle();
    expect(find.text('Resign this game?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
    await tester.pump();

    expect(fake.sent, contains('resign n'));
    expect(fake.sent, isNot(contains('leave')));
  });

  testWidgets('double is hidden when FIBS says this side may not double', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = await _startGame(
      tester,
      fake,
      dice: '0:0',
      player1MayDouble: '0',
      promptRoll: true,
    );

    expect(fibs.canRoll, isTrue);
    expect(fibs.canOfferDouble, isFalse);
    expect(find.text('Roll'), findsOneWidget);
    expect(find.text('Double'), findsNothing);
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

    fake.feed('You win the 1 point match 1-0 .');
    await tester.pumpAndSettle();

    // no more "Waiting for opponent…"; the result + escape hatch show instead
    expect(find.text('You win!'), findsOneWidget);
    expect(find.text('You win the 1 point match 1-0.'), findsOneWidget);
    expect(find.text('Back to lobby'), findsOneWidget);
    final board = tester.getRect(find.byType(BoardView));
    final lobby = tester.getRect(
      find.widgetWithText(FilledButton, 'Back to lobby'),
    );
    expect(lobby.center.dy, greaterThan(board.top + board.height * 0.35));
    expect(lobby.center.dy, lessThan(board.top + board.height * 0.70));
    expect(lobby.center.dx, greaterThan(board.left));
    expect(lobby.center.dx, lessThan(board.left + board.width * 0.5));

    await tester.tap(find.text('Back to lobby'));
    await tester.pumpAndSettle();
    expect(find.text('Bots online'), findsOneWidget); // back at the lobby
  });

  testWidgets('Back leaves and saves the FIBS match instead of resigning', (
    tester,
  ) async {
    final fake = FakeTransport();
    await _startGame(tester, fake);

    await tester.tap(find.byTooltip('leave'));
    await tester.pumpAndSettle();

    expect(fake.sent, contains('leave'));
    expect(fake.sent, isNot(contains('resign n')));
    expect(find.text('Leave this game?'), findsNothing);
    expect(fake.sent.where((cmd) => cmd == 'show savedgames'), hasLength(2));
    expect(find.text('Bots online'), findsOneWidget);
    expect(find.text('wildbg'), findsOneWidget);
    expect(find.textContaining('Saved'), findsOneWidget);
  });

  testWidgets('Back never offers resign as part of leaving', (tester) async {
    final fake = FakeTransport();
    await _startGame(tester, fake);

    await tester.tap(find.byTooltip('leave'));
    await tester.pumpAndSettle();

    expect(fake.sent, contains('leave'));
    expect(fake.sent, isNot(contains('resign n')));
    expect(find.text('Leave this game?'), findsNothing);
    expect(find.text('Resign this game?'), findsNothing);
  });

  testWidgets('resign is separate and explicit', (tester) async {
    final fake = FakeTransport();
    await _startGame(tester, fake);

    await tester.tap(find.byTooltip('resign'));
    await tester.pumpAndSettle();
    expect(find.text('Resign this game?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Resign'));
    await tester.pump();

    expect(fake.sent, contains('resign n'));
    expect(fake.sent, isNot(contains('leave')));
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

  testWidgets('watch UI uses the full read-only board and updates frames', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');
    fibs.resumeSavedMatch('bot');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );

    fake.feed(boardLine(player1: 'alice', player2: 'wildbg'));
    await tester.pumpAndSettle();

    expect(find.byType(BoardView), findsOneWidget);
    expect(find.text('Watching alice vs wildbg'), findsWidgets);
    expect(find.textContaining('alice to move'), findsOneWidget);
    expect(find.textContaining('alice pips'), findsOneWidget);
    expect(find.textContaining('wildbg pips'), findsOneWidget);

    GameBoard board() => tester.widget<GameBoard>(find.byType(GameBoard));
    expect(board().interactive, isFalse);
    expect(board().onMove, isNull);
    expect(board().game.dice.map((d) => d.roll).toList(), [6, 3]);

    fake.feed(boardLine(player1: 'alice', player2: 'wildbg', p1dice: '4:2'));
    await tester.pumpAndSettle();

    expect(board().game.dice.map((d) => d.roll).toList(), [4, 2]);
    expect(find.textContaining('dice 4, 2'), findsOneWidget);
  });

  testWidgets('auto bear-off in a pure race submits a bear-off turn', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');
    fibs.resumeSavedMatch('bot');
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
    await tester.pump();

    BoardView board() => tester.widget<BoardView>(find.byType(BoardView));
    expect(board().pieceAnimations, isNotEmpty);
    expect(board().ignoring, isTrue);
    for (var i = 0; i != 10; i += 1) {
      if (fake.sent.any((c) => c.startsWith('move '))) break;
      final boardView = board();
      final onEnd = boardView.onPieceAnimationEnd!;
      boardView.pieceAnimations.keys.toList().forEach(onEnd);
      await tester.pump();
    }

    final moves = fake.sent.where((c) => c.startsWith('move '));
    expect(moves, isNotEmpty);
    expect(moves.last, contains('off'), reason: 'it bore checkers off');
  });

  testWidgets('auto bear-off doubles keep advancing real animations', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'x');
    fibs.resumeSavedMatch('bot');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    fake.feed(lateBearOffRaceLine());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('auto bear-off'));
    await tester.pump();
    for (var i = 0; i != 8; i += 1) {
      if (fake.sent.any((c) => c.startsWith('move '))) break;
      await tester.pump(kHopAnimationDuration);
    }

    expect(
      fake.sent.where((c) => c.startsWith('move ')).last,
      'move 1-off 1-off',
    );
    expect(fibs.canMoveNow, isFalse);
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

  testWidgets('a local FIBS tap starts a checker animation', (tester) async {
    final fake = FakeTransport();
    final fibs = await _startGame(tester, fake);

    final legal = fibs.gameState!.getAllLegalMoves();
    final from = legal.keys.first;
    final to = legal[from]!.first.toPipNo;
    BoardView board() => tester.widget<BoardView>(find.byType(BoardView));
    board().onTapPip!(from);
    await tester.pump();
    board().onTapPip!(to);
    await tester.pump();

    expect(board().pieceAnimations, isNotEmpty);
    expect(board().ignoring, isTrue);
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

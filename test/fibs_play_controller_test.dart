import 'package:fibscli/fibs_play_controller.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

String boardLine({String p1dice = '6:3'}) =>
    'board:You:wildbg:1:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0'
    ':2:0:1:$p1dice:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

String watchedBoardLine(List<int> points, {int turn = -1}) {
  assert(points.length == 26);
  return [
    'board',
    'xplayer',
    'oplayer',
    '1',
    '0',
    '0',
    points.join(':'),
    '$turn',
    '0:0',
    '0:0',
    '1',
    '1',
    '1',
    '0',
    '-1',
    '-1',
    '0',
    '25',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
  ].join(':');
}

String ownXBoardLine(
  List<int> points, {
  int turn = -1,
  List<int> xDice = const [0, 0],
  List<int> oDice = const [0, 0],
}) {
  assert(points.length == 26);
  return [
    'board',
    'You',
    'wildbg',
    '1',
    '0',
    '0',
    points.join(':'),
    '$turn',
    '${xDice[0]}:${xDice[1]}',
    '${oDice[0]}:${oDice[1]}',
    '1',
    '1',
    '1',
    '0',
    '-1',
    '-1',
    '0',
    '25',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
    '0',
  ].join(':');
}

List<int> countsFromBoard(List<List<int>> board) => [
  for (final pip in board)
    pip.fold<int>(
      0,
      (count, piece) =>
          count + (GammonRules.playerFor(piece) == GammonPlayer.one ? -1 : 1),
    ),
];

Future<FibsState> _inGame(FakeTransport fake) async {
  final fibs = FibsState.withTransport(fake);
  await fibs.login(user: 'joe_grammer', pass: 'x');
  fake.feed(boardLine());
  await Future<void>.delayed(Duration.zero);
  return fibs;
}

Future<void> _playCompleteTurn(FibsPlayController controller) async {
  while (controller.legalMoves.isNotEmpty) {
    final entry = controller.legalMoves.entries.first;
    final move = entry.value.first;
    expect(controller.applyLocalMove(entry.key, move.toPipNo), isTrue);
    await _finishAnimations(controller);
  }
}

Future<void> _finishAnimations(FibsPlayController controller) async {
  for (var i = 0; i < 10 && controller.animator.isAnimating; i += 1) {
    controller.animator.layouts.keys.toList().forEach(
      controller.animator.endPiece,
    );
    await Future<void>.delayed(Duration.zero);
  }
  expect(controller.animator.isAnimating, isFalse);
}

void main() {
  test(
    'submitting keeps the locally moved board until FIBS sends a board',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake);
      final controller = FibsPlayController(fibs: fibs);
      addTearDown(controller.dispose);

      controller.syncTurn();
      final liveBeforeSubmit = Position.fromBoard(fibs.gameState!.board);

      await _playCompleteTurn(controller);
      final submitted = Position.fromBoard(controller.displayGame.board);
      expect(submitted, isNot(liveBeforeSubmit));

      controller.submitTurn();

      expect(fake.sent.any((c) => c.startsWith('move ')), isTrue);
      expect(controller.interactive, isFalse);
      expect(Position.fromBoard(fibs.gameState!.board), liveBeforeSubmit);
      expect(Position.fromBoard(controller.displayGame.board), submitted);
    },
  );

  test(
    'a rejected submitted turn restores the editable server board',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake);
      final controller = FibsPlayController(fibs: fibs);
      addTearDown(controller.dispose);

      controller.syncTurn();
      final liveBeforeSubmit = Position.fromBoard(fibs.gameState!.board);
      await _playCompleteTurn(controller);
      final submitted = Position.fromBoard(controller.displayGame.board);
      expect(submitted, isNot(liveBeforeSubmit));

      controller.submitTurn();
      expect(controller.interactive, isFalse);

      fake.feed('** You must give 2 moves.');
      await Future<void>.delayed(Duration.zero);

      expect(controller.interactive, isTrue);
      expect(
        Position.fromBoard(controller.displayGame.board),
        liveBeforeSubmit,
      );
      expect(fibs.messages.last.message, 'You must give 2 moves.');
    },
  );

  test('incoming FIBS boards animate through captured opponent dice', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe_grammer', pass: 'x');

    final before = List<int>.filled(26, 0)
      ..[24] = -1
      ..[13] = -1;
    final after = List<int>.filled(26, 0)
      ..[16] = -1
      ..[9] = -1;

    fake.feed(watchedBoardLine(before));
    await Future<void>.delayed(Duration.zero);

    final controller = FibsPlayController(fibs: fibs);
    addTearDown(controller.dispose);

    fake.feed('xplayer rolls 4 and 4');
    await Future<void>.delayed(Duration.zero);
    fake.feed(watchedBoardLine(after, turn: 1));
    await Future<void>.delayed(Duration.zero);

    final paths = controller.animator.layouts.values
        .map((frames) => frames.map((frame) => frame.pipNo).toList())
        .toList();
    expect(paths.map((path) => path.join(',')), contains('24,20,16'));
    expect(
      controller.animator.delays.values,
      contains(kHopAnimationDuration * 2),
    );
  });

  test('post-submit opponent board animates with PlayerRolls dice', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe_grammer', pass: 'x');

    final points = List<int>.filled(26, 0)
      ..[24] = -4
      ..[1] = 1
      ..[12] = 1;
    fake.feed(ownXBoardLine(points, xDice: [1, 1]));
    await Future<void>.delayed(Duration.zero);

    final controller = FibsPlayController(fibs: fibs);
    addTearDown(controller.dispose);
    controller.syncTurn();
    await _playCompleteTurn(controller);
    controller.submitTurn();

    final afterOpponent = countsFromBoard(controller.displayGame.board);
    final from = [
      for (var pip = 1; pip <= 16; pip += 1)
        if (afterOpponent[pip] > 0 &&
            afterOpponent[pip + 4] >= 0 &&
            afterOpponent[pip + 8] >= 0)
          pip,
    ].first;
    afterOpponent[from] -= 1;
    afterOpponent[from + 8] += 1;

    fake.feed('wildbg rolls 4 and 4');
    await Future<void>.delayed(Duration.zero);
    fake.feed(ownXBoardLine(afterOpponent, turn: -1));
    await Future<void>.delayed(Duration.zero);

    final paths = controller.animator.layouts.values
        .map((frames) => frames.map((frame) => frame.pipNo).toList().join(','))
        .toList();
    expect(paths, contains('$from,${from + 4},${from + 8}'));
  });

  test(
    'post-submit YouRoll without a board starts the next local turn',
    () async {
      final fake = FakeTransport();
      final fibs = FibsState.withTransport(fake);
      await fibs.login(user: 'joe_grammer', pass: 'x');

      final points = List<int>.filled(26, 0)
        ..[24] = -4
        ..[1] = 1
        ..[12] = 1;
      fake.feed(ownXBoardLine(points, xDice: [1, 1]));
      await Future<void>.delayed(Duration.zero);

      final controller = FibsPlayController(fibs: fibs);
      addTearDown(controller.dispose);
      controller.syncTurn();
      await _playCompleteTurn(controller);
      final submitted = Position.fromBoard(controller.displayGame.board);

      controller.submitTurn();
      expect(controller.interactive, isFalse);

      fake.feed('You roll 4 and 3');
      await Future<void>.delayed(Duration.zero);

      expect(fibs.canMoveNow, isTrue);
      expect(controller.interactive, isTrue);
      expect(Position.fromBoard(controller.displayGame.board), submitted);
      expect(controller.displayGame.dice.map((d) => d.roll), [4, 3]);
    },
  );

  test('board-frame doubles allow all four local moves', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe_grammer', pass: 'x');

    final points = List<int>.filled(26, 0)
      ..[6] = -4
      ..[24] = -11
      ..[1] = 2
      ..[12] = 13;
    fake.feed(ownXBoardLine(points, xDice: [1, 1]));
    await Future<void>.delayed(Duration.zero);

    final controller = FibsPlayController(fibs: fibs);
    addTearDown(controller.dispose);
    controller.syncTurn();

    expect(fibs.activeDice, [1, 1, 1, 1]);
    expect(controller.displayGame.dice.map((d) => d.roll), [1, 1, 1, 1]);

    await _playCompleteTurn(controller);
    controller.submitTurn();

    final command = fake.sent.lastWhere((cmd) => cmd.startsWith('move '));
    expect(command.substring('move '.length).split(' '), hasLength(4));
  });

  test(
    'local FIBS moves cannot advance while a checker is animating',
    () async {
      final fake = FakeTransport();
      final fibs = await _inGame(fake);
      final controller = FibsPlayController(fibs: fibs);
      addTearDown(controller.dispose);
      controller.syncTurn();

      final entry = controller.legalMoves.entries.first;
      final move = entry.value.first;
      expect(controller.applyLocalMove(entry.key, move.toPipNo), isTrue);
      expect(controller.animator.isAnimating, isTrue);
      final afterFirstMove = Position.fromBoard(controller.displayGame.board);

      expect(controller.applyLocalMove(entry.key, move.toPipNo), isFalse);
      expect(Position.fromBoard(controller.displayGame.board), afterFirstMove);

      await _finishAnimations(controller);
    },
  );
}

import 'package:fibscli/board_view.dart';
import 'package:fibscli/game_board.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The one shared board widget's selection state machine, driven through the
// real BoardView wiring (no pixel geometry): we read the onTapPip callback the
// board hands BoardView and invoke it, then inspect BoardView's props.

BoardView _board(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView));

Future<void> _pump(
  WidgetTester tester, {
  required Map<int, List<GammonMove>> legalMoves,
  required bool interactive,
  required bool Function(int, int) onMove,
}) => tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: GameBoard(
        game: GammonState(),
        legalMoves: legalMoves,
        interactive: interactive,
        onMove: onMove,
      ),
    ),
  ),
);

void main() {
  testWidgets('a from->to tap performs the move and clears the selection', (
    tester,
  ) async {
    final moves = <List<int>>[];
    await _pump(
      tester,
      legalMoves: {
        24: [
          GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
        ],
      },
      interactive: true,
      onMove: (from, to) {
        moves.add([from, to]);
        return true;
      },
    );
    final tapPip = _board(tester).onTapPip!;

    tapPip(24); // select the from-pip
    await tester.pump();
    expect(_board(tester).selectedPip, 24);

    tapPip(23); // tap the destination
    await tester.pump();
    expect(moves, [
      [24, 23],
    ]);
    expect(_board(tester).selectedPip, isNull); // cleared after the move
  });

  testWidgets('an illegal destination re-selects the tapped pip', (
    tester,
  ) async {
    await _pump(
      tester,
      legalMoves: {
        24: [
          GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
        ],
        13: [
          GammonMove(fromPipNo: 13, toPipNo: 11, hops: const [-2]),
        ],
      },
      interactive: true,
      onMove: (from, to) => false, // every move "fails"
    );
    final tapPip = _board(tester).onTapPip!;

    tapPip(24);
    await tester.pump();
    expect(_board(tester).selectedPip, 24);

    tapPip(13); // a different movable pip -> becomes the new selection
    await tester.pump();
    expect(_board(tester).selectedPip, 13);
  });

  testWidgets('tapping the same selected pip toggles it off', (tester) async {
    await _pump(
      tester,
      legalMoves: {
        24: [
          GammonMove(fromPipNo: 24, toPipNo: 23, hops: const [-1]),
        ],
      },
      interactive: true,
      onMove: (from, to) => false,
    );
    final tapPip = _board(tester).onTapPip!;

    tapPip(24);
    await tester.pump();
    expect(_board(tester).selectedPip, 24);

    tapPip(24); // same pip again
    await tester.pump();
    expect(_board(tester).selectedPip, isNull);
  });

  testWidgets('a read-only board is non-interactive and shows no legals', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GameBoard(game: GammonState())),
      ),
    );
    final board = _board(tester);
    expect(board.ignoring, isTrue);
    expect(board.legalMoves, isEmpty);
  });
}

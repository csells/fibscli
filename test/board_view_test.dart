import 'package:fibscli/board_view.dart';
import 'package:fibscli/fibs_board.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fibs_board_test.dart' show fibsBoardLine, parse;

void main() {
  group('ReadOnlyBoardView (milestone 1)', () {
    testWidgets('renders a FIBS-derived board with no exception',
        (tester) async {
      const opening = [
        0, 2, 0, 0, 0, 0, -5, 0, -3, 0, 0, 0, 5, //
        -5, 0, 0, 0, 3, 0, 5, 0, 0, 0, 0, -2, 0,
      ];
      // a watched board with the roller's dice showing
      final cm = parse(fibsBoardLine(opening, turn: 1, oDice: [3, 1]));
      final game = FibsBoard.fromCrumbs(cm.crumbs!).toGammonState();

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReadOnlyBoardView(game: game)),
      ));

      expect(tester.takeException(), isNull);
      expect(find.byType(ReadOnlyBoardView), findsOneWidget);
      // the doubling cube shows its value
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('renders a board with no dice (pre-roll) safely',
        (tester) async {
      final game = GammonState.from(
        board: GammonRules.initialBoard(),
        dice: const [],
        turnPlayer: GammonPlayer.one,
      );

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ReadOnlyBoardView(game: game)),
      ));

      expect(tester.takeException(), isNull);
    });
  });
}

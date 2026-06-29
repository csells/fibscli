import 'package:fibscli/dice.dart';
import 'package:fibscli/game_dialogs.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  group('OddsDialog (issue #14)', () {
    testWidgets('shows both win chances and cube advice', (tester) async {
      final game = GammonState();
      await tester.pumpWidget(MaterialApp(home: OddsDialog(game)));

      expect(find.text('Win Chances'), findsOneWidget);
      // each player's win chance line is shown (the on-roll player's name also
      // appears in the cube-advice line, so allow more than one match)
      expect(find.textContaining('Player 1:'), findsWidgets);
      expect(find.textContaining('Player 2:'), findsWidgets);
      // a percentage is shown for each player
      expect(find.textContaining('%'), findsWidgets);
      // some cube advice mentioning doubling is shown
      expect(find.textContaining('double'), findsOneWidget);
      // and the honesty disclaimer
      expect(find.textContaining('not an exact rollout'), findsOneWidget);
    });

    testWidgets('labels a pure race as an exact calculation', (tester) async {
      // a no-contact race: the win chances come from the exact solver
      final game = GammonState.from(
        board: makeBoard({6: -1, 24: 1}),
        dice: [DieState(3), DieState(1)],
        turnPlayer: GammonPlayer.one,
      );
      await tester.pumpWidget(MaterialApp(home: OddsDialog(game)));

      expect(find.textContaining('Exact race calculation'), findsOneWidget);
      expect(find.textContaining('not an exact rollout'), findsNothing);
    });

    testWidgets('OK dismisses the dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => OddsDialog.show(context, GammonState()),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Win Chances'), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Win Chances'), findsNothing);
    });
  });

  group('DoubleOfferDialog (issue #12)', () {
    Future<bool?> showAndTap(WidgetTester tester, String button) async {
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  result = await DoubleOfferDialog.show(
                    context,
                    GammonPlayer.one,
                    2,
                  );
                },
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.text('Player 1 doubles to 2'), findsOneWidget);
      expect(find.text('Player 2, do you accept?'), findsOneWidget);

      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Accept returns true', (tester) async {
      expect(await showAndTap(tester, 'Accept'), isTrue);
    });

    testWidgets('Decline returns false', (tester) async {
      expect(await showAndTap(tester, 'Decline'), isFalse);
    });
  });

  group('NewGameDialog stats (issue #10)', () {
    testWidgets('shows the winner and the per-player stats table', (
      tester,
    ) async {
      final game = GammonState();
      await tester.pumpWidget(
        MaterialApp(home: NewGameDialog(GammonPlayer.one, game)),
      );

      expect(find.textContaining('wins'), findsOneWidget);
      // stats table labels
      expect(find.text('Rolls'), findsOneWidget);
      expect(find.text('Total dice'), findsOneWidget);
      expect(find.text('Doubles'), findsOneWidget);
      // column headers
      expect(find.text('Player 1'), findsOneWidget);
      expect(find.text('Player 2'), findsOneWidget);
      // play-again actions
      expect(find.text('Yes, Please!'), findsOneWidget);
      expect(find.text('No, Thanks'), findsOneWidget);
    });
  });
}

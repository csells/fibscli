import 'package:fibscli/dice.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('renders the board and the doubling cube', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    expect(find.byType(GameView), findsOneWidget);
    expect(find.byType(DoublingCubeView), findsOneWidget);
  });

  testWidgets('auto bear-off button is hidden off the start (not a race)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('auto bear off'), findsNothing);
  });

  testWidgets('insights button opens the win-chances dialog (issue #14)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('win chances & cube advice'));
    await tester.pumpAndSettle();

    expect(find.text('Win Chances'), findsOneWidget);
  });

  testWidgets('tapping the cube offers a double and accepting raises it',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DoublingCubeView));
    await tester.pumpAndSettle();

    // a double is offered for the doubled value (1 -> 2)
    expect(find.textContaining('doubles to 2'), findsOneWidget);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    // the cube now reads 2
    expect(
      find.descendant(
          of: find.byType(DoublingCubeView), matching: find.text('2')),
      findsOneWidget,
    );
  });

  testWidgets('reverse button toggles without error', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('reverse board'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(GameView), findsOneWidget);
  });
}

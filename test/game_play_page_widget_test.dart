import 'package:bg_engine/bg_engine.dart';
import 'package:fibscli/dice.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Records whether dispose() was called (and never plays, since aiSide is null).
class _RecordingAi extends BgAiPlayer {
  bool disposed = false;
  @override
  String get name => 'recording';
  @override
  Future<BgTurn> chooseTurn(BgPosition position) async => const BgTurn([]);
  @override
  void dispose() => disposed = true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // Regression: the AI engine (widget.ai) was never disposed, leaking the gnubg
  // adapter's http.Client per game. GameView.dispose now releases it.
  testWidgets('disposing the game page disposes the AI engine', (tester) async {
    final ai = _RecordingAi();
    // aiSide null -> the AI never plays, but it's still owned and must be freed
    await tester.pumpWidget(MaterialApp(home: GamePlayPage(ai: ai)));
    await tester.pumpAndSettle();
    expect(ai.disposed, isFalse);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(ai.disposed, isTrue);
  });

  testWidgets('renders the board and the doubling cube', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    expect(find.byType(GameView), findsOneWidget);
    expect(find.byType(DoublingCubeView), findsOneWidget);
  });

  testWidgets('auto bear-off button is hidden off the start (not a race)', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    expect(find.byTooltip('auto bear off'), findsNothing);
  });

  testWidgets('insights button opens the win-chances dialog (issue #14)', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('win chances & cube advice'));
    await tester.pumpAndSettle();

    expect(find.text('Win Chances'), findsOneWidget);
  });

  testWidgets('tapping the cube offers a double and accepting raises it', (
    tester,
  ) async {
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
        of: find.byType(DoublingCubeView),
        matching: find.text('2'),
      ),
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

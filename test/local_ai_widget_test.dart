import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (GammonPlayer, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('1-player mode builds and the AI plays without error', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: GamePlayPage(aiSide: GammonPlayer.two, ai: PubevalAiPlayer()),
      ),
    );
    // let the opening roll resolve and, if the AI is on roll, play its turn
    await tester.pumpAndSettle(const Duration(milliseconds: 300));

    expect(find.byType(GameView), findsOneWidget);
    expect(tester.takeException(), isNull); // no crash driving the AI side
  });

  testWidgets('2-player mode is unchanged (no AI configured)', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: GamePlayPage()));
    await tester.pumpAndSettle();

    expect(find.byType(GameView), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

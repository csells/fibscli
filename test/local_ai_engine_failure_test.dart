import 'package:fibscli/dice.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (GammonPlayer, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An engine that fails on its turn with an ordinary (non-gnubg) error, the way
// an unexpected throw from the external backgammon_ai engine would.
class _ThrowingAi extends BgAiPlayer {
  @override
  String get name => 'throwing';

  @override
  Future<BgCubeAction> cubeDecision(BgPosition position) async =>
      BgCubeAction.noDouble; // get straight to the checker play

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async =>
      throw StateError('engine boom');
}

// The AI (player two) is on roll with dice to play from the standard opening,
// so _maybePlayAi drives its turn (and the throwing engine rejects).
GammonState _aiOnRoll() => GammonState.from(
  board: GammonState().board,
  dice: [DieState(3), DieState(1)],
  turnPlayer: GammonPlayer.two,
);

void main() {
  testWidgets(
    'an engine that throws does not strand the game -- offers Retry',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameView(
              aiSide: GammonPlayer.two,
              ai: _ThrowingAi(),
              aiThinkDelay: Duration.zero,
              aiMoveDelay: Duration.zero,
              createGame: _aiOnRoll,
            ),
          ),
        ),
      );

      // build + kick off _maybePlayAi, then let the throwing chooseTurn reject
      await tester.pump();
      await tester.pump();

      // the failure is caught (no unhandled crash) and surfaced with a way out
      expect(tester.takeException(), isNull);
      expect(
        find.textContaining('Computer engine unavailable'),
        findsOneWidget,
      );
      expect(find.widgetWithText(SnackBarAction, 'Retry'), findsOneWidget);
    },
  );
}

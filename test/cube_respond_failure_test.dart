import 'package:fibscli/dice.dart';
import 'package:fibscli/game_board.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (GammonPlayer, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// An AI whose double-response fails the way the gnubg adapter does when the
// service is unreachable: GnubgUnavailableException, never a local fallback.
class _UnavailableCubeAi extends BgAiPlayer {
  @override
  String get name => 'unavailable';

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async => const BgTurn([]);

  @override
  Future<BgCubeAction> respondToDouble(BgPosition position) async =>
      throw GnubgUnavailableException('the gnubg endpoint is unavailable');
}

void main() {
  // The human doubles; the AI opponent's answer comes from the engine. When
  // the engine cannot answer, the offer must be surfaced as unavailable and
  // withdrawn -- not silently answered by a local heuristic, and the game must
  // not end or crash. The human can tap the cube again to retry.
  testWidgets('an unanswerable double is surfaced, not decided locally', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GameView(
            aiSide: GammonPlayer.two,
            ai: _UnavailableCubeAi(),
            aiThinkDelay: Duration.zero,
            aiMoveDelay: Duration.zero,
            // human (player one) on roll, dice unused -> the human can double
            createGame: () => GammonState.from(
              board: GammonRules.initialBoard(),
              dice: [DieState(3), DieState(1)],
              turnPlayer: GammonPlayer.one,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final game = tester.widget<GameBoard>(find.byType(GameBoard)).game;

    // tap the cube -> _tapCube awaits ai.respondToDouble, which fails
    tester.widget<GameBoard>(find.byType(GameBoard)).onTapCube!();
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Computer engine unavailable'), findsOneWidget);
    // the offer was withdrawn, not resolved: the game and cube are untouched
    expect(game.gameOver, isFalse);
    expect(game.cube.value, 1);
  });
}

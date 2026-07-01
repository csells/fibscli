import 'dart:async';

import 'package:fibscli/dice.dart';
import 'package:fibscli/game_board.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// An AI whose double-response we hold open, so we can pop the page while
// _tapCube is awaiting it.
class _PendingCubeAi extends BgAiPlayer {
  final completer = Completer<BgCubeAction>();
  @override
  String get name => 'pending';
  @override
  Future<BgTurn> chooseTurn(BgPosition position) async => const BgTurn([]);
  @override
  Future<BgCubeAction> respondToDouble(BgPosition position) => completer.future;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // The cube tap offers a double to the AI and awaits its response; if the page
  // is popped during that await (the gnubg response can be HTTP-slow), _tapCube
  // must re-check mounted before touching _game/_reset -- no setState on a
  // disposed State.
  testWidgets('cube tap does not setState after the page is popped mid-await', (
    tester,
  ) async {
    final ai = _PendingCubeAi();
    await tester.pumpWidget(
      MaterialApp(
        home: GameView(
          aiSide: GammonPlayer.two,
          ai: ai,
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
    );
    await tester.pump();

    // tap the cube -> _tapCube awaits ai.respondToDouble (still pending)
    tester.widget<GameBoard>(find.byType(GameBoard)).onTapCube!();
    await tester.pump();

    // pop the page while the response is outstanding -> GameView disposed
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));

    // now the AI answers: _tapCube resumes on the disposed State
    ai.completer.complete(BgCubeAction.take);
    await tester.pump();

    // with the mounted guard there's no setState-after-dispose
    expect(tester.takeException(), isNull);
  });
}

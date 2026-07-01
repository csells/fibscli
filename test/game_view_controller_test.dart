import 'package:fibscli/dice.dart';
import 'package:fibscli/game_view_controller.dart';
import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'board_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // While the computer plays its turn the board is IgnorePointer-locked; the
  // app-bar / undo-FAB lock too (canUndo/canAutoBearOff gate on busy), so the
  // human can't undo/new-game/auto-bear-off mid-AI-turn and mutate the board
  // out from under the AI's cached move plan.
  test('busy (AI turn) disables undo and auto-bear-off', () {
    final controller = GameViewController();
    // a pure-race position, player one on roll (so canAutoBearOff is true idle)
    final race = makeBoard({
      6: -3,
      5: -3,
      4: -3,
      3: -2,
      2: -2,
      1: -2,
      19: 3,
      20: 3,
      21: 3,
      22: 2,
      23: 2,
      24: 2,
    });
    final game = GammonState.from(
      board: race,
      dice: [DieState(3), DieState(1)],
      turnPlayer: GammonPlayer.one,
    );
    controller.attach(game);

    // idle: the app-bar/FAB actions are live
    expect(controller.busy, isFalse);
    expect(controller.canUndo, isTrue);
    expect(controller.canAutoBearOff, isTrue);

    // during the AI's turn they must lock with the board
    controller.busy = true;
    expect(controller.canUndo, isFalse);
    expect(controller.canAutoBearOff, isFalse);

    controller.dispose();
  });
}

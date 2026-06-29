// BgPosition/BgTurn/BgAiPlayer/GammonPlayer all come via model.dart, which
// re-exports package:bg_engine.
import 'model.dart';

/// Build the representation-neutral [BgPosition] an AI consumes from the app's
/// live [GammonState] (a deep board copy, the available dice, and the cube).
BgPosition positionFromState(GammonState state) => BgPosition(
  board: [for (final point in state.board) List<int>.of(point)],
  onRoll: state.turnPlayer!,
  dice: [
    for (final die in state.dice)
      if (die.available) die.roll,
  ],
  cubeValue: state.cube.value,
  cubeOwner: state.cube.owner,
);

/// Play the AI's full turn on [state]: ask [ai] for the turn, apply each move,
/// then commit (rolling for the opponent). A dance (no legal move) just passes.
/// Stops without committing if a move ends the game. Headless — no UI/pacing.
Future<void> playAiTurn(GammonState state, BgAiPlayer ai) async {
  if (state.gameOver || state.turnPlayer == null) return;
  final turn = await ai.chooseTurn(positionFromState(state));
  for (final move in turn.moves) {
    state.applyMove(move: move);
    if (state.gameOver) return;
  }
  if (!state.gameOver) state.commitTurn();
}

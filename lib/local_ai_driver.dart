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

/// Drive the AI's full turn on [state] headlessly: first an optional doubling
/// decision, then the chosen checker play, then commit (rolling for the
/// opponent). A dance (no legal move) just passes; stops without committing if
/// a move ends the game. No UI or pacing — the host supplies those via hooks:
///
/// - [onOfferDouble] is called when the AI decides to double, with the proposed
///   new cube value; it returns whether the opponent takes (true) or passes
///   (false). When omitted the opponent takes (the headless default). A pass
///   concedes the game (the AI wins) and the turn ends.
/// - [onMove] is called for each chosen checker move so the host can animate
///   it; the host is responsible for applying the move to [state] (as the UI
///   animator does). When omitted each move is applied directly.
Future<void> playAiTurn(
  GammonState state,
  BgAiPlayer ai, {
  Future<bool> Function(int proposedCubeValue)? onOfferDouble,
  Future<void> Function(GammonMove move)? onMove,
}) async {
  if (state.gameOver || state.turnPlayer == null) return;

  // The AI may double before playing its dice.
  if (state.canOfferDouble(state.turnPlayer)) {
    final decision = await ai.cubeDecision(positionFromState(state));
    if (decision == BgCubeAction.offerDouble) {
      final taken = (await onOfferDouble?.call(state.cube.value * 2)) ?? true;
      if (taken) {
        state.acceptDouble();
      } else {
        state.declineDouble(); // the opponent passed: the AI wins
        return;
      }
    }
  }
  if (state.gameOver) return;

  final turn = await ai.chooseTurn(positionFromState(state));
  for (final move in turn.moves) {
    if (onMove != null) {
      await onMove(move);
    } else {
      state.applyMove(move: move);
    }
    if (state.gameOver) return;
  }
  if (!state.gameOver) state.commitTurn();
}

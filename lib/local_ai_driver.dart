import 'dart:async';

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

/// Drives one side of a local game with a [BgAiPlayer]. Listens to the shared
/// [GammonState]; when it becomes [aiSide]'s turn it plays a full turn with
/// human-style pacing. The human plays the other side through the UI as usual.
class LocalAiDriver {
  /// Attaches to the game state and starts driving [aiSide] with the given AI.
  LocalAiDriver(
    this._state,
    this._ai,
    this.aiSide, {
    this.thinkDelay = const Duration(milliseconds: 700),
    this.moveDelay = const Duration(milliseconds: 450),
    this.onChanged,
  }) {
    _state.addListener(_onStateChanged);
    unawaited(_maybeAct());
  }

  final GammonState _state;
  final BgAiPlayer _ai;

  /// The side this driver plays.
  final GammonPlayer aiSide;

  /// Pause before the AI starts moving (so it feels like it's "thinking").
  final Duration thinkDelay;

  /// Pause between the AI's individual checker moves.
  final Duration moveDelay;

  /// Called after the AI mutates the game (so the UI can refresh, since
  /// `GammonState.commitTurn` does not itself notify listeners).
  final void Function()? onChanged;

  var _busy = false;
  var _stopped = false;

  /// Stop driving and release the AI.
  void dispose() {
    _stopped = true;
    _state.removeListener(_onStateChanged);
    _ai.dispose();
  }

  void _onStateChanged() => unawaited(_maybeAct());

  Future<void> _maybeAct() async {
    if (_stopped || _busy) return;
    if (_state.gameOver || _state.turnPlayer != aiSide) return;
    _busy = true;
    try {
      await _delay(thinkDelay);
      if (_stopped || _state.gameOver || _state.turnPlayer != aiSide) return;
      final turn = await _ai.chooseTurn(positionFromState(_state));
      for (final move in turn.moves) {
        if (_stopped || _state.gameOver) break;
        _state.applyMove(move: move);
        onChanged?.call();
        await _delay(moveDelay);
      }
      if (!_stopped && !_state.gameOver) {
        _state.commitTurn();
        onChanged?.call();
      }
    } finally {
      _busy = false;
    }
  }

  Future<void> _delay(Duration d) =>
      d == Duration.zero ? Future<void>.value() : Future<void>.delayed(d);
}

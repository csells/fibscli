import 'dart:async';

import 'package:flutter/foundation.dart';

import 'board_animator.dart';
import 'dice.dart';
import 'fibs_state.dart';
import 'main.dart';
import 'model.dart';
import 'pieces.dart';

// The turn-building state machine behind the FIBS play view, extracted out of
// the widget so it has no BuildContext and can be unit-tested. It owns the
// LOCAL working turn (the same mechanic as the local game: make your moves,
// undo freely, then tap the dice to submit the WHOLE turn -- FIBS wants the
// complete turn in one command, so we only talk to the server on submit), plus
// the diff-based board animation (FIBS only ever hands us whole boards, never
// move deltas, so a fresh board is animated by diffing against the previous
// one). It listens to [FibsState] and notifies its own listeners (the view) on
// every change.
class FibsPlayController extends ChangeNotifier {
  FibsPlayController({FibsState? fibs}) : _fibs = fibs ?? App.fibs {
    _prevBoard = _boardCopy();
    _prevDice = _diceSnapshot();
    _fibs.addListener(_onFibsChanged);
  }

  final FibsState _fibs;

  // The shared BoardAnimator owns the in-flight tween lifecycle (same one the
  // local game uses); the view hands it to its GameBoard.
  final BoardAnimator animator = BoardAnimator();

  // The in-progress turn, non-null only while it's our move; null when watching
  // the opponent.
  GammonState? _turn;
  final _moves = <GammonMove>[]; // the moves made this turn, to submit

  // The last board we saw + the dice in play on it -- i.e. the dice that
  // PRODUCED the move we animate when the next board arrives. We must capture
  // them from the board we move FROM: by the time the result board lands, those
  // dice are already gone, so reading them then would give the wrong dice.
  List<List<int>>? _prevBoard;
  List<int> _prevDice = const [];

  // --- read surface for the view ------------------------------------------

  /// The board to render: our local working turn while it's ours, else the live
  /// (read-only) board.
  GammonState get displayGame => _turn ?? _fibs.gameState!;

  /// Whether the board is interactive (our move, editing a local turn).
  bool get interactive => _turn != null;

  /// Legal moves to highlight (empty when it isn't our move).
  Map<int, List<GammonMove>> get legalMoves =>
      _turn?.getAllLegalMoves() ?? const {};

  /// Whether there's a move this turn to undo.
  bool get canUndo => _moves.isNotEmpty;

  /// A pure race on our turn -> offer to auto bear-off (no decision affects the
  /// outcome, so it's tedium reduction, not the bot playing for us).
  bool get canAutoBearOff => _turn != null && GammonRules.isRace(_turn!.board);

  /// Our turn, a move started, and no more legal moves -> ready to submit.
  bool get turnComplete => _turn != null && _turn!.getAllLegalMoves().isEmpty;

  // --- turn lifecycle ------------------------------------------------------

  /// Reconcile the working turn with whose move it is. Idempotent and
  /// side-effect-light, so the view calls it from build too (covers entering
  /// the view already on our move, when no notification fires). Never clobbers
  /// an in-progress turn.
  void syncTurn() {
    if (_fibs.canMoveNow && _turn == null) {
      _turn = _freshTurn();
      _moves.clear();
    } else if (!_fibs.canMoveNow && _turn != null) {
      _turn = null;
      _moves.clear();
    }
  }

  void _onFibsChanged() {
    syncTurn();

    final cur = _fibs.gameState?.board;
    if (cur != null) {
      // Animate a whole-board change (the opponent's play, or our committed
      // turn coming back) only when we're NOT mid-edit -- our own in-progress
      // moves animate themselves as we make them. Use the PREVIOUS board's dice
      // so a multi-hop move animates through each pip rather than sliding
      // straight.
      if (_turn == null &&
          _prevBoard != null &&
          Position.fromBoard(_prevBoard!) != Position.fromBoard(cur) &&
          !animator.isAnimating) {
        unawaited(
          animator.play(
            MoveAnimation.between(_prevBoard!, cur, dice: _prevDice),
          ),
        );
      }
      _prevBoard = _boardCopy();
      _prevDice = _diceSnapshot();
    }
    // rebuild the view on every FIBS change (turn state, waiting/roll/double)
    notifyListeners();
  }

  /// Apply a move to the LOCAL working turn (no server traffic yet): find the
  /// hops, record the move to submit later, and animate it on the shared board.
  /// Returns whether the move was legal/applied.
  bool applyLocalMove(int fromPip, int toPip) {
    final turn = _turn;
    if (turn == null) return false;
    final hops = GammonRules.preferredHops(
      turn.board,
      turn.getAllLegalMoves()[fromPip] ?? const <GammonMove>[],
      fromPipNo: fromPip,
      toPipNo: toPip,
    );
    if (hops == null) return false;
    final move = GammonMove(fromPipNo: fromPip, toPipNo: toPip, hops: hops);
    _moves.add(move);

    final initial = [for (final c in turn.board) List<int>.of(c)];
    final deltas = turn.applyMove(move: move);
    notifyListeners(); // legal moves / dice changed
    unawaited(animator.play(MoveAnimation.forMove(initial, deltas)));
    return true;
  }

  /// Play the whole current turn greedily (via the engine's shared bear-off
  /// policy) and submit it. Only sensible in a pure race ([canAutoBearOff]).
  void autoBearOff() {
    final turn = _turn;
    if (turn == null) return;
    final dice = turn.dice
        .where((d) => d.available)
        .map((d) => d.roll)
        .toList();
    for (final move in GammonRules.autoBearOffTurn(
      turn.board,
      turn.turnPlayer,
      dice,
    )) {
      _moves.add(move);
      turn.applyMove(move: move);
    }
    submitTurn();
  }

  /// Submit the whole turn -- only once there are no more legal moves to make
  /// (the forced-move rules require using every playable die).
  void submitTurn() {
    final turn = _turn;
    if (turn == null || turn.getAllLegalMoves().isNotEmpty) return;
    // the post-submit board echoes our move, so don't let it re-animate
    _prevBoard = [for (final c in turn.board) List<int>.of(c)];
    _prevDice = const [];
    _fibs.submitTurn(List<GammonMove>.of(_moves));
    _turn = null;
    _moves.clear();
    notifyListeners();
  }

  /// Undo the LAST move made this turn (call again to keep walking back).
  /// Rebuilds the working turn from scratch and replays all but the last move.
  void undoMove() {
    if (_moves.isEmpty) return;
    final replay = _moves.sublist(0, _moves.length - 1);
    final turn = _freshTurn();
    for (final m in replay) {
      turn.applyMove(move: m);
    }
    _turn = turn;
    _moves
      ..clear()
      ..addAll(replay);
    notifyListeners();
  }

  // A fresh working copy of the current (viewer) board to build our turn on.
  GammonState _freshTurn() {
    final gs = _fibs.gameState!;
    return GammonState.from(
      board: gs.board,
      dice: [for (final d in gs.dice) DieState(d.roll)],
      turnPlayer: gs.turnPlayer,
      moveNo: 2, // a normal FIBS roll: both dice are ours, not the opening
    );
  }

  List<List<int>>? _boardCopy() {
    final board = _fibs.gameState?.board;
    return board == null ? null : [for (final c in board) List<int>.of(c)];
  }

  // the dice the on-roll player has in play on the current board
  List<int> _diceSnapshot() =>
      _fibs.gameState?.dice.map((d) => d.roll).toList() ?? const <int>[];

  @override
  void dispose() {
    _fibs.removeListener(_onFibsChanged);
    animator.dispose();
    super.dispose();
  }
}

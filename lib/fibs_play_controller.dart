import 'dart:async';

import 'package:flutter/foundation.dart';

import 'board_animator.dart';
import 'dice.dart';
import 'fibs_state.dart';
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
  // A named initializing formal can't target a private field (_fibs), so we
  // assign in the initializer list instead.
  // ignore: prefer_initializing_formals
  FibsPlayController({required FibsState fibs})
    : _fibs = fibs,
      _seenCookieCount = fibs.cookieCount {
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
  GammonState? _submittedTurn;
  final _moves = <GammonMove>[]; // the moves made this turn, to submit
  int _seenCookieCount;

  // The last board we saw + the dice in play on it -- i.e. the dice that
  // PRODUCED the move we animate when the next board arrives. We must capture
  // them from the board we move FROM: by the time the result board lands, those
  // dice are already gone, so reading them then would give the wrong dice.
  List<List<int>>? _prevBoard;
  List<int> _prevDice = const [];

  // --- read surface for the view ------------------------------------------

  /// The board to render: our local working turn while it's ours, else the live
  /// (read-only) board.
  GammonState get displayGame => _turn ?? _submittedTurn ?? _fibs.gameState!;

  /// Whether the board is interactive (our move, editing a local turn).
  bool get interactive => _turn != null && !_autoBearOffBusy;

  /// Legal moves to highlight (empty when it isn't our move).
  Map<int, List<GammonMove>> get legalMoves =>
      _turn?.getAllLegalMoves() ?? const {};

  /// Whether there's a move this turn to undo.
  bool get canUndo => _moves.isNotEmpty && !_autoBearOffBusy;

  /// A pure race on our turn -> offer to auto bear-off (no decision affects the
  /// outcome, so it's tedium reduction, not the bot playing for us).
  bool get canAutoBearOff =>
      _turn != null && !_autoBearOffBusy && GammonRules.isRace(_turn!.board);

  // Once enabled, keep auto-playing our bear-off turns as they come. FIBS deals
  // dice one turn at a time (so, unlike the local game, we can't finish the
  // race in a single action), but we can spare the user a tap on every one of
  // turns until contact resumes or the game ends.
  bool _autoBearOff = false;
  bool _autoBearOffBusy = false;

  /// Our turn, a move started, and no more legal moves -> ready to submit.
  bool get turnComplete => _turn != null && _turn!.getAllLegalMoves().isEmpty;

  // --- turn lifecycle ------------------------------------------------------

  /// Reconcile the working turn with whose move it is. Idempotent and
  /// side-effect-light, so the view calls it from build too (covers entering
  /// the view already on our move, when no notification fires). Never clobbers
  /// an in-progress turn.
  void syncTurn({bool freshBoard = false}) {
    if (freshBoard) {
      _submittedTurn = null;
    } else if (_submittedTurn != null && _fibs.canMoveNow) {
      _turn = _freshTurn(
        boardOverride: _fibs.lastCommandRejected ? null : _submittedTurn!.board,
      );
      _submittedTurn = null;
      _moves.clear();
      return;
    } else if (_submittedTurn != null) {
      return;
    }

    if (_fibs.canMoveNow && _turn == null) {
      _turn = _freshTurn();
      _moves.clear();
    } else if (!_fibs.canMoveNow && _turn != null) {
      _turn = null;
      _moves.clear();
    }
  }

  void _onFibsChanged() {
    final advanced = _fibs.cookieCount != _seenCookieCount;
    final lastCookie = _fibs.lastCookie;
    final freshBoard = advanced && lastCookie == 'FIBS_Board';
    final opponentRolled = advanced && lastCookie == 'FIBS_PlayerRolls';
    final commandRejected = advanced && _fibs.lastCommandRejected;
    _seenCookieCount = _fibs.cookieCount;
    if (commandRejected) _autoBearOff = false;
    syncTurn(freshBoard: freshBoard);

    // Continue an enabled auto-bear-off onto our next turn (a fresh, un-started
    // race turn). Stop the moment contact resumes -- then it's a real decision
    // again and the user takes over.
    if (_autoBearOff && !_autoBearOffBusy && _turn != null && _moves.isEmpty) {
      if (GammonRules.isRace(_turn!.board)) {
        unawaited(_playAutoBearOffTurn());
      } else {
        _autoBearOff = false;
      }
    }

    final cur = _fibs.gameState?.board;
    if (cur != null) {
      if (_submittedTurn != null && opponentRolled) {
        _prevDice = _diceSnapshot();
      }
      // Animate a whole-board change (the opponent's play, or our committed
      // turn coming back) only when we're NOT mid-edit -- our own in-progress
      // moves animate themselves as we make them. Use the PREVIOUS board's dice
      // so a multi-hop move animates through each pip rather than sliding
      // straight.
      if (_turn == null &&
          _submittedTurn == null &&
          _prevBoard != null &&
          Position.fromBoard(_prevBoard!) != Position.fromBoard(cur) &&
          !animator.isAnimating) {
        unawaited(
          animator.play(
            MoveAnimation.between(_prevBoard!, cur, dice: _prevDice),
          ),
        );
      }
      if (_submittedTurn == null) {
        _prevBoard = _boardCopy();
        _prevDice = _diceSnapshot();
      }
    }
    // rebuild the view on every FIBS change (turn state, waiting/roll/double)
    notifyListeners();
  }

  /// Apply a move to the LOCAL working turn (no server traffic yet): find the
  /// hops, record the move to submit later, and animate it on the shared board.
  /// Returns whether the move was legal/applied.
  bool applyLocalMove(int fromPip, int toPip) {
    if (animator.isAnimating) return false;
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
    unawaited(_applyMoveAnimated(move));
    return true;
  }

  /// Enable auto bear-off and play the current turn. Stays enabled so each of
  /// our subsequent race turns plays itself (see [_onFibsChanged]). Only
  /// sensible in a pure race ([canAutoBearOff]).
  void autoBearOff() {
    _autoBearOff = true;
    unawaited(_playAutoBearOffTurn());
  }

  Future<bool> _applyMoveAnimated(GammonMove move) async {
    final turn = _turn;
    if (turn == null) return false;

    final initial = [for (final c in turn.board) List<int>.of(c)];
    final deltas = turn.applyMove(move: move);
    if (deltas.isEmpty) return false;
    _moves.add(move);
    notifyListeners(); // legal moves / dice changed
    await animator.play(MoveAnimation.forMove(initial, deltas));
    return true;
  }

  // Play the current turn greedily (via the engine's shared bear-off policy),
  // showing each checker move before submitting the completed turn to FIBS.
  Future<void> _playAutoBearOffTurn() async {
    if (_turn == null || _autoBearOffBusy) return;

    _autoBearOffBusy = true;
    notifyListeners();
    try {
      while (_turn != null && _turn!.getAllLegalMoves().isNotEmpty) {
        final move = _nextAutoBearOffMove();
        if (move == null) {
          _autoBearOff = false;
          return;
        }
        final applied = await _applyMoveAnimated(move);
        if (!applied) {
          _autoBearOff = false;
          return;
        }
      }
      submitTurn();
    } finally {
      _autoBearOffBusy = false;
      notifyListeners();
    }
  }

  GammonMove? _nextAutoBearOffMove() {
    final turn = _turn;
    if (turn == null) return null;
    final dice = turn.dice
        .where((d) => d.available)
        .map((d) => d.roll)
        .toList();
    final moves = GammonRules.autoBearOffTurn(
      turn.board,
      turn.turnPlayer,
      dice,
    );
    return moves.isEmpty ? null : moves.first;
  }

  /// Submit the whole turn -- only once there are no more legal moves to make
  /// (the forced-move rules require using every playable die).
  void submitTurn() {
    final turn = _turn;
    if (turn == null || turn.getAllLegalMoves().isNotEmpty) return;
    final moves = List<GammonMove>.of(_moves);
    // the post-submit board echoes our move, so don't let it re-animate
    _prevBoard = [for (final c in turn.board) List<int>.of(c)];
    _prevDice = const [];
    _submittedTurn = turn;
    _turn = null;
    _moves.clear();
    try {
      _fibs.submitTurn(moves);
    } on Object {
      _submittedTurn = null;
      _turn = turn;
      _moves.addAll(moves);
      rethrow;
    } finally {
      notifyListeners();
    }
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
  GammonState _freshTurn({List<List<int>>? boardOverride}) {
    final gs = _fibs.gameState!;
    return GammonState.from(
      board: boardOverride ?? gs.board,
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

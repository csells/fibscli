import 'package:flutter/material.dart';

import 'board_animator.dart';
import 'board_view.dart';
import 'model.dart';
import 'tinystate.dart';

/// The one and only interactive board widget, shared by the local game and the
/// FIBS client. It owns the tap-to-move selection, renders the board via
/// [BoardView], and shows whatever the [animator] is tweening.
///
/// What differs between the two modes is NOT the board -- it's what a move
/// *does*: the host applies or submits the move and feeds [animator]. Local and
/// FIBS play use the same renderer/animator path. Everything mode-specific (the
/// AI loop, cube dialogs, FIBS roll/double controls, the app bar) lives in the
/// host screen, not here.
class GameBoard extends StatefulWidget {
  const GameBoard({
    required this.game,
    this.animator,
    this.legalMoves = const {},
    this.interactive = false,
    this.onMove,
    this.reversed = false,
    this.onTapDice,
    this.onTapCube,
    super.key,
  });

  /// The game model to render.
  final GammonState game;

  /// The in-flight checker animation. When null (e.g. a read-only watch view)
  /// the board owns an empty one and simply shows no animation.
  final BoardAnimator? animator;

  /// Legal destinations keyed by from-pip, used to highlight and gate taps.
  final Map<int, List<GammonMove>> legalMoves;

  /// Whether the human may interact right now (their turn, not animating/AI).
  final bool interactive;

  /// Perform the move from a source pip to a destination pip; returns whether
  /// it was made. Locally that means applying + animating it; over FIBS,
  /// sending it to the server. A false return lets the board re-select. Null
  /// (with [interactive] false) makes the board read-only (a spectator view).
  final bool Function(int fromPip, int toPip)? onMove;

  /// Whether to rotate the board 180° (local hot-seat convenience).
  final bool reversed;

  /// Tap on the dice (local: end/commit the turn). Null disables it.
  final VoidCallback? onTapDice;

  /// Tap on the cube (local: offer a double). Null disables it.
  final VoidCallback? onTapCube;

  @override
  State<GameBoard> createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  int? _selected;
  // a fallback animator for a read-only board that wasn't given one
  BoardAnimator? _ownAnimator;
  BoardAnimator get _animator =>
      widget.animator ?? (_ownAnimator ??= BoardAnimator());

  @override
  void dispose() {
    _ownAnimator?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(GameBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Drop a stale selection once it's no longer playable (the turn passed, the
    // board changed, or interaction was disabled) so nothing stays highlighted.
    if (_selected != null &&
        (!widget.interactive || widget.legalMoves[_selected] == null)) {
      _selected = null;
    }
  }

  void _tapPip(int pip) {
    final from = _selected;
    if (from == null) {
      // first tap: select a from-pip only if it can actually move
      if (widget.legalMoves[pip] != null) setState(() => _selected = pip);
      return;
    }
    // second tap: attempt the move
    if (widget.onMove?.call(from, pip) ?? false) {
      setState(() => _selected = null);
    } else {
      // illegal destination: re-select the tapped pip if IT can move, else
      // toggle the selection off (tapping the same pip clears it).
      setState(
        () => _selected = from != pip && widget.legalMoves[pip] != null
            ? pip
            : null,
      );
    }
  }

  void _tapOff(GammonPlayer player) {
    final from = _selected;
    if (from == null) return;
    widget.onMove?.call(from, GammonRules.offPipNoFor(player)); // bear off
    setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<BoardAnimator>(
    notifier: _animator,
    builder: (context, animator, child) {
      final animating = animator.isAnimating;
      final interactive = widget.interactive && !animating;
      return BoardView(
        game: widget.game,
        legalMoves: interactive ? widget.legalMoves : const {},
        selectedPip: animating ? null : _selected,
        reversed: widget.reversed,
        ignoring: !interactive,
        onTapPip: interactive ? _tapPip : null,
        onTapOff: interactive ? _tapOff : null,
        onTapCube: interactive ? widget.onTapCube : null,
        onTapDice: interactive ? widget.onTapDice : null,
        onTapBoard: interactive ? () => setState(() => _selected = null) : null,
        pieceAnimations: animator.layouts,
        pieceDelays: animator.delays,
        onPieceAnimationEnd: animator.endPiece,
      );
    },
  );
}

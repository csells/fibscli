import 'dart:async';

import 'package:flutter/foundation.dart';

import 'pieces.dart';

/// Owns the in-flight checker animation for a board view: the per-piece tween
/// layouts, their start delays, and a completion signal. Both board hosts (the
/// local game and the FIBS play view) drive the SAME animator -- they differ
/// only in how they *build* a [MoveAnimation] (the local game tweens through
/// each hop with hit-delays via [MoveAnimation.forMove]; FIBS diffs whole
/// boards via [MoveAnimation.between]). This is the stateful coordination both
/// used to hand-roll and drift on; it now lives in one tested place.
class BoardAnimator extends ChangeNotifier {
  final _layouts = <int?, List<PieceLayout>>{};
  final _delays = <int?, Duration>{};
  Completer<void>? _done;

  /// The per-piece tween paths the view renders (empty when settled).
  Map<int?, List<PieceLayout>> get layouts => _layouts;

  /// Per-piece start delays (e.g. a hittee waits for the hitter to arrive).
  Map<int?, Duration> get delays => _delays;

  /// Whether a move is currently being animated.
  bool get isAnimating => _layouts.isNotEmpty;

  /// Start animating [anim]; the returned future completes once every piece has
  /// finished (immediately, with no redraw, when there's nothing to animate).
  Future<void> play(MoveAnimation anim) {
    assert(_layouts.isEmpty, 'an animation is already in flight');
    if (anim.layouts.isEmpty) return Future<void>.value();
    _layouts.addAll(anim.layouts);
    _delays.addAll(anim.delays);
    _done = Completer<void>();
    notifyListeners();
    return _done!.future;
  }

  /// Called by the view when a piece's tween finishes. Once the last piece is
  /// done, redraw the settled board (labels, edges, final stacks) and complete.
  void endPiece(int? pieceId) {
    _layouts.remove(pieceId);
    _delays.remove(pieceId);
    if (_layouts.isEmpty) {
      notifyListeners();
      _done?.complete();
      _done = null;
    }
  }
}

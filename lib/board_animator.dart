import 'dart:async';

import 'package:flutter/foundation.dart';

import 'pieces.dart';

/// Owns the in-flight checker animation for a board view: the per-piece tween
/// layouts, their start delays, and a completion signal. Both board hosts (the
/// local game and the FIBS play view) drive the SAME animator -- they differ
/// only in how they *build* a [MoveAnimation] (the local game tweens through
/// each hop with hit-delays via [MoveAnimation.forMove]; FIBS diffs whole
/// boards via [MoveAnimation.between]). Centralizing the in-flight tween
/// lifecycle here keeps it in one tested place.
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
  ///
  /// Serialized: if a move is still in flight (a fast second tap, or an AI move
  /// landing on the tail of the human's animation), this waits for it to settle
  /// before starting rather than clobbering the in-flight tweens.
  Future<void> play(MoveAnimation anim) async {
    while (isAnimating) {
      await _done!.future;
    }
    if (anim.layouts.isEmpty) return;
    _layouts.addAll(anim.layouts);
    _delays.addAll(anim.delays);
    _done = Completer<void>();
    notifyListeners();
    await _done!.future;
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

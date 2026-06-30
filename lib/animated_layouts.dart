import 'dart:async';

import 'package:flutter/widgets.dart';

import 'pieces.dart';

class AnimatedPiece extends StatefulWidget {
  const AnimatedPiece.fromLayouts({
    required this.layouts,
    required this.child,
    this.onEnd = _noop,
    this.delay = Duration.zero,
    super.key,
  }) : assert(layouts.length > 1);

  final List<PieceLayout> layouts;
  final Widget child;
  final void Function() onEnd;
  final Duration delay;

  @override
  _AnimatedPieceState createState() => _AnimatedPieceState();

  static void _noop() {}
}

class _AnimatedPieceState extends State<AnimatedPiece>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<PieceLayout> _animation;

  @override
  void initState() {
    super.initState();

    final hops = widget.layouts.length - 1;

    // Fixed duration per hop (not distance-proportional), so a 1-pip nudge and
    // a bar flight take the same beat and the rhythm stays steady move-to-move.
    _controller = AnimationController(
      vsync: this,
      duration: kHopAnimationDuration * hops,
    );

    // The easing is applied per hop inside _animatableFor (each hop eases in
    // AND out), so the controller itself drives the sequence linearly.
    _animation = _animatableFor(widget.layouts).animate(_controller);

    // a hittee waits for the hitter to arrive before sliding to the bar
    // (issue #5); during the delay it stays at its first layout
    void start() {
      if (!mounted) return;
      unawaited(_controller.forward().then((_) => widget.onEnd()));
    }

    if (widget.delay == Duration.zero) {
      start();
    } else {
      unawaited(Future<void>.delayed(widget.delay, start));
    }
  }

  // Each hop is its own equal-weight (equal-time) ease-in-out slide, run back
  // to back with no frozen pauses between them: a doubles move reads as
  // "slide... slide... slide", with every hop accelerating off its start and
  // decelerating into its destination (matches the Android app's feel).
  // easeInOutSine is the raised cosine (1 - cos(pi*t)) / 2 the Android app uses.
  static Animatable<PieceLayout> _animatableFor(List<PieceLayout> layouts) =>
      TweenSequence([
        for (var i = 1; i != layouts.length; ++i)
          TweenSequenceItem(
            tween: PieceLayoutTween(
              begin: layouts[i - 1],
              end: layouts[i],
            ).chain(CurveTween(curve: Curves.easeInOutSine)),
            weight: 1,
          ),
      ]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) =>
        Positioned.fromRect(rect: _animation.value.rect, child: child!),
    child: widget.child,
  );
}

class PieceLayoutTween extends Tween<PieceLayout> {
  PieceLayoutTween({required PieceLayout begin, required PieceLayout end})
    : assert(begin.highlight == end.highlight),
      assert(begin.pieceID == end.pieceID),
      super(begin: begin, end: end) {
    // only the offset and the pipno changes (accept when it doesn't...)
    // assert(begin.offset != end.offset);
    // assert(begin.pipNo != end.pipNo);

    // label could change...
    // assert(begin.label == end.label);
    // assert(begin.edge == end.edge);
  }

  @override
  PieceLayout lerp(double t) => PieceLayout(
    pipNo: 0, // used?
    pieceID: begin!.pieceID,
    offset: Offset.lerp(
      begin!.offset,
      end!.offset,
      t,
    ), // only the offset changes
    label: '', // used?
    highlight: begin!.highlight,
    edge: begin!.edge,
  );
}

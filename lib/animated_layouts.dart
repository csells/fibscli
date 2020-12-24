import 'package:fibscli/pieces.dart';
import 'package:flutter/widgets.dart';

class AnimatedLayouts extends StatefulWidget {
  final List<PieceLayout> layouts;
  final void Function() onEnd;
  final Widget child;

  AnimatedLayouts({this.layouts, this.child, this.onEnd = _noop})
      : assert(layouts != null),
        assert(layouts.length > 1),
        assert(onEnd != null),
        assert(child != null);

  @override
  _AnimatedLayoutsState createState() => _AnimatedLayoutsState();

  static void _noop() {}
}

class _AnimatedLayoutsState extends State<AnimatedLayouts> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<PieceLayout> _animation;

  @override
  void initState() {
    super.initState();

    final animatable = _animatableFor(widget.layouts);
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _animation = animatable.animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward().then((_) => widget.onEnd());
  }

  static Animatable<PieceLayout> _animatableFor(List<PieceLayout> layouts) => TweenSequence(
        [
          for (var i = 1; i != layouts.length; ++i)
            TweenSequenceItem(tween: PieceLayoutTween(begin: layouts[i - 1], end: layouts[i]), weight: 1),
        ],
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Positioned.fromRect(rect: _animation.value.rect, child: child),
        child: widget.child,
      );
}

class PieceLayoutTween extends Tween<PieceLayout> {
  PieceLayoutTween({PieceLayout begin, PieceLayout end}) : super(begin: begin, end: end) {
    // these things shouldn't change...
    assert(begin.edge == end.edge);
    assert(begin.highlight == end.highlight);
    assert(begin.label == end.label);
    assert(begin.pieceID == end.pieceID);
    assert(begin.pipNo == end.pipNo);

    // only the offset changes
    assert(begin.offset != end.offset);
  }

  @override
  PieceLayout lerp(double t) => PieceLayout(
        pipNo: begin.pipNo,
        pieceID: begin.pieceID,
        offset: Offset.lerp(begin.offset, end.offset, t), // only the offset changes
        label: begin.label,
        highlight: begin.highlight,
        edge: begin.edge,
      );
}

import 'package:fibscli/pieces.dart';
import 'package:flutter/widgets.dart';
import 'package:dartx/dartx.dart';

class AnimatedLayouts extends StatefulWidget {
  final List<PieceLayout> layouts;
  final Widget child;

  AnimatedLayouts({
    @required this.layouts,
    @required this.child,
  })  : assert(layouts != null),
        assert(layouts.length > 1),
        assert(child != null);

  @override
  _AnimatedLayoutsState createState() => _AnimatedLayoutsState();
}

class _AnimatedLayoutsState extends State<AnimatedLayouts> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<PieceLayout> _animation;

  @override
  void initState() {
    super.initState();

    final distance = [
      for (var i = 1; i != widget.layouts.length; ++i)
        (widget.layouts[i - 1].offset - widget.layouts[i].offset).distance
    ].sum();
    final animatable = _animatableFor(widget.layouts);
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: (distance * 1.5).floor()));
    _animation = animatable.animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward();
  }

  static Animatable<PieceLayout> _animatableFor(List<PieceLayout> layouts) => TweenSequence(
        [
          for (var i = 1; i != layouts.length; ++i) ...[
            TweenSequenceItem(
              tween: PieceLayoutTween(begin: layouts[i - 1], end: layouts[i]),
              weight: (layouts[i - 1].offset - layouts[i].offset).distance + 1,
            ),
            TweenSequenceItem(
              tween: ConstantTween(layouts[i]),
              weight: 100,
            ),
          ],
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
    assert(begin.pieceID == end.pieceID);

    // only the offset and the pipno changes (accept when it doesn't...)
    // assert(begin.offset != end.offset);
    // assert(begin.pipNo != end.pipNo);

    // label could change...
    // assert(begin.label == end.label);
  }

  @override
  PieceLayout lerp(double t) => PieceLayout(
        pipNo: 0, // used?
        pieceID: begin.pieceID,
        offset: Offset.lerp(begin.offset, end.offset, t), // only the offset changes
        label: '', // used?
        highlight: begin.highlight,
        edge: begin.edge,
      );
}

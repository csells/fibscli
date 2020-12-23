import 'package:flutter/widgets.dart';

class AnimatedPositions extends StatefulWidget {
  final List<Offset> positions;
  final Size size;
  final Widget child;
  final void Function() onEnd;

  AnimatedPositions({this.positions, this.size, this.child, this.onEnd = _noop})
      : assert(positions != null),
        assert(positions.isNotEmpty),
        assert(size != null),
        assert(onEnd != null),
        assert(child != null);

  @override
  _AnimatedPositionsState createState() => _AnimatedPositionsState();

  static void _noop() {}
}

class _AnimatedPositionsState extends State<AnimatedPositions> with TickerProviderStateMixin {
  AnimationController _controller;
  Animation<Offset> _animation;

  @override
  void initState() {
    super.initState();

    final animatable = _animatableFor(widget.positions);
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: 250));
    _animation = animatable.animate(CurvedAnimation(parent: _controller, curve: Curves.linear));
    _controller.forward().then((_) => widget.onEnd());
  }

  static Animatable<Offset> _animatableFor(List<Offset> positions) {
    assert(positions != null && positions.isNotEmpty);
    if (positions.length == 1) return ConstantTween(positions[0]);

    return TweenSequence(
      [
        for (var i = 1; i != positions.length; ++i)
          TweenSequenceItem(
            tween: Tween(
              begin: Offset(positions[i - 1].dx, positions[i - 1].dy),
              end: Offset(positions[i].dx, positions[i].dy),
            ),
            weight: 1,
          ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Positioned.fromRect(rect: _animation.value & widget.size, child: child),
        child: widget.child,
      );
}

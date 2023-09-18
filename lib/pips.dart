import 'package:flutter/material.dart';

class PipLabel extends StatelessWidget {
  const PipLabel({required this.layout, super.key, this.reversed = false});
  final bool reversed;
  final PipLayout layout;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: reversed ? 2 : 0,
          child: Text(
            layout.pipNo.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black, fontSize: 10),
          ),
        ),
      );
}

class PipTriangle extends StatelessWidget {
  PipTriangle({required this.pip, required this.highlight, super.key})
      : painter = PipPainter(
          pip: pip,
          clipper: PipClipper(pip),
          highlight: highlight,
        );

  final int pip;
  final bool highlight;
  final PipPainter painter;

  @override
  Widget build(BuildContext context) =>
      ClipPath(clipper: painter.clipper, child: CustomPaint(painter: painter));
}

class PipLayout {
  PipLayout({
    required this.pipNo,
    required this.left,
    required this.top,
    required this.labelDy,
  });
  static List<PipLayout>? _layouts;
  static const double width = 34;
  static const double height = 150;
  static const double labelHeight = 15;

  final int pipNo;
  final double left;
  final double top;
  final double labelDy;

  Rect get rect => Rect.fromLTWH(left, top, width, height);
  Rect get labelRect => Rect.fromLTWH(left, top + labelDy, width, labelHeight);

  static List<PipLayout>? get layouts {
    if (_layouts == null) {
      final layouts = <PipLayout>[];
      for (var j = 0; j != 4; j++) {
        for (var i = 0; i != 6; ++i) {
          final pip = j * 6 + (j < 2 ? 6 - i : i + 1);
          final dx = (width + 2) * i;

          // bottom-right
          if (pip >= 1 && pip <= 6) {
            layouts.add(PipLayout(
                pipNo: pip, left: 285 + dx, top: 249, labelDy: height + 1));
          }
          // bottom-left
          else if (pip >= 7 && pip <= 12) {
            layouts.add(PipLayout(
                pipNo: pip, left: 21 + dx, top: 249, labelDy: height + 1));
          }
          // top-left
          else if (pip >= 13 && pip <= 18) {
            layouts.add(PipLayout(
                pipNo: pip, left: 21 + dx, top: 21, labelDy: -labelHeight - 1));
          }
          // top-right
          else if (pip >= 19 && pip <= 24) {
            layouts.add(PipLayout(
                pipNo: pip,
                left: 285 + dx,
                top: 21,
                labelDy: -labelHeight - 1));
          }
          // error
          else {
            assert(false, 'pip: $pip');
            throw Exception('unreachable');
          }
        }
      }

      _layouts = List.unmodifiable(layouts);
    }

    return _layouts;
  }
}

class PipPainter extends CustomPainter {
  PipPainter({required int pip, required this.clipper, required this.highlight})
      : _color = pip.isOdd ? _lightColor : _darkColor;
  static final _lightColor = Colors.grey[300];
  static const _darkColor = Colors.grey;

  final PipClipper clipper;
  final Color? _color;
  final bool highlight;

  @override
  void paint(Canvas canvas, Size size) {
    // draw the pip
    final path = clipper.getClip(size);
    final paint = Paint();
    paint.color = _color!;
    canvas.drawPath(path, paint);

    // highlight or outline the pip
    if (highlight) {
      paint.strokeWidth = 4.0;
      paint.style = PaintingStyle.stroke;
      paint.color = Colors.yellow;
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// from https://www.developerlibs.com/2019/08/flutter-draw-custom-shaps-clip-path.html
class PipClipper extends CustomClipper<Path> {
  PipClipper(int pip) : _up = pip < 13;
  final bool _up;

  @override
  Path getClip(Size size) {
    final path = Path();
    if (_up) {
      path.moveTo(0, size.height);
      path.lineTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
    } else {
      path.lineTo(size.width / 2, size.height);
      path.lineTo(size.width, 0);
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

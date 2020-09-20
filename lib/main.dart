import 'package:flutter/material.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  static const title = 'Backgammon';
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: title,
        theme: ThemeData(
          primarySwatch: Colors.green,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: HomePage(),
      );
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(App.title)),
        body: GameBoard(),
      );
}

class GameBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FittedBox(
          child: Stack(
            children: [
              // frame
              Container(
                width: 574,
                height: 420,
                decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 5)),
              ),

              // outer board
              Positioned.fromRect(
                rect: Rect.fromLTWH(20, 20, 216, 380),
                child: Container(
                  decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                ),
              ),

              // inner board
              Positioned.fromRect(
                rect: Rect.fromLTWH(284, 20, 216, 380),
                child: Container(
                  decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                ),
              ),

              // pips and labels
              for (final layout in PipLayout.layouts) ...[
                Positioned.fromRect(rect: layout.rect, child: PipTriangle(layout.pip)),
                Positioned.fromRect(rect: layout.labelRect, child: PipLabel(layout: layout)),
              ],

              // player1 home
              Positioned.fromRect(
                rect: Rect.fromLTWH(520, 220, 32, 180),
                child: Container(
                  decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                ),
              ),

              // player2 home
              Positioned.fromRect(
                rect: Rect.fromLTWH(520, 20, 32, 180),
                child: Container(
                  decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                ),
              ),

              // doubling cube: undoubled
              Positioned.fromRect(
                rect: Rect.fromLTWH(238, 186, 44, 44),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Center(child: Text('64', textAlign: TextAlign.center)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PipLabel extends StatelessWidget {
  final PipLayout layout;
  const PipLabel({@required this.layout});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Text(
        layout.pip.toString(),
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.black),
      ),
    );
  }
}

class PipTriangle extends StatelessWidget {
  final int pip;
  final PipPainter painter;
  PipTriangle(this.pip) : painter = PipPainter(pip, PipClipper(pip));

  @override
  Widget build(BuildContext context) => ClipPath(clipper: painter.clipper, child: CustomPaint(painter: painter));
}

class PipLayout {
  static List<PipLayout> _layouts;
  static final double width = 34;
  static final double height = 150;
  static final double labelHeight = 15;

  final int pip;
  final double left;
  final double top;
  final double labelDy;
  PipLayout({
    @required this.pip,
    @required this.left,
    @required this.top,
    @required this.labelDy,
  });

  Rect get rect => Rect.fromLTWH(left, top, width, height);
  Rect get labelRect => Rect.fromLTWH(left, top + labelDy, width, labelHeight);

  static List<PipLayout> get layouts {
    if (_layouts == null) {
      final layouts = <PipLayout>[];
      for (var j = 0; j != 4; j++)
        for (var i = 0; i != 6; ++i) {
          final pip = j * 6 + (j < 2 ? 6-i : i + 1);
          final dx = (width + 2) * i;

          // bottom-right
          if (pip >= 1 && pip <= 6) {
            layouts.add(PipLayout(pip: pip, left: 285 + dx, top: 250, labelDy: height - 1));
          }
          // bottom-left
          else if (pip >= 7 && pip <= 12) {
            layouts.add(PipLayout(pip: pip, left: 21 + dx, top: 250, labelDy: height - 1));
          }
          // top-left
          else if (pip >= 13 && pip <= 18) {
            layouts.add(PipLayout(pip: pip, left: 21 + dx, top: 20, labelDy: -labelHeight - 1));
          }
          // top-right
          else if (pip >= 19 && pip <= 24) {
            layouts.add(PipLayout(pip: pip, left: 285 + dx, top: 20, labelDy: -labelHeight - 1));
          }
          // error
          else {
            assert(false, 'pip: $pip');
            throw 'unreachable';
          }
        }

      _layouts = List.unmodifiable(layouts);
    }

    return _layouts;
  }
}

class PipPainter extends CustomPainter {
  static final _lightColor = Colors.grey[300];
  static final _darkColor = Colors.grey;

  final PipClipper clipper;
  final Color _color;
  PipPainter(int pip, this.clipper) : _color = pip.isOdd ? _lightColor : _darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    // draw the pip
    final path = clipper.getClip(size);
    final paint = Paint();
    paint.color = _color;
    canvas.drawPath(path, paint);

    // outline the pip
    paint.strokeWidth = 1.0;
    paint.style = PaintingStyle.stroke;
    paint.color = Colors.black;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

// from https://www.developerlibs.com/2019/08/flutter-draw-custom-shaps-clip-path.html
class PipClipper extends CustomClipper<Path> {
  final bool _up;
  PipClipper(int pip) : _up = pip < 13;

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

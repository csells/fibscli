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

class GameBoard extends StatefulWidget {
  const GameBoard({
    Key key,
  }) : super(key: key);

  @override
  _GameBoardState createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FittedBox(
          child: Stack(
            children: [
              // frame
              Container(width: 574, height: 420, color: Colors.black),

              // outer board
              Positioned.fromRect(
                rect: Rect.fromLTWH(20, 20, 216, 380),
                child: Container(color: Colors.green[900]),
              ),

              // inner board
              Positioned.fromRect(
                rect: Rect.fromLTWH(284, 20, 216, 380),
                child: Container(color: Colors.green[900]),
              ),

              // pips: top-left
              for (var i = 0; i != 6; ++i)
                Positioned.fromRect(
                  rect: Rect.fromLTWH(21 + 36.0 * i, 20, 34, 150),
                  child: Pip(i + 13),
                ),

              // pips: top-right
              for (var i = 0; i != 6; ++i)
                Positioned.fromRect(
                  rect: Rect.fromLTWH(285 + 36.0 * i, 20, 34, 150),
                  child: Pip(i + 19),
                ),

              // bottom-left
              for (var i = 0; i != 6; ++i)
                Positioned.fromRect(
                  rect: Rect.fromLTWH(21 + 36.0 * i, 250, 34, 150),
                  child: Pip(i + 7),
                ),
              // pips: bottom-right
              // <polygon points="284,400 302,250 318,400" fill="grey" stroke="black" />
              for (var i = 0; i != 6; ++i)
                Positioned.fromRect(
                  rect: Rect.fromLTWH(285 + 36.0 * i, 250, 34, 150),
                  child: Pip(i + 1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Pip extends StatelessWidget {
  final int pip;
  final bool boardReversed;
  Pip(this.pip, {bool boardReversed = false}) : boardReversed = boardReversed;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: PipClipper(pip),
      child: CustomPaint(painter: PipPainter(pip)),
    );
  }
}

class PipPainter extends CustomPainter {
  static final _lightColor = Colors.grey[300];
  static final _darkColor = Colors.grey;

  final int pip;
  final Color _color;
  PipPainter(this.pip) : _color = pip.isOdd ? _lightColor : _darkColor;

  @override
  void paint(Canvas canvas, Size size) {
    // draw the pip
    final path = PipClipper(pip).getClip(size);
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

// class Pip extends StatelessWidget {
//   static final _lightPipColor = Color.fromRGBO(206, 181, 145, 1);
//   static final _darkPipColor = Color.fromRGBO(164, 117, 80, 1);
//   static final _activePipColor = Colors.greenAccent;
//   static final _pipWidth = 10.0;
//   static final _pipHeight = 50.0;
//   static final _highlightDx = 10;

//   final int pip;
//   final Color _color;
//   final Color _shadow;
//   Pip(
//     this.pip, {
//     bool active,
//     Key key,
//   })  : _color = pip.isEven ? _darkPipColor : _lightPipColor,
//         _shadow = active == true ? _activePipColor : Colors.transparent,
//         super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     final x = _pipWidth * (pip - 1);
//     final y = 0.0; // depends on what pip number and board orientation

//     return Stack(
//       children: [
//         Positioned.fromRect(
//           rect: Rect.fromLTWH(x + _highlightDx, y, _pipWidth, _pipHeight),
//           child: ClipPath(
//             clipper: TriangleClipper(),
//             child: Container(color: _shadow),
//           ),
//         ),
//         Positioned.fromRect(
//           rect: Rect.fromLTWH(x, y, _pipWidth, _pipHeight),
//           child: ClipPath(
//             clipper: TriangleClipper(),
//             child: Container(color: _color),
//           ),
//         ),
//       ],
//     );
//   }
// }

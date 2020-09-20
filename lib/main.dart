import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'dart:math';

var random = Random(0);

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) => WidgetsApp(
        title: 'Backgammon',
        color: Colors.brown,
        builder: (BuildContext context, Widget navigator) => MyWidget(),
      );
}

class GammonRules {
  // The total number of points on the table.
  static const numPoints = 24;

  // The initial position tuples - [index, count]
  static const initialPointTuples = const [
    [0, 2],
    [11, 5],
    [16, 3],
    [18, 5]
  ];

  static List<int> initialPoints() {
    var points = List<int>.filled(numPoints, 0);
    for (var indexCount in initialPointTuples) {
      var pointIndex = indexCount[0];
      var checkerCount = indexCount[1];

      // White checkers are positive.
      points[pointIndex] = checkerCount;

      // Black checkers are negative, placed mirrorwise.
      points[numPoints - pointIndex - 1] = -checkerCount;
    }
    return points;
  }

  // Returns true if a checker can be moved, without hitting.
  static bool canMove(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[toIndex] == 0) return true;
    return points[fromIndex].sign == points[toIndex].sign;
  }

  // Returns true, if a piece can be hit, and taken out.
  static bool canHit(int fromIndex, int toIndex, final List<int> points) {
    if (points[fromIndex] == 0) return false;
    if (points[fromIndex].sign == points[toIndex].sign) return false;
    return points[toIndex].abs() == 1;
  }

  // Moves a checker without hitting.
  static void doMove(int fromIndex, int toIndex, final List<int> points) {
    assert(canMove(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign * (points[toIndex].abs() + 1);
  }

  // Hits a lone checker.
  static void doHit(int fromIndex, int toIndex, final List<int> points, List<int> hits) {
    assert(canHit(fromIndex, toIndex, points));
    int sideSign = points[fromIndex].sign;
    points[fromIndex] = sideSign * (points[fromIndex].abs() - 1);
    points[toIndex] = sideSign;
  }

  static int sideIndex(int sideSign /* -1 or 1 */) {
    assert(sideSign.abs() == 1);
    return (sideSign + 1) >> 1;
  }

  // Returns true if the player has any hit checkers, false otherwise.
  static bool hasHit(int sideSign, final List<int> hits) {
    return hits[sideIndex(sideSign)] != 0;
  }

  // Adds a hit checker.
  static void addHit(int sideSign, final List<int> hits) {
    hits[sideIndex(sideSign)]++;
  }

  // Remove a hit checker.
  static void removeHit(int sideSign, List<int> hits) {
    hits[sideIndex(sideSign)]--;
  }
}

class GammonState {
  var points = GammonRules.initialPoints();
  var hits = [0, 0]; // Checkers hit per player
  var dice = [0, 0]; // Dice roll
  var sideSign = 1; // Either -1, or 1, or 0 if no game is playing
  var turnCount = 0;
  int selectedIndex = -1; // -1 if no selection.
}

class TrianglePainter extends CustomPainter {
  final GammonState _gammonState;
  final bool _pointingDown;
  final Color _color;
  final int _point;
  const TrianglePainter(this._gammonState, this._color, this._point) : _pointingDown = _point < 12;

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint();
    paint.style = PaintingStyle.fill;
    paint.color = _color;
    var path = Path();
    var halfWidth = size.width / 2;
    if (_pointingDown) {
      path.moveTo(0, 0);
      path.lineTo(halfWidth, size.height);
      path.lineTo(size.width, 0);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(halfWidth, 0);
      path.lineTo(size.width, size.height);
    }
    path.close();
    canvas.drawPath(path, paint);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1;
    paint.color = Colors.black45;
    canvas.drawPath(path, paint);
    var checker = _gammonState.points[_point];
    var count = checker.abs();
    Offset offset;
    var halfHeight = min(halfWidth, size.height / 8);
    var checkersSize = size.width / 3 * 2;
    for (var i = 0; i < count; i++) {
      if (i >= 5) break;
      offset = Offset(halfWidth, _pointingDown ? halfHeight * (i + 1) : size.height - (halfHeight * (i + 1)));

      var rect = Rect.fromCenter(center: offset, width: checkersSize, height: checkersSize);

      paint.color = checker > 0 ? Colors.white : Colors.red;
      paint.style = PaintingStyle.fill;
      canvas.drawOval(rect, paint);

      paint.color = Colors.black87;
      paint.style = PaintingStyle.stroke;
      canvas.drawOval(rect, paint);
    }

    if (count < 1) {
      return;
    }

    offset = offset.translate(count < 10 ? -size.width / 7 : -size.width / 3.5, -size.width / 3.5);
    var textSpan = TextSpan(
      style: TextStyle(color: Colors.black, fontSize: halfWidth),
      text: '$count',
    );
    var textPainter = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}

class BackgammonPoint extends StatefulWidget {
  final Color _color;
  final int _index;
  const BackgammonPoint(this._index) : _color = _index % 2 == 0 ? Colors.grey : Colors.blueGrey;
  @override
  BackgammonPointState createState() => BackgammonPointState();
}

class BackgammonPointState extends State<BackgammonPoint> {
  bool _canMove() {
    var state = GammonQuery.of(context).state;
    if (state.selectedIndex == -1) return false;
    return GammonRules.canMove(state.selectedIndex, this.widget._index, state.points);
  }

  bool _canHit() {
    var state = GammonQuery.of(context).state;
    if (state.selectedIndex == -1) return false;
    return GammonRules.canHit(state.selectedIndex, this.widget._index, state.points);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
      onTapDown: (_) => GammonQuery.of(context).mainWidget.selectPoint(this.widget._index),
      child: CustomPaint(
        size: Size(
          MediaQuery.of(context).size.width / 15,
          MediaQuery.of(context).size.height * 4 / 11,
        ),
        painter: TrianglePainter(
          GammonQuery.of(context).state,
          GammonQuery.of(context).state.selectedIndex == this.widget._index
              ? Colors.red
              : (GammonQuery.of(context).state.selectedIndex == -1)
                  ? this.widget._color
                  : (_canMove() ? Colors.green : (_canHit() ? Colors.yellow : Colors.grey[300])),
          this.widget._index,
        ),
      ));
}

class BackgammonRow extends StatelessWidget {
  final int _startIndex;
  final int _sign;
  const BackgammonRow(bool top)
      : _startIndex = top ? 0 : 23,
        _sign = top ? 1 : -1;
  @override
  Widget build(BuildContext context) => Row(children: <Widget>[
        Container(
          color: const Color(0xff808000), // Yellow
          width: MediaQuery.of(context).size.width / 15,
        ),
        BackgammonPoint(_startIndex + 0 * _sign),
        BackgammonPoint(_startIndex + 1 * _sign),
        BackgammonPoint(_startIndex + 2 * _sign),
        BackgammonPoint(_startIndex + 3 * _sign),
        BackgammonPoint(_startIndex + 4 * _sign),
        BackgammonPoint(_startIndex + 5 * _sign),
        Container(
          color: const Color(0xff808000), // Yellow
          width: MediaQuery.of(context).size.width / 15,
        ),
        BackgammonPoint(_startIndex + 6 * _sign),
        BackgammonPoint(_startIndex + 7 * _sign),
        BackgammonPoint(_startIndex + 8 * _sign),
        BackgammonPoint(_startIndex + 9 * _sign),
        BackgammonPoint(_startIndex + 10 * _sign),
        BackgammonPoint(_startIndex + 11 * _sign),
        Container(
          color: const Color(0xff808000), // Yellow
          width: MediaQuery.of(context).size.width / 15,
        ),
      ]);
}

class GammonQuery extends InheritedWidget {
  final GammonState state;
  final MyWidgetState mainWidget;
  const GammonQuery({this.mainWidget, this.state, child: Widget}) : super(child: child);

  static GammonQuery of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<GammonQuery>();

  @override
  bool updateShouldNotify(GammonQuery old) => true; //state != old.state;
}

class MyWidget extends StatefulWidget {
  @override
  MyWidgetState createState() => MyWidgetState();
}

class MyWidgetState extends State<MyWidget> with SingleTickerProviderStateMixin {
  GammonState _gammonState = GammonState();
  AnimationController _animationController;

  @override
  initState() {
    super.initState();
    throwDice();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 10000),
      animationBehavior: AnimationBehavior.normal,
      vsync: this,
    );
    _animationController.addListener(() {
      setState(() => randomMove());
    });
    //_animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void startAgain() {
    _gammonState = GammonState();
    _animationController.repeat(min: 0.0, max: 1.0, reverse: false, period: const Duration(milliseconds: 10000));
  }

  void throwDice() {
    var gs = _gammonState;
    gs.dice[0] = random.nextInt(6) + 1;
    gs.dice[1] = random.nextInt(6) + 1;
  }

  void nextSide() {
    var gs = _gammonState;
    gs.sideSign = -gs.sideSign;
    gs.turnCount++;
  }

  void deselectPoint() {
    setState(() => _gammonState.selectedIndex = -1);
  }

  void selectPoint(int index) {
    setState(() {
      if (_gammonState.selectedIndex == index)
        _gammonState.selectedIndex = -1;
      else
        _gammonState.selectedIndex = index;
    });
  }

  void randomMove() {
    nextSide();
    throwDice();
    var gs = _gammonState;
    var pc = gs.points;
    for (var i = 0; i < pc.length - 1; i++) {
      var x = i;
      if (gs.sideSign == -1) x = GammonRules.numPoints - x - 1;
      if (pc[x].sign != gs.sideSign) continue;
      for (var d = 0; d < 2; d++) {
        var j = i + gs.dice[d];
        if (j >= GammonRules.numPoints) continue;

        var y = j;
        if (gs.sideSign == -1) y = GammonRules.numPoints - y - 1;

        if (GammonRules.canMove(x, y, pc)) {
          GammonRules.doMove(x, y, pc);
          return;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => GammonQuery(
        mainWidget: this,
        state: _gammonState,
        child: Column(
          children: <Widget>[
            SizedBox(
              height: MediaQuery.of(context).size.height / 11,
              width: MediaQuery.of(context).size.width,
              child: Text(
                "back:gammon",
                style: TextStyle(fontSize: MediaQuery.of(context).size.height / 15),
                textAlign: TextAlign.center,
              ),
            ),
            BackgammonRow(true),
            Container(
              height: MediaQuery.of(context).size.height / 11,
            ),
            BackgammonRow(false),
            SizedBox(
              height: MediaQuery.of(context).size.height / 11,
              width: MediaQuery.of(context).size.width,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Spacer(flex: 4),
                  RaisedButton(
                    child: Text("${_gammonState.dice[0]} ${_gammonState.dice[1]} (${_gammonState.turnCount})"),
                    onPressed: () => setState(() => randomMove()),
                  ),
                  Spacer(flex: 1),
                  RaisedButton(
                    child: Text("RESET"),
                    onPressed: () => setState(() => startAgain()),
                  ),
                  Spacer(flex: 4),
                ],
              ),
            )
          ],
        ),
      );
}

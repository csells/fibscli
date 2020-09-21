import 'dart:math';

import 'package:fibscli/model.dart';
import 'package:fibscli/pips.dart';
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
  @override
  _GameBoardState createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  final _gammonState = GammonState();

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

              // pieces
              for (final layout in PieceLayout.getLayouts(_gammonState))
                Positioned.fromRect(
                  rect: layout.rect,
                  child: Container(
                    decoration: BoxDecoration(
                      color: layout.player1 ? Colors.black : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                    child: Center(
                        child: Text(
                      layout.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: layout.player1 ? Colors.white : Colors.black),
                    )),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PieceLayout {
  static final _pieceWidth = 28.0;
  static final _pieceHeight = 28.0;
  static final _dx = 36.0;
  static final _dy = 28.0;

  final bool player1;
  final double left;
  final double top;
  final String label;
  PieceLayout({@required this.player1, @required this.left, @required this.top, @required this.label});

  Rect get rect => Rect.fromLTWH(left, top, _pieceWidth, _pieceHeight);

  static Iterable<PieceLayout> getLayouts(GammonState state) sync* {
    assert(state.points.length == 24);
    assert(_pieceWidth == _pieceHeight);
    for (var j = 0; j != 4; j++)
      for (var i = 0; i != 6; ++i) {
        final pip = j * 6 + i + 1;
        final dx = _dx * i;
        final point = state.points[pip - 1];
        final player1 = point < 0;
        final pieceCount = point.abs();

        print('pip: $pip, player1= $player1, pieceCount= $pieceCount');

        for (var h = 0; h != min(pieceCount, 5); ++h) {
          // if there's more than 5, the last one gets a label w/ the total number of pieces in the stack
          final label = (h + 1) == 5 && pieceCount > 5 ? pieceCount.toString() : '';
          final dy = _dy * h;

          if (pip >= 1 && pip <= 6) {
            yield PieceLayout(player1: player1, left: 468 - dx, top: 370 - dy, label: label);
          } else if (pip >= 7 && pip <= 12) {
            yield PieceLayout(player1: player1, left: 204 - dx, top: 372 - dy, label: label);
          } else if (pip >= 13 && pip <= 18) {
            yield PieceLayout(player1: player1, left: 24 + dx, top: 20 + dy, label: label);
          } else if (pip >= 19 && pip <= 24) {
            yield PieceLayout(player1: player1, left: 288 + dx, top: 20 + dy, label: label);
          } else {
            assert(false);
          }
        }
      }
  }
}

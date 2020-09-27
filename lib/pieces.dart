import 'dart:math';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class PieceView extends StatelessWidget {
  final PieceLayout layout;
  const PieceView({@required this.layout});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: layout.player1 ? Colors.black : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: 2),
        ),
        child: Center(
          child: Text(
            layout.label,
            textAlign: TextAlign.center,
            style: TextStyle(color: layout.player1 ? Colors.white : Colors.black),
          ),
        ),
      );
}

class PieceLayout {
  static final _pieceWidth = 28.0;
  static final _pieceHeight = 28.0;
  static final _dx = 36.0;
  static final _dy = 28.0;

  final int pip;
  final bool player1;
  final double left;
  final double top;
  final String label;
  final bool highlight;
  PieceLayout({
    @required this.pip,
    @required this.player1,
    @required this.left,
    @required this.top,
    @required this.label,
    @required this.highlight,
  });

  Rect get rect => Rect.fromLTWH(left, top, _pieceWidth, _pieceHeight);

  static Iterable<PieceLayout> getLayouts(GammonState state, {int highlightedPiecePip}) sync* {
    assert(state.points.length == 24);
    assert(_pieceWidth == _pieceHeight);
    for (var j = 0; j != 4; j++)
      for (var i = 0; i != 6; ++i) {
        final pip = j * 6 + i + 1;
        final dx = _dx * i;
        final point = state.points[pip - 1];
        final player1 = point < 0;
        final pieceCount = point.abs();

        for (var h = 0; h != min(pieceCount, 5); ++h) {
          // if there's more than 5, the last one gets a label w/ the total number of pieces in the stack
          final label = (h + 1) == 5 && pieceCount > 5 ? pieceCount.toString() : '';
          final dy = _dy * h;
          final highlight = pip == highlightedPiecePip && (h + 1) == min(pieceCount, 5);

          if (pip >= 1 && pip <= 6) {
            yield PieceLayout(
                pip: pip, player1: player1, left: 468 - dx, top: 371 - dy, label: label, highlight: highlight);
          } else if (pip >= 7 && pip <= 12) {
            yield PieceLayout(
                pip: pip, player1: player1, left: 204 - dx, top: 371 - dy, label: label, highlight: highlight);
          } else if (pip >= 13 && pip <= 18) {
            yield PieceLayout(
                pip: pip, player1: player1, left: 24 + dx, top: 21 + dy, label: label, highlight: highlight);
          } else if (pip >= 19 && pip <= 24) {
            yield PieceLayout(
                pip: pip, player1: player1, left: 288 + dx, top: 21 + dy, label: label, highlight: highlight);
          } else {
            assert(false);
          }
        }
      }
  }
}

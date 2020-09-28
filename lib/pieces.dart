import 'dart:math';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class PieceView extends StatelessWidget {
  final PieceLayout layout;
  const PieceView({@required this.layout});

  @override
  Widget build(BuildContext context) => layout.edge
      ? Container(
          decoration: BoxDecoration(
            color: layout.pieceId.sign == -1 ? Colors.black : Colors.white,
            border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: 2),
          ),
        )
      : Container(
          decoration: BoxDecoration(
            color: layout.pieceId.sign == -1 ? Colors.black : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: 2),
          ),
          child: Center(
            child: Text(
              layout.label,
              textAlign: TextAlign.center,
              style: TextStyle(color: layout.pieceId.sign == -1 ? Colors.white : Colors.black),
            ),
          ),
        );
}

class PieceLayout {
  static final _pieceWidth = 28.0;
  static final _pieceHeight = 28.0;
  static final _dx = 36.0;
  static final _dy = 29.0;
  static final _edgeWidth = 32.0;
  static final _edgeHeight = 11.0;

  final int pipNo;
  final int pieceId;
  final double left;
  final double top;
  final String label;
  final bool highlight;
  final bool edge;
  PieceLayout({
    @required this.pipNo,
    @required this.pieceId,
    @required this.left,
    @required this.top,
    @required this.label,
    this.highlight = false,
    this.edge = false,
  });

  Rect get rect =>
      edge ? Rect.fromLTWH(left, top, _edgeWidth, _edgeHeight) : Rect.fromLTWH(left, top, _pieceWidth, _pieceHeight);

  static Iterable<PieceLayout> getLayouts(GammonState state, {int highlightedPiecePip}) sync* {
    final pips = state.pips;
    assert(pips.length == 26);
    assert(_pieceWidth == _pieceHeight);

    // draw the pieces on the board
    for (var j = 0; j != 4; j++)
      for (var i = 0; i != 6; ++i) {
        final pipNo = j * 6 + i + 1;
        final pip = pips[pipNo];
        if (pip.isEmpty) continue;
        assert(pip.every((p) => p.sign == pip[0].sign));
        final pieceCount = pip.length;
        final dx = _dx * i;

        for (var h = 0; h != pieceCount; ++h) {
          // if there's more than 5, the last one gets a label w/ the total number of pieces in the stack
          final label = pieceCount > 5 && (h + 1) == pieceCount ? pieceCount.toString() : '';
          final dy = _dy * min(4, h);
          final highlight = pipNo == highlightedPiecePip && (h + 1) == min(pieceCount, 5);
          final pieceId = pip[h];

          if (pipNo >= 1 && pipNo <= 6) {
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 468 - dx, top: 370 - dy, label: label, highlight: highlight);
          } else if (pipNo >= 7 && pipNo <= 12) {
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 204 - dx, top: 370 - dy, label: label, highlight: highlight);
          } else if (pipNo >= 13 && pipNo <= 18) {
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 24 + dx, top: 22 + dy, label: label, highlight: highlight);
          } else if (pipNo >= 19 && pipNo <= 24) {
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 288 + dx, top: 22 + dy, label: label, highlight: highlight);
          } else {
            assert(false);
          }
        }
      }

    // draw the pieces on the bar
    final bar = pips[0];
    final barPieceCount = bar.length;
    for (var i = 0; i != barPieceCount; ++i) {
      final pieceId = bar[i];
      final label = (i + 1) == 1 && barPieceCount > 5 ? barPieceCount.toString() : '';
      final top = pieceId.sign == -1 ? 138.0 - _dy * min(i, 4) : 252.0 + _dy * min(i, 4);
      yield PieceLayout(pipNo: 0, pieceId: pieceId, left: 246, top: top, label: label, highlight: false);
    }

    // draw the pieces in their homes
    final home = pips[25];
    final homePieceCount = home.length;
    for (var i = 0; i != homePieceCount; ++i) {
      final pieceId = home[i];
      final top = pieceId.sign == -1 ? 386.0 - (_edgeHeight + 1) * min(i, 4) : 22.0 + (_edgeHeight + 1) * min(i, 4);
      yield PieceLayout(pipNo: 0, pieceId: pieceId, left: 520, top: top, label: '', edge: true);
    }
  }
}

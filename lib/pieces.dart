import 'dart:math';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class PieceView extends StatelessWidget {
  static final _pieceColors = [
    [Colors.grey[800], Colors.black],
    [Colors.grey[400], Colors.white]
  ];

  final List<Color> _gradeColors;
  final PieceLayout layout;
  PieceView({@required this.layout}) : _gradeColors = _pieceColors[layout.pieceId.sign == -1 ? 0 : 1];

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
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              colors: _gradeColors,
            ),
            border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: 1),
          ),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .90,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    colors: [_gradeColors[1], _gradeColors[0]],
                  ),
                ),
              ),
            ),
          ),
        );
  // : Container(
  //     decoration: BoxDecoration(
  //       color: layout.pieceId.sign == -1 ? Colors.black : Colors.white,
  //       shape: BoxShape.circle,
  //       border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: 2),
  //     ),
  //     child: Center(
  //       child: Text(
  //         layout.label,
  //         textAlign: TextAlign.center,
  //         style: TextStyle(color: layout.pieceId.sign == -1 ? Colors.white : Colors.black),
  //       ),
  //     ),
  //   );
}

class PieceLayout {
  static final _pieceWidth = 28.0;
  static final _pieceHeight = 28.0;
  static final _dx = 36.0;
  static final _dy = 28.0;
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
    for (var j = 0; j != 4; j++) {
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

          if (pipNo >= 1 && pipNo <= 6) { // bottom right
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 468 - dx, top: 371 - dy, label: label, highlight: highlight);
          } else if (pipNo >= 7 && pipNo <= 12) { // bottom left
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 204 - dx, top: 371 - dy, label: label, highlight: highlight);
          } else if (pipNo >= 13 && pipNo <= 18) { // top left
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 24 + dx, top: 21 + dy, label: label, highlight: highlight);
          } else if (pipNo >= 19 && pipNo <= 24) { // top right
            yield PieceLayout(
                pipNo: pipNo, pieceId: pieceId, left: 288 + dx, top: 21 + dy, label: label, highlight: highlight);
          } else {
            assert(false);
          }
        }
      }
    }

    // draw the pieces on the bar
    for (final player in Player.values) {
      final sign = GammonRules.signFor(player);
      final bar = GammonRules.barPipNoFor(player);
      final pieces = pips[bar].where((p) => p.sign == sign).toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceId = pieces[i];
        final label = (i + 1) == pieceCount && pieceCount > 3 ? pieceCount.toString() : '';
        final top = pieceId.sign == -1 ? 254.0 + _dy * min(i, 2) : 138.0 - _dy * min(i, 2);
        final highlight = bar == highlightedPiecePip && i == 0;
        yield PieceLayout(pipNo: 0, pieceId: pieceId, left: 246, top: top, label: label, highlight: highlight);
      }
    }

    // draw the pieces in their homes
    for (final player in Player.values) {
      final sign = GammonRules.signFor(player);
      final pieces = pips[GammonRules.homePipNoFor(player)].where((p) => p.sign == sign).toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceId = pieces[i];
        final top = pieceId.sign == -1 ? 386.0 - (_edgeHeight + 1) * i : 22.0 + (_edgeHeight + 1) * i;
        yield PieceLayout(pipNo: 0, pieceId: pieceId, left: 520, top: top, label: '', edge: true);
      }
    }
  }
}

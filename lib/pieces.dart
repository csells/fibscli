import 'dart:math';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class PieceView extends StatelessWidget {
  static final _pieceColors = [
    [Colors.grey[800], Colors.black],
    [Colors.white, Colors.grey[400]]
  ];

  final Color _textColor;
  final List<Color> _gradeColors;
  final PieceLayout layout;
  PieceView({@required this.layout})
      : _gradeColors = _pieceColors[layout.pieceID.sign == -1 ? 0 : 1],
        _textColor = layout.pieceID.sign == -1 ? Colors.white : Colors.black;

  @override
  Widget build(BuildContext context) => layout.edge
      ? Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradeColors),
            border: Border.all(color: Colors.black, width: 1),
          ),
        )
      : Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(begin: Alignment.topLeft, colors: _gradeColors),
            border: Border.all(color: layout.highlight ? Colors.yellow : Colors.black, width: layout.highlight ? 2 : 1),
          ),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .9,
              child: SizedBox.expand(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, colors: [_gradeColors[1], _gradeColors[0]]),
                  ),
                  child: Center(
                    child: Text(
                      layout.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _textColor),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
}

class PieceLayout {
  static final _pieceSize = Size(28, 28);
  static final _offset = Offset(36, 28);
  static final _edgeSize = Size(32, 11);

  final int pipNo;
  final int pieceID;
  final Offset offset;
  final String label;
  final bool highlight;
  final bool edge;

  PieceLayout({
    @required this.pipNo,
    @required this.pieceID,
    @required this.offset,
    @required this.label,
    this.highlight = false,
    this.edge = false,
  });

  Size get size => edge ? _edgeSize : _pieceSize;
  Rect get rect => offset & size;

  @override
  String toString() => 'layout(id=$pieceID, pipNo=$pipNo, label=$label, rect=$rect, highlight=$highlight)';

  static Iterable<PieceLayout> getLayouts(List<List<int>> board, [List<int> pipNosToHighlight]) sync* {
    assert(board.length == 26);
    assert(_pieceSize.width == _pieceSize.height);

    pipNosToHighlight ??= [];

    // draw the pieces on the board
    for (var j = 0; j != 4; j++) {
      for (var i = 0; i != 6; ++i) {
        final pipNo = j * 6 + i + 1;
        final highlightedPiecePip = pipNosToHighlight.contains(pipNo);
        final pip = board[pipNo];
        if (pip.isEmpty) continue;
        assert(pip.every((p) => p.sign == pip[0].sign));
        final pieceCount = pip.length;
        final dx = _offset.dx * i;

        for (var h = 0; h != pieceCount; ++h) {
          // if there's more than 5, the last one gets a label w/ the total number of pieces in the stack
          final label = pieceCount > 5 && (h + 1) == pieceCount ? pieceCount.toString() : '';
          final dy = _offset.dy * min(4, h);
          final highlight = highlightedPiecePip && h == pieceCount - 1;
          final pieceID = pip[h];

          if (pipNo >= 1 && pipNo <= 6) {
            // bottom right
            yield PieceLayout(
                pipNo: pipNo, pieceID: pieceID, offset: Offset(468 - dx, 371 - dy), label: label, highlight: highlight);
          } else if (pipNo >= 7 && pipNo <= 12) {
            // bottom left
            yield PieceLayout(
                pipNo: pipNo, pieceID: pieceID, offset: Offset(204 - dx, 371 - dy), label: label, highlight: highlight);
          } else if (pipNo >= 13 && pipNo <= 18) {
            // top left
            yield PieceLayout(
                pipNo: pipNo, pieceID: pieceID, offset: Offset(24 + dx, 21 + dy), label: label, highlight: highlight);
          } else if (pipNo >= 19 && pipNo <= 24) {
            // top right
            yield PieceLayout(
                pipNo: pipNo, pieceID: pieceID, offset: Offset(288 + dx, 21 + dy), label: label, highlight: highlight);
          } else {
            assert(false);
          }
        }
      }
    }

    // draw the pieces on the bar
    for (final player in GammonPlayer.values) {
      final bar = GammonRules.barPipNoFor(player);
      final highlightedPiecePip = pipNosToHighlight.contains(bar);
      final pieces = board[bar].where((p) => GammonRules.playerFor(p) == player).toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final label = (i + 1) == pieceCount && pieceCount > 3 ? pieceCount.toString() : '';
        final top = pieceID.sign == -1 ? 254.0 + _offset.dy * min(i, 2) : 138.0 - _offset.dy * min(i, 2);
        final highlight = highlightedPiecePip && i == 0;
        yield PieceLayout(pipNo: 0, pieceID: pieceID, offset: Offset(246, top), label: label, highlight: highlight);
      }
    }

    // draw the pieces in their homes
    for (final player in GammonPlayer.values) {
      final pieces = board[GammonRules.offPipNoFor(player)].where((p) => GammonRules.playerFor(p) == player).toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final top = pieceID.sign == -1 ? 386.0 - (_edgeSize.height + 1) * i : 22.0 + (_edgeSize.height + 1) * i;
        yield PieceLayout(pipNo: 0, pieceID: pieceID, offset: Offset(520, top), label: '', edge: true);
      }
    }
  }
}

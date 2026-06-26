import 'dart:math';

import 'package:flutter/material.dart';

import 'model.dart';

// Milliseconds of animation per unit of on-screen distance a piece travels.
// Shared by AnimatedPiece (segment duration) and MoveAnimation (hit delays) so
// a hittee's wait lines up with the hitter's travel time.
const kAnimationMsPerDistance = 3;

class PieceView extends StatelessWidget {
  PieceView({required this.layout, super.key})
      : _gradeColors = _pieceColors[layout.pieceID.sign == -1 ? 0 : 1],
        _textColor = layout.pieceID.sign == -1 ? Colors.white : Colors.black;
  static final _pieceColors = [
    [Colors.grey[800]!, Colors.black],
    [Colors.white, Colors.grey[400]!]
  ];

  final Color _textColor;
  final List<Color> _gradeColors;
  final PieceLayout layout;

  @override
  Widget build(BuildContext context) => layout.edge
      ? Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _gradeColors),
            border: Border.all(color: Colors.black, width: 1),
          ),
        )
      : DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient:
                LinearGradient(begin: Alignment.topLeft, colors: _gradeColors),
            border: Border.all(
                color: layout.highlight ? Colors.yellow : Colors.black,
                width: layout.highlight ? 2 : 1),
          ),
          child: Center(
            child: FractionallySizedBox(
              widthFactor: .9,
              child: SizedBox.expand(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        colors: [_gradeColors[1], _gradeColors[0]]),
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

// The per-piece layout paths and start delays for animating a single move.
// A hittee waits ([delays]) until the hitter reaches it before sliding to the
// bar, so a piece is no longer sent off before it's hit on screen (issue #5).
class MoveAnimation {
  MoveAnimation(this.layouts, this.delays);

  factory MoveAnimation.forMove(
    List<List<int>> initialBoard,
    List<List<GammonDelta>> deltasForHops,
  ) {
    // the main piece that's moving (not the pieces being sent to the bar)
    final mainPieceID = deltasForHops[0][0].pieceID;

    // copy the initial board; it'll change as we apply deltas
    final board = List<List<int>>.generate(
        initialBoard.length, (i) => List<int>.from(initialBoard[i]));

    // every piece affected by this move (the mover plus any hittees)
    final pieceIDs = <int?>[
      for (final deltasForHop in deltasForHops)
        for (final delta in deltasForHop) delta.pieceID
    ];

    final layouts = <int?, List<PieceLayout>>{
      for (final pieceID in pieceIDs) pieceID: <PieceLayout>[]
    };

    // record each piece's layout at each board state (initial, then each hop)
    for (final deltasForHop in <List<GammonDelta>>[
      <GammonDelta>[],
      ...deltasForHops
    ]) {
      GammonRules.applyDeltasForHop(board, deltasForHop);
      final hopLayouts = PieceLayout.getLayouts(board);
      for (final pieceID in pieceIDs) {
        layouts[pieceID]!
            .add(hopLayouts.firstWhere((l) => l.pieceID == pieceID));
      }
    }

    // a hittee starts moving only once the hitter has reached the hit pip
    final delays = <int?, Duration>{};
    final hitterPath = layouts[mainPieceID]!;
    for (var hop = 0; hop != deltasForHops.length; ++hop) {
      for (final delta in deltasForHops[hop]) {
        if (delta.kind != GammonDeltaKind.bar) continue;
        var distance = 0.0;
        for (var i = 1; i <= hop + 1; ++i) {
          distance += (hitterPath[i - 1].offset! - hitterPath[i].offset!)
              .distance;
        }
        delays[delta.pieceID] = Duration(
            milliseconds: (distance * kAnimationMsPerDistance).floor());
      }
    }

    return MoveAnimation(layouts, delays);
  }

  final Map<int?, List<PieceLayout>> layouts;
  final Map<int?, Duration> delays;
}

class PieceLayout {
  PieceLayout({
    required this.pipNo,
    required this.pieceID,
    required this.offset,
    required this.label,
    this.highlight = false,
    this.edge = false,
  });
  static const _pieceSize = Size(28, 28);
  static const _offset = Offset(36, 28);
  static const _edgeSize = Size(32, 11);

  final int pipNo;
  final int pieceID;
  final Offset? offset;
  final String label;
  final bool highlight;
  final bool edge;

  Size get size => edge ? _edgeSize : _pieceSize;
  Rect get rect => offset! & size;
  PieceLayout get animated =>
      PieceLayout(pieceID: pieceID, offset: offset, label: '', pipNo: pipNo);

  @override
  String toString() =>
      'layout(id=$pieceID, pipNo=$pipNo, label=$label, rect=$rect, '
      'highlight=$highlight)';

  // Order layouts so that currently-animating (moving) pieces are drawn last,
  // i.e. on top of stationary pieces, instead of in pip order (issue #6).
  static List<PieceLayout> drawOrder(
      Iterable<PieceLayout> layouts, Set<int?> animatingIDs) {
    final stationary = <PieceLayout>[];
    final moving = <PieceLayout>[];
    for (final layout in layouts) {
      (animatingIDs.contains(layout.pieceID) ? moving : stationary).add(layout);
    }
    return [...stationary, ...moving];
  }

  static Iterable<PieceLayout> getLayouts(List<List<int>> board,
      [List<int?>? pipNosToHighlight]) sync* {
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
          final label = pieceCount > 5 && (h + 1) == pieceCount
              ? pieceCount.toString()
              : '';
          final dy = _offset.dy * min(4, h);
          final highlight = highlightedPiecePip && h == pieceCount - 1;
          final pieceID = pip[h];

          if (pipNo >= 1 && pipNo <= 6) {
            // bottom right
            yield PieceLayout(
                pipNo: pipNo,
                pieceID: pieceID,
                offset: Offset(468 - dx, 371 - dy),
                label: label,
                highlight: highlight);
          } else if (pipNo >= 7 && pipNo <= 12) {
            // bottom left
            yield PieceLayout(
                pipNo: pipNo,
                pieceID: pieceID,
                offset: Offset(204 - dx, 371 - dy),
                label: label,
                highlight: highlight);
          } else if (pipNo >= 13 && pipNo <= 18) {
            // top left
            yield PieceLayout(
                pipNo: pipNo,
                pieceID: pieceID,
                offset: Offset(24 + dx, 21 + dy),
                label: label,
                highlight: highlight);
          } else if (pipNo >= 19 && pipNo <= 24) {
            // top right
            yield PieceLayout(
                pipNo: pipNo,
                pieceID: pieceID,
                offset: Offset(288 + dx, 21 + dy),
                label: label,
                highlight: highlight);
          } else {
            assert(false);
          }
        }
      }
    }

    // draw the pieces on the bar
    for (final player in GammonPlayer.values) {
      final barPipNo = GammonRules.barPipNoFor(player);
      final highlightedPiecePip = pipNosToHighlight.contains(barPipNo);
      final pieces = board[barPipNo]
          .where((p) => GammonRules.playerFor(p) == player)
          .toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final label = (i + 1) == pieceCount && pieceCount > 3
            ? pieceCount.toString()
            : '';
        final top = pieceID.sign == -1
            ? 254.0 + _offset.dy * min(i, 2)
            : 138.0 - _offset.dy * min(i, 2);
        final highlight = highlightedPiecePip && i == 0;
        yield PieceLayout(
            pipNo: barPipNo,
            pieceID: pieceID,
            offset: Offset(246, top),
            label: label,
            highlight: highlight);
      }
    }

    // draw the pieces born off
    for (final player in GammonPlayer.values) {
      final offPipNo = GammonRules.offPipNoFor(player);
      final pieces = board[offPipNo]
          .where((p) => GammonRules.playerFor(p) == player)
          .toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final top = pieceID.sign == -1
            ? 386.0 - (_edgeSize.height + 1) * i
            : 22.0 + (_edgeSize.height + 1) * i;
        yield PieceLayout(
            pipNo: offPipNo,
            pieceID: pieceID,
            offset: Offset(520, top),
            label: '',
            edge: true);
      }
    }
  }
}

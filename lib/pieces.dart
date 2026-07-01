import 'dart:math';

import 'package:flutter/material.dart';

import 'model.dart';

// Fixed wall-clock duration for a single piece hop, independent of the distance
// travelled, so every move shares a steady rhythm instead of short moves
// popping and long moves crawling (matches the Android app's per-hop slide). A
// multi-hop move (doubles) runs this many milliseconds per hop, back to back.
// Shared by AnimatedPiece (segment duration) and MoveAnimation (hit delays) so
// a hittee's wait lines up with the hitter's arrival.
const kHopAnimationDuration = Duration(milliseconds: 250);

// The board sign-encodes ownership (negative = player one). Decode it through
// the engine's typed ownership helper so the render layer never pokes the raw
// sign itself -- the encoding stays an engine detail, named in one place.
bool _isPlayerOne(int pieceID) =>
    GammonRules.playerFor(pieceID) == GammonPlayer.one;

class PieceView extends StatelessWidget {
  PieceView({required this.layout, super.key})
    : _gradeColors = _pieceColors[_isPlayerOne(layout.pieceID) ? 0 : 1],
      _textColor = _isPlayerOne(layout.pieceID) ? Colors.white : Colors.black;
  static final _pieceColors = [
    [Colors.grey[800]!, Colors.black],
    [Colors.white, Colors.grey[400]!],
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
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              colors: _gradeColors,
            ),
            border: Border.all(
              color: layout.highlight ? Colors.yellow : Colors.black,
              width: layout.highlight ? 2 : 1,
            ),
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
                      colors: [_gradeColors[1], _gradeColors[0]],
                    ),
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
    // copy the initial board; it'll change as we apply deltas
    final board = List<List<int>>.generate(
      initialBoard.length,
      (i) => List<int>.from(initialBoard[i]),
    );

    // every piece affected by this move (the mover plus any hittees)
    final pieceIDs = <int?>[
      for (final deltasForHop in deltasForHops)
        for (final delta in deltasForHop) delta.pieceID,
    ];

    final layouts = <int?, List<PieceLayout>>{
      for (final pieceID in pieceIDs) pieceID: <PieceLayout>[],
    };

    // record each piece's layout at each board state (initial, then each hop)
    for (final deltasForHop in <List<GammonDelta>>[
      <GammonDelta>[],
      ...deltasForHops,
    ]) {
      GammonRules.applyDeltasForHop(board, deltasForHop);
      final hopLayouts = PieceLayout.getLayouts(board);
      for (final pieceID in pieceIDs) {
        layouts[pieceID]!.add(
          hopLayouts.firstWhere((l) => l.pieceID == pieceID),
        );
      }
    }

    // A hittee starts moving only once the hitter has finished the hop that
    // lands on (and hits) it: the hitter completes hop `hop` after `hop + 1`
    // fixed-duration hops, so the hittee waits exactly that long. Because each
    // hop is a fixed duration now, the wait is no longer distance-derived.
    final delays = <int?, Duration>{};
    final hittees = <int?>{};
    for (var hop = 0; hop != deltasForHops.length; ++hop) {
      for (final delta in deltasForHops[hop]) {
        if (delta.kind != GammonDeltaKind.bar) continue;
        hittees.add(delta.pieceID);
        delays[delta.pieceID] = kHopAnimationDuration * (hop + 1);
      }
    }

    // Collapse each hittee's path to a single slide (its resting spot -> the
    // bar). It never moves before the hit, so the recorded stay-frames would
    // otherwise burn extra hops sitting still on top of the `delay` wait.
    for (final pieceID in hittees) {
      final path = layouts[pieceID]!;
      layouts[pieceID] = [path.first, path.last];
    }

    return MoveAnimation(layouts, delays);
  }

  /// Build an animation purely from the *difference* between two boards — no
  /// move deltas required. Each [boardMovements] entry is mapped onto a piece
  /// in [toBoard] (its final resting place) and tweened from the matching slot
  /// in [fromBoard]. This is what lets FIBS and opponent moves animate the same
  /// way the local game does, even though FIBS only ever hands us whole boards.
  ///
  /// When the turn's [dice] are supplied, a checker that travelled more than
  /// one die is animated THROUGH each intermediate pip (via [consumeHopPath])
  /// rather than sliding straight to the end — so a multi-hop move reads as the
  /// hops it actually was. The dice are allocated across checkers (longest
  /// journeys first), so each multi-die checker claims its own dice.
  factory MoveAnimation.between(
    List<List<int>> fromBoard,
    List<List<int>> toBoard, {
    List<int> dice = const [],
  }) {
    final movements = boardMovements(
      Position.fromBoard(fromBoard),
      Position.fromBoard(toBoard),
    );
    final fromLayouts = PieceLayout.getLayouts(fromBoard).toList();
    final toLayouts = PieceLayout.getLayouts(toBoard).toList();
    final usedFrom = <PieceLayout>{};
    final usedTo = <PieceLayout>{};
    final layouts = <int?, List<PieceLayout>>{};

    // Owner-aware: engine pips 0 and 25 are each shared between one player's
    // bar and the other player's off, so a pip alone doesn't identify a checker
    // -- match the mover's colour too, or a bear-off could pick the opponent's
    // same-pip bar checker (which must stay put).
    PieceLayout? take(
      List<PieceLayout> pool,
      Set<PieceLayout> used,
      int pip,
      GammonPlayer player,
    ) {
      for (final l in pool) {
        if (l.pipNo == pip &&
            GammonRules.playerFor(l.pieceID) == player &&
            !used.contains(l)) {
          used.add(l);
          return l;
        }
      }
      return null;
    }

    // Allocate dice to the longest journeys first so a multi-hop checker claims
    // its dice before single-hop movers nibble at the shared pool.
    final pool = List<int>.of(dice);
    int travel(Movement m) =>
        (m.toPip - m.fromPip) * (m.player == GammonPlayer.one ? -1 : 1);
    final ordered = movements.toList()
      ..sort((a, b) => travel(b).compareTo(travel(a)));

    for (final move in ordered) {
      final dest = take(toLayouts, usedTo, move.toPip, move.player);
      final src = take(fromLayouts, usedFrom, move.fromPip, move.player);
      // A board diff should always pair a source and destination slot. If it
      // ever doesn't, fail loudly in debug/tests instead of silently snapping
      // the checker to place with no animation (which is invisible in a replay
      // fixture that never hits the case).
      assert(
        dest != null && src != null,
        'unmatched movement $move (from ${move.fromPip} to ${move.toPip})',
      );
      if (dest == null || src == null) continue;

      // intermediate hops only when landing on a real point (1..24); bar/off
      // moves (hits, bear-offs) stay a single segment.
      final hopPips = (move.toPip >= 1 && move.toPip <= 24)
          ? consumeHopPath(
              fromPip: move.fromPip,
              toPip: move.toPip,
              player: move.player,
              dice: pool,
            )
          : <int>[move.fromPip, move.toPip];

      // first frame = the real source slot; last = the real destination slot;
      // any middle pips = that point's base slot (a transient pass-through).
      final frames = <PieceLayout>[
        PieceLayout(
          pieceID: dest.pieceID,
          offset: src.offset,
          label: '',
          pipNo: move.fromPip,
          edge: src.edge,
        ),
        for (final pip in hopPips.getRange(1, hopPips.length - 1))
          PieceLayout(
            pieceID: dest.pieceID,
            offset: PieceLayout.baseSlotOffset(pip),
            label: '',
            pipNo: pip,
          ),
        dest,
      ];
      layouts[dest.pieceID] = frames;
    }
    return MoveAnimation(layouts, const {});
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

  // Board geometry for the 4 point quadrants: the baseline y of the bottom vs
  // top rows, and the x of the FIRST column of each quadrant. Columns step by
  // _offset.dx toward the board's center -- so -dx on the right/bottom sides
  // and +dx on the left/top sides (see baseSlotOffset).
  static const _bottomRowY = 371.0;
  static const _topRowY = 21.0;
  static const _bottomRightX = 468.0;
  static const _bottomLeftX = 204.0;
  static const _topLeftX = 24.0;
  static const _topRightX = 288.0;

  // The bar (center) and off (right tray) columns. Player one (bottom home)
  // stacks down from its baseline; player two (top home) stacks up from its.
  static const _barX = 246.0;
  static const _barBottomBaselineY = 254.0; // player one, growing down
  static const _barTopBaselineY = 138.0; // player two, growing up
  static const _offX = 520.0;
  static const _offBottomBaselineY = 386.0; // player one, growing up the tray
  static const _offTopBaselineY = 22.0; // player two, growing down the tray

  final int pipNo;
  final int pieceID;
  final Offset offset;
  final String label;
  final bool highlight;
  final bool edge;

  Size get size => edge ? _edgeSize : _pieceSize;
  Rect get rect => offset & size;

  // The on-screen offset of the FIRST checker (stack base) on point [pipNo],
  // 1..24 -- the same geometry getLayouts assigns at stack height 0. Used to
  // place a checker mid-journey as it hops through an intermediate point.
  static Offset baseSlotOffset(int pipNo) {
    assert(pipNo >= 1 && pipNo <= 24);
    final dx = _offset.dx * ((pipNo - 1) % 6);
    if (pipNo <= 6) return Offset(_bottomRightX - dx, _bottomRowY);
    if (pipNo <= 12) return Offset(_bottomLeftX - dx, _bottomRowY);
    if (pipNo <= 18) return Offset(_topLeftX + dx, _topRowY);
    return Offset(_topRightX + dx, _topRowY);
  }

  PieceLayout get animated =>
      PieceLayout(pieceID: pieceID, offset: offset, label: '', pipNo: pipNo);

  @override
  String toString() =>
      'layout(id=$pieceID, pipNo=$pipNo, label=$label, rect=$rect, '
      'highlight=$highlight)';

  // Order layouts so that currently-animating (moving) pieces are drawn last,
  // i.e. on top of stationary pieces, instead of in pip order (issue #6).
  static List<PieceLayout> drawOrder(
    Iterable<PieceLayout> layouts,
    Set<int?> animatingIDs,
  ) {
    final stationary = <PieceLayout>[];
    final moving = <PieceLayout>[];
    for (final layout in layouts) {
      (animatingIDs.contains(layout.pieceID) ? moving : stationary).add(layout);
    }
    return [...stationary, ...moving];
  }

  static Iterable<PieceLayout> getLayouts(
    List<List<int>> board, [
    List<int?>? pipNosToHighlight,
  ]) sync* {
    assert(board.length == 26);
    assert(_pieceSize.width == _pieceSize.height);

    pipNosToHighlight ??= [];

    // typed view over the raw board so this reads in domain terms (checkersAt/
    // countAt/isVacantAt) instead of bare indices -- zero-cost (see GammonBoard)
    final b = GammonBoard(board);

    // draw the pieces on the board
    for (var j = 0; j != 4; j++) {
      for (var i = 0; i != 6; ++i) {
        final pipNo = j * 6 + i + 1;
        final highlightedPiecePip = pipNosToHighlight.contains(pipNo);
        if (b.isVacantAt(pipNo)) continue;
        final pip = b.checkersAt(pipNo);
        assert(pip.every((p) => _isPlayerOne(p) == _isPlayerOne(pip[0])));
        final pieceCount = b.countAt(pipNo);

        for (var h = 0; h != pieceCount; ++h) {
          // if there's more than 5, the last one gets a label w/ the total number of pieces in the stack
          final label = pieceCount > 5 && (h + 1) == pieceCount
              ? pieceCount.toString()
              : '';
          final dy = _offset.dy * min(4, h);
          final highlight = highlightedPiecePip && h == pieceCount - 1;
          final pieceID = pip[h];

          // Base slot geometry lives in exactly one place (baseSlotOffset);
          // stacks grow away from the baseline -- down (-dy) on the bottom
          // quadrants, up (+dy) on the top.
          final dyDir = pipNo <= 12 ? -1.0 : 1.0;
          yield PieceLayout(
            pipNo: pipNo,
            pieceID: pieceID,
            offset: baseSlotOffset(pipNo) + Offset(0, dyDir * dy),
            label: label,
            highlight: highlight,
          );
        }
      }
    }

    // draw the pieces on the bar
    for (final player in GammonPlayer.values) {
      final barPipNo = GammonRules.barPipNoFor(player);
      final highlightedPiecePip = pipNosToHighlight.contains(barPipNo);
      final pieces = b
          .checkersAt(barPipNo)
          .where((p) => GammonRules.playerFor(p) == player)
          .toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final label = (i + 1) == pieceCount && pieceCount > 3
            ? pieceCount.toString()
            : '';
        final top = _isPlayerOne(pieceID)
            ? _barBottomBaselineY + _offset.dy * min(i, 2)
            : _barTopBaselineY - _offset.dy * min(i, 2);
        final highlight = highlightedPiecePip && i == 0;
        yield PieceLayout(
          pipNo: barPipNo,
          pieceID: pieceID,
          offset: Offset(_barX, top),
          label: label,
          highlight: highlight,
        );
      }
    }

    // draw the pieces born off
    for (final player in GammonPlayer.values) {
      final offPipNo = GammonRules.offPipNoFor(player);
      final pieces = b
          .checkersAt(offPipNo)
          .where((p) => GammonRules.playerFor(p) == player)
          .toList();
      final pieceCount = pieces.length;
      for (var i = 0; i != pieceCount; ++i) {
        final pieceID = pieces[i];
        final top = _isPlayerOne(pieceID)
            ? _offBottomBaselineY - (_edgeSize.height + 1) * i
            : _offTopBaselineY + (_edgeSize.height + 1) * i;
        yield PieceLayout(
          pipNo: offPipNo,
          pieceID: pieceID,
          offset: Offset(_offX, top),
          label: '',
          edge: true,
        );
      }
    }
  }
}

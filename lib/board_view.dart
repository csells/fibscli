import 'dart:math';

import 'package:flutter/material.dart';

import 'animated_layouts.dart';
import 'dice.dart';
import 'model.dart';
import 'pieces.dart';
import 'pip_count.dart';
import 'pips.dart';
import 'theme.dart';

/// THE single backgammon board renderer — used by the local game, FIBS play,
/// and FIBS watch, so they always look and highlight identically.
///
/// It is purely presentational: it draws [game], dispatches taps through the
/// callbacks, and derives all highlighting from [legalMoves] + [selectedPip].
/// The parent owns selection state and what a move *means* (the local game
/// applies + animates locally; FIBS sends the move to the server). Animation is
/// optional: pass [pieceAnimations]/[pieceDelays] to tween moving checkers
/// (the local game does); omit them for a static render (FIBS).
class BoardView extends StatelessWidget {
  const BoardView({
    required this.game,
    super.key,
    this.legalMoves = const {},
    this.selectedPip,
    this.reversed = false,
    this.ignoring = false,
    this.onTapPip,
    this.onTapOff,
    this.onTapCube,
    this.onTapDice,
    this.onTapBoard,
    this.pieceAnimations = const {},
    this.pieceDelays = const {},
    this.onPieceAnimationEnd,
  });

  /// The position (and dice/cube) to draw.
  final GammonState game;

  /// Legal moves keyed by from-pip, used to highlight movable checkers and
  /// (once [selectedPip] is set) the valid destinations.
  final Map<int, List<GammonMove>> legalMoves;

  /// The currently selected from-pip, or null.
  final int? selectedPip;

  /// Whether the board is rotated 180° (player-two perspective).
  final bool reversed;

  /// Whether to ignore all pointer input (game over / opponent's turn / watch).
  final bool ignoring;

  /// Tap on a pip or a checker (reports the pip number).
  final void Function(int pipNo)? onTapPip;

  /// Tap on a player's off tray (bear off).
  final void Function(GammonPlayer player)? onTapOff;

  /// Tap on the doubling cube.
  final VoidCallback? onTapCube;

  /// Tap on the dice.
  final VoidCallback? onTapDice;

  /// Tap on empty board (deselect).
  final VoidCallback? onTapBoard;

  /// Per-piece animation layouts (empty == no animation, static render).
  final Map<int?, List<PieceLayout>> pieceAnimations;

  /// Per-piece animation start delays.
  final Map<int?, Duration> pieceDelays;

  /// Called when a piece's animation finishes.
  final void Function(int? pieceId)? onPieceAnimationEnd;

  List<int?> get _pipNosToHighlight =>
      selectedPip != null ? [selectedPip] : legalMoves.keys.toList();

  bool _highlightPip(int pipNo) {
    final moves = selectedPip == null ? null : legalMoves[selectedPip];
    return moves != null &&
        moves.hasHops(fromPipNo: selectedPip, toPipNo: pipNo);
  }

  bool _highlightOff(GammonPlayer player) {
    final offPipNo = GammonRules.offPipNoFor(player);
    final moves = selectedPip == null ? null : legalMoves[selectedPip];
    return moves != null && moves.any((m) => m.toPipNo == offPipNo);
  }

  // the cube sits at the center bar, shifted toward its owner's side
  static Rect _cubeRect(GammonPlayer? owner) {
    const top = <GammonPlayer?, double>{
      null: 186, // centered
      GammonPlayer.one: 354, // player1 home is along the bottom
      GammonPlayer.two: 18, // player2 home is along the top
    };
    return Rect.fromLTWH(238, top[owner]!, 44, 44);
  }

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 500),
    transform: Matrix4.rotationZ(reversed ? pi : 0),
    transformAlignment: Alignment.center,
    child: FittedBox(
      child: IgnorePointer(
        ignoring: ignoring,
        child: Stack(
          children: [
            // frame: the surrounding rail + the central bar read as stone
            Container(
              width: 574,
              height: 420,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.ink, width: 4),
                color: AppColors.stone,
              ),
            ),

            // outer + home board backgrounds (ivory field, tap to deselect)
            for (final rect in const [
              Rect.fromLTWH(20, 20, 216, 380),
              Rect.fromLTWH(284, 20, 216, 380),
            ])
              Positioned.fromRect(
                rect: rect,
                child: GestureDetector(
                  onTap: onTapBoard,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.ivory,
                      border: Border.all(color: AppColors.ink),
                    ),
                  ),
                ),
              ),

            // pips and labels
            for (final layout in PipLayout.layouts!) ...[
              Positioned.fromRect(
                rect: layout.rect,
                child: GestureDetector(
                  onTap: onTapPip == null
                      ? null
                      : () => onTapPip!(layout.pipNo),
                  child: PipTriangle(
                    pip: layout.pipNo,
                    highlight: _highlightPip(layout.pipNo),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: layout.labelRect,
                child: PipLabel(layout: layout, reversed: reversed),
              ),
            ],

            // off trays (player1 bottom, player2 top)
            for (final player in GammonPlayer.values)
              Positioned.fromRect(
                rect: player == GammonPlayer.one
                    ? const Rect.fromLTWH(520, 216, 32, 183)
                    : const Rect.fromLTWH(520, 20, 32, 183),
                child: GestureDetector(
                  onTap: onTapOff == null ? null : () => onTapOff!(player),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.bone,
                      border: Border.all(
                        color: _highlightOff(player)
                            ? AppColors.accent
                            : AppColors.ink,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),

            // doubling cube (issue #12)
            Positioned.fromRect(
              rect: _cubeRect(game.cube.owner),
              child: GestureDetector(
                onTap: onTapCube,
                child: DoublingCubeView(cube: game.cube, reversed: reversed),
              ),
            ),

            // pieces; moving pieces are drawn last so they appear on top of
            // stationary pieces (issue #6)
            for (final layout in PieceLayout.drawOrder(
              PieceLayout.getLayouts(game.board, _pipNosToHighlight),
              pieceAnimations.keys.toSet(),
            ))
              pieceAnimations.containsKey(layout.pieceID)
                  ? AnimatedPiece.fromLayouts(
                      layouts: pieceAnimations[layout.pieceID]!,
                      delay: pieceDelays[layout.pieceID] ?? Duration.zero,
                      onEnd: () => onPieceAnimationEnd?.call(layout.pieceID),
                      child: GestureDetector(
                        onTap: onTapPip == null
                            ? null
                            : () => onTapPip!(layout.pipNo),
                        child: PieceView(layout: layout.animated),
                      ),
                    )
                  : Positioned.fromRect(
                      rect: layout.rect,
                      child: GestureDetector(
                        onTap: onTapPip == null
                            ? null
                            : () => onTapPip!(layout.pipNo),
                        child: PieceView(layout: layout),
                      ),
                    ),

            // dice (only once someone has rolled)
            if (game.dice.length == 2 || game.dice.length == 4)
              for (final layout in DieLayout.getLayouts(game))
                Positioned.fromRect(
                  rect: layout.rect,
                  child: DieView(layout: layout, onTap: onTapDice),
                ),

            // pip counts
            for (final layout in PipCountLayout.getLayouts(game))
              Positioned.fromRect(
                rect: layout.rect,
                child: PipCountView(layout: layout, reversed: reversed),
              ),
          ],
        ),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import 'dice.dart';
import 'game_play_page.dart' show InnerShadingRect;
import 'model.dart';
import 'pieces.dart';
import 'pip_count.dart';
import 'pips.dart';

// A render of a [GammonState]: the same board the local game draws. Read-only
// when watching (milestone 1); when [onTapPip] is supplied it overlays tap
// targets for playing a FIBS game via tap-to-move (milestone 2). Points report
// their pip number; the bar reports [myBarPip] and our off tray [myOffPip].
class ReadOnlyBoardView extends StatelessWidget {
  const ReadOnlyBoardView({
    required this.game,
    super.key,
    this.onTapPip,
    this.selectedPip,
    this.myBarPip,
    this.myOffPip,
  });
  final GammonState game;
  final void Function(int pipNo)? onTapPip;
  final int? selectedPip;
  final int? myBarPip; // 25 (X) or 0 (O) — where our hit checkers wait
  final int? myOffPip; // 0 (X, bottom tray) or 25 (O, top tray)

  bool get _interactive => onTapPip != null;

  @override
  Widget build(BuildContext context) => FittedBox(
        child: Stack(
          children: [
            // frame
            Container(
              width: 574,
              height: 420,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 5),
                color: Colors.grey[300],
              ),
            ),

            // outer + home board backgrounds
            for (final rect in const [
              Rect.fromLTWH(20, 20, 216, 380),
              Rect.fromLTWH(284, 20, 216, 380),
            ])
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.green[900],
                    border: Border.all(color: Colors.black),
                  ),
                ),
              ),

            // pips + labels
            for (final layout in PipLayout.layouts!) ...[
              Positioned.fromRect(
                rect: layout.rect,
                child: PipTriangle(pip: layout.pipNo, highlight: false),
              ),
              Positioned.fromRect(
                rect: layout.labelRect,
                child: PipLabel(layout: layout),
              ),
            ],

            // off trays
            for (final rect in const [
              Rect.fromLTWH(520, 216, 32, 183),
              Rect.fromLTWH(520, 20, 32, 183),
            ])
              Positioned.fromRect(
                rect: rect,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.green[900],
                    border: Border.all(color: Colors.black, width: 2),
                  ),
                ),
              ),

            const InnerShadingRect(rect: Rect.fromLTWH(20, 20, 216, 380)),
            const InnerShadingRect(rect: Rect.fromLTWH(284, 20, 216, 380)),
            const InnerShadingRect(rect: Rect.fromLTWH(520, 216, 32, 183)),
            const InnerShadingRect(rect: Rect.fromLTWH(520, 20, 32, 183)),

            // doubling cube
            Positioned.fromRect(
              rect: const Rect.fromLTWH(238, 186, 44, 44),
              child: DoublingCubeView(cube: game.cube),
            ),

            // pieces
            for (final layout in PieceLayout.getLayouts(game.board))
              Positioned.fromRect(
                rect: layout.rect,
                child: PieceView(layout: layout),
              ),

            // dice (only once someone has rolled)
            if (game.dice.length == 2 || game.dice.length == 4)
              for (final layout in DieLayout.getLayouts(game))
                Positioned.fromRect(
                  rect: layout.rect,
                  child: DieView(layout: layout),
                ),

            // pip counts
            for (final layout in PipCountLayout.getLayouts(game))
              Positioned.fromRect(
                rect: layout.rect,
                child: PipCountView(layout: layout),
              ),

            // tap targets for playing (milestone 2)
            if (_interactive) ...[
              // the 24 points
              for (final layout in PipLayout.layouts!)
                _tapZone(layout.rect, layout.pipNo),
              // the bar (center) -> our bar pip
              if (myBarPip != null)
                _tapZone(const Rect.fromLTWH(236, 20, 48, 380), myBarPip!),
              // our off tray (bottom for X, top for O) -> our off pip
              if (myOffPip != null)
                _tapZone(
                  myOffPip == 0
                      ? const Rect.fromLTWH(520, 216, 32, 183)
                      : const Rect.fromLTWH(520, 20, 32, 183),
                  myOffPip!,
                ),
            ],
          ],
        ),
      );

  Widget _tapZone(Rect rect, int pipNo) => Positioned.fromRect(
        rect: rect,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => onTapPip!(pipNo),
          child: selectedPip == pipNo
              ? DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 3),
                  ),
                )
              : null,
        ),
      );
}

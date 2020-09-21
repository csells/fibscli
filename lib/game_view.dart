import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:fibscli/pips.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/material.dart';

class GameView extends StatefulWidget {
  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  final _game = GammonState();
  var _legalMoves = <int>[];
  var _fromPip = 0;

  @override
  void initState() {
    super.initState();
    _game.nextTurn();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<GammonState>(
        notifier: _game,
        builder: (context, game, child) => Container(
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
                    Positioned.fromRect(
                      rect: layout.rect,
                      child: GestureDetector(
                        onTap: () => _legalMoves.contains(layout.pip) ? _pipTap(layout.pip) : null,
                        child: PipTriangle(
                          pip: layout.pip,
                          highlight: _legalMoves.contains(layout.pip),
                        ),
                      ),
                    ),
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
                  // Positioned.fromRect(
                  //   rect: Rect.fromLTWH(238, 186, 44, 44),
                  //   child: DoublingCubeView(),
                  // ),

                  // pieces
                  for (final layout in PieceLayout.getLayouts(game, highlightedPiecePip: _fromPip))
                    Positioned.fromRect(
                      rect: layout.rect,
                      child: GestureDetector(
                        onTap: () => _togglePieceHilight(layout.pip),
                        child: PieceView(layout: layout),
                      ),
                    ),

                  // dice
                  for (final layout in DieLayout.getLayouts(game))
                    Positioned.fromRect(
                      rect: layout.rect,
                      child: DieView(
                        layout: layout,
                        onTap: _diceTap,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

  void _togglePieceHilight(int pip) {
    // reset and bail early if we're turning off the highlighting
    setState(() => _legalMoves.clear());
    if (_fromPip != 0) {
      setState(() => _fromPip = 0);
      return;
    }

    final legalMoves = _game.getLegalMoves(pip);
    if (legalMoves.isEmpty) return;

    setState(() {
      _fromPip = pip;
      _legalMoves = legalMoves.toList();
    });
  }

  void _pipTap(int pip) {
    assert(_legalMoves.contains(pip));
    _game.doMoveOrHit(fromPip: _fromPip, toPip: pip);
    _legalMoves.clear();
    _fromPip = 0;
    setState(() {});
  }

  void _diceTap() {
    _game.nextTurn();
  }
}

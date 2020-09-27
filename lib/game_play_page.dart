import 'package:fibscli/dice.dart';
import 'package:fibscli/main.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:fibscli/pips.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class GamePlayPage extends StatelessWidget {
  final _controller = GameViewController();

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(App.title),
          actions: [IconButton(icon: Icon(Icons.sync), onPressed: _tapSync)],
        ),
        body: GameView(controller: _controller),
      );

  void _tapSync() => _controller.reversed = !_controller.reversed;
}

class GameViewController {
  final _reversed = ValueNotifier(false);
  bool get reversed => _reversed.value;
  set reversed(bool reversed) => _reversed.value = reversed;
}

class GameView extends StatefulWidget {
  final GameViewController controller;
  GameView({GameViewController controller}) : controller = controller ?? GameViewController();

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  final _game = GammonState();
  var _legalMoves = <GammonMove>[];
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
            child: ValueListenableBuilder<bool>(
              valueListenable: widget.controller._reversed,
              builder: (context, reversed, child) => RotatedBox(
                quarterTurns: reversed ? 2 : 0,
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
                            onTap: () => _pipTap(layout.pip),
                            child: PipTriangle(
                              pip: layout.pip,
                              highlight: _legalMoves.hasHops(fromPip: _fromPip, toPip: layout.pip),
                            ),
                          ),
                        ),
                        Positioned.fromRect(
                            rect: layout.labelRect, child: PipLabel(layout: layout, reversed: reversed)),
                      ],

                      // player1 home
                      Positioned.fromRect(
                        rect: Rect.fromLTWH(520, 216, 32, 183),
                        child: Container(
                          decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                        ),
                      ),

                      // player2 home
                      Positioned.fromRect(
                        rect: Rect.fromLTWH(520, 20, 32, 183),
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
                            onTap: () => _pieceTap(layout.pip),
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
          ),
        ),
      );

  void _pieceTap(int pip) {
    // if there are legal moves, try to move
    if (_legalMoves.isNotEmpty) {
      _move(pip);
      return;
    }

    // calculate legal moves
    assert(_legalMoves.isEmpty);
    final legalMoves = _game.getLegalMoves(pip).toList();
    if (legalMoves.isEmpty) return;

    setState(() {
      _fromPip = pip;
      _legalMoves = legalMoves;
    });
  }

  void _pipTap(int toPip) => _move(toPip);

  void _move(int toEndPip) {
    // find the first set of hops that move from the current pip to the desired pip
    final hops = _legalMoves.hops(fromPip: _fromPip, toPip: toEndPip);

    // if this is a legal move, do the move
    if (hops != null) {
      // move the piece for each hop
      var fromPip = _fromPip;
      for (final hop in hops) {
        final toPip = fromPip + hop;
        _game.doMoveOrHit(fromPip: fromPip, toPip: toPip);
        fromPip = toPip;
      }
    }

    // reset
    setState(() {
      _legalMoves.clear();
      _fromPip = 0;
    });
  }

  void _diceTap() => _game.nextTurn();
}

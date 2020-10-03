import 'package:fibscli/dice.dart';
import 'package:fibscli/main.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:fibscli/pip_count.dart';
import 'package:fibscli/pips.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GamePlayPage extends StatefulWidget {
  @override
  _GamePlayPageState createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage> {
  final _controller = GameViewController();
  final _prefsFuture = SharedPreferences.getInstance();
  SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();
    _prefsFuture.then((prefs) {
      _prefs = prefs;
      _controller.addListener(_savePrefs);
    });
  }

  void _savePrefs() {
    _prefs.setBool('reversed', _controller.reversed);
  }

  @override
  void dispose() {
    _controller.removeListener(_savePrefs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(App.title),
          actions: [
            IconButton(
              tooltip: 'reverse board',
              icon: Icon(Icons.sync),
              onPressed: _tapSync,
            )
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'undo turn',
          onPressed: _tapUndo,
          child: Icon(Icons.undo),
        ),
        body: FutureBuilder2<SharedPreferences>(
          future: _prefsFuture,
          data: (context, prefs) {
            _controller.reversed = prefs.getBool('reversed') ?? false;
            return GameView(controller: _controller);
          },
        ),
      );

  void _tapSync() => _controller.reversed = !_controller.reversed;
  void _tapUndo() => _controller.undo();
}

class GameViewController extends ChangeNotifier {
  void Function() _onUndo;
  bool _reversed;

  bool get reversed => _reversed;
  set reversed(bool reversed) {
    _reversed = reversed;
    notifyListeners();
  }

  set onUndo(void Function() onUndo) => _onUndo = onUndo;
  void undo() => _onUndo();
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
  int _fromPip;

  @override
  void initState() {
    super.initState();
    widget.controller.onUndo = () => _game.undo();
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
            child: ChangeNotifierBuilder<GameViewController>(
              notifier: widget.controller,
              builder: (context, controller, child) => RotatedBox(
                quarterTurns: controller.reversed ? 2 : 0,
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
                              highlight: _legalMoves.hasHops(fromPipNo: _fromPip, toPipNo: layout.pip),
                            ),
                          ),
                        ),
                        Positioned.fromRect(
                          rect: layout.labelRect,
                          child: PipLabel(layout: layout, reversed: controller.reversed),
                        ),
                      ],

                      // player1 home
                      Positioned.fromRect(
                        rect: Rect.fromLTWH(520, 216, 32, 183),
                        child: GestureDetector(
                          onTap: () => _homeTap(Player.one),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green[900],
                              border: Border.all(
                                  color: _highlightHome(Player.one) ? Colors.yellow : Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ),

                      // player2 home
                      Positioned.fromRect(
                        rect: Rect.fromLTWH(520, 20, 32, 183),
                        child: GestureDetector(
                          onTap: () => _homeTap(Player.two),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.green[900],
                              border: Border.all(
                                  color: _highlightHome(Player.two) ? Colors.yellow : Colors.black, width: 2),
                            ),
                          ),
                        ),
                      ),

                      // outer board shading
                      InnerShadingRect(rect: Rect.fromLTWH(20, 20, 216, 380)),

                      // inner board shading
                      InnerShadingRect(rect: Rect.fromLTWH(284, 20, 216, 380)),

                      // player1 home shading
                      InnerShadingRect(rect: Rect.fromLTWH(520, 216, 32, 183)),

                      // player2 home shading
                      InnerShadingRect(rect: Rect.fromLTWH(520, 20, 32, 183)),

                      // doubling cube: undoubled
                      // Positioned.fromRect(
                      //   rect: Rect.fromLTWH(238, 186, 44, 44),
                      //   child: DoublingCubeView(),
                      // ),

                      // pieces
                      for (final layout in PieceLayout.getLayouts(game, highlightedPiecePip: _fromPip))
                        AnimatedPositioned.fromRect(
                          duration: Duration(milliseconds: 250),
                          key: ValueKey(layout.pieceId),
                          rect: layout.rect,
                          child: GestureDetector(
                            onTap: GammonRules.signFor(_game.turnPlayer) != layout.pieceId.sign
                                ? null
                                : () => _pieceTap(
                                    layout.pipNo == 0 ? GammonRules.barPipNoFor(_game.turnPlayer) : layout.pipNo),
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

                      // pip counts
                      for (final layout in PipCountLayout.getLayouts(game))
                        Positioned.fromRect(
                          rect: layout.rect,
                          child: PipCountView(layout: layout, reversed: controller.reversed),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  void _pieceTap(int pipNo) {
    // if there are legal moves, try to move
    if (_legalMoves.isNotEmpty) {
      _move(pipNo);
      return;
    }

    // calculate legal moves
    assert(_legalMoves.isEmpty);
    final legalMoves = _game.getLegalMoves(pipNo).toList();
    if (legalMoves.isEmpty) return;

    setState(() {
      _fromPip = pipNo;
      _legalMoves = legalMoves;
    });
  }

  void _homeTap(Player player) => _move(GammonRules.homePipNoFor(player));

  void _pipTap(int toPip) => _move(toPip);

  void _move(int toEndPip) {
    // find the first set of hops that move from the current pip to the desired pip
    final hops = _legalMoves.hops(fromPipNo: _fromPip, toPipNo: toEndPip);

    // if this is a legal move, do the move
    if (hops != null) {
      // move the piece for each hop
      var fromPip = _fromPip;
      for (final hop in hops) {
        final toPip = fromPip + hop;
        _game.doMoveHitOrBearOff(fromPipNo: fromPip, toPipNo: toPip);
        fromPip = toPip;
      }
    }

    // reset
    setState(() {
      _legalMoves.clear();
      _fromPip = null;
    });
  }

  void _diceTap() {
    // can't go to the next turn until there are no more available dice
    if (_game.dice.every((d) => !d.available)) _game.nextTurn();
  }

  bool _highlightHome(Player player) {
    final homePipNo = GammonRules.homePipNoFor(player);
    return _legalMoves.any((m) => m.toPipNo == homePipNo);
  }
}

class InnerShadingRect extends StatelessWidget {
  final Rect rect;
  const InnerShadingRect({
    Key key,
    @required this.rect,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) => Positioned.fromRect(
        rect: rect,
        child: Stack(
          children: [
            Container(
              height: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(.20), Colors.transparent],
                ),
              ),
            ),
            Container(
              width: 10,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Colors.black.withOpacity(.20), Colors.transparent],
                ),
              ),
            ),
          ],
        ),
      );
}

import 'dart:math';
import 'package:fibscli/animated_layouts.dart';
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
import 'package:url_launcher/url_launcher.dart' as ul;

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
        backgroundColor: Colors.green,
        appBar: AppBar(
          title: Text(App.title),
          actions: [
            IconButton(
              tooltip: 'provide feedback',
              icon: Icon(Icons.feedback),
              onPressed: _tapFeedback,
            ),
            IconButton(
              tooltip: 'backgammon help',
              icon: Icon(Icons.help),
              onPressed: _tapHelp,
            ),
            IconButton(
              tooltip: 'reverse board',
              icon: Icon(Icons.sync),
              onPressed: _tapReverse,
            ),
            IconButton(
              tooltip: 'new game',
              icon: Icon(Icons.fiber_new),
              onPressed: _tapNewGame,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          tooltip: 'undo turn',
          onPressed: _controller.canUndo ? _tapUndo : null,
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

  void _tapNewGame() => _controller.newGame();
  void _tapReverse() => _controller.reversed = !_controller.reversed;
  void _tapUndo() => _controller.undo();
  void _tapFeedback() => ul.launch('https://github.com/csells/fibscli/issues');
  void _tapHelp() => ul.launch('https://www.bkgm.com/rules.html');
}

class GameViewController extends ChangeNotifier {
  bool _reversed = false;
  var _canUndo = true;
  void Function() _onUndo;
  void Function() _onNewGame;

  bool get reversed => _reversed;
  set reversed(bool reversed) {
    _reversed = reversed;
    notifyListeners();
  }

  bool get canUndo => _canUndo;
  set canUndo(bool canUndo) {
    _canUndo = canUndo;
    notifyListeners();
  }

  set onUndo(void Function() onUndo) => _onUndo = onUndo;
  void undo() => _onUndo();

  set onNewGame(void Function() onNewGame) => _onNewGame = onNewGame;
  void newGame() => _onNewGame();
}

class GameView extends StatefulWidget {
  final GameViewController controller;
  GameView({GameViewController controller}) : controller = controller ?? GameViewController();

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  GammonState _game;
  var _legalMovesForPips = <int, List<GammonMove>>{};
  int _fromPipNo;
  final _pieceLayouts = <int, List<PieceLayout>>{};

  @override
  void initState() {
    super.initState();

    widget.controller.onUndo = () {
      assert(!_game.gameOver);
      _game.undoTurn();
      _reset();
    };

    widget.controller.onNewGame = () async {
      final ok = _game.gameOver ? true : await QuitGameDialog.show(context); // result can return null
      if (ok == true) _newGame();
    };

    _newGame();
  }

  @override
  void dispose() {
    if (_game != null) _game.removeListener(_gameChanged);
    super.dispose();
  }

  void _newGame() {
    if (_game != null) _game.removeListener(_gameChanged);

    _game = GammonState();
    widget.controller.canUndo = true;
    _game.addListener(_gameChanged);
    _reset();
  }

  void _gameChanged() async {
    if (!_game.gameOver) return;

    _game.removeListener(_gameChanged);
    widget.controller.canUndo = false;
    final ok = await NewGameDialog.show(context, _game.turnPlayer); // result can be null
    if (ok == true) _newGame();
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
              builder: (context, controller, child) => AnimatedContainer(
                duration: Duration(milliseconds: 500),
                transform: Matrix4.rotationZ(controller.reversed ? pi : 0),
                transformAlignment: Alignment.center,
                child: FittedBox(
                  child: IgnorePointer(
                    ignoring: _game.gameOver,
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

                        // outer board
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(20, 20, 216, 380),
                          child: GestureDetector(
                            onTap: _tapBoard,
                            child: Container(
                              decoration:
                                  BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                            ),
                          ),
                        ),

                        // home board
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(284, 20, 216, 380),
                          child: GestureDetector(
                            onTap: _tapBoard,
                            child: Container(
                              decoration:
                                  BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                            ),
                          ),
                        ),

                        // pips and labels
                        for (final layout in PipLayout.layouts) ...[
                          Positioned.fromRect(
                            rect: layout.rect,
                            child: GestureDetector(
                              onTap: () => _tapPip(layout.pipNo),
                              child: PipTriangle(
                                pip: layout.pipNo,
                                highlight: _highlightPip(layout.pipNo),
                              ),
                            ),
                          ),
                          Positioned.fromRect(
                            rect: layout.labelRect,
                            child: PipLabel(layout: layout, reversed: controller.reversed),
                          ),
                        ],

                        // player1 off
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(520, 216, 32, 183),
                          child: GestureDetector(
                            onTap: () => _tapOff(GammonPlayer.one),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green[900],
                                border: Border.all(
                                    color: _highlightOff(GammonPlayer.one) ? Colors.yellow : Colors.black, width: 2),
                              ),
                            ),
                          ),
                        ),

                        // player2 off
                        Positioned.fromRect(
                          rect: Rect.fromLTWH(520, 20, 32, 183),
                          child: GestureDetector(
                            onTap: () => _tapOff(GammonPlayer.two),
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.green[900],
                                border: Border.all(
                                    color: _highlightOff(GammonPlayer.two) ? Colors.yellow : Colors.black, width: 2),
                              ),
                            ),
                          ),
                        ),

                        InnerShadingRect(rect: Rect.fromLTWH(20, 20, 216, 380)), // outer board shading
                        InnerShadingRect(rect: Rect.fromLTWH(284, 20, 216, 380)), // home board shading
                        InnerShadingRect(rect: Rect.fromLTWH(520, 216, 32, 183)), // player1 home shading
                        InnerShadingRect(rect: Rect.fromLTWH(520, 20, 32, 183)), // player2 home shading

                        // doubling cube: undoubled
                        // Positioned.fromRect(
                        //   rect: Rect.fromLTWH(238, 186, 44, 44),
                        //   child: DoublingCubeView(),
                        // ),

                        // pieces
                        for (final layout in PieceLayout.getLayouts(game.board, _pipNosToHighlight))
                          _pieceLayouts.containsKey(layout.pieceID)
                              ? AnimatedPiece.fromLayouts(
                                  layouts: _pieceLayouts[layout.pieceID],
                                  onEnd: () => _endPieceAnimation(layout.pieceID),
                                  child: GestureDetector(
                                    onTap: () => _tapPiece(layout.pipNo),
                                    child: PieceView(layout: layout.animated),
                                  ),
                                )
                              : Positioned.fromRect(
                                  rect: layout.rect,
                                  child: GestureDetector(
                                    onTap: () => _tapPiece(layout.pipNo),
                                    child: PieceView(layout: layout),
                                  ),
                                ),

                        // dice
                        for (final layout in DieLayout.getLayouts(game))
                          Positioned.fromRect(
                            rect: layout.rect,
                            child: DieView(
                              layout: layout,
                              onTap: _tapDice,
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
        ),
      );

  List<int> get _pipNosToHighlight => _fromPipNo != null ? [_fromPipNo] : _legalMovesForPips.keys.toList();

  void _tapPiece(int pipNo) => _tapPip(pipNo);
  void _tapOff(GammonPlayer player) => _move(GammonRules.offPipNoFor(player));

  void _tapPip(int pipNo) {
    if (_fromPipNo == null) {
      // if there's no pip to move from selected and it has legal moves, select it
      if (_legalMovesForPips[pipNo] != null) setState(() => _fromPipNo = pipNo);
    } else {
      final _oldFromPipNo = _fromPipNo;

      // if there is a pip to move from selected, attempt to move to this piece
      if (!_move(pipNo)) {
        // if the move failed, check if it's got legal moves and highlight it,
        // unless it's the same out pip, then toggle it on/off
        if (_oldFromPipNo != pipNo && _legalMovesForPips[pipNo] != null) setState(() => _fromPipNo = pipNo);
      }
    }
  }

  // remove each animated piece from the list of pieces to animate
  void _endPieceAnimation(int pieceID) {
    final removed = _pieceLayouts.remove(pieceID);
    assert(removed != null);

    // the last piece has been animated, so draw the final state of the board w/ labels, on edge, etc.
    if (_pieceLayouts.isEmpty) {
      print('endAnimation');
      setState(() {});
    }
  }

  bool _move(int toEndPipNo) {
    // find the first set of hops that move from the current pip to the desired pip
    final hops =
        _fromPipNo == null ? null : _legalMovesForPips[_fromPipNo].hops(fromPipNo: _fromPipNo, toPipNo: toEndPipNo);

    // if this is a legal move, do the move
    if (hops != null) {
      final initialBoard = List<List<int>>.generate(_game.board.length, (i) => List<int>.from(_game.board[i]));
      final move = GammonMove(fromPipNo: _fromPipNo, toPipNo: toEndPipNo, hops: hops);
      final deltasForHops = _game.applyMove(move: move);

      // convert game states for each hop into a sequence of layouts for each affected piece
      assert(deltasForHops.length == hops.length);
      assert(_pieceLayouts.isEmpty);
      _pieceLayouts.addAll(_pieceLayoutsFor(initialBoard, deltasForHops));
    }

    _reset();
    return hops != null;
  }

  void _reset() {
    setState(() {
      _legalMovesForPips = _game.getAllLegalMoves();
      _fromPipNo = null;
    });
  }

  void _tapDice() {
    // can't go to the next turn until there are no more available dice
    if (_game.dice.every((d) => !d.available)) {
      _game.commitTurn();
      _reset();
    }
  }

  bool _highlightOff(GammonPlayer player) {
    final offPipNo = GammonRules.offPipNoFor(player);
    final legalMoves = _fromPipNo == null ? null : _legalMovesForPips[_fromPipNo];
    return legalMoves != null && legalMoves.any((m) => m.toPipNo == offPipNo);
  }

  bool _highlightPip(int pipNo) {
    final legalMoves = _fromPipNo == null ? null : _legalMovesForPips[_fromPipNo];
    final result = legalMoves != null && legalMoves.hasHops(fromPipNo: _fromPipNo, toPipNo: pipNo);
    return result;
  }

  static Map<int, List<PieceLayout>> _pieceLayoutsFor(
    List<List<int>> initialBoard,
    List<List<GammonDelta>> deltasForHops,
  ) {
    // copy the initial board; it'll change as we apply deltas
    final board = List<List<int>>.generate(initialBoard.length, (i) => List<int>.from(initialBoard[i]));

    // find the set of pieces that are affected by this move
    final pieceIDs = [
      for (final deltasForHop in deltasForHops)
        for (final delta in deltasForHop) delta.pieceID
    ];

    // initialize the list of layouts that each piece travels
    final pieceLayouts = <int, List<PieceLayout>>{};
    for (final pieceID in pieceIDs) pieceLayouts[pieceID] = [];

    // get layout for each piece at each hop (most won't move)
    // start with an empty delta to handle initial board state
    for (final deltasForHop in [<GammonDelta>[], ...deltasForHops]) {
      // update the board for the this hop
      GammonRules.applyDeltasForHop(board, deltasForHop);

      final layouts = PieceLayout.getLayouts(board);
      for (final pieceID in pieceIDs) {
        // add the layout to this hop for this piece
        final layout = layouts.firstWhere((l) => l.pieceID == pieceID);
        pieceLayouts[pieceID].add(layout);
      }
    }

    return pieceLayouts;
  }

  void _tapBoard() {
    _reset();
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

class QuitGameDialog extends StatelessWidget {
  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Game Already In Progress'),
        content: Text('OK to quit current game?'),
        actions: [
          OutlineButton(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Keep Playing'),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Quit Game'),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );

  static Future<bool> show(BuildContext context) =>
      showDialog<bool>(context: context, builder: (context) => QuitGameDialog());
}

class NewGameDialog extends StatelessWidget {
  final GammonPlayer winner;
  const NewGameDialog(this.winner);

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text('Player ${winner == GammonPlayer.one ? 1 : 2} wins!'),
        content: Text('Would you like to play another game?'),
        actions: [
          OutlineButton(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('No, Thanks'),
            ),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Yes, Please!'),
            ),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      );

  static Future<bool> show(BuildContext context, GammonPlayer winner) =>
      showDialog<bool>(context: context, builder: (context) => NewGameDialog(winner));
}

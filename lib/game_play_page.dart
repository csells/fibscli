import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'animated_layouts.dart';
import 'dice.dart';
import 'main.dart';
import 'model.dart';
import 'pieces.dart';
import 'pip_count.dart';
import 'pips.dart';
import 'tinystate.dart';

class GamePlayPage extends StatefulWidget {
  const GamePlayPage({super.key});

  @override
  _GamePlayPageState createState() => _GamePlayPageState();
}

class _GamePlayPageState extends State<GamePlayPage> {
  final _controller = GameViewController();
  final _prefsFuture = SharedPreferences.getInstance();
  late SharedPreferences _prefs;

  @override
  void initState() {
    super.initState();

    unawaited(
      _prefsFuture.then((prefs) {
        _prefs = prefs;
        _controller.reversed = prefs.getBool('reversed') ?? false;
        _controller.addListener(_savePrefs);
      }),
    );
  }

  void _savePrefs() {
    unawaited(_prefs.setBool('reversed', _controller.reversed));
  }

  @override
  void dispose() {
    _controller.removeListener(_savePrefs);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<GameViewController>(
        notifier: _controller,
        builder: (context, controller, child) => Scaffold(
          backgroundColor: Colors.green,
          appBar: AppBar(
            title: const Text(App.title),
            elevation: 0,
            actions: [
              if (controller.canAutoBearOff)
                IconButton(
                  tooltip: 'auto bear off',
                  icon: const Icon(Icons.fast_forward),
                  onPressed: _tapAutoBearOff,
                ),
              IconButton(
                tooltip: 'win chances & cube advice',
                icon: const Icon(Icons.insights),
                onPressed: _tapOdds,
              ),
              IconButton(
                tooltip: 'provide feedback',
                icon: const Icon(Icons.feedback),
                onPressed: _tapFeedback,
              ),
              IconButton(
                tooltip: 'backgammon help',
                icon: const Icon(Icons.help),
                onPressed: _tapHelp,
              ),
              IconButton(
                tooltip: 'reverse board',
                icon: const Icon(Icons.sync),
                onPressed: _tapReverse,
              ),
              IconButton(
                tooltip: 'new game',
                icon: const Icon(Icons.fiber_new),
                onPressed: _tapNewGame,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'undo turn',
            onPressed: controller.canUndo ? _tapUndo : null,
            child: const Icon(Icons.undo),
          ),
          body: FutureBuilder2<SharedPreferences>(
            future: _prefsFuture,
            data: (context, prefs) => GameView(controller: _controller),
          ),
        ),
      );

  void _tapNewGame() => _controller.newGame();
  void _tapReverse() => _controller.reversed = !_controller.reversed;
  void _tapUndo() => _controller.undo();
  void _tapAutoBearOff() => _controller.autoBearOff();
  void _tapOdds() => _controller.showOdds();
  void _tapFeedback() => unawaited(
    ul.launchUrl(Uri.parse('https://github.com/csells/fibscli/issues')),
  );
  void _tapHelp() =>
      unawaited(ul.launchUrl(Uri.parse('https://www.bkgm.com/rules.html')));
}

class GameViewController extends ChangeNotifier {
  bool _reversed = false;
  var _canUndo = true;
  var _canAutoBearOff = false;
  // command hooks the GameView injects; invoked by the matching methods below
  late void Function() onUndo;
  late void Function() onNewGame;
  late void Function() onAutoBearOff;
  late void Function() onShowOdds;

  bool get reversed => _reversed;
  set reversed(bool reversed) {
    if (_reversed == reversed) return;
    _reversed = reversed;
    notifyListeners();
  }

  bool get canUndo => _canUndo;
  set canUndo(bool canUndo) {
    if (_canUndo == canUndo) return;
    _canUndo = canUndo;
    notifyListeners();
  }

  bool get canAutoBearOff => _canAutoBearOff;
  set canAutoBearOff(bool canAutoBearOff) {
    if (_canAutoBearOff == canAutoBearOff) return;
    _canAutoBearOff = canAutoBearOff;
    notifyListeners();
  }

  void undo() => onUndo();
  void newGame() => onNewGame();
  void autoBearOff() => onAutoBearOff();
  void showOdds() => onShowOdds();
}

class GameView extends StatefulWidget {
  GameView({super.key, GameViewController? controller})
    : controller = controller ?? GameViewController();
  final GameViewController controller;

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  GammonState? _game;
  var _legalMovesForPips = <int, List<GammonMove>>{};
  int? _fromPipNo;
  final _pieceLayouts = <int?, List<PieceLayout>>{};
  final _pieceDelays = <int?, Duration>{};

  @override
  void initState() {
    super.initState();

    widget.controller.onUndo = () {
      assert(!_game!.gameOver);
      _game!.undoTurn();
      _reset();
    };

    widget.controller.onNewGame = () async {
      final ok = _game!.gameOver
          ? true
          : await QuitGameDialog.show(context); // result can return null
      if (ok ?? false) _newGame();
    };

    widget.controller.onAutoBearOff = () {
      assert(_game!.canAutoBearOff);
      _game!.autoBearOff();
      _reset();
    };

    widget.controller.onShowOdds = () => OddsDialog.show(context, _game!);

    _newGame();
  }

  @override
  void dispose() {
    if (_game != null) _game!.removeListener(_gameChanged);
    super.dispose();
  }

  void _newGame() {
    if (_game != null) _game!.removeListener(_gameChanged);

    _game = GammonState();
    widget.controller.canUndo = true;
    _game!.addListener(_gameChanged);
    _reset();
  }

  Future<void> _gameChanged() async {
    if (!_game!.gameOver) return;

    _game!.removeListener(_gameChanged);
    widget.controller.canUndo = false;
    final ok = await NewGameDialog.show(
      context,
      _game!.turnPlayer,
      _game!,
    ); // result can be null
    if (ok ?? false) _newGame();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<GammonState?>(
    notifier: _game,
    builder: (context, game, child) => SizedBox.expand(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: ChangeNotifierBuilder<GameViewController>(
          notifier: widget.controller,
          builder: (context, controller, child) => AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            transform: Matrix4.rotationZ(controller.reversed ? pi : 0),
            transformAlignment: Alignment.center,
            child: FittedBox(
              child: IgnorePointer(
                ignoring: _game!.gameOver,
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
                      rect: const Rect.fromLTWH(20, 20, 216, 380),
                      child: GestureDetector(
                        onTap: _tapBoard,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            border: Border.all(color: Colors.black),
                          ),
                        ),
                      ),
                    ),

                    // home board
                    Positioned.fromRect(
                      rect: const Rect.fromLTWH(284, 20, 216, 380),
                      child: GestureDetector(
                        onTap: _tapBoard,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            border: Border.all(color: Colors.black),
                          ),
                        ),
                      ),
                    ),

                    // pips and labels
                    for (final layout in PipLayout.layouts!) ...[
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
                        child: PipLabel(
                          layout: layout,
                          reversed: controller.reversed,
                        ),
                      ),
                    ],

                    // player1 off
                    Positioned.fromRect(
                      rect: const Rect.fromLTWH(520, 216, 32, 183),
                      child: GestureDetector(
                        onTap: () => _tapOff(GammonPlayer.one),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            border: Border.all(
                              color: _highlightOff(GammonPlayer.one)
                                  ? Colors.yellow
                                  : Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // player2 off
                    Positioned.fromRect(
                      rect: const Rect.fromLTWH(520, 20, 32, 183),
                      child: GestureDetector(
                        onTap: () => _tapOff(GammonPlayer.two),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green[900],
                            border: Border.all(
                              color: _highlightOff(GammonPlayer.two)
                                  ? Colors.yellow
                                  : Colors.black,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const InnerShadingRect(
                      rect: Rect.fromLTWH(20, 20, 216, 380),
                    ), // outer board shading
                    const InnerShadingRect(
                      rect: Rect.fromLTWH(284, 20, 216, 380),
                    ), // home board shading
                    const InnerShadingRect(
                      rect: Rect.fromLTWH(520, 216, 32, 183),
                    ), // player1 home shading
                    const InnerShadingRect(
                      rect: Rect.fromLTWH(520, 20, 32, 183),
                    ), // player2 home shading
                    // doubling cube (issue #12)
                    Positioned.fromRect(
                      rect: _cubeRect(_game!.cube.owner),
                      child: GestureDetector(
                        onTap: _tapCube,
                        child: DoublingCubeView(
                          cube: _game!.cube,
                          reversed: controller.reversed,
                        ),
                      ),
                    ),

                    // pieces; moving pieces are drawn last so they appear
                    // on top of stationary pieces (issue #6)
                    for (final layout in PieceLayout.drawOrder(
                      PieceLayout.getLayouts(game!.board, _pipNosToHighlight),
                      _pieceLayouts.keys.toSet(),
                    ))
                      _pieceLayouts.containsKey(layout.pieceID)
                          ? AnimatedPiece.fromLayouts(
                              layouts: _pieceLayouts[layout.pieceID]!,
                              delay:
                                  _pieceDelays[layout.pieceID] ?? Duration.zero,
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
                        child: DieView(layout: layout, onTap: _tapDice),
                      ),

                    // pip counts
                    for (final layout in PipCountLayout.getLayouts(game))
                      Positioned.fromRect(
                        rect: layout.rect,
                        child: PipCountView(
                          layout: layout,
                          reversed: controller.reversed,
                        ),
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

  List<int?> get _pipNosToHighlight =>
      _fromPipNo != null ? [_fromPipNo] : _legalMovesForPips.keys.toList();

  void _tapPiece(int pipNo) => _tapPip(pipNo);
  void _tapOff(GammonPlayer player) => _move(GammonRules.offPipNoFor(player));

  // the cube sits at the center bar, shifted toward its owner's side
  static Rect _cubeRect(GammonPlayer? owner) {
    const top = <GammonPlayer?, double>{
      null: 186, // centered
      GammonPlayer.one: 354, // player1 home is along the bottom
      GammonPlayer.two: 18, // player2 home is along the top
    };
    return Rect.fromLTWH(238, top[owner]!, 44, 44);
  }

  Future<void> _tapCube() async {
    final player = _game!.turnPlayer;
    if (player == null || !_game!.canOfferDouble(player)) return;

    final accepted = await DoubleOfferDialog.show(
      context,
      player,
      _game!.cube.value * 2,
    );
    if (accepted == null) return; // dismissed

    if (accepted) {
      _game!.acceptDouble();
      _reset();
    } else {
      _game!.declineDouble(); // ends the game; _gameChanged shows the result
    }
  }

  void _tapPip(int pipNo) {
    if (_fromPipNo == null) {
      // if there's no pip to move from selected and it has legal moves,
      // select it
      if (_legalMovesForPips[pipNo] != null) setState(() => _fromPipNo = pipNo);
    } else {
      final oldFromPipNo = _fromPipNo;

      // if there is a pip to move from selected, attempt to move to this piece
      if (!_move(pipNo)) {
        // if the move failed, check if it's got legal moves and highlight it,
        // unless it's the same out pip, then toggle it on/off
        if (oldFromPipNo != pipNo && _legalMovesForPips[pipNo] != null) {
          setState(() => _fromPipNo = pipNo);
        }
      }
    }
  }

  bool _move(int toEndPipNo) {
    // find the set of hops that move from the current pip to the desired pip,
    // preferring an ordering that hits opponent blots along the way (issue #9)
    final hops = _fromPipNo == null
        ? null
        : GammonRules.preferredHops(
            _game!.board,
            _legalMovesForPips[_fromPipNo] ?? const <GammonMove>[],
            fromPipNo: _fromPipNo!,
            toPipNo: toEndPipNo,
          );

    // if this is a legal move, do the move
    if (hops != null) {
      final initialBoard = List<List<int>>.generate(
        _game!.board.length,
        (i) => List<int>.from(_game!.board[i]),
      );
      final move = GammonMove(
        fromPipNo: _fromPipNo!,
        toPipNo: toEndPipNo,
        hops: hops,
      );
      final deltasForHops = _game!.applyMove(move: move);

      // convert game states for each hop into a sequence of layouts (and hit
      // delays) for each affected piece
      assert(deltasForHops.length == hops.length);
      assert(_pieceLayouts.isEmpty);
      final anim = MoveAnimation.forMove(initialBoard, deltasForHops);
      _pieceLayouts.addAll(anim.layouts);
      _pieceDelays.addAll(anim.delays);
    }

    _reset();
    return hops != null;
  }

  void _reset() {
    setState(() {
      _legalMovesForPips = _game!.getAllLegalMoves();
      _fromPipNo = null;
    });
    widget.controller.canAutoBearOff = _game!.canAutoBearOff;
  }

  void _tapDice() {
    // can't go to the next turn until there are no more available dice
    if (_game!.dice.every((d) => !d.available)) {
      _game!.commitTurn();
      _reset();
    }
  }

  void _tapBoard() {
    _reset();
  }

  bool _highlightOff(GammonPlayer player) {
    final offPipNo = GammonRules.offPipNoFor(player);
    final legalMoves = _fromPipNo == null
        ? null
        : _legalMovesForPips[_fromPipNo];
    return legalMoves != null && legalMoves.any((m) => m.toPipNo == offPipNo);
  }

  bool _highlightPip(int pipNo) {
    final legalMoves = _fromPipNo == null
        ? null
        : _legalMovesForPips[_fromPipNo];
    final result =
        legalMoves != null &&
        legalMoves.hasHops(fromPipNo: _fromPipNo, toPipNo: pipNo);
    return result;
  }

  // remove each animated piece from the list of pieces to animate
  void _endPieceAnimation(int pieceID) {
    _pieceLayouts.remove(pieceID)!;
    _pieceDelays.remove(pieceID);

    // the last piece has been animated, so draw the final state of the board
    // w/ labels, on edge, etc.
    if (_pieceLayouts.isEmpty) setState(() {});
  }
}

class InnerShadingRect extends StatelessWidget {
  const InnerShadingRect({required this.rect, super.key});
  final Rect rect;

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
              colors: [Colors.black.withAlpha(51), Colors.transparent],
            ),
          ),
        ),
        Container(
          width: 10,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Colors.black.withAlpha(51), Colors.transparent],
            ),
          ),
        ),
      ],
    ),
  );
}

class QuitGameDialog extends StatelessWidget {
  const QuitGameDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Game Already In Progress'),
    content: const Text('OK to quit current game?'),
    actions: [
      OutlinedButton(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Keep Playing'),
        ),
        onPressed: () => Navigator.pop(context, false),
      ),
      ElevatedButton(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Quit Game'),
        ),
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => const QuitGameDialog(),
  );
}

// Win-chance estimate and recommended cube action (issue #14). The numbers are
// a race heuristic, not an equity-engine rollout.
class OddsDialog extends StatelessWidget {
  const OddsDialog(this.game, {super.key});
  final GammonState game;

  static String _cubeAdvice(CubeAction action, int onRollNo) {
    switch (action) {
      case CubeAction.noDouble:
        return 'Player $onRollNo: too early to double.';
      case CubeAction.doubleTake:
        return 'Player $onRollNo should double; opponent should take.';
      case CubeAction.doublePass:
        return 'Player $onRollNo should double; opponent should pass.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = (game.winProbabilityFor(GammonPlayer.one) * 100).round();
    final p2 = (game.winProbabilityFor(GammonPlayer.two) * 100).round();
    final onRollNo = game.turnPlayer == GammonPlayer.one ? 1 : 2;

    return AlertDialog(
      title: const Text('Win Chances'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Player 1: $p1%'),
          Text('Player 2: $p2%'),
          const SizedBox(height: 12),
          Text(_cubeAdvice(game.recommendedCubeAction, onRollNo)),
          const SizedBox(height: 12),
          Text(
            game.hasExactOdds
                ? 'Exact race calculation (no contact remaining).'
                : 'Estimated from the pip-count race; not an exact rollout.',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Padding(padding: EdgeInsets.all(8), child: Text('OK')),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, GammonState game) =>
      showDialog<void>(
        context: context,
        builder: (context) => OddsDialog(game),
      );
}

// Offer-a-double dialog: the player on roll doubles, the opponent decides
// (issue #12).
class DoubleOfferDialog extends StatelessWidget {
  const DoubleOfferDialog(this.doubler, this.newValue, {super.key});
  final GammonPlayer doubler;
  final int newValue;

  @override
  Widget build(BuildContext context) {
    final doublerNo = doubler == GammonPlayer.one ? 1 : 2;
    final opponentNo = doubler == GammonPlayer.one ? 2 : 1;
    return AlertDialog(
      title: Text('Player $doublerNo doubles to $newValue'),
      content: Text('Player $opponentNo, do you accept?'),
      actions: [
        OutlinedButton(
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Decline'),
          ),
          onPressed: () => Navigator.pop(context, false),
        ),
        ElevatedButton(
          child: const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Accept'),
          ),
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }

  static Future<bool?> show(
    BuildContext context,
    GammonPlayer doubler,
    int newValue,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => DoubleOfferDialog(doubler, newValue),
  );
}

class NewGameDialog extends StatelessWidget {
  const NewGameDialog(this.winner, this.game, {super.key});
  final GammonPlayer? winner;
  final GammonState game;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Player ${winner == GammonPlayer.one ? 1 : 2} wins!'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsTable(game: game),
        const SizedBox(height: 16),
        const Text('Would you like to play another game?'),
      ],
    ),
    actions: [
      OutlinedButton(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('No, Thanks'),
        ),
        onPressed: () => Navigator.pop(context, false),
      ),
      ElevatedButton(
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: Text('Yes, Please!'),
        ),
        onPressed: () => Navigator.pop(context, true),
      ),
    ],
  );

  static Future<bool?> show(
    BuildContext context,
    GammonPlayer? winner,
    GammonState game,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => NewGameDialog(winner, game),
  );
}

// End-of-game stats: rolls, total dice pips, doubles per player (issue #10).
class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.game});
  final GammonState game;

  @override
  Widget build(BuildContext context) {
    final p1 = game.statsFor(GammonPlayer.one);
    final p2 = game.statsFor(GammonPlayer.two);
    const headerStyle = TextStyle(fontWeight: FontWeight.bold);

    TableRow row(String label, Object a, Object b) => TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(4), child: Text(label)),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text('$a', textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text('$b', textAlign: TextAlign.center),
        ),
      ],
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {0: FlexColumnWidth()},
      children: [
        const TableRow(
          children: [
            Padding(padding: EdgeInsets.all(4), child: Text('')),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                'Player 1',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                'Player 2',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        row('Rolls', p1.rolls, p2.rolls),
        row('Total dice', p1.pips, p2.pips),
        row('Doubles', p1.doubles, p2.doubles),
      ],
    );
  }
}

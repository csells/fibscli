import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'board_view.dart';
import 'local_ai_driver.dart';
import 'main.dart';
import 'model.dart';
import 'pieces.dart';
import 'tinystate.dart';

class GamePlayPage extends StatefulWidget {
  const GamePlayPage({
    super.key,
    this.aiSide,
    this.ai,
    this.aiThinkDelay = const Duration(milliseconds: 600),
    this.aiMoveDelay = const Duration(milliseconds: 250),
  });

  /// When non-null, the computer plays this side using [ai] (1-player mode).
  /// Null means the standard 2-player hot-seat game.
  final GammonPlayer? aiSide;

  /// The AI engine driving [aiSide] (ignored when [aiSide] is null).
  final BgAiPlayer? ai;

  /// Pause before the AI starts moving (overridable for tests).
  final Duration aiThinkDelay;

  /// Pause between the AI's individual checker moves (overridable for tests).
  final Duration aiMoveDelay;

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
            data: (context, prefs) => GameView(
              controller: _controller,
              aiSide: widget.aiSide,
              ai: widget.ai,
              aiThinkDelay: widget.aiThinkDelay,
              aiMoveDelay: widget.aiMoveDelay,
            ),
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
  GameView({
    super.key,
    GameViewController? controller,
    this.aiSide,
    this.ai,
    this.aiThinkDelay = const Duration(milliseconds: 600),
    this.aiMoveDelay = const Duration(milliseconds: 250),
  }) : controller = controller ?? GameViewController();
  final GameViewController controller;

  /// When non-null, the computer plays this side using [ai].
  final GammonPlayer? aiSide;

  /// The AI engine driving [aiSide].
  final BgAiPlayer? ai;

  /// Pause before the AI starts moving.
  final Duration aiThinkDelay;

  /// Pause between the AI's individual checker moves.
  final Duration aiMoveDelay;

  @override
  _GameViewState createState() => _GameViewState();
}

class _GameViewState extends State<GameView> {
  GammonState? _game;
  var _legalMovesForPips = <int, List<GammonMove>>{};
  int? _fromPipNo;
  final _pieceLayouts = <int?, List<PieceLayout>>{};
  final _pieceDelays = <int?, Duration>{};
  // 1-player mode: guards re-entrancy while the AI plays, and signals when the
  // current move's animation has fully finished (so AI moves are sequenced on
  // real animation completion, not fragile fixed timers).
  var _aiBusy = false;
  Completer<void>? _animDone;

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
    unawaited(_maybePlayAi()); // the AI may be on roll first
  }

  // 1-player mode: when it becomes the AI side's turn, play a full turn with
  // human-style pacing, animating each move and committing at the end. A no-op
  // in 2-player mode (widget.ai == null) and re-entrancy-guarded by _aiBusy.
  Future<void> _maybePlayAi() async {
    if (widget.ai == null || _aiBusy) return;
    if (_game == null || _game!.gameOver) return;
    if (_game!.turnPlayer != widget.aiSide) return;
    _aiBusy = true;
    try {
      await _pace(widget.aiThinkDelay);
      if (!mounted || _game == null || _game!.gameOver) return;
      if (_game!.turnPlayer != widget.aiSide) return;
      final turn = await widget.ai!.chooseTurn(positionFromState(_game!));
      for (final move in turn.moves) {
        if (!mounted || _game!.gameOver) break;
        await _applyMoveAnimated(move);
        await _pace(widget.aiMoveDelay);
      }
      if (mounted && _game != null && !_game!.gameOver) {
        _game!.commitTurn();
        _reset();
      }
    } finally {
      _aiBusy = false;
    }
  }

  // Pace the AI: a real delay when positive, but a plain microtask when zero so
  // a zero-paced AI (in tests) leaves no pending timer to trip teardown.
  Future<void> _pace(Duration d) =>
      d > Duration.zero ? Future<void>.delayed(d) : Future<void>.value();

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
          builder: (context, controller, child) => BoardView(
            game: _game!,
            legalMoves: _legalMovesForPips,
            selectedPip: _fromPipNo,
            reversed: controller.reversed,
            ignoring: _game!.gameOver || _aiBusy,
            onTapPip: _tapPip,
            onTapOff: _tapOff,
            onTapCube: () => unawaited(_tapCube()),
            onTapDice: _tapDice,
            onTapBoard: _tapBoard,
            pieceAnimations: _pieceLayouts,
            pieceDelays: _pieceDelays,
            onPieceAnimationEnd: (id) => _endPieceAnimation(id!),
          ),
        ),
      ),
    ),
  );

  void _tapOff(GammonPlayer player) => _move(GammonRules.offPipNoFor(player));

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
      final move = GammonMove(
        fromPipNo: _fromPipNo!,
        toPipNo: toEndPipNo,
        hops: hops,
      );
      unawaited(_applyMoveAnimated(move));
    }

    _reset();
    return hops != null;
  }

  // Apply [move] to the game and animate it; returns a future that completes
  // when the move's piece animation has fully finished. Shared by tap-to-move
  // (fire-and-forget) and the AI driver (awaited, to sequence its moves).
  Future<void> _applyMoveAnimated(GammonMove move) {
    final initialBoard = List<List<int>>.generate(
      _game!.board.length,
      (i) => List<int>.from(_game!.board[i]),
    );
    final deltasForHops = _game!.applyMove(move: move);

    // convert game states for each hop into a sequence of layouts (and hit
    // delays) for each affected piece
    assert(deltasForHops.length == move.hops.length);
    assert(_pieceLayouts.isEmpty);
    final anim = MoveAnimation.forMove(initialBoard, deltasForHops);
    if (anim.layouts.isEmpty) return Future<void>.value();
    _animDone = Completer<void>();
    _pieceLayouts.addAll(anim.layouts);
    _pieceDelays.addAll(anim.delays);
    return _animDone!.future;
  }

  void _reset() {
    setState(() {
      _legalMovesForPips = _game!.getAllLegalMoves();
      _fromPipNo = null;
    });
    widget.controller.canAutoBearOff = _game!.canAutoBearOff;
  }

  void _tapDice() {
    if (_aiBusy) return; // the AI is on roll; ignore taps
    // can't go to the next turn until there are no more available dice
    if (_game!.dice.every((d) => !d.available)) {
      _game!.commitTurn();
      _reset();
      unawaited(_maybePlayAi()); // turn may now be the AI's
    }
  }

  void _tapBoard() {
    _reset();
  }

  // remove each animated piece from the list of pieces to animate
  void _endPieceAnimation(int pieceID) {
    _pieceLayouts.remove(pieceID)!;
    _pieceDelays.remove(pieceID);

    // the last piece has been animated, so draw the final state of the board
    // w/ labels, on edge, etc.
    if (_pieceLayouts.isEmpty) {
      setState(() {});
      _animDone?.complete();
      _animDone = null;
    }
  }
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

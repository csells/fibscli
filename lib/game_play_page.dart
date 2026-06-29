import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'board_view.dart';
import 'game_dialogs.dart';
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
    this.createGame,
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

  /// Builds the starting game. Defaults to a fresh random opening; injected by
  /// tests to drive a deterministic position (e.g. a forced cube decision).
  @visibleForTesting
  final GammonState Function()? createGame;

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

    _game = widget.createGame?.call() ?? GammonState();
    widget.controller.canUndo = true;
    _game!.addListener(_gameChanged);
    _reset();
    unawaited(_maybePlayAi()); // the AI may be on roll first
  }

  // 1-player mode: when it becomes the AI side's turn, drive a full turn with
  // human-style pacing via the headless playAiTurn driver -- the cube + move
  // logic lives there (and is unit-tested); this only supplies the UI hooks
  // (think pause, the double-offer dialog, animation). A no-op in 2-player mode
  // (widget.ai == null) and re-entrancy-guarded by _aiBusy.
  Future<void> _maybePlayAi() async {
    if (widget.ai == null || _aiBusy) return;
    if (_game == null || _game!.gameOver) return;
    if (_game!.turnPlayer != widget.aiSide) return;
    _aiBusy = true;
    try {
      await _pace(widget.aiThinkDelay);
      if (!mounted || _game == null || _game!.gameOver) return;
      if (_game!.turnPlayer != widget.aiSide) return;
      await playAiTurn(
        _game!,
        widget.ai!,
        onOfferDouble: _humanAnswersAiDouble,
        onMove: (move) async {
          if (!mounted || _game!.gameOver) return;
          await _applyMoveAnimated(move);
          await _pace(widget.aiMoveDelay);
        },
      );
      if (mounted && _game != null) _reset();
    } finally {
      _aiBusy = false;
    }
  }

  // The AI offered a double; ask the human (the opponent) to take or pass.
  Future<bool> _humanAnswersAiDouble(int proposedCubeValue) async {
    if (!mounted) return false; // treat as a pass if the view is gone
    final accepted = await DoubleOfferDialog.show(
      context,
      widget.aiSide!,
      proposedCubeValue,
    );
    return accepted ?? false;
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

    // When the opponent is the computer it answers itself; otherwise the human
    // opponent is asked (hot-seat) via the dialog.
    final opponent = GammonRules.otherPlayer(player);
    final bool? accepted;
    if (widget.ai != null && opponent == widget.aiSide) {
      final response = await widget.ai!.respondToDouble(
        positionFromState(_game!),
      );
      accepted = response == BgCubeAction.take;
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Computer ${accepted ? 'accepts' : 'declines'} the double',
              ),
            ),
          );
      }
    } else {
      accepted = await DoubleOfferDialog.show(
        context,
        player,
        _game!.cube.value * 2,
      );
    }
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

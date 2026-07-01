import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'board_animator.dart';
import 'game_board.dart';
import 'game_dialogs.dart';
import 'game_view_controller.dart';
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
    _controller.dispose();
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
                  onPressed: controller.autoBearOff,
                ),
              IconButton(
                tooltip: 'win chances & cube advice',
                icon: const Icon(Icons.insights),
                onPressed: controller.showOdds,
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
                onPressed: controller.busy ? null : controller.newGame,
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'undo turn',
            onPressed: controller.canUndo ? controller.undo : null,
            child: const Icon(Icons.undo),
          ),
          // hold first paint until prefs resolve (the controller reads
          // `reversed` from them); GameView itself doesn't need the value.
          body: FutureBuilder<SharedPreferences>(
            future: _prefsFuture,
            builder: (context, snapshot) => snapshot.hasData
                ? GameView(
                    controller: _controller,
                    aiSide: widget.aiSide,
                    ai: widget.ai,
                    aiThinkDelay: widget.aiThinkDelay,
                    aiMoveDelay: widget.aiMoveDelay,
                  )
                : const Center(child: CircularProgressIndicator()),
          ),
        ),
      );

  void _tapReverse() => _controller.reversed = !_controller.reversed;
  void _tapFeedback() => unawaited(
    ul.launchUrl(Uri.parse('https://github.com/csells/fibscli/issues')),
  );
  void _tapHelp() =>
      unawaited(ul.launchUrl(Uri.parse('https://www.bkgm.com/rules.html')));
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
  // owns the in-flight checker animation (layouts, hit-delays, completion) so
  // the AI loop can await a move's animation and the view can redraw on finish.
  final _animator = BoardAnimator();
  // 1-player mode: guards re-entrancy while the AI plays.
  var _aiBusy = false;

  @override
  void initState() {
    super.initState();

    // Every mutating command no-ops while the AI is mid-turn -- the buttons are
    // also disabled via controller.busy, but guard here too so nothing can
    // mutate/replace the board out from under the running AI move plan.
    widget.controller.onUndo = () {
      if (_aiBusy) return;
      assert(!_game!.gameOver);
      _game!.undoTurn();
      _reset();
    };

    widget.controller.onNewGame = () async {
      if (_aiBusy) return;
      final ok = _game!.gameOver
          ? true
          : await QuitGameDialog.show(context); // result can return null
      if (ok ?? false) _newGame();
    };

    widget.controller.onAutoBearOff = () {
      if (_aiBusy) return;
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
    _animator.dispose();
    // Release the AI engine's resources (e.g. the gnubg adapter's http.Client
    // connection pool). pubeval/backgammon_ai have a no-op dispose.
    widget.ai?.dispose();
    super.dispose();
  }

  void _newGame() {
    if (_game != null) _game!.removeListener(_gameChanged);

    _game = widget.createGame?.call() ?? GammonState();
    widget.controller.attach(_game!); // derives canUndo/canAutoBearOff
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
    widget.controller.busy = true; // lock the app-bar/FAB with the board
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
    } on GnubgUnavailableException catch (e) {
      // The chosen engine couldn't supply a move (after its own retries). We do
      // NOT fabricate one -- tell the user and let them retry the engine.
      _reportEngineUnavailable(e.message);
    } finally {
      _aiBusy = false;
      widget.controller.busy = false;
    }
  }

  void _reportEngineUnavailable(String message) {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Computer engine unavailable: $message'),
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => unawaited(_maybePlayAi()),
          ),
        ),
      );
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
          builder: (context, controller, child) => GameBoard(
            game: _game!,
            animator: _animator,
            legalMoves: _legalMovesForPips,
            interactive: !_game!.gameOver && !_aiBusy,
            onMove: _performMove,
            reversed: controller.reversed,
            onTapDice: _tapDice,
            onTapCube: () => unawaited(_tapCube()),
          ),
        ),
      ),
    ),
  );

  // Apply a human move locally: find the hops, animate it, recompute legals.
  // Returns whether the move was legal (so the board can re-select on a miss).
  bool _performMove(int fromPip, int toPip) {
    final hops = GammonRules.preferredHops(
      _game!.board,
      _legalMovesForPips[fromPip] ?? const <GammonMove>[],
      fromPipNo: fromPip,
      toPipNo: toPip,
    );
    if (hops == null) return false;
    unawaited(
      _applyMoveAnimated(
        GammonMove(fromPipNo: fromPip, toPipNo: toPip, hops: hops),
      ),
    );
    _reset();
    return true;
  }

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
    if (!mounted) return; // the page was popped during the await

    if (accepted) {
      _game!.acceptDouble();
      _reset();
    } else {
      _game!.declineDouble(); // ends the game; _gameChanged shows the result
    }
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
    // delays) for each affected piece, then hand them to the shared animator
    assert(deltasForHops.length == move.hops.length);
    return _animator.play(MoveAnimation.forMove(initialBoard, deltasForHops));
  }

  void _reset() {
    // canAutoBearOff/canUndo are derived on the controller from the attached
    // game, so there's nothing to push here beyond the board's legal moves.
    setState(() => _legalMovesForPips = _game!.getAllLegalMoves());
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
}

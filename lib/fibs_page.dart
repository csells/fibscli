import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'board_animator.dart';
import 'dice.dart';
import 'fibs_state.dart';
import 'game_board.dart';
import 'main.dart';
import 'model.dart';
import 'pieces.dart';
import 'tinystate.dart';

final _log = Logger('fibs.login');

// The FIBS "play a bot" flow: connect, then watch a bot game (milestone 1).
// Bots-only throughout — the who-list only ever shows bots.
class FibsPage extends StatefulWidget {
  const FibsPage({super.key});

  @override
  State<FibsPage> createState() => _FibsPageState();
}

class _FibsPageState extends State<FibsPage> {
  // how many FIBS messages we've already surfaced (so we only toast new ones)
  var _shownMessages = 0;

  @override
  void initState() {
    super.initState();
    _shownMessages = App.fibs.messages.length;
    App.fibs.messages.addListener(_onMessages);
  }

  @override
  void dispose() {
    App.fibs.messages.removeListener(_onMessages);
    super.dispose();
  }

  // Surface incoming FIBS replies (a bot declining an invite, errors, chat) as
  // a SnackBar. Without this they were captured but never shown, so a declined
  // invite looked like a silent failure.
  void _onMessages() {
    final messages = App.fibs.messages;
    if (!mounted || messages.length <= _shownMessages) {
      _shownMessages = messages.length;
      return;
    }
    final latest = messages.last;
    _shownMessages = messages.length;
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('${latest.from}: ${latest.message}')),
      );
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) {
      // This picks WHICH view to show. Each view listens to FibsState
      // itself (via its own ChangeNotifierBuilder) so it refreshes on
      // every board update even though it's a const child here.
      if (!fibs.loggedIn) return const _LoginView();
      if (fibs.gameState != null) {
        // playing if we're one of the players, otherwise just watching
        return fibs.myColor != null ? const _PlayView() : const _WatchView();
      }
      return const _BotListView();
    },
  );
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final _user = TextEditingController(text: App.creds.user ?? '');
  late final _pass = TextEditingController(text: App.creds.password ?? '');
  var _remember = App.creds.remember;
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // creds are loaded before any UI (see bootstrap), so they're available
    // synchronously here -- connect on our own when we have usable ones.
    if (!App.fibs.loggedIn && !_busy && App.creds.canAutologin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !App.fibs.loggedIn && !_busy) unawaited(_login());
      });
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _user.text.trim();
      await App.fibs.login(user: user, pass: _pass.text);
      await App.creds.save(
        user: user,
        password: _pass.text,
        remember: _remember,
      );
    } on Exception catch (ex, st) {
      _log.warning('FIBS login failed for "${_user.text.trim()}"', ex, st);
      if (mounted) setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connect to FIBS')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'FIBS user'),
                autofillHints: const [AutofillHints.username],
              ),
              TextField(
                controller: _pass,
                decoration: InputDecoration(
                  labelText: 'FIBS password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                onSubmitted: (_) => unawaited(_login()),
              ),
              CheckboxListTile(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? false),
                title: const Text('Remember my password'),
                subtitle: const Text('only on a device you trust'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => unawaited(_login()),
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// The bots currently in a game, each watchable.
class _BotListView extends StatefulWidget {
  const _BotListView();

  @override
  State<_BotListView> createState() => _BotListViewState();
}

class _BotListViewState extends State<_BotListView> {
  // NOTE: no "play for me" here. Letting a bot play your moves on the live FIBS
  // server is cheating, full stop. The autonomous FibsBotPlayer still exists,
  // but only as a test/e2e driver -- never wired to a button the user can press.

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<FibsState>(notifier: App.fibs, builder: _build);

  Widget _build(BuildContext context, FibsState fibs, Widget? child) {
    final free = App.fibs.availableBots; // invite these
    final playing = App.fibs.watchableBots; // watch these
    final saved = App.fibs.savedMatches; // unfinished matches to resume
    final empty = free.isEmpty && playing.isEmpty && saved.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bots'),
        actions: [
          TextButton(
            onPressed: () => unawaited(App.fibs.logout()),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: empty
          ? const Center(
              child: Text(
                'No bots online yet.\nWaiting for the who-list…',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                // A resume request or "type join" prompt is AUTO-joined in
                // FibsState (see _applyAndAutoJoin), so there's no manual Join
                // tile here -- an outstanding game just drops us back in.
                //
                // Unfinished matches we can pick back up when the opponent
                // isn't online to auto-resume (re-inviting reloads the saved
                // game). Finishing saved matches is good manners.
                if (saved.isNotEmpty)
                  const _SectionHeader('Resume a saved match'),
                for (final opponent in saved)
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: Text(opponent),
                    subtitle: const Text('unfinished match — tap to resume'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => App.fibs.resumeSavedMatch(opponent),
                  ),
                if (free.isNotEmpty)
                  const _SectionHeader('Play a bot (tap to invite)'),
                for (final who in free)
                  ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: Text(who.user),
                    subtitle: Text(
                      'rating ${who.rating.toStringAsFixed(0)} · '
                      '${who.experience} exp · '
                      '${who.client.isEmpty ? 'no client' : who.client}'
                      '${who.playsOnePointOnly ? ' · 1-point only' : ''}',
                    ),
                    trailing: const Icon(Icons.sports_esports),
                    onTap: () => _confirmInvite(context, who),
                  ),
                if (playing.isNotEmpty)
                  const _SectionHeader('Watch a bot game'),
                for (final who in playing)
                  ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: Text(who.user),
                    subtitle: Text(
                      'playing ${who.opponent} · rating '
                      '${who.rating.toStringAsFixed(0)}',
                    ),
                    trailing: const Icon(Icons.visibility),
                    onTap: () => App.fibs.watch(who),
                  ),
              ],
            ),
    );
  }

  Future<void> _confirmInvite(BuildContext context, WhoInfo bot) async {
    // default to 1 for bots that only play 1-point matches, else a short 3-pt
    var length = bot.playsOnePointOnly ? 1 : 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Invite ${bot.user}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Match length (points):'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                  ButtonSegment(value: 7, label: Text('7')),
                ],
                selected: {length},
                onSelectionChanged: (s) =>
                    setLocalState(() => length = s.first),
              ),
              const SizedBox(height: 12),
              if (bot.playsOnePointOnly)
                Text(
                  '${bot.user} only accepts 1-point matches — a longer '
                  'match will be declined.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              const Text(
                'Please finish the game once it starts — be a good FIBS '
                'citizen.',
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Invite ($length pt)'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) App.fibs.invite(bot, matchLength: length);
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      text,
      style: TextStyle(
        color: Theme.of(context).primaryColor,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

class _WatchView extends StatelessWidget {
  const _WatchView();

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) => Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: const Text('Watching'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: App.fibs.stopWatching,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: GameBoard(game: fibs.gameState!), // read-only spectator board
      ),
    ),
  );
}

// Playing a bot via tap-to-move: tap a source pip, then a destination; the
// server validates (milestone 2).
class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  // The in-progress turn we're building LOCALLY on the shared board -- same
  // mechanic as the local game: make your moves (seeing the pieces move), undo
  // freely, then tap the dice to submit the WHOLE turn. FIBS wants the complete
  // turn in one command, so we only talk to the server on submit. Non-null only
  // while it's our turn to move; null when watching the opponent.
  GammonState? _turn;
  final _moves = <GammonMove>[]; // the moves we've made this turn, to submit
  // diff-based animation: remember the last board so a fresh FIBS board (our
  // move OR the opponent's) animates instead of snapping (issue: FIBS only
  // hands us whole boards, never move deltas). The shared BoardAnimator owns
  // the in-flight tween lifecycle (same one the local game uses).
  List<List<int>>? _prevBoard;
  // The dice in play on [_prevBoard] -- i.e. the dice that PRODUCED the move we
  // animate when the next board arrives. We must capture them from the board
  // we move FROM: by the time the result board lands, those dice are already
  // gone (the turn passed), so reading them then would give the wrong dice.
  List<int> _prevDice = const [];
  final _animator = BoardAnimator();
  // Board orientation. Null means "use our perspective": player two (O) moves
  // up the board, so we flip it by default to put our home at the bottom --
  // same view the local game gives the down-moving player. The flip button
  // overrides it.
  bool? _reversed;

  @override
  void initState() {
    super.initState();
    _prevBoard = _boardCopy();
    _prevDice = _diceSnapshot();
    App.fibs.addListener(_onFibsChanged);
  }

  @override
  void dispose() {
    App.fibs.removeListener(_onFibsChanged);
    _animator.dispose();
    super.dispose();
  }

  List<List<int>>? _boardCopy() {
    final board = App.fibs.gameState?.board;
    return board == null ? null : [for (final c in board) List<int>.of(c)];
  }

  // the dice the on-roll player has in play on the current board
  List<int> _diceSnapshot() =>
      App.fibs.gameState?.dice.map((d) => d.roll).toList() ?? const <int>[];

  // Keep the local working turn in sync with whose move it is: create one when
  // it's ours, drop it when the turn ends (we submitted, or it's the opponent's
  // move). Idempotent and side-effect-light, so it's safe to call from build
  // (covers entering the view already on our move -- a resumed game, or the
  // turn already ours -- when no further notification fires) AND from the
  // listener. Never clobbers an in-progress turn (_turn != null on our move).
  bool _syncTurn() {
    final fibs = App.fibs;
    if (fibs.canMoveNow && _turn == null) {
      _turn = _freshTurn(fibs);
      _moves.clear();
      return true;
    }
    if (!fibs.canMoveNow && _turn != null) {
      _turn = null;
      _moves.clear();
      return true;
    }
    return false;
  }

  void _onFibsChanged() {
    final fibs = App.fibs;
    if (_syncTurn()) setState(() {});

    final cur = fibs.gameState?.board;
    if (cur == null) return;
    // Animate a whole-board change (the opponent's play, or our committed turn
    // coming back) only when we're NOT mid-edit -- our own in-progress moves
    // animate themselves as we make them. Use the PREVIOUS board's dice so a
    // multi-hop move animates through each pip rather than sliding straight.
    if (_turn == null &&
        _prevBoard != null &&
        Position.fromBoard(_prevBoard!) != Position.fromBoard(cur) &&
        !_animator.isAnimating) {
      unawaited(
        _animator.play(
          MoveAnimation.between(_prevBoard!, cur, dice: _prevDice),
        ),
      );
    }
    _prevBoard = _boardCopy();
    _prevDice = _diceSnapshot();
  }

  // A fresh working copy of the current (viewer) board to build our turn on.
  GammonState _freshTurn(FibsState fibs) {
    final gs = fibs.gameState!;
    return GammonState.from(
      board: gs.board,
      dice: [for (final d in gs.dice) DieState(d.roll)],
      turnPlayer: gs.turnPlayer,
      moveNo: 2, // a normal FIBS roll: both dice are ours, not the opening
    );
  }

  // Apply a move to our LOCAL working turn (no server traffic yet): find the
  // hops, record the move to submit later, and animate it on the shared board.
  bool _applyLocalMove(int fromPip, int toPip) {
    final turn = _turn;
    if (turn == null) return false;
    final hops = GammonRules.preferredHops(
      turn.board,
      turn.getAllLegalMoves()[fromPip] ?? const <GammonMove>[],
      fromPipNo: fromPip,
      toPipNo: toPip,
    );
    if (hops == null) return false;
    final move = GammonMove(fromPipNo: fromPip, toPipNo: toPip, hops: hops);
    _moves.add(move);

    final initial = [for (final c in turn.board) List<int>.of(c)];
    final deltas = turn.applyMove(move: move);
    setState(() {}); // legal moves / dice changed
    unawaited(_animator.play(MoveAnimation.forMove(initial, deltas)));
    return true;
  }

  // A pure race on our turn -> offer to auto bear-off (no decisions matter, so
  // it's tedium reduction, not the bot playing for us). Unlike "play for me" it
  // never decides a contested position and only acts on a button press.
  bool get _canAutoBearOff => _turn != null && GammonRules.isRace(_turn!.board);

  // Play the whole current turn greedily and submit it: bear a checker off when
  // we can, else advance the rear-most checker. Completes the turn (so it's
  // ready to submit), then submits.
  void _autoBearOff() {
    final turn = _turn;
    if (turn == null) return;
    while (true) {
      final legal = turn.getAllLegalMoves();
      if (legal.isEmpty) break;
      final off = GammonRules.offPipNoFor(turn.turnPlayer);
      // prefer a move that bears a checker off
      GammonMove? move;
      for (final moves in legal.values) {
        for (final m in moves) {
          if (m.toPipNo == off) {
            move = m;
            break;
          }
        }
        if (move != null) break;
      }
      // else advance the rear-most checker (we are player one: home is 1..6, so
      // the rear-most is the highest pip)
      final fromPips = legal.keys.toList()..sort((a, b) => b.compareTo(a));
      move ??= legal[fromPips.first]!.first;
      _moves.add(move);
      turn.applyMove(move: move);
    }
    setState(() {});
    _submitTurn();
  }

  // Tap the dice to submit the whole turn -- only once there are no more legal
  // moves to make (the forced-move rules require using every playable die).
  void _submitTurn() {
    final turn = _turn;
    if (turn == null || turn.getAllLegalMoves().isNotEmpty) return;
    // the post-submit board echoes our move, so don't let it re-animate
    _prevBoard = [for (final c in turn.board) List<int>.of(c)];
    _prevDice = const [];
    App.fibs.submitTurn(List<GammonMove>.of(_moves));
    setState(() {
      _turn = null;
      _moves.clear();
    });
  }

  // Undo the LAST move you made this turn (tap again to keep walking back).
  // Rebuild the working turn from scratch and replay all but the last move.
  void _undoMove() {
    if (_moves.isEmpty) return;
    final replay = _moves.sublist(0, _moves.length - 1);
    final turn = _freshTurn(App.fibs);
    for (final m in replay) {
      turn.applyMove(move: m);
    }
    setState(() {
      _turn = turn;
      _moves
        ..clear()
        ..addAll(replay);
    });
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) => _buildBoard(context, fibs),
  );

  Widget _buildBoard(BuildContext context, FibsState fibs) {
    _syncTurn(); // create/drop the working turn (also covers entering on ours)

    // FIBS names us player1 "You" in our own game; the opponent is the other
    final b = fibs.board!;
    final p1IsUs = b.player1Name == 'You' || b.player1Name == fibs.user;
    final opponent = p1IsUs ? b.player2Name : b.player1Name;

    // FIBS already hands us the board from our perspective (we move toward our
    // home in the lower-right), so no auto-flip; the button is a preference.
    final reversed = _reversed ?? false;

    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('vs $opponent'),
        leading: IconButton(
          icon: const Icon(Icons.flag),
          tooltip: 'resign / leave',
          onPressed: () => _confirmLeave(context),
        ),
        actions: [
          // in a pure race, fast-forward your bear-off (no decisions matter)
          if (_canAutoBearOff)
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: 'auto bear-off',
              onPressed: _autoBearOff,
            ),
          // always visible so it's discoverable; disabled until you've moved
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'undo last move',
            onPressed: _moves.isEmpty ? null : _undoMove,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'flip board',
            onPressed: () => setState(() => _reversed = !reversed),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              // While it's our turn we edit a LOCAL working board (_turn) and
              // submit on a dice tap; otherwise we just render the live board.
              child: GameBoard(
                game: _turn ?? fibs.gameState!,
                animator: _animator,
                legalMoves: _turn?.getAllLegalMoves() ?? const {},
                interactive: _turn != null,
                reversed: reversed,
                onMove: _applyLocalMove,
                onTapDice: _submitTurn,
              ),
            ),
          ),
          _Controls(fibs: fibs, turnComplete: _turnComplete),
        ],
      ),
    );
  }

  // our turn, a move started, and no more legal moves -> ready to submit
  bool get _turnComplete => _turn != null && _turn!.getAllLegalMoves().isEmpty;

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this game?'),
        content: const Text(
          'Resigning mid-match is poor FIBS etiquette — '
          'try to finish. Leave anyway?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (ok ?? false) App.fibs.resign();
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.fibs, this.turnComplete = false});
  final FibsState fibs;
  // our turn is fully played -> prompt to tap the dice to submit it
  final bool turnComplete;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (fibs.doubleOffered) {
      children.addAll([
        const Text('Opponent doubled!'),
        ElevatedButton(onPressed: fibs.acceptDouble, child: const Text('Take')),
        OutlinedButton(onPressed: fibs.rejectDouble, child: const Text('Pass')),
      ]);
    } else if (fibs.canRoll) {
      children.addAll([
        ElevatedButton.icon(
          onPressed: fibs.roll,
          icon: const Icon(Icons.casino),
          label: const Text('Roll'),
        ),
        OutlinedButton(
          onPressed: fibs.offerDouble,
          child: const Text('Double'),
        ),
      ]);
    } else if (fibs.canMoveNow) {
      children.add(
        Text(
          turnComplete
              ? 'Tap the dice to submit your move'
              : 'Your move — make your moves, then tap the dice '
                    '(dice ${fibs.activeDice.join(", ")})',
          style: const TextStyle(color: Colors.white),
        ),
      );
    } else {
      children.add(
        const Text(
          'Waiting for opponent…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black26,
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

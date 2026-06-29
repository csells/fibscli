import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'board_animator.dart';
import 'fibs_bot_player.dart';
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
  // "Play for me": the autonomous FibsBotPlayer invites a weak bot and plays a
  // match for the user (move selection runs through the shared bg_engine /
  // pubeval pipeline). Held here so we never start two at once.
  FibsBotPlayer? _autoPlayer;

  bool get _autoPlaying => _autoPlayer != null;

  void _toggleAutoPlay() {
    if (_autoPlaying) {
      _autoPlayer!.stop('user stopped');
      setState(() => _autoPlayer = null);
      return;
    }
    final player = FibsBotPlayer(App.fibs);
    setState(() => _autoPlayer = player);
    unawaited(
      player.run().whenComplete(() {
        if (mounted) setState(() => _autoPlayer = null);
      }),
    );
  }

  @override
  void dispose() {
    _autoPlayer?.stop('view disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<FibsState>(notifier: App.fibs, builder: _build);

  Widget _build(BuildContext context, FibsState fibs, Widget? child) {
    final free = App.fibs.availableBots; // invite these
    final playing = App.fibs.watchableBots; // watch these
    final saved = App.fibs.savedMatches; // unfinished matches to resume
    final resumeFrom = App.fibs.resumeRequestFrom; // opponent asked to resume
    final empty =
        free.isEmpty && playing.isEmpty && saved.isEmpty && resumeFrom == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bots'),
        actions: [
          TextButton.icon(
            onPressed: _toggleAutoPlay,
            icon: Icon(
              _autoPlaying ? Icons.stop : Icons.smart_toy,
              color: Colors.white,
            ),
            label: Text(
              _autoPlaying ? 'Stop' : 'Play for me',
              style: const TextStyle(color: Colors.white),
            ),
          ),
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
                // An opponent (or FIBS between games) is waiting on us to join.
                if (resumeFrom != null || App.fibs.mustJoin)
                  ListTile(
                    leading: const Icon(Icons.play_circle),
                    title: Text(
                      resumeFrom != null
                          ? '$resumeFrom wants to resume your match'
                          : 'Ready to continue your match',
                    ),
                    subtitle: const Text('tap Join to continue'),
                    trailing: FilledButton(
                      onPressed: App.fibs.joinGame,
                      child: const Text('Join'),
                    ),
                    onTap: App.fibs.joinGame,
                  ),
                // Unfinished matches we can pick back up (re-inviting reloads
                // the saved game). Finishing saved matches is good manners.
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

  void _onFibsChanged() {
    final cur = App.fibs.gameState?.board;
    if (cur == null) return;
    // animate only when the checkers actually moved (not a dice-only refresh).
    // Use the PREVIOUS board's dice so a multi-hop move animates through each
    // pip rather than sliding straight to the end (same as the local game).
    if (_prevBoard != null &&
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

  // Send the move to the server (it validates; a decline surfaces as a toast).
  // We optimistically report success so the board clears its selection; the
  // result board -- or the lack of one -- arrives over the wire.
  bool _performMove(int fromPip, int toPip) {
    App.fibs.move(fromPip, toPip);
    return true;
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) => _buildBoard(context, fibs),
  );

  Widget _buildBoard(BuildContext context, FibsState fibs) {
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
              child: GameBoard(
                game: fibs.gameState!,
                animator: _animator,
                // mirror-aware highlights in real FIBS coords (see FibsState)
                legalMoves: fibs.legalMoves,
                interactive: fibs.canMoveNow,
                reversed: reversed,
                onMove: _performMove,
              ),
            ),
          ),
          _Controls(fibs: fibs),
        ],
      ),
    );
  }

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
  const _Controls({required this.fibs});
  final FibsState fibs;

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
          'Your move — dice ${fibs.activeDice.join(", ")}',
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

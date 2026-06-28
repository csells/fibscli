import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'board_view.dart';
import 'fibs_state.dart';
import 'main.dart';
import 'model.dart';
import 'tinystate.dart';

final _log = Logger('fibs.login');

// The FIBS "play a bot" flow: connect, then watch a bot game (milestone 1).
// Bots-only throughout — the who-list only ever shows bots.
class FibsPage extends StatelessWidget {
  const FibsPage({super.key});

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
                decoration: const InputDecoration(labelText: 'FIBS password'),
                obscureText: true,
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
class _BotListView extends StatelessWidget {
  const _BotListView();

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<FibsState>(notifier: App.fibs, builder: _build);

  Widget _build(BuildContext context, FibsState fibs, Widget? child) {
    final free = App.fibs.availableBots; // invite these
    final playing = App.fibs.watchableBots; // watch these
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
      body: (free.isEmpty && playing.isEmpty)
          ? const Center(
              child: Text(
                'No bots online yet.\nWaiting for the who-list…',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                if (free.isNotEmpty)
                  const _SectionHeader('Play a bot (tap to invite)'),
                for (final who in free)
                  ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: Text(who.user),
                    subtitle: Text(
                      'ready · rating '
                      '${who.rating.toStringAsFixed(0)}',
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
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Invite ${bot.user}?'),
        content: const Text(
          'Start a 3-point match. Please finish the game '
          'once it starts — be a good FIBS citizen.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (ok ?? false) App.fibs.invite(bot);
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
        child: ReadOnlyBoardView(game: fibs.gameState!),
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
  int? _selected;

  void _tapPip(int pip) {
    if (!App.fibs.canMoveNow) return;
    if (_selected == null) {
      setState(() => _selected = pip);
    } else {
      App.fibs.move(_selected!, pip);
      setState(() => _selected = null);
    }
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) => _buildBoard(context, fibs),
  );

  Widget _buildBoard(BuildContext context, FibsState fibs) {
    final me = fibs.myColor!;
    final barPip = GammonRules.barPipNoFor(me);
    final offPip = GammonRules.offPipNoFor(me);
    // FIBS names us player1 "You" in our own game; the opponent is the other
    final b = fibs.board!;
    final p1IsUs = b.player1Name == 'You' || b.player1Name == fibs.user;
    final opponent = p1IsUs ? b.player2Name : b.player1Name;

    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('vs $opponent'),
        leading: IconButton(
          icon: const Icon(Icons.flag),
          tooltip: 'resign / leave',
          onPressed: () => _confirmLeave(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: ReadOnlyBoardView(
                game: fibs.gameState!,
                onTapPip: fibs.canMoveNow ? _tapPip : null,
                selectedPip: _selected,
                myBarPip: barPip,
                myOffPip: offPip,
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
          'Your move — dice ${fibs.board!.activeDice.join(", ")}',
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

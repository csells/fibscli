import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'board_view.dart';
import 'fibs_state.dart';
import 'main.dart';
import 'tinystate.dart';

// The FIBS "play a bot" flow: connect, then watch a bot game (milestone 1).
// Bots-only throughout — the who-list only ever shows bots.
class FibsPage extends StatelessWidget {
  const FibsPage({super.key});

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
        notifier: App.fibs,
        builder: (context, fibs, child) {
          if (!fibs.loggedIn) return const _LoginView();
          if (fibs.gameState != null) return const _WatchView();
          return const _BotListView();
        },
      );
}

// ---- credentials persistence (obscured, opt-in) --------------------------

class _Creds {
  static String _obscure(String s) => base64.encode(utf8.encode(s));
  static String _reveal(String s) => utf8.decode(base64.decode(s));

  static String? user() => App.prefs.value?.getString('user');
  static String? pass() {
    final p = App.prefs.value?.getString('pass');
    return p == null ? null : _reveal(p);
  }

  static bool remember() => App.prefs.value?.getBool('remember') ?? false;

  static Future<void> save(String user, String pass,
      {required bool remember}) async {
    final prefs = App.prefs.value!;
    await prefs.setString('user', user);
    await prefs.setBool('remember', remember);
    if (remember) {
      await prefs.setString('pass', _obscure(pass));
    } else {
      await prefs.remove('pass');
    }
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final _user = TextEditingController(text: _Creds.user() ?? '');
  late final _pass = TextEditingController(text: _Creds.pass() ?? '');
  var _remember = _Creds.remember();
  var _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await App.fibs.login(user: _user.text.trim(), pass: _pass.text);
      await _Creds.save(_user.text.trim(), _pass.text, remember: _remember);
    } on Exception catch (ex) {
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
                    decoration:
                        const InputDecoration(labelText: 'FIBS password'),
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
                      child: Text(_error!,
                          style: const TextStyle(color: Colors.red)),
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
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
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
  Widget build(BuildContext context) {
    final bots = App.fibs.watchableBots;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Watch a bot'),
        actions: [
          TextButton(
            onPressed: () => unawaited(App.fibs.logout()),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: bots.isEmpty
          ? const Center(
              child: Text('No bots are playing right now.\n'
                  'Waiting for the who-list…'),
            )
          : ListView(
              children: [
                for (final who in bots)
                  ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: Text(who.user),
                    subtitle: Text('playing ${who.opponent} · '
                        'rating ${who.rating.toStringAsFixed(0)}'),
                    trailing: const Icon(Icons.visibility),
                    onTap: () => App.fibs.watch(who),
                  ),
              ],
            ),
    );
  }
}

class _WatchView extends StatelessWidget {
  const _WatchView();

  @override
  Widget build(BuildContext context) => Scaffold(
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
          child: ReadOnlyBoardView(game: App.fibs.gameState!),
        ),
      );
}

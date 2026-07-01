import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'credential_store.dart';
import 'fibs_play_controller.dart';
import 'fibs_state.dart';
import 'game_board.dart';
import 'theme.dart';
import 'tinystate.dart';

part 'fibs_login_view.dart';
part 'fibs_bot_list_view.dart';
part 'fibs_watch_view.dart';
part 'fibs_play_view.dart';

final _log = Logger('fibs.login');

// Provides the active FibsState to the FIBS view subtree, so the views read it
// from context (FibsScope.of). FibsPage binds the injected FibsState into the
// tree here; everything below depends on this handle.
class FibsScope extends InheritedWidget {
  const FibsScope({required this.fibs, required super.child, super.key});

  final FibsState fibs;

  static FibsState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<FibsScope>();
    assert(scope != null, 'No FibsScope found in context');
    return scope!.fibs;
  }

  @override
  bool updateShouldNotify(FibsScope oldWidget) => fibs != oldWidget.fibs;
}

// The FIBS "play a bot" flow: connect, then watch a bot game (milestone 1).
// Bots-only throughout — the who-list only ever shows bots.
class FibsPage extends StatefulWidget {
  const FibsPage({required this.fibs, required this.creds, super.key});

  // Injected by the composition root (LandingPage). FibsPage provides [fibs] to
  // the subtree via FibsScope and hands [creds] to the login view.
  final FibsState fibs;
  final SecureCredentialStore creds;

  @override
  State<FibsPage> createState() => _FibsPageState();
}

class _FibsPageState extends State<FibsPage> {
  // how many FIBS messages we've already surfaced (so we only toast new ones)
  var _shownMessages = 0;

  @override
  void initState() {
    super.initState();
    _shownMessages = widget.fibs.messages.length;
    widget.fibs.messages.addListener(_onMessages);
  }

  @override
  void dispose() {
    widget.fibs.messages.removeListener(_onMessages);
    super.dispose();
  }

  // Surface incoming FIBS replies (a bot declining an invite, errors, chat) as
  // a SnackBar. Without this they were captured but never shown, so a declined
  // invite looked like a silent failure.
  void _onMessages() {
    final messages = widget.fibs.messages;
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
  Widget build(BuildContext context) => FibsScope(
    fibs: widget.fibs,
    child: ChangeNotifierBuilder<FibsState>(
      notifier: widget.fibs,
      builder: (context, fibs, child) {
        // This picks WHICH view to show. Each view listens to FibsState
        // itself (via its own ChangeNotifierBuilder) so it refreshes on
        // every board update even though it's a const child here.
        if (!fibs.loggedIn) return _LoginView(creds: widget.creds);
        if (fibs.gameState != null) {
          // playing if we're one of the players, otherwise just watching
          return fibs.myColor != null ? const _PlayView() : const _WatchView();
        }
        return const _BotListView();
      },
    ),
  );
}

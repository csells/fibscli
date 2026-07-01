import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

import 'fibs_play_controller.dart';
import 'fibs_state.dart';
import 'game_board.dart';
import 'main.dart';
import 'tinystate.dart';

part 'fibs_login_view.dart';
part 'fibs_bot_list_view.dart';
part 'fibs_watch_view.dart';
part 'fibs_play_view.dart';

final _log = Logger('fibs.login');

// Provides the active FibsState to the FIBS view subtree, so the views read it
// from context (FibsScope.of) instead of reaching the App.fibs global directly.
// FibsPage is the one place that binds the app-level singleton into the tree;
// everything below depends on this typed handle, not the global.
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
  Widget build(BuildContext context) => FibsScope(
    fibs: App.fibs,
    child: ChangeNotifierBuilder<FibsState>(
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
    ),
  );
}

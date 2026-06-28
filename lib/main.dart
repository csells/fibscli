import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_close_stub.dart' if (dart.library.html) 'app_close_web.dart';
import 'fibs_page.dart';
import 'fibs_state.dart';
import 'game_play_page.dart';
import 'tinystate.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  static const title = 'Backgammon';
  // mutable so tests can swap in a fake-backed FibsState before pumping the UI
  static FibsState fibs = FibsState();
  static final prefs = ValueNotifier<SharedPreferences?>(null);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    unawaited(
      SharedPreferences.getInstance().then((prefs) => App.prefs.value = prefs),
    );

    // On web, send FIBS a courtesy `bye` when the tab closes. Best-effort: a
    // dropped connection ends the session regardless (see app_close_web.dart).
    onAppClose(() {
      if (App.fibs.loggedIn) App.fibs.send('bye');
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: App.title,
        theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity),
        debugShowCheckedModeBanner: false,
        // listen to the FIBS singleton at the root so the app can react to
        // connection state (and keeps the singleton owned here)
        home: ChangeNotifierBuilder<FibsState>(
          notifier: App.fibs,
          builder: (context, fibs, child) => const LandingPage(),
        ),
      );
}

// Pick a mode: the local hot-seat game, or play a bot over FIBS (milestone 1:
// watch a bot game). Keeps the working local game as a first-class path.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text(App.title)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 240,
                child: FilledButton.icon(
                  icon: const Icon(Icons.casino),
                  label: const Text('Local game'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                        builder: (_) => const GamePlayPage()),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 240,
                child: FilledButton.icon(
                  icon: const Icon(Icons.smart_toy),
                  label: const Text('Play a bot (FIBS)'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const FibsPage()),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

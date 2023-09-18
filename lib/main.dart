import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fibs_state.dart';
import 'game_play_page.dart';
import 'tinystate.dart';

void main() => runApp(const App());

class App extends StatefulWidget {
  const App({super.key});

  static const title = 'Backgammon';
  static final fibs = FibsState();
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
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: App.title,
        theme: ThemeData(
            primarySwatch: Colors.green,
            visualDensity: VisualDensity.adaptivePlatformDensity),
        debugShowCheckedModeBanner: false,
        home: ChangeNotifierBuilder<FibsState>(
          notifier: App.fibs,
          builder: (context, state, child) => Navigator(
            pages: const [
              // if (!state.loggedIn)
              //   MaterialPage<void>(child: LoginPage())
              // else ...[
              //   MaterialPage<void>(child: WhoPage()),
              // ]
              MaterialPage<void>(child: GamePlayPage()),
            ],
            onPopPage: (route, dynamic result) => route.didPop(result),
          ),
        ),
      );
}

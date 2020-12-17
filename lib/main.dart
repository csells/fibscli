import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/login.dart';
import 'package:fibscli/tinystate.dart';
import 'package:fibscli/who_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(App());

class App extends StatefulWidget {
  static const title = 'Backgammon';
  static final fibs = FibsState();
  static final prefs = ValueNotifier<SharedPreferences>(null);

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) => App.prefs.value = prefs);
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: App.title,
        theme: ThemeData(primarySwatch: Colors.green, visualDensity: VisualDensity.adaptivePlatformDensity),
        debugShowCheckedModeBanner: false,
        home: ChangeNotifierBuilder<FibsState>(
          notifier: App.fibs,
          builder: (context, state, child) => Navigator(
            pages: [
              if (!state.loggedIn)
                MaterialPage<void>(child: LoginPage())
              else ...[
                MaterialPage<void>(child: WhoPage()),
                // MaterialPage(builder: (context) => GamePlayPage()),
              ]
            ],
            onPopPage: (route, dynamic result) => route.didPop(result),
          ),
        ),
      );
}

import 'package:device_preview/device_preview.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/login.dart';
import 'package:fibscli/tinystate.dart';
import 'package:fibscli/who_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:logging/logging.dart';

void main() {
  // Logger.root.level = Level.ALL; // defaults to Level.INFO
  // Logger.root.onRecord.listen((record) {
  //   print('${record.level.name}: ${record.time}: ${record.message}');
  // });
  // final enabled = !kReleaseMode;
  final enabled = false;
  runApp(DevicePreview(enabled: enabled, builder: (context) => App()));
}

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
        locale: DevicePreview.of(context).locale,
        builder: DevicePreview.appBuilder,
        home: ChangeNotifierBuilder<FibsState>(
          notifier: App.fibs,
          builder: (context, state, child) => Navigator(
            pages: [
              if (!state.loggedIn)
                MaterialPage(builder: (context) => LoginPage())
              else ...[
                MaterialPage(builder: (context) => WhoPage()),
                // MaterialPage(builder: (context) => GamePlayPage()),
              ]
            ],
            onPopPage: (route, result) => route.didPop(result),
          ),
        ),
      );
}

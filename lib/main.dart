import 'package:device_preview/device_preview.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/login.dart';
import 'package:fibscli/who_page.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

class App extends StatelessWidget {
  static const fibsProxy = 'localhost';
  static const fibsPort = 8080;
  static const title = 'Backgammon';
  static final fibsState = FibsState();

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: App.title,
        theme: ThemeData(primarySwatch: Colors.green, visualDensity: VisualDensity.adaptivePlatformDensity),
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.of(context).locale,
        builder: DevicePreview.appBuilder,
        home: ValueListenableBuilder<FibsConnection>(
          valueListenable: fibsState.fibs,
          builder: (context, fibs, child) => Navigator(
            pages: [
              if (fibs == null)
                MaterialPage(builder: (context) => LoginPage())
              else ...[
                MaterialPage(builder: (context) => WhoPage()),
                // MaterialPage(builder: (context) => GamePlayPage()),
              ]
            ],
            onPopPage: (route, result) {
              if (!route.didPop(result)) return false;
              // setState(() => _selectedColor = null);
              return true;
            },
          ),
        ),
      );
}

class FutureBuilder2<T> extends StatelessWidget {
  final Future<T> future;
  final T initialData;
  final Widget Function(BuildContext context) pending;
  final Widget Function(BuildContext context, Object error) error;
  final Widget Function(BuildContext context, T data) data;

  FutureBuilder2({
    Key key,
    @required this.future,
    this.initialData,
    this.pending,
    this.error,
    @required this.data,
  })  : assert(data != null),
        super(key: key);

  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
      future: future,
      initialData: initialData,
      builder: (context, snapshot) {
        if (snapshot.hasError) return error != null ? error(context, snapshot.error) : Text(snapshot.error.toString());
        if (snapshot.hasData) return data(context, snapshot.data);
        return pending != null ? pending(context) : Center(child: CircularProgressIndicator());
      });
}

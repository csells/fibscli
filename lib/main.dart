import 'package:device_preview/device_preview.dart';
import 'package:fibscli/game_play_page.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

void main() {
  // final enabled = !kReleaseMode;
  final enabled = false;
  runApp(DevicePreview(enabled: enabled, builder: (context) => App()));
}

class App extends StatelessWidget {
  static const title = 'Backgammon';
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: title,
        theme: ThemeData(primarySwatch: Colors.green, visualDensity: VisualDensity.adaptivePlatformDensity),
        home: GamePlayPage(),
        debugShowCheckedModeBanner: false,
        locale: DevicePreview.of(context).locale,
        builder: DevicePreview.appBuilder,
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

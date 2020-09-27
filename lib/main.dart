import 'package:fibscli/game_play_page.dart';
import 'package:flutter/material.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  static const title = 'Backgammon';
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: title,
        theme: ThemeData(primarySwatch: Colors.green, visualDensity: VisualDensity.adaptivePlatformDensity),
        home: GamePlayPage(),
        debugShowCheckedModeBanner: false,
      );
}

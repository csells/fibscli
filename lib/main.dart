import 'package:fibscli/dice.dart';
import 'package:fibscli/tinystate.dart';
import 'package:flutter/material.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:fibscli/pips.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  static const title = 'Backgammon';
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: title,
        theme: ThemeData(primarySwatch: Colors.green, visualDensity: VisualDensity.adaptivePlatformDensity),
        home: HomePage(),
      );
}

class HomePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(App.title)), body: GameView());
}

class GameView extends StatelessWidget {
  final _game = GammonState();

  GameView() {
    _game.rollDice();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<GammonState>(
        notifier: _game,
        builder: (context, game, child) => Container(
          width: double.infinity,
          height: double.infinity,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: FittedBox(
              child: Stack(
                children: [
                  // frame
                  Container(
                    width: 574,
                    height: 420,
                    decoration: BoxDecoration(border: Border.all(color: Colors.black, width: 5)),
                  ),

                  // outer board
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(20, 20, 216, 380),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                    ),
                  ),

                  // inner board
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(284, 20, 216, 380),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                    ),
                  ),

                  // pips and labels
                  for (final layout in PipLayout.layouts) ...[
                    Positioned.fromRect(rect: layout.rect, child: PipTriangle(layout.pip)),
                    Positioned.fromRect(rect: layout.labelRect, child: PipLabel(layout: layout)),
                  ],

                  // player1 home
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(520, 220, 32, 180),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                    ),
                  ),

                  // player2 home
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(520, 20, 32, 180),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.green[900], border: Border.all(color: Colors.black)),
                    ),
                  ),

                  // doubling cube: undoubled
                  Positioned.fromRect(
                    rect: Rect.fromLTWH(238, 186, 44, 44),
                    child: DoublingCubeView(),
                  ),

                  // pieces
                  for (final layout in PieceLayout.getLayouts(game))
                    Positioned.fromRect(
                      rect: layout.rect,
                      child: PieceView(layout: layout),
                    ),

                  // dice
                  for (final layout in DieLayout.getLayouts(game))
                    Positioned.fromRect(
                      rect: layout.rect,
                      child: DieView(layout: layout),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

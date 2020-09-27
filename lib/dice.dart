import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class DieView extends StatelessWidget {
  final DieLayout layout;
  final void Function() _onTap;
  const DieView({@required this.layout, void Function() onTap}) : _onTap = onTap == null ? _noop : onTap;

  static void _noop() {}

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _onTap,
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: layout.player1 ? Colors.black : Colors.white,
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
            ),
            for (final rect in layout.getSpotRects())
              Positioned.fromRect(
                rect: rect,
                child: Container(
                  decoration: BoxDecoration(
                    color: layout.player1 ? Colors.white : Colors.black,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      );
}

class DieLayout {
  static final _dieWidth = 36.0;
  static final _dieHeight = 36.0;
  static final _spotses = <List<Offset>>[
    [Offset(18, 18)], // 1
    [Offset(10, 10), Offset(26, 26)], // 2
    [Offset(10, 10), Offset(18, 18), Offset(26, 26)], // 3
    [Offset(10, 10), Offset(26, 26), Offset(10, 26), Offset(26, 10)], // 4
    [Offset(10, 10), Offset(26, 26), Offset(10, 26), Offset(26, 10), Offset(18, 18)], // 5
    [Offset(10, 10), Offset(26, 26), Offset(10, 26), Offset(26, 10), Offset(10, 18), Offset(26, 18)], // 6
  ];

  final int die;
  final bool player1;
  final double left;
  final double top;
  final List<Offset> spots;
  DieLayout({
    @required this.die,
    @required this.player1,
    @required this.left,
    @required this.top,
    @required this.spots,
  });

  Rect get rect => Rect.fromLTWH(left, top, _dieWidth, _dieHeight);
  Iterable<Rect> getSpotRects() sync* {
    for (final spot in spots) yield Rect.fromCenter(center: spot, width: 5, height: 5);
  }

  static Iterable<DieLayout> getLayouts(GammonState game) sync* {
    final dice = game.dice;
    assert(dice.length == 2 || dice.length == 4);

    for (var i = 0; i != 2; ++i) {
      final die = dice[i];
      yield DieLayout(
        left: 354 + 42.0 * i,
        top: 194,
        die: die,
        player1: game.sideSign == -1,
        spots: _spotses[die - 1],
      );
    }

    if (dice.length == 4)
      for (var i = 0; i != 2; ++i) {
        final die = dice[0]; // they're all the same...
        yield DieLayout(
          left: 312 + 126.0 * i,
          top: 194,
          die: die,
          player1: game.sideSign == -1,
          spots: _spotses[die - 1],
        );
      }
  }
}

class DoublingCubeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Center(child: Text('64', textAlign: TextAlign.center)),
      );
}

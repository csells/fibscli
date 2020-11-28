import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class DieState {
  final int roll;
  bool available = true;
  DieState(this.roll);
}

class DieView extends StatelessWidget {
  static final _dieColors = [
    [Colors.grey[850], Color(0xFF141414)],
    [Colors.grey[50], Colors.grey[300]]
  ];

  final List<Color> _gradeColors;
  final Color _playerColor;
  final Color _otherColor;
  final DieLayout layout;
  final void Function() _onTap;
  DieView({@required this.layout, void Function() onTap})
      : _onTap = onTap == null ? _noop : onTap,
        _playerColor = layout.player == Player.one ? Colors.black : Colors.white,
        _otherColor = layout.player == Player.one ? Colors.white : Colors.black,
        _gradeColors = _dieColors[layout.player.index];

  static void _noop() {}

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _onTap,
        child: Opacity(
          opacity: layout.die.available ? 1.0 : 0.5,
          child: Container(
            decoration: BoxDecoration(
              color: _playerColor,
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: BorderRadius.all(Radius.circular(4)),
              gradient: LinearGradient(begin: Alignment.topLeft, colors: _gradeColors),
            ),
            child: FractionallySizedBox(
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: _playerColor),
                child: Stack(
                  children: [
                    for (final rect in layout.getSpotRects())
                      Positioned.fromRect(
                        rect: rect.shift(Offset(-1, -1)),
                        child: Container(decoration: BoxDecoration(color: _otherColor, shape: BoxShape.circle)),
                      ),
                  ],
                ),
              ),
            ),
          ),
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

  final DieState die;
  final Player player;
  final double left;
  final double top;
  final List<Offset> spots;
  DieLayout({
    @required this.die,
    @required this.player,
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

    final dx = dice.length == 2 ? 42 : 0;
    for (var i = 0; i != dice.length; ++i) {
      final die = dice[i];
      yield DieLayout(
        left: dx + 312 + 42.0 * i,
        top: 194,
        die: die,
        player: game.turnPlayer,
        spots: _spotses[die.roll - 1],
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

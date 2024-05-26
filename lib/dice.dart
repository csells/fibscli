import 'package:flutter/material.dart';

import 'model.dart';

class DieState {
  DieState(this.roll);
  final int roll;
  bool available = true;
}

class DieView extends StatelessWidget {
  DieView({required this.layout, super.key, void Function()? onTap})
      : _onTap = onTap ?? _noop,
        _playerColor =
            layout.player == GammonPlayer.one ? Colors.black : Colors.white,
        _otherColor =
            layout.player == GammonPlayer.one ? Colors.white : Colors.black,
        _gradeColors = _dieColors[layout.player!.index];

  static final _dieColors = [
    [Colors.grey[850]!, const Color(0xFF141414)],
    [Colors.grey[50]!, Colors.grey[300]!]
  ];

  final List<Color> _gradeColors;
  final Color _playerColor;
  final Color _otherColor;
  final DieLayout layout;
  final void Function() _onTap;

  static void _noop() {}

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: _onTap,
        child: Opacity(
          opacity: layout.die.available ? 1.0 : 0.5,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: _playerColor,
              border: Border.all(color: Colors.black, width: 1),
              borderRadius: const BorderRadius.all(Radius.circular(4)),
              gradient: LinearGradient(
                  begin: Alignment.topLeft, colors: _gradeColors),
            ),
            child: FractionallySizedBox(
              widthFactor: .925,
              heightFactor: .925,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _playerColor,
                  border: const Border(),
                ),
                child: Stack(
                  children: [
                    for (final rect in layout.getSpotRects())
                      Positioned.fromRect(
                        rect: rect.shift(const Offset(-1, -1)),
                        child: Container(
                            decoration: BoxDecoration(
                                color: _otherColor, shape: BoxShape.circle)),
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
  DieLayout({
    required this.die,
    required this.player,
    required this.left,
    required this.top,
    required this.spots,
  });
  static const _dieWidth = 36.0;
  static const _dieHeight = 36.0;
  static final _spotses = <List<Offset>>[
    [
      // 1
      const Offset(18, 18),
    ],
    [
      // 2
      const Offset(10, 10),
      const Offset(26, 26),
    ],
    [
      // 3
      const Offset(10, 10),
      const Offset(18, 18),
      const Offset(26, 26),
    ],
    [
      // 4
      const Offset(10, 10),
      const Offset(26, 26),
      const Offset(10, 26),
      const Offset(26, 10)
    ],
    [
      // 5
      const Offset(10, 10),
      const Offset(26, 26),
      const Offset(10, 26),
      const Offset(26, 10),
      const Offset(18, 18)
    ],
    [
      // 6
      const Offset(10, 10),
      const Offset(26, 26),
      const Offset(10, 26),
      const Offset(26, 10),
      const Offset(10, 18),
      const Offset(26, 18)
    ],
  ];

  final DieState die;
  final GammonPlayer? player;
  final double left;
  final double top;
  final List<Offset> spots;

  Rect get rect => Rect.fromLTWH(left, top, _dieWidth, _dieHeight);
  Iterable<Rect> getSpotRects() sync* {
    for (final spot in spots) {
      yield Rect.fromCenter(center: spot, width: 5, height: 5);
    }
  }

  static Iterable<DieLayout> getLayouts(GammonState game) sync* {
    final dice = game.dice;
    assert(dice.length == 2 || dice.length == 4);

    GammonPlayer? diePlayer(
        int moveNo, List<DieState> dice, int index, GammonPlayer? turnPlayer) {
      if (moveNo != 1) return turnPlayer;
      final maxDieIndex = dice[0].roll > dice[1].roll ? 0 : 1;
      return index == maxDieIndex
          ? turnPlayer
          : GammonRules.otherPlayer(turnPlayer);
    }

    final dx = dice.length == 2 ? 42 : 0;
    for (var i = 0; i != dice.length; ++i) {
      final die = dice[i];
      final player = diePlayer(game.moveNo, dice, i, game.turnPlayer);
      yield DieLayout(
        left: dx + 312 + 42.0 * i,
        top: 194,
        die: die,
        player: player,
        spots: _spotses[die.roll - 1],
      );
    }
  }
}

class DoublingCubeView extends StatelessWidget {
  const DoublingCubeView({super.key});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Center(child: Text('64', textAlign: TextAlign.center)),
      );
}

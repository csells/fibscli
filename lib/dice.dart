import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'model.dart';
import 'theme.dart';

class DieState {
  DieState(this.roll);
  final int roll;
  bool available = true;
}

// One die per player, in the two checker colors: player one is an ink face with
// ivory spots, player two an ivory face (ink-ringed) with ink spots. A spent
// die dims.
class DieView extends StatelessWidget {
  DieView({required this.layout, super.key, void Function()? onTap})
    : _onTap = onTap ?? _noop,
      _solid = layout.player == GammonPlayer.one;

  final bool _solid;
  final DieLayout layout;
  final void Function() _onTap;

  Color get _faceColor => _solid ? AppColors.ink : AppColors.ivory;
  Color get _spotColor => _solid ? AppColors.ivory : AppColors.ink;

  static void _noop() {}

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _onTap,
    child: Opacity(
      opacity: layout.die.available ? 1.0 : 0.4,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _faceColor,
          border: Border.all(color: AppColors.ink, width: _solid ? 1 : 1.5),
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        // spots sit directly on the die face (no inner circle behind them)
        child: Stack(
          children: [
            for (final rect in layout.getSpotRects())
              Positioned.fromRect(
                rect: rect.shift(const Offset(-1, -1)),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _spotColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
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
      const Offset(26, 10),
    ],
    [
      // 5
      const Offset(10, 10),
      const Offset(26, 26),
      const Offset(10, 26),
      const Offset(26, 10),
      const Offset(18, 18),
    ],
    [
      // 6
      const Offset(10, 10),
      const Offset(26, 26),
      const Offset(10, 26),
      const Offset(26, 10),
      const Offset(10, 18),
      const Offset(26, 18),
    ],
  ];

  final DieState die;
  final GammonPlayer? player;
  final double left;
  final double top;
  final List<Offset> spots;

  static List<Offset> spotsFor(int roll) => _spotses[roll - 1];

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
      int moveNo,
      List<DieState> dice,
      int index,
      GammonPlayer? turnPlayer,
    ) {
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
  const DoublingCubeView({
    required this.cube,
    super.key,
    this.reversed = false,
  });
  final DoublingCube cube;
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final faceValue = cube.value;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ivory,
        border: Border.all(color: AppColors.ink, width: 2),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Center(
        // counter-rotate the number so it reads upright when the whole board is
        // flipped 180 degrees, the same way the pip labels do
        child: RotatedBox(
          quarterTurns: reversed ? 2 : 0,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(
                '$faceValue',
                textAlign: TextAlign.center,
                style: GoogleFonts.instrumentSerif(
                  color: AppColors.ink,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

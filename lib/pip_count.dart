import 'package:flutter/material.dart';

import 'model.dart';

class PipCountView extends StatelessWidget {
  const PipCountView({required this.layout, super.key, this.reversed = false});
  final bool reversed;
  final PipCountLayout layout;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: reversed ? 2 : 0,
          child: Text(
            '${layout.pipCount}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black, fontSize: 10),
          ),
        ),
      );
}

class PipCountLayout {
  PipCountLayout({
    required this.pipCount,
    required this.left,
    required this.top,
  });
  static const double width = 34;
  static const double height = 15;

  final int pipCount;
  final double left;
  final double top;

  Rect get rect => Rect.fromLTWH(left, top, width, height);

  static List<PipCountLayout> getLayouts(GammonState game) => [
      PipCountLayout(pipCount: game.pipCount(sign: -1), left: 518, top: 399),
      PipCountLayout(pipCount: game.pipCount(sign: 1), left: 518, top: 5),
    ];
}

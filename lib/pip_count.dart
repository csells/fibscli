import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';

class PipCountView extends StatelessWidget {
  final bool reversed;
  final PipCountLayout layout;
  const PipCountView({@required this.layout, this.reversed = false});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.center,
        child: RotatedBox(
          quarterTurns: reversed ? 2 : 0,
          child: Text(
            '${layout.pipCount}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: 10),
          ),
        ),
      );
}

class PipCountLayout {
  static final double width = 34;
  static final double height = 15;

  final int pipCount;
  final double left;
  final double top;
  PipCountLayout({
    @required this.pipCount,
    @required this.left,
    @required this.top,
  });

  Rect get rect => Rect.fromLTWH(left, top, width, height);

  static List<PipCountLayout> getLayouts(GammonState game) {
    return [
      PipCountLayout(pipCount: game.pipCount(sign: -1), left: 518, top: 399),
      PipCountLayout(pipCount: game.pipCount(sign: 1), left: 518, top: 5),
    ];
  }
}

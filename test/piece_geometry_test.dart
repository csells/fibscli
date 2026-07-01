import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // baseSlotOffset's quadrant geometry lives in named constants
  // (_bottomRightX/_topRowY/...). Pin the exact slot origin of the first + last
  // pip of each of the 4 quadrants, so a wrong constant (or a lost -dx/+dx
  // direction) is caught here rather than as a visual glitch. Columns step by
  // 36px toward board centre: -dx on the right/bottom sides, +dx on the top/left.
  test('baseSlotOffset places each quadrant at its named origin', () {
    // bottom-right quadrant (pips 1..6), baseline y = 371, origin x = 468
    expect(PieceLayout.baseSlotOffset(1), const Offset(468, 371));
    expect(PieceLayout.baseSlotOffset(6), const Offset(288, 371));
    // bottom-left quadrant (7..12), origin x = 204
    expect(PieceLayout.baseSlotOffset(7), const Offset(204, 371));
    expect(PieceLayout.baseSlotOffset(12), const Offset(24, 371));
    // top-left quadrant (13..18), baseline y = 21, origin x = 24
    expect(PieceLayout.baseSlotOffset(13), const Offset(24, 21));
    expect(PieceLayout.baseSlotOffset(18), const Offset(204, 21));
    // top-right quadrant (19..24), origin x = 288
    expect(PieceLayout.baseSlotOffset(19), const Offset(288, 21));
    expect(PieceLayout.baseSlotOffset(24), const Offset(468, 21));
  });

  // The bar (centre) and off (right tray) columns were also extracted from
  // magic literals into named constants. Pin a player-one checker on the bar
  // and one borne off so a wrong _barX/_offBottomBaselineY/etc is caught here.
  test('bar and off checkers sit at their named columns and baselines', () {
    final board = List.generate(26, (_) => <int>[]);
    board[25] = [-1]; // player one on the bar (index 25 = P1 bar)
    board[0] = [-1]; // player one borne off (index 0 = P1 off)

    final layouts = PieceLayout.getLayouts(board).toList();
    expect(
      layouts.firstWhere((l) => l.pipNo == 25).offset,
      const Offset(246, 254), // _barX, _barBottomBaselineY
    );
    expect(
      layouts.firstWhere((l) => l.pipNo == 0).offset,
      const Offset(520, 386), // _offX, _offBottomBaselineY
    );
  });
}

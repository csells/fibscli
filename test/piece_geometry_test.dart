import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // #5: baseSlotOffset's quadrant geometry was extracted from magic literals
  // into named constants (_bottomRightX/_topRowY/...). This pins the exact
  // slot origin of the first + last pip of each of the 4 quadrants, so a
  // fat-fingered constant (or a lost -dx/+dx direction) is caught, not just
  // discovered as a visual glitch. Columns step by 36px toward board centre:
  // -dx on the right/bottom sides, +dx on the left/top.
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
}

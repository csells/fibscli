import 'package:fibscli/pieces.dart';
import 'package:fibscli/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color _outerFill(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
  return (box.decoration as BoxDecoration).color!;
}

Future<void> _pumpPiece(WidgetTester tester, int pieceID) => tester.pumpWidget(
  Directionality(
    textDirection: TextDirection.ltr,
    child: PieceView(
      layout: PieceLayout(
        pipNo: 1,
        pieceID: pieceID,
        offset: Offset.zero,
        label: '',
      ),
    ),
  ),
);

void main() {
  // The render layer decodes checker ownership through the engine's typed
  // helper (playerFor), not the board's raw sign. Pin the owner->colour
  // mapping: player one (negative ids) is the solid ink checker, player two
  // (positive ids) the hollow ivory one.
  testWidgets('a checker colour follows its typed owner', (tester) async {
    await _pumpPiece(tester, -1); // player one owns negative ids
    expect(_outerFill(tester), AppColors.ink);

    await _pumpPiece(tester, 1); // player two owns positive ids
    expect(_outerFill(tester), AppColors.ivory);
  });
}

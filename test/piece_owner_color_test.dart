import 'package:fibscli/pieces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

LinearGradient _outerGradient(WidgetTester tester) {
  final box = tester.widget<DecoratedBox>(find.byType(DecoratedBox).first);
  return (box.decoration as BoxDecoration).gradient! as LinearGradient;
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
  // mapping: player one (negative ids) renders the dark grade, player two
  // (positive ids) the light grade.
  testWidgets('a checker colour follows its typed owner', (tester) async {
    await _pumpPiece(tester, -1); // player one owns negative ids
    expect(_outerGradient(tester).colors.first, Colors.grey[800]);

    await _pumpPiece(tester, 1); // player two owns positive ids
    expect(_outerGradient(tester).colors.first, Colors.white);
  });
}

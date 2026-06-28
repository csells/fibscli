import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PieceLayout.drawOrder (issue #6)', () {
    test('moving pieces are ordered after all stationary pieces', () {
      final board = GammonRules.initialBoard();
      final layouts = PieceLayout.getLayouts(board).toList();

      // animate a piece that appears early in pip order
      final animating = <int?>{layouts.first.pieceID};
      final ordered = PieceLayout.drawOrder(layouts, animating);

      expect(ordered.length, layouts.length);

      final firstMoving = ordered.indexWhere(
        (l) => animating.contains(l.pieceID),
      );
      final lastStationary = ordered.lastIndexWhere(
        (l) => !animating.contains(l.pieceID),
      );
      expect(firstMoving, greaterThan(lastStationary));
      // the animated piece ends up last (drawn on top)
      expect(ordered.last.pieceID, layouts.first.pieceID);
    });

    test('order is unchanged when nothing is animating', () {
      final board = GammonRules.initialBoard();
      final layouts = PieceLayout.getLayouts(board).toList();
      final ordered = PieceLayout.drawOrder(layouts, <int?>{});
      expect(ordered.map((l) => l.pieceID), layouts.map((l) => l.pieceID));
    });
  });
}

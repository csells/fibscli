import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DieView (issue #17)', () {
    testWidgets('white die renders its spots without overflow', (tester) async {
      final layout = DieLayout(
        die: DieState(6),
        player: GammonPlayer.two, // white die
        left: 0,
        top: 0,
        spots: DieLayout.spotsFor(6),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 36,
              height: 36,
              child: DieView(layout: layout),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(DieView), findsOneWidget);
    });
  });
}

import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Center(child: SizedBox(width: 60, height: 60, child: child)),
      ),
    );

void main() {
  group('DoublingCubeView (issue #12)', () {
    testWidgets('shows the current cube value', (tester) async {
      final cube = DoublingCube()
        ..applyTake(GammonPlayer.one) // -> 2
        ..applyTake(GammonPlayer.two); // -> 4
      await tester.pumpWidget(_host(DoublingCubeView(cube: cube)));

      expect(find.text('4'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a centered cube shows 1', (tester) async {
      await tester.pumpWidget(_host(DoublingCubeView(cube: DoublingCube())));
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('counter-rotates its value when the board is reversed',
        (tester) async {
      await tester.pumpWidget(
          _host(DoublingCubeView(cube: DoublingCube(), reversed: true)));
      final rotated = tester.widget<RotatedBox>(find.descendant(
        of: find.byType(DoublingCubeView),
        matching: find.byType(RotatedBox),
      ));
      expect(rotated.quarterTurns, 2); // flipped 180 to read upright
    });
  });

  group('DieView (issue #17)', () {
    for (final player in GammonPlayer.values) {
      for (var roll = 1; roll <= 6; ++roll) {
        testWidgets('renders $player die showing $roll without overflow',
            (tester) async {
          final layout = DieLayout(
            die: DieState(roll),
            player: player,
            left: 0,
            top: 0,
            spots: DieLayout.spotsFor(roll),
          );
          await tester.pumpWidget(_host(DieView(layout: layout)));
          expect(find.byType(DieView), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('PieceView', () {
    testWidgets('renders a stack-count label for tall stacks', (tester) async {
      final layout = PieceLayout(
        pipNo: 6,
        pieceID: -1,
        offset: Offset.zero,
        label: '7',
      );
      await tester.pumpWidget(_host(PieceView(layout: layout)));
      expect(find.text('7'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

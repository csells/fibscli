import 'package:fibscli/dice.dart';
import 'package:fibscli/model.dart';
import 'package:fibscli/pieces.dart';
import 'package:fibscli/theme.dart';
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

    testWidgets('counter-rotates its value when the board is reversed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(DoublingCubeView(cube: DoublingCube(), reversed: true)),
      );
      final rotated = tester.widget<RotatedBox>(
        find.descendant(
          of: find.byType(DoublingCubeView),
          matching: find.byType(RotatedBox),
        ),
      );
      expect(rotated.quarterTurns, 2); // flipped 180 to read upright
    });
  });

  group('DieView (issue #17)', () {
    for (final player in GammonPlayer.values) {
      for (var roll = 1; roll <= 6; ++roll) {
        testWidgets('renders $player die showing $roll without overflow', (
          tester,
        ) async {
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
    BoxDecoration outerDecoration(WidgetTester tester) =>
        tester.widget<DecoratedBox>(find.byType(DecoratedBox).first).decoration
            as BoxDecoration;

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

    testWidgets('renders movable and selected highlights with one red ring', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          PieceView(
            layout: PieceLayout(
              pipNo: 6,
              pieceID: -1,
              offset: Offset.zero,
              label: '',
              highlightKind: PieceHighlight.movable,
            ),
          ),
        ),
      );
      final movable = outerDecoration(tester);
      expect((movable.border! as Border).top.color, AppColors.accent);
      expect((movable.border! as Border).top.width, 2.5);
      expect(movable.boxShadow, isNull);
      expect(find.byKey(const ValueKey('piece-selected-marker')), findsNothing);

      await tester.pumpWidget(
        _host(
          PieceView(
            layout: PieceLayout(
              pipNo: 6,
              pieceID: -1,
              offset: Offset.zero,
              label: '',
              highlightKind: PieceHighlight.selected,
            ),
          ),
        ),
      );
      final selected = outerDecoration(tester);
      expect((selected.border! as Border).top.color, AppColors.accent);
      expect((selected.border! as Border).top.width, 2.5);
      expect(selected.boxShadow, isNull);
      expect(
        find.byKey(const ValueKey('piece-selected-marker')),
        findsOneWidget,
      );
      final marker = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('piece-selected-marker')),
      );
      final markerDecoration = marker.decoration as BoxDecoration;
      expect(markerDecoration.color, const Color(0xD9E1341E));
      expect(markerDecoration.border, isNull);
      expect((marker.child! as SizedBox).width, 5);
      expect((marker.child! as SizedBox).height, 5);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('piece-selected-marker')),
          matching: find.byType(Center),
        ),
        findsWidgets,
      );

      await tester.pumpWidget(
        _host(
          PieceView(
            layout: PieceLayout(
              pipNo: 6,
              pieceID: 1,
              offset: Offset.zero,
              label: '',
              highlightKind: PieceHighlight.selected,
            ),
          ),
        ),
      );
      final whiteSelected = outerDecoration(tester);
      expect((whiteSelected.border! as Border).top.color, AppColors.accent);
      expect(
        find.byKey(const ValueKey('piece-selected-marker')),
        findsOneWidget,
      );
    });
  });
}

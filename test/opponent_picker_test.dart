import 'package:fibscli/main.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (factories, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A single-strength engine (no levels) and a leveled one.
class _FlatFactory extends BgAiPlayerFactory {
  @override
  String get name => 'Flat Engine';
  @override
  BgAiPlayer create({String? level}) => PubevalAiPlayer();
}

class _LeveledFactory extends BgAiPlayerFactory {
  @override
  String get name => 'Leveled Engine';
  @override
  List<String> get levels => const ['easy', 'medium', 'hard'];
  @override
  BgAiPlayer create({String? level}) => PubevalAiPlayer();
}

// Open the picker via a button; the tapped result is written into [onResult].
Future<void> _open(
  WidgetTester tester,
  OpponentPicker picker,
  void Function(AiChoice?) onResult,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => onResult(
              await showDialog<AiChoice>(
                context: context,
                builder: (_) => picker,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one dialog shows the engine AND difficulty together', (
    tester,
  ) async {
    AiChoice? result;
    await _open(
      tester,
      OpponentPicker(factories: [_LeveledFactory()]),
      (c) => result = c,
    );

    // both are on-screen at once -- no second step to reach difficulty
    expect(find.text('Leveled Engine'), findsOneWidget);
    expect(find.textContaining('Difficulty'), findsOneWidget);
    expect(find.text('OK'), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result!.factory.name, 'Leveled Engine');
    expect(result!.level, 'medium'); // middle of [easy, medium, hard]
  });

  testWidgets(
    'remembers the previous choice: OK returns the pre-selected level',
    (tester) async {
      AiChoice? result;
      await _open(
        tester,
        OpponentPicker(factories: [_LeveledFactory()], initialLevel: 'hard'),
        (c) => result = c,
      );

      // no interaction beyond OK -- the remembered level is pre-filled
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(result!.level, 'hard');
    },
  );

  testWidgets('the difficulty can be changed within the one dialog', (
    tester,
  ) async {
    AiChoice? result;
    await _open(
      tester,
      OpponentPicker(factories: [_LeveledFactory()], initialLevel: 'easy'),
      (c) => result = c,
    );

    await tester.tap(find.text('easy')); // open the difficulty dropdown
    await tester.pumpAndSettle();
    await tester.tap(find.text('hard').last); // choose a different level
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result!.level, 'hard');
  });

  testWidgets('a level-less engine has no difficulty control; level is null', (
    tester,
  ) async {
    AiChoice? result;
    await _open(
      tester,
      OpponentPicker(factories: [_FlatFactory()]),
      (c) => result = c,
    );

    expect(find.textContaining('Difficulty'), findsNothing);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(result!.factory.name, 'Flat Engine');
    expect(result!.level, isNull);
  });
}

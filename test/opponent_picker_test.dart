import 'package:fibscli/main.dart';
import 'package:fibscli/model.dart'; // re-exports bg_engine (factories, …)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A single-strength engine (no levels) and a leveled one, so we can drive both
// picker paths without depending on the global AiRegistry.
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
  List<String> get levels => const ['easy', 'hard'];
  @override
  BgAiPlayer create({String? level}) => PubevalAiPlayer();
}

Future<AiChoice?> _openPicker(WidgetTester tester) async {
  AiChoice? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => result = await showDialog<AiChoice>(
              context: context,
              builder: (_) => OpponentPicker(
                factories: [_FlatFactory(), _LeveledFactory()],
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
  return result;
}

void main() {
  testWidgets('a single-strength engine is chosen directly (no level)', (
    tester,
  ) async {
    await _openPicker(tester);
    await tester.tap(find.text('Flat Engine'));
    await tester.pumpAndSettle();
    // dialog closed straight away -- no difficulty step
    expect(find.textContaining('difficulty'), findsNothing);
  });

  testWidgets('a leveled engine offers a difficulty step', (tester) async {
    await _openPicker(tester);

    // picking the leveled engine reveals its levels rather than starting
    await tester.tap(find.text('Leveled Engine'));
    await tester.pumpAndSettle();
    expect(find.textContaining('difficulty'), findsOneWidget);
    expect(find.text('easy'), findsOneWidget);
    expect(find.text('hard'), findsOneWidget);
  });
}

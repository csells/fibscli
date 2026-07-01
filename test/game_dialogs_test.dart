import 'package:fibscli/game_dialogs.dart';
import 'package:fibscli/model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Open a dialog via its show() helper, tap [tapText], and return the choice the
// helper resolved to.
Future<T?> _openAndTap<T>(
  WidgetTester tester,
  Future<T?> Function(BuildContext) show,
  String tapText,
) async {
  T? choice;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => ElevatedButton(
          onPressed: () async => choice = await show(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tapText));
  await tester.pumpAndSettle();
  return choice;
}

void main() {
  testWidgets('QuitGameDialog returns the chosen answer', (tester) async {
    expect(
      await _openAndTap<bool>(tester, QuitGameDialog.show, 'Quit Game'),
      isTrue,
    );
    expect(
      await _openAndTap<bool>(tester, QuitGameDialog.show, 'Keep Playing'),
      isFalse,
    );
  });

  testWidgets('DoubleOfferDialog shows the stakes and returns the answer', (
    tester,
  ) async {
    Future<bool?> show(BuildContext c) =>
        DoubleOfferDialog.show(c, GammonPlayer.one, 4);

    final accepted = await _openAndTap<bool>(tester, show, 'Accept');
    expect(accepted, isTrue);

    // reopen to read the content + the decline path
    bool? declined;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => declined = await show(context),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Player 1 doubles to 4'), findsOneWidget);
    expect(find.textContaining('Player 2'), findsOneWidget); // opponent decides
    await tester.tap(find.text('Decline'));
    await tester.pumpAndSettle();
    expect(declined, isFalse);
  });

  testWidgets('OddsDialog shows win chances and cube advice', (tester) async {
    final game = GammonState();
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => OddsDialog.show(context, game),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Win Chances'), findsOneWidget);
    expect(find.textContaining('%'), findsNWidgets(2)); // both players' chances
    // opening position isn't a double -> "too early" advice
    expect(find.textContaining('too early to double'), findsOneWidget);
  });

  testWidgets('NewGameDialog announces the winner and shows the stats', (
    tester,
  ) async {
    final game = GammonState();
    bool? again;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async => again = await NewGameDialog.show(
              context,
              GammonPlayer.one,
              game,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.text('Rolls'), findsOneWidget); // the stats table
    await tester.tap(find.text('Yes, Please!'));
    await tester.pumpAndSettle();
    expect(again, isTrue);
  });
}

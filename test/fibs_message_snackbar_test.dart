import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a FIBS reply (e.g. a bot declining an invite) is surfaced', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw'); // -> bot-list view

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pump();

    // FIBS sends a `says` (CLIP code 12) — here a bot declining the invite
    fake.feed('12 MonteCarlo only know how to play 1 point matches');
    await tester.pump(); // process the message + queue the SnackBar
    await tester.pump(const Duration(milliseconds: 100)); // animate it in

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('MonteCarlo'), findsOneWidget);
    expect(find.textContaining('1 point matches'), findsOneWidget);
  });

  // FibsPage is constructor-injected: it listens to the fibs it was GIVEN.
  // Prove it by feeding a reply on the injected instance and seeing it surface
  // (there is no App.fibs global to accidentally listen to anymore).
  testWidgets('FibsPage listens to its injected fibs', (tester) async {
    final injectedFake = FakeTransport();
    final injected = FibsState.withTransport(injectedFake);
    await injected.login(user: 'me', pass: 'pw');

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: injected, creds: await fakeCreds()),
      ),
    );
    await tester.pump();

    injectedFake.feed('12 MonteCarlo declines the invite');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('MonteCarlo'), findsOneWidget);
  });
}

import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

void main() {
  testWidgets('a FIBS reply (e.g. a bot declining an invite) is surfaced', (
    tester,
  ) async {
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);
    await App.fibs.login(user: 'me', pass: 'pw'); // -> bot-list view

    await tester.pumpWidget(MaterialApp(home: FibsPage(fibs: App.fibs)));
    await tester.pump();

    // FIBS sends a `says` (CLIP code 12) — here a bot declining the invite
    fake.feed('12 MonteCarlo only know how to play 1 point matches');
    await tester.pump(); // process the message + queue the SnackBar
    await tester.pump(const Duration(milliseconds: 100)); // animate it in

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('MonteCarlo'), findsOneWidget);
    expect(find.textContaining('1 point matches'), findsOneWidget);
  });

  // #2c: FibsPage is now constructor-injected end-to-end -- it listens to the
  // fibs it was given, NOT the App.fibs global. Prove it: App.fibs is a
  // different, message-less instance; the reply arrives on the INJECTED one and
  // must still surface. (Reverting FibsPage to App.fibs drops the message.)
  testWidgets('FibsPage listens to its injected fibs, not App.fibs', (
    tester,
  ) async {
    App.fibs = FibsState.withTransport(FakeTransport()); // decoy, no messages
    final injectedFake = FakeTransport();
    final injected = FibsState.withTransport(injectedFake);
    await injected.login(user: 'me', pass: 'pw');

    await tester.pumpWidget(MaterialApp(home: FibsPage(fibs: injected)));
    await tester.pump();

    injectedFake.feed('12 MonteCarlo declines the invite');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('MonteCarlo'), findsOneWidget);
  });
}

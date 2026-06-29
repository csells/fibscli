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

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pump();

    // FIBS sends a `says` (CLIP code 12) — here a bot declining the invite
    fake.feed('12 MonteCarlo only know how to play 1 point matches');
    await tester.pump(); // process the message + queue the SnackBar
    await tester.pump(const Duration(milliseconds: 100)); // animate it in

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.textContaining('MonteCarlo'), findsOneWidget);
    expect(find.textContaining('1 point matches'), findsOneWidget);
  });
}

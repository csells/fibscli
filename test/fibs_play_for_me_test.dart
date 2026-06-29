import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

void main() {
  testWidgets('"Play for me" starts and stops the autonomous bot player', (
    tester,
  ) async {
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);
    await App.fibs.login(user: 'me', pass: 'pw'); // -> bot-list view

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pump();

    expect(find.text('Play for me'), findsOneWidget);

    await tester.tap(find.text('Play for me'));
    await tester.pump();

    // run() asked the server for the lobby, and the toggle flipped
    expect(fake.sent, contains('who'));
    expect(find.text('Stop'), findsOneWidget);

    await tester.tap(find.text('Stop'));
    await tester.pump();

    // stopped cleanly (its timers cancelled) and the toggle reset
    expect(find.text('Play for me'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';
import 'fake_transport.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the lobby lists a saved match and resumes it on tap', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    // a `show savedgames` listing arrives on login
    fake.feed('  MG 0 0 - 1');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    // the unfinished match with MG is offered for resume (the section header
    // reads in editorial small-caps)
    expect(find.text('MG'), findsOneWidget);
    expect(find.textContaining('RESUME'), findsWidgets);

    await tester.tap(find.text('MG'));
    await tester.pumpAndSettle();

    // resuming re-invites the opponent so FIBS reloads the saved match
    expect(fake.sent, contains('invite MG'));
  });

  testWidgets('an opponent resume request auto-joins (no manual prompt)', (
    tester,
  ) async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'me', pass: 'pw');
    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: await fakeCreds()),
      ),
    );
    await tester.pumpAndSettle();

    fake.feed('MG wants to resume a saved match with you.');
    await tester.pumpAndSettle();

    // no tap needed -- the app sends `join` itself to drop us into the game
    expect(fake.sent, contains('join'));
    expect(find.text('Join'), findsNothing);
  });
}

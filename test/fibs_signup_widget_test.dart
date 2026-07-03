import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

void main() {
  testWidgets('creating a FIBS account can remember and then log in', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secret = FakeSecretStore();
    final creds = SecureCredentialStore(prefs, secret);
    await creds.load();
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Create a FIBS account'));
    await tester.pump();

    await tester.enterText(
      find.widgetWithText(TextField, 'FIBS user'),
      'new_user',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'FIBS password'),
      'hunter2',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Confirm password'),
      'hunter2',
    );
    await tester.tap(find.text('Remember this password'));
    await tester.pump();

    await tester.tap(find.text('Create and connect'));
    await tester.pumpAndSettle();

    expect(fake.createdAccounts, {'new_user': 'hunter2'});
    expect(fibs.loggedIn, isTrue);
    expect(creds.user, 'new_user');
    expect(creds.password, 'hunter2');
    expect(creds.remember, isTrue);
  });
}

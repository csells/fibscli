import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

void main() {
  testWidgets('FIBS password field has a working show/hide toggle', (
    tester,
  ) async {
    // logged-out, no remembered creds -> the login form (not autologin) shows
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final creds = SecureCredentialStore(prefs, FakeSecretStore());
    await creds.load();
    final fibs = FibsState.withTransport(FakeTransport());

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    final passField = tester.widget<TextField>(
      find.ancestor(
        of: find.text('FIBS password'),
        matching: find.byType(TextField),
      ),
    );
    expect(passField.obscureText, isTrue); // starts hidden

    // the reveal icon is shown; tapping it un-hides the password
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    await tester.tap(find.byIcon(Icons.visibility));
    await tester.pump();

    expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    final revealed = tester.widget<TextField>(
      find.ancestor(
        of: find.text('FIBS password'),
        matching: find.byType(TextField),
      ),
    );
    expect(revealed.obscureText, isFalse); // now visible
  });
}

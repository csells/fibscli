import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

void main() {
  // The login view is driven by the creds it was given (constructor-injected):
  // a store with a remembered username prefills the FIBS-user field with it.
  testWidgets('the login view prefills from the injected creds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'user': 'alice'});
    final prefs = await SharedPreferences.getInstance();
    final creds = SecureCredentialStore(prefs, FakeSecretStore());
    await creds.load();
    expect(creds.user, 'alice'); // remembered

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(
          fibs: FibsState.withTransport(FakeTransport()),
          creds: creds,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final userField = tester.widget<TextField>(
      find.ancestor(
        of: find.text('FIBS user'),
        matching: find.byType(TextField),
      ),
    );
    expect(userField.controller!.text, 'alice'); // from the injected store
  });
}

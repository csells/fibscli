import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

// An empty credential store -> no saved user, so the login screen shows.
Future<SecureCredentialStore> _emptyCreds() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SecureCredentialStore(prefs, FakeSecretStore());
  await store.load();
  return store;
}

void main() {
  testWidgets('tapping "Remember my password" toggles the checkbox', (
    tester,
  ) async {
    final creds = await _emptyCreds();
    final fibs = FibsState.withTransport(FakeTransport());

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    Checkbox checkbox() => tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox().value, isFalse, reason: 'starts unchecked');

    await tester.tap(find.text('Remember my password'));
    await tester.pumpAndSettle();
    expect(checkbox().value, isTrue, reason: 'a tap should check it');

    await tester.tap(find.text('Remember my password'));
    await tester.pumpAndSettle();
    expect(checkbox().value, isFalse, reason: 'a second tap unchecks it');
  });
}

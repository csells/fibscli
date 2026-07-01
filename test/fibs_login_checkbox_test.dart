import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

Future<void> _installEmptyCreds() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SecureCredentialStore(prefs, FakeSecretStore());
  await store.load();
  App.creds = store; // no saved user -> the login screen shows
}

void main() {
  testWidgets('tapping "Remember my password" toggles the checkbox', (
    tester,
  ) async {
    await _installEmptyCreds();
    App.fibs = FibsState.withTransport(FakeTransport());

    await tester.pumpWidget(MaterialApp(home: FibsPage(fibs: App.fibs)));
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

import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

// Build App.creds from a saved state and install it as the app's credential
// store, the way bootstrap() would in production.
Future<FakeSecretStore> _installCreds({
  String? user,
  String? password,
  bool remember = false,
}) async {
  final secret = FakeSecretStore();
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final store = SecureCredentialStore(prefs, secret);
  await store.load();
  if (user != null) {
    await store.save(user: user, password: password ?? '', remember: remember);
  }
  await store.load();
  App.creds = store;
  return secret;
}

void main() {
  testWidgets('auto-connects when a password was remembered', (tester) async {
    await _installCreds(user: 'joe', password: 'hunter2', remember: true);
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pumpAndSettle();

    expect(App.fibs.loggedIn, isTrue); // connected on its own
    expect(fake.sent, contains('who')); // login sends `who`
  });

  testWidgets('does NOT auto-connect without remembered creds', (tester) async {
    await _installCreds(user: 'joe', remember: false); // username only
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pumpAndSettle();

    expect(App.fibs.loggedIn, isFalse); // login screen waits for the user
  });

  testWidgets('explicit logout forgets the remembered password', (
    tester,
  ) async {
    final secret = await _installCreds(
      user: 'joe',
      password: 'hunter2',
      remember: true,
    );
    expect(secret.values, isNotEmpty); // password is stored

    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    App.fibs = fibs;
    await fibs.login(user: 'joe', pass: 'hunter2');

    await fibs.logout();

    expect(App.creds.remember, isFalse);
    expect(App.creds.password, isNull);
    expect(secret.values, isEmpty); // wiped from secure storage
    expect(fake.sent, contains('bye'));
  });
}

import 'package:fibscli/credential_store.dart';
import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';
import 'fake_transport.dart';

// Build App.creds from a saved state and install it as the app's credential
// store, the way bootstrap() would in production.
// Build a credential store from a saved state (the way bootstrap() would),
// returning both it and the backing secret store for assertions.
Future<(SecureCredentialStore, FakeSecretStore)> _installCreds({
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
  return (store, secret);
}

void main() {
  testWidgets('auto-connects when a password was remembered', (tester) async {
    final (creds, _) = await _installCreds(
      user: 'joe',
      password: 'hunter2',
      remember: true,
    );
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    expect(fibs.loggedIn, isTrue); // connected on its own
    expect(fake.sent, contains('who')); // login sends `who`
  });

  testWidgets('does NOT re-fire autologin once it has been tried', (
    tester,
  ) async {
    // One-shot guard: a connection that drops after login must not loop the
    // login<->lobby flash. With autoLoginTried already set (as it would be
    // after the first attempt), a re-shown login view does NOT autologin.
    final (creds, _) = await _installCreds(
      user: 'joe',
      password: 'hunter2',
      remember: true,
    );
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake)..markAutoLoginTried();

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    expect(fibs.loggedIn, isFalse); // did not auto-connect
    expect(fake.sent, isEmpty); // nothing sent
    expect(find.text('Connect'), findsOneWidget); // the login screen is shown
  });

  test('an explicit logout re-arms autologin', () async {
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake)..markAutoLoginTried();
    expect(fibs.autoLoginTried, isTrue);

    await fibs.login(user: 'joe', pass: 'x');
    await fibs.logout();
    expect(fibs.autoLoginTried, isFalse); // logout re-arms it
  });

  testWidgets('does NOT auto-connect without remembered creds', (tester) async {
    final (creds, _) = await _installCreds(user: 'joe'); // username only
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(
      MaterialApp(
        home: FibsPage(fibs: fibs, creds: creds),
      ),
    );
    await tester.pumpAndSettle();

    expect(fibs.loggedIn, isFalse); // login screen waits for the user
  });

  // Pure credential-flow logic (no widget pumped), so a plain test() in a real
  // async zone -- not the testWidgets FakeAsync zone, where the secure-storage
  // platform-channel reply and the stream-subscription cancel never settle
  // without a pump. The logout teardown itself is covered by fibs_logout_test.
  test('explicit logout forgets the remembered password', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final (creds, secret) = await _installCreds(
      user: 'joe',
      password: 'hunter2',
      remember: true,
    );
    expect(secret.values, isNotEmpty); // password is stored

    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    fibs.onLogout = creds.forget; // wired by bootstrap in production
    await fibs.login(user: 'joe', pass: 'hunter2');

    await fibs.logout();

    expect(creds.remember, isFalse);
    expect(creds.password, isNull);
    expect(secret.values, isEmpty); // wiped from secure storage
    expect(fake.sent, contains('bye'));
  });
}

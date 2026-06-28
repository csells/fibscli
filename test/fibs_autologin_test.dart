import 'dart:convert';

import 'package:fibscli/fibs_page.dart';
import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_transport.dart';

// _Creds stores the password base64(utf8(...))-obscured under the 'pass' key.
String _obscured(String s) => base64.encode(utf8.encode(s));

Future<void> _setPrefs(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  App.prefs.value = await SharedPreferences.getInstance();
}

void main() {
  testWidgets('auto-connects when a password was remembered', (tester) async {
    await _setPrefs({
      'remember': true,
      'user': 'joe_grammer',
      'pass': _obscured('hunter2'),
    });
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pumpAndSettle();

    // the login view should have connected on its own, using the saved creds
    expect(App.fibs.loggedIn, isTrue);
    expect(fake.sent, contains('who')); // login sends `who`
  });

  testWidgets('does NOT auto-connect without remembered creds',
      (tester) async {
    await _setPrefs({'remember': false});
    final fake = FakeTransport();
    App.fibs = FibsState.withTransport(fake);

    await tester.pumpWidget(const MaterialApp(home: FibsPage()));
    await tester.pumpAndSettle();

    expect(App.fibs.loggedIn, isFalse); // login screen waits for the user
  });

  test('explicit logout forgets the remembered password', () async {
    await _setPrefs({
      'remember': true,
      'user': 'joe_grammer',
      'pass': _obscured('hunter2'),
    });
    final fake = FakeTransport();
    final fibs = FibsState.withTransport(fake);
    await fibs.login(user: 'joe_grammer', pass: 'hunter2');

    await fibs.logout();

    final prefs = App.prefs.value!;
    expect(prefs.getBool('remember'), isFalse);
    expect(prefs.containsKey('pass'), isFalse);
    expect(fake.sent, contains('bye'));
  });
}

import 'package:fibscli/fibs_state.dart';
import 'package:fibscli/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_creds.dart';

// The gnubg session's Turnstile attestation needs a context with BOTH an
// Overlay ancestor (the challenge runs hidden in the overlay) and a Navigator
// ancestor (a challenge Cloudflare escalates is shown with showDialog). Both
// lookups walk ANCESTORS, and the router's Navigator builds its Overlay as a
// CHILD -- so neither the navigator key's own context nor a context above the
// router satisfies them. The app therefore keys a subtree INSIDE the router's
// navigator, mounted for the app's lifetime.
void main() {
  testWidgets(
    'the Turnstile context resolves both an Overlay and a Navigator',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      App.prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(App(fibs: FibsState(), creds: await fakeCreds()));
      await tester.pumpAndSettle();

      final host = App.turnstileContext;
      expect(host, isNotNull, reason: 'the host must be mounted');
      expect(
        Overlay.maybeOf(host!, rootOverlay: true),
        isNotNull,
        reason: 'the hidden challenge renders into an Overlay',
      );
      expect(
        Navigator.maybeOf(host, rootNavigator: true),
        isNotNull,
        reason: 'an escalated challenge is shown with showDialog',
      );
    },
  );
}

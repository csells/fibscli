import 'package:fibscli/credential_store.dart';
import 'package:fibscli/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A secret store whose reads always fail, to prove bootstrap degrades to the
// login screen instead of crashing the app at startup.
class _ThrowingSecretStore implements SecretStore {
  @override
  Future<String?> read(String key) async => throw StateError('keychain locked');
  @override
  Future<void> write(String key, String value) async {}
  @override
  Future<void> delete(String key) async {}
}

void main() {
  // The app loads persisted state BEFORE building any UI, so App.creds is set
  // and its remembered username is available while widgets exist. That
  // invariant is what lets the login view read remembered credentials
  // synchronously (no load-race retry dance).
  test('bootstrap loads remembered credentials before the app runs', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({'user': 'joe_grammer'});

    final deps = await bootstrap();

    expect(deps.creds.user, 'joe_grammer');
  });

  test(
    'bootstrap tolerates a failing secret store (degrades, no crash)',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'user': 'joe', 'remember': true});

      // Must not throw even though the secure-storage read blows up.
      final deps = await bootstrap(secretStore: _ThrowingSecretStore());

      expect(deps.creds.user, 'joe'); // username still recovered from prefs
      expect(
        deps.creds.password,
        isNull,
      ); // no password recovered, but app is up
    },
  );
}

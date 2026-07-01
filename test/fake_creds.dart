import 'package:fibscli/credential_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_secret_store.dart';

// A throwaway credential store for tests that need to construct a FibsPage/App
// but don't exercise the login/remember flow. Call SharedPreferences
// .setMockInitialValues(...) first if you want remembered values.
Future<SecureCredentialStore> fakeCreds() async {
  final prefs = await SharedPreferences.getInstance();
  final creds = SecureCredentialStore(prefs, FakeSecretStore());
  await creds.load();
  return creds;
}

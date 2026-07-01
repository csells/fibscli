import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _log = Logger('credential_store');

// A tiny key/value secret store — the seam over flutter_secure_storage so the
// credential store can be unit-tested with an in-memory fake (and the
// third-party dependency stays confined to one adapter).
abstract interface class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

// Platform secure storage (Keychain / Keystore / libsecret / Credential
// Manager / Web Crypto), one per supported platform.
class FlutterSecretStore implements SecretStore {
  const FlutterSecretStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

// Persisted FIBS credentials for the "remember my password" feature. The
// username (not a secret) lives in SharedPreferences; the password lives ONLY
// in platform secure storage, never in prefs. Optionally falls back to creds
// baked in at build time via --dart-define (for an automated / kiosk client).
//
// load() reads everything into memory once (call it in bootstrap, before the
// UI builds) so the login view can read creds synchronously.
class SecureCredentialStore {
  SecureCredentialStore(this._prefs, this._secret);

  // dart-define is the intended compile-time seam for kiosk/e2e autologin.
  // There is no non-environment way to read a --dart-define value, so this
  // suppression is unavoidable (not a fixable smell) and stays justified.
  // ignore: do_not_use_environment
  static const _envUser = String.fromEnvironment('fibs_uname');
  // ignore: do_not_use_environment -- see _envUser: unavoidable dart-define seam
  static const _envPass = String.fromEnvironment('fibs_pword');

  static const _userKey = 'user';
  static const _rememberKey = 'remember';
  static const _passKey = 'fibs_password';

  final SharedPreferences _prefs;
  final SecretStore _secret;

  String? _user;
  String? _password;
  var _remember = false;

  // Read persisted state into memory. Safe to call more than once.
  Future<void> load() async {
    _user = _prefs.getString(_userKey);
    _remember = _prefs.getBool(_rememberKey) ?? false;
    _password = _remember ? await _secret.read(_passKey) : null;
  }

  String? get user => _user ?? (_envUser.isEmpty ? null : _envUser);
  String? get password => _password ?? (_envPass.isEmpty ? null : _envPass);
  bool get remember => _remember;

  // Connect on our own when we have usable creds: baked-in config, or a
  // remembered username + password.
  bool get canAutologin =>
      (_envUser.isNotEmpty && _envPass.isNotEmpty) ||
      (_remember && _user != null && _password != null);

  Future<void> save({
    required String user,
    required String password,
    required bool remember,
  }) async {
    _user = user;
    _remember = remember;
    await _prefs.setString(_userKey, user);
    await _prefs.setBool(_rememberKey, remember);
    if (remember) {
      _password = password;
      await _secret.write(_passKey, password);
    } else {
      _password = null;
      await _secret.delete(_passKey);
    }
  }

  // An explicit logout: drop the remembered password so we don't auto-reconnect
  // next launch, but keep the username for convenience.
  Future<void> forget() async {
    _password = null;
    _remember = false;
    // Flip the pref FIRST: next launch gates auto-login on remember, so this
    // alone guarantees the login screen even if the secret delete below fails.
    await _prefs.setBool(_rememberKey, false);
    // Best-effort delete: a failure leaves a harmless orphaned secret (never
    // read once remember=false), so log and continue rather than throwing (a
    // throw here must not abort the logout teardown that awaits us).
    try {
      await _secret.delete(_passKey);
    } on Object catch (ex, st) {
      _log.warning(
        'secret delete failed on forget (orphaned, harmless)',
        ex,
        st,
      );
    }
  }
}

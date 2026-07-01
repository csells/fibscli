part of 'fibs_page.dart';

// The FIBS login/connect screen (autologin from remembered creds).

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  late final _user = TextEditingController(text: App.creds.user ?? '');
  late final _pass = TextEditingController(text: App.creds.password ?? '');
  var _remember = App.creds.remember;
  var _busy = false;
  var _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // creds are loaded before any UI (see bootstrap), so they're available
    // synchronously here -- connect on our own when we have usable ones.
    if (!App.fibs.loggedIn && !_busy && App.creds.canAutologin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !App.fibs.loggedIn && !_busy) unawaited(_login());
      });
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = _user.text.trim();
      await App.fibs.login(user: user, pass: _pass.text);
      await App.creds.save(
        user: user,
        password: _pass.text,
        remember: _remember,
      );
    } on Exception catch (ex, st) {
      _log.warning('FIBS login failed for "${_user.text.trim()}"', ex, st);
      if (mounted) setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Connect to FIBS')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _user,
                decoration: const InputDecoration(labelText: 'FIBS user'),
                autofillHints: const [AutofillHints.username],
              ),
              TextField(
                controller: _pass,
                decoration: InputDecoration(
                  labelText: 'FIBS password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility : Icons.visibility_off,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                obscureText: _obscure,
                onSubmitted: (_) => unawaited(_login()),
              ),
              CheckboxListTile(
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? false),
                title: const Text('Remember my password'),
                subtitle: const Text('only on a device you trust'),
                contentPadding: EdgeInsets.zero,
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _busy ? null : () => unawaited(_login()),
                  child: _busy
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Connect'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

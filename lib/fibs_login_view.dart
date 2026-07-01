part of 'fibs_page.dart';

// The FIBS login/connect screen (autologin from remembered creds).

class _LoginView extends StatefulWidget {
  const _LoginView({required this.creds});

  // The remembered-credentials store, injected by FibsPage.
  final SecureCredentialStore creds;

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  // `late` so these read widget.creds lazily on first build (widget isn't bound
  // during field construction).
  late final _user = TextEditingController(text: widget.creds.user ?? '');
  late final _pass = TextEditingController(text: widget.creds.password ?? '');
  late bool _remember = widget.creds.remember;
  var _busy = false;
  var _obscure = true;
  String? _error;
  // The active FibsState, read from FibsScope. Bound in didChangeDependencies
  // (InheritedWidget lookups aren't allowed in initState), which runs before
  // the post-frame autologin callback fires.
  late FibsState _fibs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fibs = FibsScope.of(context);
  }

  @override
  void initState() {
    super.initState();
    // creds are loaded before any UI (see bootstrap), so they're available
    // synchronously here -- connect on our own when we have usable ones. The
    // callback re-checks loggedIn/busy against the (now-bound) _fibs.
    if (widget.creds.canAutologin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_fibs.loggedIn && !_busy) unawaited(_login());
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
      await _fibs.login(user: user, pass: _pass.text);
      await widget.creds.save(
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

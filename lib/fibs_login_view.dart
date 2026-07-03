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
  late final _confirmPass = TextEditingController();
  late bool _remember = widget.creds.remember;
  var _busy = false;
  var _obscure = true;
  var _creating = false;
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
    // callback re-checks loggedIn/busy against the (now-bound) _fibs, and the
    // one-shot autoLoginTried guard stops a dropped connection from looping the
    // login<->lobby flash (see FibsState.autoLoginTried).
    if (widget.creds.canAutologin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_fibs.loggedIn && !_busy && !_fibs.autoLoginTried) {
          _fibs.markAutoLoginTried();
          unawaited(_login());
        }
      });
    }
  }

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _confirmPass.dispose();
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
      await _saveCredentials(user, _pass.text);
    } on Exception catch (ex, st) {
      _log.warning('FIBS login failed for "${_user.text.trim()}"', ex, st);
      if (mounted) setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createAccount() async {
    final user = _user.text.trim();
    final password = _pass.text;
    final validationError = _validateNewAccount(user, password);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _fibs.createAccount(user: user, pass: password);
      await _fibs.login(user: user, pass: password);
      await _saveCredentials(user, password);
    } on Exception catch (ex, st) {
      _log.warning('FIBS account creation failed for "$user"', ex, st);
      if (mounted) setState(() => _error = ex.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveCredentials(String user, String password) async {
    try {
      await widget.creds.save(
        user: user,
        password: password,
        remember: _remember,
      );
    } on Exception catch (ex, st) {
      _log.warning('credential save failed for "$user"', ex, st);
      if (!mounted) return;
      final message = _remember
          ? 'Connected, but this device could not remember the password.'
          : 'Connected, but saved credentials could not be updated.';
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String? _validateNewAccount(String user, String password) {
    if (!RegExp(r'^[A-Za-z_]+$').hasMatch(user)) {
      return 'FIBS usernames may only contain letters and underscores.';
    }
    if (password.length < 4) {
      return 'FIBS passwords must be at least 4 characters.';
    }
    if (password.contains('\n') || password.contains('\r')) {
      return 'Password may not contain newlines.';
    }
    if (password != _confirmPass.text) {
      return 'The passwords do not match.';
    }
    return null;
  }

  void _submit() => unawaited(_creating ? _createAccount() : _login());

  void _toggleMode() {
    setState(() {
      _creating = !_creating;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_creating ? 'Create FIBS account' : 'Connect to FIBS'),
      leading: IconButton(
        tooltip: 'Home',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => GoRouter.maybeOf(context)?.go('/'),
      ),
    ),
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Est. 1992 · fibs.com',
                      style: editorialKicker(color: AppColors.accent),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _creating ? 'Create account' : 'Sign in',
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _user,
                      decoration: const InputDecoration(labelText: 'FIBS user'),
                      autofillHints: const [AutofillHints.username],
                    ),
                    const SizedBox(height: 12),
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
                      onSubmitted: (_) => _submit(),
                    ),
                    if (_creating) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: _confirmPass,
                        decoration: const InputDecoration(
                          labelText: 'Confirm password',
                        ),
                        obscureText: _obscure,
                        onSubmitted: (_) => _submit(),
                      ),
                    ],
                    CheckboxListTile(
                      value: _remember,
                      onChanged: (v) => setState(() => _remember = v ?? false),
                      title: Text(
                        _creating
                            ? 'Remember this password'
                            : 'Remember my password',
                      ),
                      subtitle: const Text('only on a device you trust'),
                      contentPadding: EdgeInsets.zero,
                      activeColor: AppColors.accent,
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.accent),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.ivory,
                                ),
                              )
                            : Text(
                                _creating ? 'Create and connect' : 'Connect',
                              ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: _busy ? null : _toggleMode,
                        child: Text(
                          _creating
                              ? 'I already have a FIBS account'
                              : 'Create a FIBS account',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

import 'dart:async';

import 'package:bg_engine/bg_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_close_stub.dart' if (dart.library.html) 'app_close_web.dart';
import 'backgammon_ai_player.dart';
import 'credential_store.dart';
import 'fibs_page.dart';
import 'fibs_state.dart';
import 'game_play_page.dart';
import 'http_error_sink.dart';
import 'logging.dart';
import 'tinystate.dart';

Future<void> main() async {
  // Attach the log sink FIRST, so the FlutterError handler wired next (and any
  // framework error during binding init) actually has a subscriber. Route every
  // uncaught error -- framework and async -- to the log instead of letting it
  // vanish.
  setupLogging();
  FlutterError.onError = (details) =>
      reportError(details.exception, details.stack, context: 'flutter error');
  await runZonedGuarded(
    () async {
      final deps = await bootstrap();
      runApp(App(fibs: deps.fibs, creds: deps.creds));
    },
    (error, stack) => reportError(error, stack, context: 'uncaught zone error'),
  );
}

/// The app-level dependencies [bootstrap] builds and [main] threads into [App].
/// Constructor-injected so the UI stays decoupled from global state and tests
/// can supply their own (see `specs/architecture/decisions.md`).
class AppDeps {
  AppDeps({required this.fibs, required this.creds});
  final FibsState fibs;
  final SecureCredentialStore creds;
}

// Load persisted state before any UI builds, then hand the ready-to-use
// dependencies back to main(). The login view reads remembered credentials
// synchronously from the injected store (no load-race retry needed).
Future<AppDeps> bootstrap({
  SecretStore secretStore = const FlutterSecretStore(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  // Opt-in remote crash reporting: a production build can supply a report URL
  // via --dart-define=crash_report_url=... to observe failures off-device.
  // Nothing is sent unless a deployer sets it.
  // ignore: do_not_use_environment
  const crashReportUrl = String.fromEnvironment('crash_report_url');
  if (crashReportUrl.isNotEmpty) {
    errorSink = httpErrorSink(Uri.parse(crashReportUrl));
  }
  // Bundle the backgammon_ai engine as a selectable opponent alongside the
  // built-in pubeval (gnubg is registered separately once a URL is configured).
  AiRegistry.register(BackgammonAiPlayerFactory());
  final prefs = await SharedPreferences.getInstance();
  final creds = SecureCredentialStore(prefs, secretStore);
  try {
    await creds.load();
  } on Object catch (ex, st) {
    // Secure-storage reads can fail (locked keychain, missing libsecret, web
    // crypto hiccup) and may surface as either an Exception or an Error, so
    // catch broadly: degrade to the login screen rather than crashing at
    // startup -- the user can still type their credentials.
    Logger('bootstrap').warning('credential load failed', ex, st);
  }
  final fibs = FibsState();
  // Wire end-of-session cleanup without FibsState depending on credentials:
  // an explicit logout forgets the remembered password.
  fibs.onLogout = creds.forget;
  return AppDeps(fibs: fibs, creds: creds);
}

class App extends StatefulWidget {
  const App({required this.fibs, required this.creds, super.key});

  // The live FIBS connection and the remembered-credentials store, threaded
  // down to the views.
  final FibsState fibs;
  final SecureCredentialStore creds;

  static const title = 'Backgammon';
  // Lets the app show error SnackBars from the global error handlers, which
  // have no BuildContext of their own -- see _AppState._showError.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    // Surface uncaught errors to the user, not just the dev console:
    // reportError (from the Flutter/zone global handlers) posts to appErrors,
    // and we show it here with enough detail to act on.
    appErrors.addListener(_showError);

    // SharedPreferences are already loaded by bootstrap(); just wire up the
    // tab-close handler. On web, send FIBS a courtesy `bye` when the tab
    // closes — best-effort: a dropped connection ends the session regardless.
    onAppClose(() {
      if (widget.fibs.loggedIn) widget.fibs.send('bye');
    });
  }

  @override
  void dispose() {
    appErrors.removeListener(_showError);
    super.dispose();
  }

  void _showError() {
    final error = appErrors.value;
    if (error == null) return;
    App.scaffoldMessengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.red[900],
          duration: const Duration(seconds: 8),
          // "Copy" gives the user the full message + detail to paste into a bug
          // report -- the actionable affordance for an otherwise opaque crash.
          action: SnackBarAction(
            label: 'Copy',
            textColor: Colors.white,
            onPressed: () => unawaited(
              Clipboard.setData(ClipboardData(text: error.clipboardText)),
            ),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: App.title,
    scaffoldMessengerKey: App.scaffoldMessengerKey,
    theme: ThemeData(
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    debugShowCheckedModeBanner: false,
    // listen to the FIBS instance at the root so the app can react to
    // connection state (App owns it and hands it to the landing page)
    home: ChangeNotifierBuilder<FibsState>(
      notifier: widget.fibs,
      builder: (context, fibs, child) =>
          LandingPage(fibs: widget.fibs, creds: widget.creds),
    ),
  );
}

// Pick a mode: the local hot-seat game, or play a bot over FIBS (milestone 1:
// watch a bot game). Keeps the working local game as a first-class path.
class LandingPage extends StatelessWidget {
  const LandingPage({required this.fibs, required this.creds, super.key});

  final FibsState fibs;
  final SecureCredentialStore creds;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text(App.title)),
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 240,
            child: FilledButton.icon(
              icon: const Icon(Icons.casino),
              label: const Text('Local 2-player'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GamePlayPage()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: FilledButton.icon(
              icon: const Icon(Icons.psychology),
              label: const Text('Play vs Computer'),
              onPressed: () => unawaited(_playVsComputer(context)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 240,
            child: FilledButton.icon(
              icon: const Icon(Icons.smart_toy),
              label: const Text('Play a bot (FIBS)'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => FibsPage(fibs: fibs, creds: creds),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );

  // Let the user pick an AI engine, then start a 1-player game with the
  // computer playing player two.
  Future<void> _playVsComputer(BuildContext context) async {
    final navigator = Navigator.of(context);
    final factory = await showDialog<BgAiPlayerFactory>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choose your opponent'),
        children: [
          for (final f in AiRegistry.available)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, f),
              child: ListTile(
                title: Text(f.name),
                subtitle: f.description == null ? null : Text(f.description!),
              ),
            ),
        ],
      ),
    );
    if (factory == null) return;
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GamePlayPage(aiSide: GammonPlayer.two, ai: factory.create()),
      ),
    );
  }
}

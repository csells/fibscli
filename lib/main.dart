import 'dart:async';

import 'package:bg_engine/bg_engine.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_close_stub.dart' if (dart.library.html) 'app_close_web.dart';
import 'backgammon_ai_player.dart';
import 'credential_store.dart';
import 'fibs_page.dart';
import 'fibs_state.dart';
import 'game_play_page.dart';
import 'logging.dart';
import 'tinystate.dart';

Future<void> main() async {
  // Route every uncaught error -- framework and async -- to the log instead of
  // letting it vanish. setupLogging() (in bootstrap) sends these to dev.log.
  final log = Logger('app');
  FlutterError.onError = (details) =>
      log.severe('flutter error', details.exception, details.stack);
  await runZonedGuarded(() async {
    await bootstrap();
    runApp(const App());
  }, (error, stack) => log.severe('uncaught error', error, stack));
}

// Load persisted state before any UI builds, so App.prefs / App.creds are
// populated whenever a widget reads them. The login view relies on this to read
// remembered credentials synchronously (no load-race retry needed).
Future<void> bootstrap({
  SecretStore secretStore = const FlutterSecretStore(),
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  setupLogging();
  // Bundle the backgammon_ai engine as a selectable opponent alongside the
  // built-in pubeval (gnubg is registered separately once a URL is configured).
  AiRegistry.register(BackgammonAiPlayerFactory());
  final prefs = await SharedPreferences.getInstance();
  App.prefs.value = prefs;
  App.creds = SecureCredentialStore(prefs, secretStore);
  try {
    await App.creds.load();
  } on Object catch (ex, st) {
    // Secure-storage reads can fail (locked keychain, missing libsecret, web
    // crypto hiccup) and may surface as either an Exception or an Error, so
    // catch broadly: degrade to the login screen rather than crashing at
    // startup -- the user can still type their credentials.
    Logger('bootstrap').warning('credential load failed', ex, st);
  }
  // Wire end-of-session cleanup without FibsState depending on credentials:
  // an explicit logout forgets the remembered password.
  App.fibs.onLogout = () => App.creds.forget();
}

class App extends StatefulWidget {
  const App({super.key});

  static const title = 'Backgammon';
  // mutable so tests can swap in a fake-backed FibsState before pumping the UI
  static FibsState fibs = FibsState();
  static final prefs = ValueNotifier<SharedPreferences?>(null);
  // remembered credentials (password in platform secure storage). Set in
  // bootstrap before any UI builds; tests inject their own.
  static late SecureCredentialStore creds;

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();

    // SharedPreferences are already loaded by bootstrap(); just wire up the
    // tab-close handler. On web, send FIBS a courtesy `bye` when the tab
    // closes — best-effort: a dropped connection ends the session regardless.
    onAppClose(() {
      if (App.fibs.loggedIn) App.fibs.send('bye');
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: App.title,
    theme: ThemeData(
      primarySwatch: Colors.green,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    ),
    debugShowCheckedModeBanner: false,
    // listen to the FIBS singleton at the root so the app can react to
    // connection state (and keeps the singleton owned here)
    home: ChangeNotifierBuilder<FibsState>(
      notifier: App.fibs,
      builder: (context, fibs, child) => const LandingPage(),
    ),
  );
}

// Pick a mode: the local hot-seat game, or play a bot over FIBS (milestone 1:
// watch a bot game). Keeps the working local game as a first-class path.
class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

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
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute<void>(builder: (_) => const FibsPage())),
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

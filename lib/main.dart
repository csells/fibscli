import 'dart:async';

import 'package:bg_engine/bg_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:gnubg_service/gnubg_service.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as ul;

import 'ai_engines.dart';
import 'analytics.dart';
import 'app_close_stub.dart' if (dart.library.html) 'app_close_web.dart';
import 'credential_store.dart';
import 'error_log_dialog.dart';
import 'fibs_e2e_probe_stub.dart'
    if (dart.library.html) 'fibs_e2e_probe_web.dart';
import 'fibs_page.dart';
import 'fibs_state.dart';
import 'game_play_page.dart';
import 'http_error_sink.dart';
import 'logging.dart';
import 'theme.dart';
import 'tinystate.dart';

part 'landing_page.dart';
part 'opponent_picker.dart';
part 'privacy_page.dart';

Future<void> main() async {
  usePathUrlStrategy();
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

abstract final class AppRoutes {
  static const home = '/';
  static const local = '/local';
  static const computer = '/computer';
  static const fibs = '/fibs';
  static const fibsLogin = '/fibs/login';
  static const fibsBots = '/fibs/bots';
  static const fibsPlay = '/fibs/play';
  static const fibsWatch = '/fibs/watch';
  static const privacy = '/privacy';

  static String computerLocation({String? engine, String? level}) {
    final query = <String, String>{};
    if (engine != null && engine.isNotEmpty) query['engine'] = engine;
    if (level != null && level.isNotEmpty) query['level'] = level;
    return Uri(
      path: computer,
      queryParameters: query.isEmpty ? null : query,
    ).toString();
  }
}

const playFibsRepoUrl = 'https://github.com/csells/fibscli';
const playFibsIssuesUrl = '$playFibsRepoUrl/issues';

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
  // Opt-in product analytics. The proxy Worker `/analytics` route writes these
  // sanitized app lifecycle rows to the same Workers Analytics Engine dataset
  // used by the WebSocket bridge.
  // ignore: do_not_use_environment
  const analyticsUrl = String.fromEnvironment('analytics_url');
  // ignore: do_not_use_environment
  const analyticsEnvironment = String.fromEnvironment(
    'analytics_environment',
    defaultValue: 'dev',
  );
  // ignore: do_not_use_environment
  const appVersion = String.fromEnvironment(
    'app_version',
    defaultValue: 'local',
  );
  final analytics = analyticsUrl.isEmpty
      ? AppAnalytics.disabled()
      : AppAnalytics.http(
          Uri.parse(analyticsUrl),
          environment: analyticsEnvironment,
          version: appVersion,
        );
  analytics.track('app_start', screen: 'landing');
  // The single computer opponent: level 0 is the offline Harry Heuristic;
  // levels 1-7 are Gary Gammon, the gnubg-service's calibrated leveled
  // opponent. Gary needs a web build (the attested token mint requires a
  // browser Origin + Turnstile) AND a publishable key configured via
  // --dart-define=gnubg_publishable_key (with gnubg_turnstile_sitekey;
  // gnubg_service_url overrides the hosted default). Without those, the
  // ladder still shows levels 1-7 but only Harry is playable.
  // ignore: do_not_use_environment -- compile-time gnubg config seam
  const gnubgUrl = String.fromEnvironment('gnubg_service_url');
  // ignore: do_not_use_environment -- compile-time gnubg config seam
  const gnubgPk = String.fromEnvironment('gnubg_publishable_key');
  // ignore: do_not_use_environment -- compile-time gnubg config seam
  const gnubgSiteKey = String.fromEnvironment('gnubg_turnstile_sitekey');
  final garySessions = (kIsWeb && gnubgPk.isNotEmpty && gnubgSiteKey.isNotEmpty)
      ? () => GnubgSession(
          baseUrl: gnubgUrl.isEmpty ? null : gnubgUrl,
          publishableKey: gnubgPk,
          // Resolve a LIVE overlay-hosting context at mint time (mints can
          // happen an hour into a game); App.turnstileContext is mounted for
          // the app's lifetime.
          attest: () =>
              turnstileAttest(App.turnstileContext!, siteKey: gnubgSiteKey),
        )
      : null;
  AiRegistry.register(ComputerOpponentsFactory(sessionFor: garySessions));
  final prefs = await SharedPreferences.getInstance();
  App.prefs = prefs;
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
  final fibs = FibsState(analytics: analytics);
  // Wire end-of-session cleanup without FibsState depending on credentials:
  // an explicit logout forgets the remembered password.
  fibs.onLogout = creds.forget;
  // Auto-reconnect after an unexpected drop by re-logging-in with the
  // remembered credentials; throw when there are none so FibsState falls back
  // to the login screen.
  fibs.onReconnect = () async {
    if (!creds.canAutologin) throw StateError('no remembered credentials');
    await fibs.login(user: creds.user!, pass: creds.password!);
  };
  return AppDeps(fibs: fibs, creds: creds);
}

class App extends StatefulWidget {
  const App({
    required this.fibs,
    required this.creds,
    this.initialLocation,
    super.key,
  });

  // The live FIBS connection and the remembered-credentials store, threaded
  // down to the views.
  final FibsState fibs;
  final SecureCredentialStore creds;
  final String? initialLocation;

  static const title = 'playfibs';
  // App-wide SharedPreferences, loaded once in bootstrap() so the landing page
  // can read the remembered difficulty synchronously. Null only in tests that
  // construct App without bootstrap; callers guard for it.
  static SharedPreferences? prefs;
  // Lets the app show error SnackBars + the error-log dialog from the global
  // error handlers, which have no BuildContext of their own (see
  // _AppState._showError).
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

  // The gnubg session's Turnstile attestation needs a context with BOTH an
  // Overlay ancestor (the challenge runs hidden in the overlay) and a
  // Navigator ancestor (an escalated challenge is shown with showDialog).
  // Both lookups walk ancestors, and the router's Navigator builds its Overlay
  // as a child -- so the key hangs on a subtree INSIDE the navigator (a shell
  // wrapping every route), mounted for the app's lifetime so a mint an hour
  // into a game still lands.
  static final _turnstileHostKey = GlobalKey();

  /// A live context resolving both an [Overlay] and a [Navigator] ancestor,
  /// for the gnubg-service Turnstile attestation. Null before the first frame.
  static BuildContext? get turnstileContext => _turnstileHostKey.currentContext;

  @override
  _AppState createState() => _AppState();
}

class _AppState extends State<App> {
  late final GoRouter _router;

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
      if (widget.fibs.loggedIn) widget.fibs.courtesyDisconnect();
    });
    installFibsE2eProbe(widget.fibs);

    _router = GoRouter(
      navigatorKey: App.navigatorKey,
      initialLocation: widget.initialLocation,
      refreshListenable: widget.fibs,
      redirect: _redirect,
      routes: [
        // Every route lives under one shell, whose subtree is keyed as the
        // app-lifetime host for the gnubg Turnstile attestation context (see
        // App.turnstileContext): it sits inside the router's navigator, so it
        // resolves both the Overlay and the Navigator the challenge needs.
        ShellRoute(
          builder: (context, state, child) =>
              KeyedSubtree(key: App._turnstileHostKey, child: child),
          routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => ChangeNotifierBuilder<FibsState>(
                notifier: widget.fibs,
                builder: (context, fibs, child) => const LandingPage(),
              ),
            ),
            GoRoute(
              path: AppRoutes.local,
              builder: (context, state) => const GamePlayPage(),
            ),
            GoRoute(path: AppRoutes.computer, builder: _buildComputerRoute),
            GoRoute(
              path: AppRoutes.privacy,
              builder: (context, state) => const PrivacyPage(),
            ),
            for (final path in [
              AppRoutes.fibs,
              AppRoutes.fibsLogin,
              AppRoutes.fibsBots,
              AppRoutes.fibsPlay,
              AppRoutes.fibsWatch,
            ])
              GoRoute(path: path, builder: _buildFibsRoute),
          ],
        ),
      ],
    );
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
          // "Details" opens the retained error log so the user can read the
          // full detail and copy recent errors into a bug report -- the
          // actionable affordance for an otherwise opaque, transient crash.
          action: SnackBarAction(
            label: 'Details',
            textColor: Colors.white,
            onPressed: _showErrorLog,
          ),
        ),
      );
  }

  void _showErrorLog() {
    final context = App.navigatorKey.currentContext;
    if (context == null) return;
    unawaited(
      showDialog<void>(
        context: context,
        builder: (_) => const ErrorLogDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: App.title,
    scaffoldMessengerKey: App.scaffoldMessengerKey,
    theme: buildAppTheme(),
    debugShowCheckedModeBanner: false,
    routerConfig: _router,
  );

  String? _redirect(BuildContext context, GoRouterState state) {
    final path = state.uri.path;
    if (!path.startsWith(AppRoutes.fibs)) return null;

    final target = _fibsPathFor(widget.fibs);
    if (path == AppRoutes.fibs) return target;
    if (path == target) return null;

    final knownFibsPath = switch (path) {
      AppRoutes.fibsLogin ||
      AppRoutes.fibsBots ||
      AppRoutes.fibsPlay ||
      AppRoutes.fibsWatch => true,
      _ => false,
    };
    return knownFibsPath ? target : AppRoutes.home;
  }

  static String _fibsPathFor(FibsState fibs) {
    if (!fibs.loggedIn) return AppRoutes.fibsLogin;
    if (fibs.gameState == null) return AppRoutes.fibsBots;
    return fibs.myColor == null ? AppRoutes.fibsWatch : AppRoutes.fibsPlay;
  }

  Widget _buildFibsRoute(BuildContext context, GoRouterState state) =>
      FibsPage(fibs: widget.fibs, creds: widget.creds);

  Widget _buildComputerRoute(BuildContext context, GoRouterState state) {
    final params = state.uri.queryParameters;
    final engineName = params['engine'] ?? 'Computer';
    final factory =
        AiRegistry.byName(engineName) ??
        AiRegistry.byName('Computer') ??
        (AiRegistry.available.isEmpty ? null : AiRegistry.available.first);
    if (factory == null) {
      return const _ComputerUnavailablePage('No computer engines registered.');
    }
    final level = _validLevel(factory, params['level']);
    try {
      final ai = factory.create(level: level);
      return GamePlayPage(aiSide: GammonPlayer.two, ai: ai);
    } on Object catch (e, st) {
      Logger('main').warning('failed to create AI engine', e, st);
      return _ComputerUnavailablePage('Computer engine unavailable: $e');
    }
  }

  static String? _validLevel(BgAiPlayerFactory factory, String? requested) {
    if (factory.levels.isEmpty) return null;
    if (requested != null && factory.levels.contains(requested)) {
      return requested;
    }
    return factory.levels[factory.levels.length ~/ 2];
  }
}

class _ComputerUnavailablePage extends StatelessWidget {
  const _ComputerUnavailablePage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(App.title),
      leading: IconButton(
        tooltip: 'Home',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => GoRouter.maybeOf(context)?.go(AppRoutes.home),
      ),
    ),
    body: Center(child: Text(message)),
  );
}

import 'dart:async';

import 'package:bg_engine/bg_engine.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ai_engines.dart';
import 'app_close_stub.dart' if (dart.library.html) 'app_close_web.dart';
import 'backgammon_ai_player.dart';
import 'credential_store.dart';
import 'error_log_dialog.dart';
import 'fibs_page.dart';
import 'fibs_state.dart';
import 'game_play_page.dart';
import 'http_error_sink.dart';
import 'logging.dart';
import 'theme.dart';
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
  // Offer Gary Gammon (five levels) as the computer opponent, and the
  // gnubg-service engine too when a service URL is configured via
  // --dart-define=gnubg_service_url=... (optional gnubg_api_key). No URL -> the
  // gnubg engine is simply not listed.
  AiRegistry.register(GaryGammonFactory());
  // ignore: do_not_use_environment -- compile-time gnubg config seam
  const gnubgUrl = String.fromEnvironment('gnubg_service_url');
  // ignore: do_not_use_environment -- compile-time gnubg config seam
  const gnubgKey = String.fromEnvironment('gnubg_api_key');
  final gnubg = gnubgFactoryFor(gnubgUrl, apiKey: gnubgKey);
  if (gnubg != null) AiRegistry.register(gnubg);
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
  final fibs = FibsState();
  // Wire end-of-session cleanup without FibsState depending on credentials:
  // an explicit logout forgets the remembered password.
  fibs.onLogout = creds.forget;
  // Auto-reconnect after an unexpected drop by re-logging-in with the
  // remembered credentials; throw when there are none so FibsState falls back
  // to the login screen. FibsState owns the one-reconnect-per-session guard.
  fibs.onReconnect = () async {
    if (!creds.canAutologin) throw StateError('no remembered credentials');
    await fibs.login(user: creds.user!, pass: creds.password!);
  };
  return AppDeps(fibs: fibs, creds: creds);
}

class App extends StatefulWidget {
  const App({required this.fibs, required this.creds, super.key});

  // The live FIBS connection and the remembered-credentials store, threaded
  // down to the views.
  final FibsState fibs;
  final SecureCredentialStore creds;

  static const title = 'Backgammon';
  // App-wide SharedPreferences, loaded once in bootstrap() so the landing page
  // can read the remembered difficulty synchronously. Null only in tests that
  // construct App without bootstrap; callers guard for it.
  static SharedPreferences? prefs;
  // Lets the app show error SnackBars + the error-log dialog from the global
  // error handlers, which have no BuildContext of their own (see
  // _AppState._showError).
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
  static final navigatorKey = GlobalKey<NavigatorState>();

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
  Widget build(BuildContext context) => MaterialApp(
    title: App.title,
    scaffoldMessengerKey: App.scaffoldMessengerKey,
    navigatorKey: App.navigatorKey,
    theme: buildAppTheme(),
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

// The landing page: an editorial masthead over three "tables" — the local
// hot-seat game, Gary Gammon (with an inline difficulty selector), and the live
// FIBS bot client. Keeps the working local game as a first-class path.
class LandingPage extends StatefulWidget {
  const LandingPage({required this.fibs, required this.creds, super.key});

  final FibsState fibs;
  final SecureCredentialStore creds;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  // SharedPreferences keys remembering the last opponent + difficulty, so the
  // page reopens on the previous choice.
  static const _aiEngineKey = 'ai_engine';
  static const _aiLevelKey = 'ai_level';

  // The inline Gary Gammon difficulty (1-5), restored from prefs (default: 3).
  int _level = 3;

  @override
  void initState() {
    super.initState();
    final stored = int.tryParse(App.prefs?.getString(_aiLevelKey) ?? '');
    if (stored != null && stored >= 1 && stored <= 5) _level = stored;
  }

  // A one-line read on what a Gary Gammon difficulty means, shown under the
  // level chips so the number isn't opaque.
  static String _levelCaption(int n) => switch (n) {
    1 => 'gentle',
    2 => 'casual',
    3 => 'club player',
    4 => 'strong',
    _ => 'ruthless',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: MediaQuery.sizeOf(context).height < 640 ? 24 : 44,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _wordmark(),
                    const SizedBox(height: 40),
                    Text(
                      'The First Internet Backgammon Server · Est. 1992',
                      style: editorialKicker(color: AppColors.accent),
                    ),
                    const SizedBox(height: 18),
                    RichText(
                      text: TextSpan(
                        style: text.displayLarge,
                        children: const [
                          TextSpan(text: 'Roll, double,\n'),
                          TextSpan(
                            text: 'bear off.',
                            style: TextStyle(color: AppColors.accent),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Text(
                        'A single-player parlor and a living '
                        'window onto FIBS — the same felt the world '
                        'has played on since 1992, redrawn with a '
                        'clean modern hand.',
                        style: text.bodyLarge?.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.55,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(height: 34),
                    const Divider(color: AppColors.ink, thickness: 1.5),
                    const SizedBox(height: 30),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Expanded(
                          child: Text(
                            'Choose your table',
                            style: text.headlineMedium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text('Three ways to play', style: editorialKicker()),
                      ],
                    ),
                    const SizedBox(height: 22),
                    _ModeRow(
                      index: '01',
                      tag: 'Hot-seat',
                      title: 'Local 2-Player',
                      description:
                          'Two players, one screen, one '
                          'board. Pass the device between turns — '
                          'no server, no wait.',
                      cta: 'Play',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const GamePlayPage(),
                        ),
                      ),
                    ),
                    _ModeRow(
                      index: '02',
                      tag: 'vs. Computer',
                      title: 'Play Gary Gammon',
                      description:
                          'One opponent, five settings — '
                          'from a gentle warm-up to a neural engine '
                          'that punishes a loose blot.',
                      cta: 'Play',
                      onTap: () => unawaited(_playGaryGammon()),
                      child: _difficultyPicker(text),
                    ),
                    _ModeRow(
                      index: '03',
                      tag: 'Live · fibs.com',
                      title: 'Play a Bot on FIBS',
                      description:
                          'Log in to the real server. '
                          'Browse who is online, invite a bot, or '
                          'watch a match already in play.',
                      cta: 'Connect',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              FibsPage(fibs: widget.fibs, creds: widget.creds),
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
    );
  }

  Widget _wordmark() => Row(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Text(
        'fibscli',
        style: GoogleFonts.instrumentSerif(
          fontSize: 30,
          color: AppColors.ink,
          height: 1,
        ),
      ),
      const SizedBox(width: 10),
      Container(width: 7, height: 7, color: AppColors.accent),
    ],
  );

  // The inline 0–8 difficulty chips for Gary Gammon plus a plain-language
  // caption for the selected level.
  Widget _difficultyPicker(TextTheme text) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 14),
      Text('Difficulty', style: editorialKicker(size: 10)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var n = 1; n <= 5; n++)
            _LevelChip(
              n: n,
              selected: n == _level,
              onTap: () => setState(() => _level = n),
            ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        'Level $_level — ${_levelCaption(_level)}',
        style: text.bodySmall?.copyWith(color: AppColors.inkSoft),
      ),
      // Only when a second engine is configured (e.g. a gnubg service) is there
      // a choice to make beyond Gary Gammon's difficulty.
      if (AiRegistry.available.length > 1) ...[
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () => unawaited(_playVsComputer()),
          child: Text(
            'MORE OPPONENTS  →',
            style: editorialKicker(size: 11, color: AppColors.accent),
          ),
        ),
      ],
    ],
  );

  // Open the full engine + difficulty picker (used only when more than one AI
  // engine is registered), then start the chosen 1-player game.
  Future<void> _playVsComputer() async {
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final choice = await showDialog<AiChoice>(
      context: context,
      builder: (_) => OpponentPicker(
        factories: AiRegistry.available,
        initialEngine: App.prefs?.getString(_aiEngineKey),
        initialLevel: App.prefs?.getString(_aiLevelKey),
      ),
    );
    if (choice == null) return;
    await App.prefs?.setString(_aiEngineKey, choice.factory.name);
    if (choice.level != null) {
      await App.prefs?.setString(_aiLevelKey, choice.level!);
    }
    final BgAiPlayer ai;
    try {
      ai = choice.factory.create(level: choice.level);
    } on Object catch (e, st) {
      Logger('main').warning('failed to create AI engine', e, st);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start ${choice.factory.name}: $e')),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GamePlayPage(aiSide: GammonPlayer.two, ai: ai),
      ),
    );
  }

  // Start a 1-player game against Gary Gammon at the selected inline level,
  // remembering the choice. Building the engine can fail (e.g. a neural weight
  // load); surface it instead of throwing with no game started.
  Future<void> _playGaryGammon() async {
    final factory = AiRegistry.available.firstWhere(
      (f) => f.name == 'Gary Gammon',
      orElse: () => AiRegistry.available.first,
    );
    final level = '$_level';
    await App.prefs?.setString(_aiEngineKey, factory.name);
    await App.prefs?.setString(_aiLevelKey, level);
    if (!mounted) return;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final BgAiPlayer ai;
    try {
      ai = factory.create(level: factory.levels.isEmpty ? null : level);
    } on Object catch (e, st) {
      Logger('main').warning('failed to create AI engine', e, st);
      messenger.showSnackBar(
        SnackBar(content: Text('Could not start ${factory.name}: $e')),
      );
      return;
    }
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => GamePlayPage(aiSide: GammonPlayer.two, ai: ai),
      ),
    );
  }
}

// One editorial "table" row: a large index number, a tagged serif title with a
// description (and optional inline controls), and a call-to-action that shifts
// its arrow on hover. The whole row is the tap target.
class _ModeRow extends StatefulWidget {
  const _ModeRow({
    required this.index,
    required this.tag,
    required this.title,
    required this.description,
    required this.cta,
    required this.onTap,
    this.child,
  });

  final String index;
  final String tag;
  final String title;
  final String description;
  final String cta;
  final VoidCallback onTap;
  final Widget? child;

  @override
  State<_ModeRow> createState() => _ModeRowState();
}

class _ModeRowState extends State<_ModeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accented = _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: EdgeInsets.fromLTRB(accented ? 16 : 4, 20, 8, 20),
          decoration: BoxDecoration(
            color: accented ? AppColors.bone : Colors.transparent,
            border: const Border(top: BorderSide(color: AppColors.line)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  widget.index,
                  style: GoogleFonts.instrumentSerif(
                    fontSize: 40,
                    height: 1,
                    color: accented ? AppColors.accent : AppColors.inkFaint,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tag.toUpperCase(),
                      style: editorialKicker(size: 10),
                    ),
                    const SizedBox(height: 4),
                    Text(widget.title, style: text.headlineSmall),
                    const SizedBox(height: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Text(
                        widget.description,
                        style: text.bodyMedium?.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.5,
                        ),
                      ),
                    ),
                    if (widget.child != null) widget.child!,
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.cta.toUpperCase(),
                      style: editorialKicker(
                        size: 11,
                        color: accented ? AppColors.accent : AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedSlide(
                      duration: const Duration(milliseconds: 180),
                      offset: Offset(accented ? 0.35 : 0, 0),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: accented ? AppColors.accent : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// A single 0–8 difficulty chip: hairline-outlined, filling to ink when selected
// (vermillion at the top of the range to signal a tougher opponent).
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.n,
    required this.selected,
    required this.onTap,
  });

  final int n;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hot = selected && n >= 4;
    final fill = hot
        ? AppColors.accent
        : selected
        ? AppColors.ink
        : Colors.transparent;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? fill : AppColors.line,
            width: 1.5,
          ),
        ),
        child: Text(
          '$n',
          style: GoogleFonts.publicSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: selected ? AppColors.ivory : AppColors.inkSoft,
          ),
        ),
      ),
    );
  }
}

/// The result of [OpponentPicker]: the chosen engine [factory] and, for engines
/// that expose difficulty levels, the picked level (null for single-strength
/// engines).
class AiChoice {
  /// Creates a choice of [factory] at the given [level].
  const AiChoice(this.factory, this.level);

  /// The chosen engine factory.
  final BgAiPlayerFactory factory;

  /// The chosen difficulty level, or null when the engine has no levels.
  final String? level;
}

/// A single modal that picks an AI engine AND (for engines that offer them) a
/// difficulty level at once, pre-selected from [initialEngine]/[initialLevel]
/// so a returning user can just press OK. Pops with an [AiChoice], or null if
/// cancelled. Building the engine is left to the caller so a construction
/// failure can be surfaced.
class OpponentPicker extends StatefulWidget {
  /// Creates a picker over [factories] (typically `AiRegistry.available`),
  /// pre-selecting [initialEngine] (by name) and [initialLevel] when valid.
  const OpponentPicker({
    required this.factories,
    this.initialEngine,
    this.initialLevel,
    super.key,
  });

  /// The engines to offer.
  final List<BgAiPlayerFactory> factories;

  /// The engine name to pre-select (the last choice), if still available.
  final String? initialEngine;

  /// The difficulty level to pre-select, if valid for the selected engine.
  final String? initialLevel;

  @override
  State<OpponentPicker> createState() => _OpponentPickerState();
}

class _OpponentPickerState extends State<OpponentPicker> {
  late BgAiPlayerFactory _engine;
  String? _level;

  @override
  void initState() {
    super.initState();
    _engine = widget.factories.firstWhere(
      (f) => f.name == widget.initialEngine,
      orElse: () => widget.factories.first,
    );
    _level = _levelFor(_engine, widget.initialLevel);
  }

  // The preferred level if it is valid for [engine], else a middling default
  // (null when the engine has no levels).
  static String? _levelFor(BgAiPlayerFactory engine, String? preferred) {
    if (engine.levels.isEmpty) return null;
    if (preferred != null && engine.levels.contains(preferred)) {
      return preferred;
    }
    return engine.levels[engine.levels.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose your opponent'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // engine: a dropdown only when there's a choice; else just its name
        if (widget.factories.length > 1)
          DropdownButton<BgAiPlayerFactory>(
            value: _engine,
            isExpanded: true,
            items: [
              for (final f in widget.factories)
                DropdownMenuItem(value: f, child: Text(f.name)),
            ],
            onChanged: (f) => setState(() {
              _engine = f!;
              _level = _levelFor(f, _level);
            }),
          )
        else
          Text(_engine.name, style: Theme.of(context).textTheme.titleMedium),
        if (_engine.description != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _engine.description!,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_engine.levels.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                const Text('Difficulty: '),
                Expanded(
                  child: DropdownButton<String>(
                    value: _level,
                    isExpanded: true,
                    items: [
                      for (final l in _engine.levels)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (l) => setState(() => _level = l),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, AiChoice(_engine, _level)),
        child: const Text('OK'),
      ),
    ],
  );
}

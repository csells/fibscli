part of 'main.dart';

// The landing page: an editorial masthead over three "tables" -- the local
// hot-seat game, Gary Gammon (with an inline difficulty selector), and the live
// FIBS bot client. Keeps the working local game as a first-class path.
class LandingPage extends StatefulWidget {
  const LandingPage({this.openUrl, super.key});

  final Future<bool> Function(Uri uri)? openUrl;

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
                    _wordmark(context),
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
                      tag: 'Live · fibs.com',
                      title: 'Play a Bot on FIBS',
                      description:
                          'Log in to the real server. '
                          'Browse who is online, invite a bot, or '
                          'watch a match already in play.',
                      cta: 'Connect',
                      onTap: () => context.go(AppRoutes.fibs),
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
                      tag: 'Hot-seat',
                      title: 'Local 2-Player',
                      description:
                          'Two players, one screen, one '
                          'board. Pass the device between turns — '
                          'no server, no wait.',
                      cta: 'Play',
                      onTap: () => context.go(AppRoutes.local),
                    ),
                    const SizedBox(height: 28),
                    const Divider(color: AppColors.line),
                    const SizedBox(height: 16),
                    _PrivacyNote(
                      onDetails: () => context.go(AppRoutes.privacy),
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

  Widget _wordmark(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final brand = Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'playfibs',
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
      final links = Wrap(
        spacing: 18,
        runSpacing: 8,
        children: [
          _MastheadLink(
            label: 'ABOUT',
            onPressed: () => _openExternal(playFibsRepoUrl),
          ),
          _MastheadLink(
            label: 'FEEDBACK',
            onPressed: () => _openExternal(playFibsIssuesUrl),
          ),
        ],
      );
      if (compact) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [brand, const SizedBox(height: 12), links],
        );
      }
      return Row(children: [brand, const Spacer(), links]);
    },
  );

  Future<void> _openExternal(String url) async {
    final launcher = widget.openUrl ?? ul.launchUrl;
    await launcher(Uri.parse(url));
  }

  // The inline 1-5 difficulty chips for Gary Gammon plus a plain-language
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
    if (!mounted) return;
    context.go(
      AppRoutes.computerLocation(
        engine: choice.factory.name,
        level: choice.level,
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
    context.go(
      AppRoutes.computerLocation(
        engine: factory.name,
        level: factory.levels.isEmpty ? null : level,
      ),
    );
  }
}

class _MastheadLink extends StatelessWidget {
  const _MastheadLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      foregroundColor: AppColors.ink,
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: editorialKicker(size: 10),
    ),
    child: Text(label),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote({required this.onDetails});

  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = text.bodySmall?.copyWith(
      color: AppColors.inkFaint,
      height: 1.45,
    );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 4,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Text(
            'Analytics are aggregate app events only: screen, mode, version, '
            'platform, and counts. We never send passwords, raw FIBS traffic, '
            'chat, emails, hostnames, or game commands.',
            style: style,
          ),
        ),
        TextButton(
          onPressed: onDetails,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.ink,
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: editorialKicker(size: 10),
          ),
          child: const Text('PRIVACY DETAILS'),
        ),
      ],
    );
  }
}

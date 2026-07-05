part of 'fibs_page.dart';

// The lobby: resume saved matches, invite free bots, watch bot games.

// The bots currently in a game, each watchable.
class _BotListView extends StatefulWidget {
  const _BotListView();

  @override
  State<_BotListView> createState() => _BotListViewState();
}

class _BotListViewState extends State<_BotListView> {
  // NOTE: no "play for me" here. Letting a bot play your moves on the live FIBS
  // server is cheating, full stop. The autonomous FibsBotPlayer still exists,
  // but only as a test/e2e driver -- never wired to a button the user can press.
  _BotSortColumn _sortColumn = _BotSortColumn.rating;
  var _sortAscending = true;

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: FibsScope.of(context),
    builder: _build,
  );

  Widget _build(BuildContext context, FibsState fibs, Widget? child) {
    final free = fibs.availableBots; // invite these
    final playing = fibs.watchableBots; // watch these
    final rows = _sortedRows(free: free, playing: playing);
    final saved = fibs.savedMatchDisplays; // unfinished matches to resume
    final empty = rows.isEmpty && saved.isEmpty;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 72),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LobbyHeader(fibs: fibs),
                    const SizedBox(height: 28),
                    if (saved.isNotEmpty) ...[
                      _SavedMatchesSection(matches: saved, fibs: fibs),
                      const SizedBox(height: 30),
                    ],
                    _BotDirectory(
                      rows: rows,
                      availableCount: free.length,
                      empty: empty,
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onSort: _sortBy,
                      onInvite: (who) => _confirmInvite(context, who),
                      onWatch: fibs.watch,
                    ),
                    const SizedBox(height: 28),
                    const _LobbyNote(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<_BotDirectoryRowData> _sortedRows({
    required List<WhoInfo> free,
    required List<WhoInfo> playing,
  }) =>
      [
        for (final bot in free) _BotDirectoryRowData(bot: bot, available: true),
        for (final bot in playing)
          _BotDirectoryRowData(bot: bot, available: false),
      ]..sort((a, b) {
        final compared = _compareRows(a, b);
        return _sortAscending ? compared : -compared;
      });

  int _compareRows(_BotDirectoryRowData a, _BotDirectoryRowData b) {
    final primary = switch (_sortColumn) {
      _BotSortColumn.bot => _compareBotNames(a.bot, b.bot),
      _BotSortColumn.strength => _compareStrength(a.bot, b.bot),
      _BotSortColumn.rating => a.bot.rating.compareTo(b.bot.rating),
      _BotSortColumn.table => _tableRank(a).compareTo(_tableRank(b)),
    };
    if (primary != 0) return primary;

    return switch (_sortColumn) {
      _BotSortColumn.bot => a.bot.rating.compareTo(b.bot.rating),
      _BotSortColumn.strength => _compareBotNames(a.bot, b.bot),
      _BotSortColumn.rating => _compareBotNames(a.bot, b.bot),
      _BotSortColumn.table => _compareBotNames(a.bot, b.bot),
    };
  }

  static int _compareStrength(WhoInfo a, WhoInfo b) {
    final strength = _strength(a).compareTo(_strength(b));
    if (strength != 0) return strength;
    final rating = a.rating.compareTo(b.rating);
    if (rating != 0) return rating;
    return _compareBotNames(a, b);
  }

  static int _compareBotNames(WhoInfo a, WhoInfo b) {
    final folded = a.user.toLowerCase().compareTo(b.user.toLowerCase());
    if (folded != 0) return folded;
    return a.user.compareTo(b.user);
  }

  static int _tableRank(_BotDirectoryRowData row) => row.available ? 0 : 1;

  void _sortBy(_BotSortColumn column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  static bool _isRecommendedBot(WhoInfo who) =>
      who.user.toLowerCase().startsWith('blunderbot');

  Future<void> _confirmInvite(BuildContext context, WhoInfo bot) async {
    final fibs = FibsScope.of(context); // capture before the async gap
    // default to 1 for bots that only play 1-point matches, else a short 3-pt
    var length = bot.playsOnePointOnly ? 1 : 3;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text('Invite ${bot.user}?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Match length (points):'),
              const SizedBox(height: 8),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 1, label: Text('1')),
                  ButtonSegment(value: 3, label: Text('3')),
                  ButtonSegment(value: 5, label: Text('5')),
                  ButtonSegment(value: 7, label: Text('7')),
                ],
                selected: {length},
                onSelectionChanged: (s) =>
                    setLocalState(() => length = s.first),
              ),
              const SizedBox(height: 12),
              if (bot.playsOnePointOnly)
                Text(
                  '${bot.user} only accepts 1-point matches — a longer '
                  'match will be declined.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 8),
              const Text(
                'Please finish the game once it starts — be a good FIBS '
                'citizen.',
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Invite ($length pt)'),
            ),
          ],
        ),
      ),
    );
    if (ok ?? false) fibs.invite(bot, matchLength: length);
  }
}

enum _BotSortColumn { bot, strength, rating, table }

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.fibs});

  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Home',
              icon: const Icon(Icons.arrow_back),
              onPressed: () => GoRouter.maybeOf(context)?.go('/'),
            ),
            const SizedBox(width: 4),
            Text('playfibs', style: Theme.of(context).textTheme.headlineSmall),
            const Spacer(),
            TextButton(
              onPressed: () => unawaited(fibs.logout()),
              child: const Text('Logout'),
            ),
          ],
        ),
        const Divider(color: AppColors.ink),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 720;
            final intro = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The Directory · Live from fibs.com:4321',
                  style: editorialKicker(color: AppColors.accent),
                ),
                const SizedBox(height: 10),
                Text(
                  "Who's on\nthe server",
                  style: text.displayMedium?.copyWith(height: 0.95),
                ),
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Text(
                    'Since 1992, players and bots have logged in from around '
                    'the world. Invite a bot to a rated match, or pull up a '
                    'chair and watch.',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.55,
                    ),
                  ),
                ),
              ],
            );
            final identity = _LobbyIdentity(fibs: fibs);
            if (narrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  intro,
                  const SizedBox(height: 22),
                  Align(alignment: Alignment.centerLeft, child: identity),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(child: intro),
                const SizedBox(width: 28),
                identity,
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const Divider(color: AppColors.ink, thickness: 1.5),
      ],
    );
  }
}

class _LobbyIdentity extends StatelessWidget {
  const _LobbyIdentity({required this.fibs});

  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    final user = fibs.user ?? 'FIBS';
    final account = fibs.currentUserInfo;
    final initial = user.isEmpty ? '?' : user.characters.first.toLowerCase();
    final accountLine = account == null
        ? 'waiting for FIBS account data'
        : 'FIBS rating ${account.rating.toStringAsFixed(0)} · '
              '${account.experience} exp';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              Text(
                fibs.connected ? 'Connected to fibs.com' : 'Connecting...',
                style: editorialKicker(size: 10),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.ivory,
              child: Text(
                initial,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: AppColors.ivory),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  accountLine,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkFaint),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

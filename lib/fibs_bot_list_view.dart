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

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: FibsScope.of(context),
    builder: _build,
  );

  Widget _build(BuildContext context, FibsState fibs, Widget? child) {
    final free = _sortedBots(fibs.availableBots); // invite these
    final playing = _sortedBots(fibs.watchableBots); // watch these
    final saved = fibs.savedMatches; // unfinished matches to resume
    final empty = free.isEmpty && playing.isEmpty && saved.isEmpty;
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
                      free: free,
                      playing: playing,
                      empty: empty,
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

  static List<WhoInfo> _sortedBots(List<WhoInfo> bots) =>
      [...bots]..sort((a, b) {
        final rec = _recommendedRank(a).compareTo(_recommendedRank(b));
        if (rec != 0) return rec;
        final rating = a.rating.compareTo(b.rating);
        if (rating != 0) return rating;
        return a.user.compareTo(b.user);
      });

  static int _recommendedRank(WhoInfo who) => _isRecommendedBot(who) ? 0 : 1;

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
            Text('fibscli', style: Theme.of(context).textTheme.headlineSmall),
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
    final initial = user.isEmpty ? '?' : user.characters.first.toLowerCase();
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
                  '${fibs.whoInfos.length} visible · '
                  '${fibs.availableBots.length} ready bots',
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

class _SavedMatchesSection extends StatelessWidget {
  const _SavedMatchesSection({required this.matches, required this.fibs});

  final List<String> matches;
  final FibsState fibs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DirectoryToolbar(
        title: 'Resume saved matches',
        meta: '${matches.length} unfinished',
      ),
      const SizedBox(height: 12),
      for (final opponent in matches)
        _SavedMatchRow(
          opponent: opponent,
          onTap: () => fibs.resumeSavedMatch(opponent),
        ),
    ],
  );
}

class _SavedMatchRow extends StatelessWidget {
  const _SavedMatchRow({required this.opponent, required this.onTap});

  final String opponent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const Icon(Icons.restore, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(opponent, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  'Unfinished match · tap to resume',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
          const _SmallAction(label: 'Resume', filled: true),
        ],
      ),
    ),
  );
}

class _BotDirectory extends StatelessWidget {
  const _BotDirectory({
    required this.free,
    required this.playing,
    required this.empty,
    required this.onInvite,
    required this.onWatch,
  });

  final List<WhoInfo> free;
  final List<WhoInfo> playing;
  final bool empty;
  final ValueChanged<WhoInfo> onInvite;
  final ValueChanged<WhoInfo> onWatch;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final bot in free) _BotDirectoryRowData(bot: bot, available: true),
      for (final bot in playing)
        _BotDirectoryRowData(bot: bot, available: false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DirectoryToolbar(
          title: 'Bots online',
          meta: '${free.length} available · Rating · FIBS scale',
        ),
        const SizedBox(height: 16),
        if (empty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 80),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.ink, width: 1.5),
                bottom: BorderSide(color: AppColors.line),
              ),
            ),
            child: Text(
              'No bots online yet.\nWaiting for the who-list...',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.inkSoft,
                height: 1.45,
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 820;
              if (narrow) {
                return Column(
                  children: [
                    for (var i = 0; i < rows.length; i++)
                      _BotCard(
                        index: i + 1,
                        row: rows[i],
                        onInvite: onInvite,
                        onWatch: onWatch,
                      ),
                  ],
                );
              }
              return Column(
                children: [
                  const _BotTableHeader(),
                  for (var i = 0; i < rows.length; i++)
                    _BotTableRow(
                      index: i + 1,
                      row: rows[i],
                      onInvite: onInvite,
                      onWatch: onWatch,
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _DirectoryToolbar extends StatelessWidget {
  const _DirectoryToolbar({required this.title, required this.meta});

  final String title;
  final String meta;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.baseline,
    textBaseline: TextBaseline.alphabetic,
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
      ),
      const SizedBox(width: 16),
      Flexible(child: Text(meta.toUpperCase(), style: editorialKicker())),
    ],
  );
}

class _BotDirectoryRowData {
  const _BotDirectoryRowData({required this.bot, required this.available});

  final WhoInfo bot;
  final bool available;
}

class _BotTableHeader extends StatelessWidget {
  const _BotTableHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.ink, width: 1.5)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 54),
        Expanded(flex: 5, child: Text('BOT', style: editorialKicker(size: 10))),
        Expanded(
          flex: 2,
          child: Center(
            child: Text('STRENGTH', style: editorialKicker(size: 10)),
          ),
        ),
        Expanded(
          flex: 2,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('RATING', style: editorialKicker(size: 10)),
          ),
        ),
        SizedBox(
          width: 220,
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('TABLE', style: editorialKicker(size: 10)),
          ),
        ),
      ],
    ),
  );
}

class _BotTableRow extends StatelessWidget {
  const _BotTableRow({
    required this.index,
    required this.row,
    required this.onInvite,
    required this.onWatch,
  });

  final int index;
  final _BotDirectoryRowData row;
  final ValueChanged<WhoInfo> onInvite;
  final ValueChanged<WhoInfo> onWatch;

  @override
  Widget build(BuildContext context) {
    final bot = row.bot;
    return InkWell(
      onTap: row.available ? () => onInvite(bot) : () => onWatch(bot),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Row(
          children: [
            SizedBox(width: 54, child: _BotIndex(index)),
            Expanded(
              flex: 5,
              child: _BotIdentity(bot: bot, busy: !row.available),
            ),
            Expanded(
              flex: 2,
              child: Center(child: _StrengthBars(strength: _strength(bot))),
            ),
            Expanded(flex: 2, child: _RatingCell(bot)),
            SizedBox(
              width: 220,
              child: _BotActions(
                bot: bot,
                available: row.available,
                onInvite: onInvite,
                onWatch: onWatch,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotCard extends StatelessWidget {
  const _BotCard({
    required this.index,
    required this.row,
    required this.onInvite,
    required this.onWatch,
  });

  final int index;
  final _BotDirectoryRowData row;
  final ValueChanged<WhoInfo> onInvite;
  final ValueChanged<WhoInfo> onWatch;

  @override
  Widget build(BuildContext context) {
    final bot = row.bot;
    return InkWell(
      onTap: row.available ? () => onInvite(bot) : () => onWatch(bot),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.line)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 48, child: _BotIndex(index)),
                Expanded(
                  child: _BotIdentity(bot: bot, busy: !row.available),
                ),
                const SizedBox(width: 12),
                _RatingCell(bot),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StrengthBars(strength: _strength(bot)),
                const Spacer(),
                _BotActions(
                  bot: bot,
                  available: row.available,
                  onInvite: onInvite,
                  onWatch: onWatch,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotIndex extends StatelessWidget {
  const _BotIndex(this.index);

  final int index;

  @override
  Widget build(BuildContext context) => Text(
    index.toString().padLeft(2, '0'),
    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
      color: AppColors.inkFaint,
      fontStyle: FontStyle.italic,
    ),
  );
}

class _BotIdentity extends StatelessWidget {
  const _BotIdentity({required this.bot, required this.busy});

  final WhoInfo bot;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final recommended = _BotListViewState._isRecommendedBot(bot);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusDot(busy: busy),
            Text(bot.user, style: Theme.of(context).textTheme.headlineSmall),
            if (recommended) const _RecommendedBadge(),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          _botSubtitle(bot, busy: busy),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.inkSoft,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: busy ? AppColors.inkFaint : const Color(0xFF3E9B5F),
      shape: BoxShape.circle,
    ),
  );
}

class _RecommendedBadge extends StatelessWidget {
  const _RecommendedBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: AppColors.accent,
      borderRadius: BorderRadius.circular(2),
    ),
    child: Text(
      'RECOMMENDED',
      style: editorialKicker(size: 9, color: AppColors.ivory),
    ),
  );
}

class _StrengthBars extends StatelessWidget {
  const _StrengthBars({required this.strength});

  final int strength;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 1; i <= 5; i++)
        Container(
          width: 6,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: i <= strength
                ? (strength <= 2 ? const Color(0xFF3E9B5F) : AppColors.ink)
                : AppColors.line,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
    ],
  );
}

class _RatingCell extends StatelessWidget {
  const _RatingCell(this.bot);

  final WhoInfo bot;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Text(
        bot.rating.toStringAsFixed(0),
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        _ratingLabel(bot.rating).toUpperCase(),
        style: editorialKicker(size: 9),
      ),
    ],
  );
}

class _BotActions extends StatelessWidget {
  const _BotActions({
    required this.bot,
    required this.available,
    required this.onInvite,
    required this.onWatch,
  });

  final WhoInfo bot;
  final bool available;
  final ValueChanged<WhoInfo> onInvite;
  final ValueChanged<WhoInfo> onWatch;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerRight,
    child: available
        ? _SmallAction(
            key: ValueKey('invite-${bot.user}'),
            label: 'Invite',
            filled: true,
            highlighted: _BotListViewState._isRecommendedBot(bot),
            onTap: () => onInvite(bot),
          )
        : _SmallAction(
            key: ValueKey('watch-${bot.user}'),
            label: 'Watch',
            filled: false,
            onTap: () => onWatch(bot),
          ),
  );
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.label,
    required this.filled,
    super.key,
    this.highlighted = false,
    this.onTap,
  });

  final String label;
  final bool filled;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final background = filled
        ? highlighted
              ? AppColors.accent
              : AppColors.ink
        : AppColors.ivory;
    final foreground = filled ? AppColors.ivory : AppColors.ink;
    return Opacity(
      opacity: active ? 1 : 0.38,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3),
          side: BorderSide(
            color: filled
                ? highlighted
                      ? AppColors.accent
                      : AppColors.ink
                : AppColors.ink,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Text(
              label.toUpperCase(),
              style: editorialKicker(size: 10, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

class _LobbyNote extends StatelessWidget {
  const _LobbyNote();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(top: 20),
    decoration: const BoxDecoration(
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '“',
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: AppColors.accent,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            'A gentle citizen wins gently. For a rated match you actually '
            'want to win, invite a BlunderBot. The stronger engines sit at '
            '1800-2100+ and mostly hand out rated losses. Finish every match '
            'you start; never abandon an opponent mid-game.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.inkSoft,
              height: 1.55,
            ),
          ),
        ),
      ],
    ),
  );
}

String _botSubtitle(WhoInfo bot, {required bool busy}) {
  if (busy) return 'Currently playing ${bot.opponent}';
  if (_BotListViewState._isRecommendedBot(bot)) {
    return 'BlunderBot family · best for a rated win';
  }
  if (bot.playsOnePointOnly) return '1-point specialist';
  if (bot.client.isNotEmpty) return bot.client;
  return 'FIBS bot';
}

int _strength(WhoInfo bot) {
  final rating = bot.rating;
  if (rating < 1600) return 1;
  if (rating < 1800) return 2;
  if (rating < 1950) return 3;
  if (rating < 2100) return 4;
  return 5;
}

String _ratingLabel(double rating) {
  if (rating < 1600) return 'beginner';
  if (rating < 1800) return 'casual';
  if (rating < 1950) return 'strong';
  if (rating < 2100) return 'expert';
  return 'master';
}

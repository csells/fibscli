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
    final free = fibs.availableBots; // invite these
    final playing = fibs.watchableBots; // watch these
    final saved = fibs.savedMatches; // unfinished matches to resume
    final empty = free.isEmpty && playing.isEmpty && saved.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bots'),
        actions: [
          TextButton(
            onPressed: () => unawaited(fibs.logout()),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: empty
          ? const Center(
              child: Text(
                'No bots online yet.\nWaiting for the who-list…',
                textAlign: TextAlign.center,
              ),
            )
          : ListView(
              children: [
                // A resume request or "type join" prompt is AUTO-joined in
                // FibsState (see _applyAndAutoJoin), so there's no manual Join
                // tile here -- an outstanding game just drops us back in.
                //
                // Unfinished matches we can pick back up when the opponent
                // isn't online to auto-resume (re-inviting reloads the saved
                // game). Finishing saved matches is good manners.
                if (saved.isNotEmpty)
                  const _SectionHeader('Resume a saved match'),
                for (final opponent in saved)
                  ListTile(
                    leading: const Icon(Icons.restore),
                    title: Text(opponent),
                    subtitle: const Text('unfinished match — tap to resume'),
                    trailing: const Icon(Icons.play_arrow),
                    onTap: () => fibs.resumeSavedMatch(opponent),
                  ),
                if (free.isNotEmpty)
                  const _SectionHeader('Play a bot (tap to invite)'),
                for (final who in free)
                  ListTile(
                    leading: const Icon(Icons.smart_toy),
                    title: Text(who.user),
                    subtitle: Text(
                      'rating ${who.rating.toStringAsFixed(0)} · '
                      '${who.experience} exp · '
                      '${who.client.isEmpty ? 'no client' : who.client}'
                      '${who.playsOnePointOnly ? ' · 1-point only' : ''}',
                    ),
                    trailing: const Icon(Icons.sports_esports),
                    onTap: () => _confirmInvite(context, who),
                  ),
                if (playing.isNotEmpty)
                  const _SectionHeader('Watch a bot game'),
                for (final who in playing)
                  ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: Text(who.user),
                    subtitle: Text(
                      'playing ${who.opponent} · rating '
                      '${who.rating.toStringAsFixed(0)}',
                    ),
                    trailing: const Icon(Icons.visibility),
                    onTap: () => fibs.watch(who),
                  ),
              ],
            ),
    );
  }

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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
    child: Row(
      children: [
        Text(
          text.toUpperCase(),
          style: editorialKicker(color: AppColors.accent),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Divider(color: AppColors.line)),
      ],
    ),
  );
}

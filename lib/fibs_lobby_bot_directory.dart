part of 'fibs_page.dart';

class _BotDirectory extends StatelessWidget {
  const _BotDirectory({
    required this.rows,
    required this.availableCount,
    required this.empty,
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
    required this.onInvite,
    required this.onWatch,
  });

  final List<_BotDirectoryRowData> rows;
  final int availableCount;
  final bool empty;
  final _BotSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_BotSortColumn> onSort;
  final ValueChanged<WhoInfo> onInvite;
  final ValueChanged<WhoInfo> onWatch;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _DirectoryToolbar(
        title: 'Bots online',
        meta: '$availableCount available · Rating · FIBS scale',
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
                _BotTableHeader(
                  sortColumn: sortColumn,
                  sortAscending: sortAscending,
                  onSort: onSort,
                ),
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
  const _BotTableHeader({
    required this.sortColumn,
    required this.sortAscending,
    required this.onSort,
  });

  final _BotSortColumn sortColumn;
  final bool sortAscending;
  final ValueChanged<_BotSortColumn> onSort;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.ink, width: 1.5)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 54),
        Expanded(
          flex: 5,
          child: _SortHeaderCell(
            label: 'BOT',
            column: _BotSortColumn.bot,
            activeColumn: sortColumn,
            ascending: sortAscending,
            onSort: onSort,
          ),
        ),
        Expanded(
          flex: 2,
          child: _SortHeaderCell(
            label: 'STRENGTH',
            column: _BotSortColumn.strength,
            activeColumn: sortColumn,
            ascending: sortAscending,
            alignment: Alignment.center,
            onSort: onSort,
          ),
        ),
        Expanded(
          flex: 2,
          child: _SortHeaderCell(
            label: 'RATING',
            column: _BotSortColumn.rating,
            activeColumn: sortColumn,
            ascending: sortAscending,
            alignment: Alignment.centerRight,
            onSort: onSort,
          ),
        ),
        SizedBox(
          width: 220,
          child: _SortHeaderCell(
            label: 'TABLE',
            column: _BotSortColumn.table,
            activeColumn: sortColumn,
            ascending: sortAscending,
            alignment: Alignment.centerRight,
            onSort: onSort,
          ),
        ),
      ],
    ),
  );
}

class _SortHeaderCell extends StatelessWidget {
  const _SortHeaderCell({
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.ascending,
    required this.onSort,
    this.alignment = Alignment.centerLeft,
  });

  final String label;
  final _BotSortColumn column;
  final _BotSortColumn activeColumn;
  final bool ascending;
  final Alignment alignment;
  final ValueChanged<_BotSortColumn> onSort;

  @override
  Widget build(BuildContext context) {
    final active = column == activeColumn;
    final color = active ? AppColors.ink : AppColors.inkFaint;
    return Align(
      alignment: alignment,
      child: Tooltip(
        message: 'Sort by ${label.toLowerCase()}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(3),
            onTap: () => onSort(column),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: editorialKicker(size: 10, color: color)),
                  if (active) ...[
                    const SizedBox(width: 5),
                    Icon(
                      ascending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 12,
                      color: color,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
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

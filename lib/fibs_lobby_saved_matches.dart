part of 'fibs_page.dart';

class _SavedMatchesSection extends StatelessWidget {
  const _SavedMatchesSection({required this.matches, required this.fibs});

  final List<SavedMatchDisplay> matches;
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
      for (final match in matches)
        _SavedMatchRow(
          display: match,
          onTap: () => fibs.resumeSavedMatch(match.match.opponent),
        ),
    ],
  );
}

class _SavedMatchRow extends StatelessWidget {
  const _SavedMatchRow({required this.display, required this.onTap});

  final SavedMatchDisplay display;
  final VoidCallback onTap;

  SavedMatchInfo get match => display.match;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: display.canResume ? onTap : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 720;
          final main = Row(
            children: [
              Icon(
                _savedMatchIcon(display.state),
                size: 20,
                color: _savedMatchIconColor(display.state),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.opponent,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      display.subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
            ],
          );
          final note = display.note == null
              ? null
              : Text(
                  display.note!,
                  textAlign: compact ? TextAlign.left : TextAlign.center,
                  style: editorialKicker(size: 10),
                );
          final action = _SmallAction(
            key: ValueKey('resume-${match.opponent}'),
            label: display.actionLabel,
            filled: display.canResume,
            onTap: display.canResume ? onTap : null,
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                main,
                if (note != null) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 34),
                    child: note,
                  ),
                ],
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          final leftWidth = (constraints.maxWidth * 0.34).clamp(320.0, 460.0);
          return Row(
            children: [
              SizedBox(width: leftWidth, child: main),
              const SizedBox(width: 18),
              Expanded(
                child: note == null
                    ? const SizedBox.shrink()
                    : Center(child: note),
              ),
              const SizedBox(width: 18),
              SizedBox(
                width: 128,
                child: Align(alignment: Alignment.centerRight, child: action),
              ),
            ],
          );
        },
      ),
    ),
  );

  IconData _savedMatchIcon(SavedMatchDisplayState state) => switch (state) {
    SavedMatchDisplayState.delayed ||
    SavedMatchDisplayState.busy ||
    SavedMatchDisplayState.checking => Icons.schedule,
    SavedMatchDisplayState.pending => Icons.hourglass_top,
    SavedMatchDisplayState.requested ||
    SavedMatchDisplayState.activeWithUser ||
    SavedMatchDisplayState.ready => Icons.play_circle_outline,
    SavedMatchDisplayState.unavailable ||
    SavedMatchDisplayState.saved => Icons.restore,
  };

  Color _savedMatchIconColor(SavedMatchDisplayState state) => switch (state) {
    SavedMatchDisplayState.requested ||
    SavedMatchDisplayState.activeWithUser ||
    SavedMatchDisplayState.ready => AppColors.ink,
    _ => AppColors.inkFaint,
  };
}

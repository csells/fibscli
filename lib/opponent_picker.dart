part of 'main.dart';

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

// A single difficulty chip: hairline-outlined, filling to ink when selected
// (vermillion at the top of the range to signal a tougher opponent). A
// disabled chip -- a level this build cannot play -- renders faint and inert.
class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.n,
    required this.selected,
    required this.onTap,
    this.enabled = true,
  });

  final int n;
  final bool selected;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final hot = selected && n >= 6;
    final fill = hot
        ? AppColors.accent
        : selected
        ? AppColors.ink
        : Colors.transparent;
    return GestureDetector(
      // A disabled chip still claims the tap (no-op) so it cannot fall
      // through to the row's own tap target and start a game.
      onTap: enabled ? onTap : () {},
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected
                ? fill
                : enabled
                ? AppColors.line
                : AppColors.lineFaint,
            width: 1.5,
          ),
        ),
        child: Text(
          '$n',
          style: GoogleFonts.publicSans(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: selected
                ? AppColors.ivory
                : enabled
                ? AppColors.inkSoft
                : AppColors.inkFaint,
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

  // The preferred level if it is valid AND playable for [engine], else a
  // middling playable default (null when the engine has no levels).
  static String? _levelFor(BgAiPlayerFactory engine, String? preferred) {
    final playable = engine.levels.where(engine.isLevelEnabled).toList();
    if (playable.isEmpty) return null;
    if (preferred != null && playable.contains(preferred)) return preferred;
    return playable[playable.length ~/ 2];
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Choose your opponent'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                        if (_engine.isLevelEnabled(l))
                          DropdownMenuItem(
                            value: l,
                            child: Text(_engine.levelLabel(l)),
                          ),
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

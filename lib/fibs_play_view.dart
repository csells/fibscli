part of 'fibs_page.dart';

// The tap-to-move play view (drives FibsPlayController) + controls.

const _fibsFooterHeight = 76.0;

// Playing a bot via tap-to-move: tap a source pip, then a destination; the
// server validates (milestone 2).
class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  // Read from FibsScope in didChangeDependencies.
  late FibsState _fibs;
  FibsPlayController? _controller;
  // Board orientation. FIBS already hands us the board from our own perspective
  // (home lower-right), so we never auto-flip; the flip button just toggles
  // this preference (pure view state, so it stays on the widget).
  bool _reversed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fibs = FibsScope.of(context);
    _controller ??= FibsPlayController(fibs: _fibs);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<FibsPlayController>(
        notifier: _controller!,
        builder: (context, controller, child) => _buildBoard(controller),
      );

  Widget _buildBoard(FibsPlayController controller) {
    // create/drop the working turn (also covers entering the view already on
    // our move, when no notification fires)
    controller.syncTurn();

    final fibs = _fibs;
    final opponent = fibs.board!.opponentNameFor(fibs.user);

    return Scaffold(
      appBar: AppBar(
        title: Text('vs $opponent'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'leave',
          onPressed: _leaveGame,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.outlined_flag),
            tooltip: 'resign',
            onPressed: () => _confirmResign(context),
          ),
          // in a pure race, fast-forward your bear-off (no decisions matter)
          if (controller.canAutoBearOff)
            IconButton(
              icon: const Icon(Icons.fast_forward),
              tooltip: 'auto bear-off',
              onPressed: controller.autoBearOff,
            ),
          // always visible so it's discoverable; disabled until you've moved
          IconButton(
            icon: const Icon(Icons.undo),
            tooltip: 'undo last move',
            onPressed: controller.canUndo ? controller.undoMove : null,
          ),
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'flip board',
            onPressed: () => setState(() => _reversed = !_reversed),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _BoardStage(
                fibs: fibs,
                controller: controller,
                reversed: _reversed,
              ),
            ),
          ),
          if (_hasBoardAction(fibs))
            const _FooterSpacer()
          else
            _StatusBar(
              fibs: fibs,
              opponent: opponent,
              turnComplete: controller.turnComplete,
              onLeave: _leaveGame,
              onResign: () => _confirmResign(context),
            ),
        ],
      ),
    );
  }

  void _leaveGame() => _fibs.leaveGame();

  Future<void> _confirmResign(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign this game?'),
        content: const Text(
          'This gives the game to your opponent. Use the back arrow if you '
          'want to leave the match instead.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (ok ?? false) _fibs.resign();
  }
}

class _FooterSpacer extends StatelessWidget {
  const _FooterSpacer();

  @override
  Widget build(BuildContext context) => const SizedBox(
    height: _fibsFooterHeight,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.ink)),
      ),
    ),
  );
}

class _BoardStage extends StatelessWidget {
  const _BoardStage({
    required this.fibs,
    required this.controller,
    required this.reversed,
  });

  static const _boardSize = Size(574, 420);
  static const _boardAspect = 574 / 420;

  final FibsState fibs;
  final FibsPlayController controller;
  final bool reversed;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = Size(
        constraints.maxWidth.isFinite ? constraints.maxWidth : _boardSize.width,
        constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _boardSize.height,
      );
      final board = _fittedBoardRect(size);
      final panelWidth = (board.width * 0.32).clamp(176.0, 260.0);
      final panelLeft = board.left + board.width * 0.055;

      return Stack(
        children: [
          // While it's our turn we edit a LOCAL working board and submit on a
          // dice tap; otherwise we just render the live board.
          Positioned.fill(
            child: GameBoard(
              game: controller.displayGame,
              animator: controller.animator,
              legalMoves: controller.legalMoves,
              interactive: controller.interactive,
              reversed: reversed,
              onMove: controller.applyLocalMove,
              onTapDice: controller.submitTurn,
            ),
          ),
          if (_hasBoardAction(fibs))
            Positioned(
              left: panelLeft,
              top: board.top,
              width: panelWidth,
              height: board.height,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _BoardActionPanel(fibs: fibs),
              ),
            ),
        ],
      );
    },
  );

  static Rect _fittedBoardRect(Size size) {
    var width = size.width;
    var height = width / _boardAspect;
    if (height > size.height) {
      height = size.height;
      width = height * _boardAspect;
    }
    final left = (size.width - width) / 2;
    final top = (size.height - height) / 2;
    return Rect.fromLTWH(left, top, width, height);
  }
}

bool _hasBoardAction(FibsState fibs) =>
    fibs.isGameOver || fibs.doubleOffered || fibs.canRoll;

class _BoardActionPanel extends StatelessWidget {
  const _BoardActionPanel({required this.fibs});
  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    final content = fibs.isGameOver
        ? _GameOverContent(fibs: fibs)
        : _ActionContent(fibs: fibs);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.ivory,
        border: Border.all(color: AppColors.ink),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: content,
      ),
    );
  }
}

class _GameOverContent extends StatelessWidget {
  const _GameOverContent({required this.fibs});
  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    final won = fibs.didIWin;
    final label = won == null
        ? 'Game over'
        : won
        ? 'You win!'
        : 'You lose';
    final result = fibs.gameResultMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: won ?? false ? AppColors.accent : AppColors.ink,
          ),
        ),
        if (result != null) ...[
          const SizedBox(height: 4),
          Text(
            result,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: fibs.returnToLobby,
          child: const Text('Back to lobby'),
        ),
      ],
    );
  }
}

class _ActionContent extends StatelessWidget {
  const _ActionContent({required this.fibs});
  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    if (fibs.doubleOffered) {
      final status = Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(color: AppColors.ink);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Opponent doubled!', style: status),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: fibs.acceptDouble,
                child: const Text('Take'),
              ),
              OutlinedButton(
                onPressed: fibs.rejectDouble,
                child: const Text('Pass'),
              ),
            ],
          ),
        ],
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          onPressed: fibs.roll,
          icon: const Icon(Icons.casino, size: 18),
          label: const Text('Roll'),
        ),
        if (fibs.canOfferDouble)
          OutlinedButton(
            onPressed: fibs.offerDouble,
            child: const Text('Double'),
          ),
      ],
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.fibs,
    required this.opponent,
    required this.onLeave,
    required this.onResign,
    this.turnComplete = false,
  });

  final FibsState fibs;
  final String opponent;
  final VoidCallback onLeave;
  final VoidCallback onResign;
  // our turn is fully played -> prompt to tap the dice to submit it
  final bool turnComplete;

  @override
  Widget build(BuildContext context) {
    final status = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(color: AppColors.inkSoft);
    final text = fibs.canMoveNow
        ? turnComplete
              ? 'Tap the dice to submit your move'
              : 'Your move — make your moves, then tap the dice '
                    '(dice ${fibs.activeDice.join(", ")})'
        : _waitingText();

    final waiting = !fibs.canMoveNow;
    return SizedBox(
      height: _fibsFooterHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.ivory,
          border: Border(top: BorderSide(color: AppColors.ink)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: status,
                ),
              ),
              if (waiting) ...[
                const SizedBox(width: 12),
                OutlinedButton(onPressed: onLeave, child: const Text('Leave')),
                const SizedBox(width: 12),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accent,
                    side: const BorderSide(color: AppColors.accent),
                  ),
                  onPressed: onResign,
                  child: const Text('Resign'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _waitingText() {
    final delay = fibs.resumeDelayFor(opponent);
    if (delay != null) return 'Waiting for $opponent — ${delay.detail}.';
    return 'Waiting for $opponent…';
  }
}

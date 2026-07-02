part of 'fibs_page.dart';

// The read-only spectator view of a watched bot game.

class _WatchView extends StatefulWidget {
  const _WatchView();

  @override
  State<_WatchView> createState() => _WatchViewState();
}

class _WatchViewState extends State<_WatchView> {
  late FibsState _fibs;
  FibsPlayController? _controller;
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
    final fibs = _fibs;
    final board = fibs.board;
    final game = fibs.gameState;
    if (board == null || game == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Watching'),
          leading: IconButton(
            tooltip: 'Back to lobby',
            icon: const Icon(Icons.arrow_back),
            onPressed: fibs.stopWatching,
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Watching ${board.player1Name} vs ${board.player2Name}'),
        leading: IconButton(
          tooltip: 'Back to lobby',
          icon: const Icon(Icons.arrow_back),
          onPressed: fibs.stopWatching,
        ),
        actions: [
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
              child: GameBoard(
                game: controller.displayGame,
                animator: controller.animator,
                reversed: _reversed,
              ),
            ),
          ),
          _WatchStatusBar(fibs: fibs),
        ],
      ),
    );
  }
}

class _WatchStatusBar extends StatelessWidget {
  const _WatchStatusBar({required this.fibs});

  final FibsState fibs;

  @override
  Widget build(BuildContext context) {
    final board = fibs.board!;
    final text = Theme.of(context).textTheme;
    final player1Color = board.player1Color == -1
        ? GammonPlayer.one
        : GammonPlayer.two;
    final player2Color = player1Color == GammonPlayer.one
        ? GammonPlayer.two
        : GammonPlayer.one;
    final position = board.position;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.ink)),
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Watching', style: editorialKicker(size: 10)),
                Text(
                  '${board.player1Name} vs ${board.player2Name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall?.copyWith(fontSize: 22),
                ),
              ],
            ),
          ),
          _WatchMetric(label: 'Turn', value: _watchTurnStatus(board, fibs)),
          _WatchMetric(
            label: '${board.player1Name} pips',
            value: '${position.pipCountFor(player1Color)}',
          ),
          _WatchMetric(
            label: '${board.player2Name} pips',
            value: '${position.pipCountFor(player2Color)}',
          ),
          _WatchMetric(label: 'Cube', value: '${board.cube}'),
        ],
      ),
    );
  }
}

class _WatchMetric extends StatelessWidget {
  const _WatchMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 220),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: editorialKicker(size: 10, color: AppColors.inkSoft),
        ),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    ),
  );
}

String _watchTurnStatus(FibsBoard board, FibsState fibs) {
  if (board.isGameOver) return 'Game over';
  final turnName = board.turnColor == board.player1Color
      ? board.player1Name
      : board.player2Name;
  final dice = fibs.activeDice;
  if (dice.isEmpty) return '$turnName to roll';
  return '$turnName to move · dice ${dice.join(', ')}';
}

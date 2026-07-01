part of 'fibs_page.dart';

// The tap-to-move play view (drives FibsPlayController) + controls.

// Playing a bot via tap-to-move: tap a source pip, then a destination; the
// server validates (milestone 2).
class _PlayView extends StatefulWidget {
  const _PlayView();

  @override
  State<_PlayView> createState() => _PlayViewState();
}

class _PlayViewState extends State<_PlayView> {
  late final _controller = FibsPlayController();
  // Board orientation. FIBS already hands us the board from our own perspective
  // (home lower-right), so we never auto-flip; the flip button just toggles
  // this preference (pure view state, so it stays on the widget).
  bool _reversed = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierBuilder<FibsPlayController>(
        notifier: _controller,
        builder: (context, controller, child) => _buildBoard(controller),
      );

  Widget _buildBoard(FibsPlayController controller) {
    // create/drop the working turn (also covers entering the view already on
    // our move, when no notification fires)
    controller.syncTurn();

    final fibs = App.fibs;
    // FIBS names us player1 "You" in our own game; the opponent is the other
    final b = fibs.board!;
    final p1IsUs = b.player1Name == 'You' || b.player1Name == fibs.user;
    final opponent = p1IsUs ? b.player2Name : b.player1Name;

    return Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: Text('vs $opponent'),
        leading: IconButton(
          icon: const Icon(Icons.flag),
          tooltip: 'resign / leave',
          onPressed: () => _confirmLeave(context),
        ),
        actions: [
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
              // While it's our turn we edit a LOCAL working board and submit on
              // a dice tap; otherwise we just render the live board.
              child: GameBoard(
                game: controller.displayGame,
                animator: controller.animator,
                legalMoves: controller.legalMoves,
                interactive: controller.interactive,
                reversed: _reversed,
                onMove: controller.applyLocalMove,
                onTapDice: controller.submitTurn,
              ),
            ),
          ),
          _Controls(fibs: fibs, turnComplete: controller.turnComplete),
        ],
      ),
    );
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave this game?'),
        content: const Text(
          'Resigning mid-match is poor FIBS etiquette — '
          'try to finish. Leave anyway?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep playing'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Resign'),
          ),
        ],
      ),
    );
    if (ok ?? false) App.fibs.resign();
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.fibs, this.turnComplete = false});
  final FibsState fibs;
  // our turn is fully played -> prompt to tap the dice to submit it
  final bool turnComplete;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    if (fibs.doubleOffered) {
      children.addAll([
        const Text('Opponent doubled!'),
        ElevatedButton(onPressed: fibs.acceptDouble, child: const Text('Take')),
        OutlinedButton(onPressed: fibs.rejectDouble, child: const Text('Pass')),
      ]);
    } else if (fibs.canRoll) {
      children.addAll([
        ElevatedButton.icon(
          onPressed: fibs.roll,
          icon: const Icon(Icons.casino),
          label: const Text('Roll'),
        ),
        OutlinedButton(
          onPressed: fibs.offerDouble,
          child: const Text('Double'),
        ),
      ]);
    } else if (fibs.canMoveNow) {
      children.add(
        Text(
          turnComplete
              ? 'Tap the dice to submit your move'
              : 'Your move — make your moves, then tap the dice '
                    '(dice ${fibs.activeDice.join(", ")})',
          style: const TextStyle(color: Colors.white),
        ),
      );
    } else {
      children.add(
        const Text(
          'Waiting for opponent…',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.black26,
      child: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      ),
    );
  }
}

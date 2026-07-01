part of 'fibs_page.dart';

// The read-only spectator view of a watched bot game.

class _WatchView extends StatelessWidget {
  const _WatchView();

  @override
  Widget build(BuildContext context) => ChangeNotifierBuilder<FibsState>(
    notifier: App.fibs,
    builder: (context, fibs, child) => Scaffold(
      backgroundColor: Colors.green,
      appBar: AppBar(
        title: const Text('Watching'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: App.fibs.stopWatching,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: GameBoard(game: fibs.gameState!), // read-only spectator board
      ),
    ),
  );
}

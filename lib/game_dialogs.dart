import 'package:flutter/material.dart';

import 'model.dart';

// The local game's modal dialogs, split out of game_play_page so that file is
// just the board screen + its controller. Each is a plain StatelessWidget with
// a static `show` helper returning the user's choice.

// A cancel (returns false) / confirm (returns true) action pair, shared by the
// yes/no dialogs.
List<Widget> _confirmActions(
  BuildContext context, {
  required String cancel,
  required String confirm,
}) => [
  OutlinedButton(
    onPressed: () => Navigator.pop(context, false),
    child: Padding(padding: const EdgeInsets.all(8), child: Text(cancel)),
  ),
  FilledButton(
    onPressed: () => Navigator.pop(context, true),
    child: Padding(padding: const EdgeInsets.all(8), child: Text(confirm)),
  ),
];

class QuitGameDialog extends StatelessWidget {
  const QuitGameDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Game Already In Progress'),
    content: const Text('OK to quit current game?'),
    actions: _confirmActions(
      context,
      cancel: 'Keep Playing',
      confirm: 'Quit Game',
    ),
  );

  static Future<bool?> show(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) => const QuitGameDialog(),
  );
}

// Win-chance estimate and recommended cube action (issue #14). The numbers are
// a race heuristic, not an equity-engine rollout.
class OddsDialog extends StatelessWidget {
  const OddsDialog(this.game, {super.key});
  final GammonState game;

  static String _cubeAdvice(CubeAction action, int onRollNo) {
    switch (action) {
      case CubeAction.noDouble:
        return 'Player $onRollNo: too early to double.';
      case CubeAction.doubleTake:
        return 'Player $onRollNo should double; opponent should take.';
      case CubeAction.doublePass:
        return 'Player $onRollNo should double; opponent should pass.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final p1 = (game.winProbabilityFor(GammonPlayer.one) * 100).round();
    final p2 = (game.winProbabilityFor(GammonPlayer.two) * 100).round();
    final onRollNo = game.turnPlayer == GammonPlayer.one ? 1 : 2;

    return AlertDialog(
      title: const Text('Win Chances'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Player 1: $p1%'),
          Text('Player 2: $p2%'),
          const SizedBox(height: 12),
          Text(_cubeAdvice(game.recommendedCubeAction, onRollNo)),
          const SizedBox(height: 12),
          Text(
            game.hasExactOdds
                ? 'Exact race calculation (no contact remaining).'
                : 'Estimated from the pip-count race; not an exact rollout.',
            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Padding(padding: EdgeInsets.all(8), child: Text('OK')),
        ),
      ],
    );
  }

  static Future<void> show(BuildContext context, GammonState game) =>
      showDialog<void>(
        context: context,
        builder: (context) => OddsDialog(game),
      );
}

// Offer-a-double dialog: the player on roll doubles, the opponent decides
// (issue #12).
class DoubleOfferDialog extends StatelessWidget {
  const DoubleOfferDialog(this.doubler, this.newValue, {super.key});
  final GammonPlayer doubler;
  final int newValue;

  @override
  Widget build(BuildContext context) {
    final doublerNo = doubler == GammonPlayer.one ? 1 : 2;
    final opponentNo = doubler == GammonPlayer.one ? 2 : 1;
    return AlertDialog(
      title: Text('Player $doublerNo doubles to $newValue'),
      content: Text('Player $opponentNo, do you accept?'),
      actions: _confirmActions(context, cancel: 'Decline', confirm: 'Accept'),
    );
  }

  static Future<bool?> show(
    BuildContext context,
    GammonPlayer doubler,
    int newValue,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => DoubleOfferDialog(doubler, newValue),
  );
}

class NewGameDialog extends StatelessWidget {
  const NewGameDialog(this.winner, this.game, {super.key});
  final GammonPlayer? winner;
  final GammonState game;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Player ${winner == GammonPlayer.one ? 1 : 2} wins!'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatsTable(game: game),
        const SizedBox(height: 16),
        const Text('Would you like to play another game?'),
      ],
    ),
    actions: _confirmActions(
      context,
      cancel: 'No, Thanks',
      confirm: 'Yes, Please!',
    ),
  );

  static Future<bool?> show(
    BuildContext context,
    GammonPlayer? winner,
    GammonState game,
  ) => showDialog<bool>(
    context: context,
    builder: (context) => NewGameDialog(winner, game),
  );
}

// End-of-game stats: rolls, total dice pips, doubles per player (issue #10).
class _StatsTable extends StatelessWidget {
  const _StatsTable({required this.game});
  final GammonState game;

  @override
  Widget build(BuildContext context) {
    final p1 = game.statsFor(GammonPlayer.one);
    final p2 = game.statsFor(GammonPlayer.two);
    const headerStyle = TextStyle(fontWeight: FontWeight.bold);

    TableRow row(String label, Object a, Object b) => TableRow(
      children: [
        Padding(padding: const EdgeInsets.all(4), child: Text(label)),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text('$a', textAlign: TextAlign.center),
        ),
        Padding(
          padding: const EdgeInsets.all(4),
          child: Text('$b', textAlign: TextAlign.center),
        ),
      ],
    );

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      columnWidths: const {0: FlexColumnWidth()},
      children: [
        const TableRow(
          children: [
            Padding(padding: EdgeInsets.all(4), child: Text('')),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                'Player 1',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(4),
              child: Text(
                'Player 2',
                style: headerStyle,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        row('Rolls', p1.rolls, p2.rolls),
        row('Total dice', p1.pips, p2.pips),
        row('Doubles', p1.doubles, p2.doubles),
      ],
    );
  }
}

import 'package:meta/meta.dart';

import 'position.dart';
import 'rules.dart';

/// One checker moving from [fromPip] to [toPip] (engine pips: 0 = player1 off /
/// player2 bar; 1..24 = points; 25 = player1 bar / player2 off). Used to drive
/// animation declaratively from a position *diff* rather than move deltas, so
/// any transition (the local game, the opponent's play, a whole FIBS board
/// update) animates the same way.
@immutable
class Movement {
  /// Creates a movement of [player]'s checker from [fromPip] to [toPip].
  const Movement(this.player, this.fromPip, this.toPip);

  /// The owner of the moving checker.
  final GammonPlayer player;

  /// The engine pip the checker leaves.
  final int fromPip;

  /// The engine pip the checker arrives at.
  final int toPip;

  @override
  bool operator ==(Object other) =>
      other is Movement &&
      other.player == player &&
      other.fromPip == fromPip &&
      other.toPip == toPip;

  @override
  int get hashCode => Object.hash(player, fromPip, toPip);

  @override
  String toString() => 'Movement($player, $fromPip->$toPip)';
}

/// Compute the checker movements that transform [from] into [to] — the minimal
/// set of (per player) departures paired with arrivals. Checkers are identical,
/// so any consistent pairing animates correctly; we pair home-ward so a move
/// reads naturally. Handles hits (the victim's point->bar move falls out of the
/// diff) and bear-offs (point->off) for free.
List<Movement> boardMovements(Position from, Position to) {
  final movements = <Movement>[];
  for (final player in GammonPlayer.values) {
    final barPip = GammonRules.barPipNoFor(player);
    final offPip = GammonRules.offPipNoFor(player);
    int countAtPip(Position p, int pip) {
      if (pip == barPip) return p.barFor(player);
      if (pip == offPip) return p.offFor(player);
      return p.countAt(point: pip, player: player);
    }

    final departures = <int>[];
    final arrivals = <int>[];
    for (var pip = 0; pip <= 25; pip++) {
      final delta = countAtPip(to, pip) - countAtPip(from, pip);
      if (delta < 0) departures.addAll(List<int>.filled(-delta, pip));
      if (delta > 0) arrivals.addAll(List<int>.filled(delta, pip));
    }

    // pair in the player's travel direction (player one moves 24->1, so home is
    // the low pips; player two moves 1->24) so multi-checker turns read sanely
    int homeward(int pip) => player == GammonPlayer.one ? -pip : pip;
    departures.sort((a, b) => homeward(a).compareTo(homeward(b)));
    arrivals.sort((a, b) => homeward(a).compareTo(homeward(b)));

    for (var i = 0; i < departures.length && i < arrivals.length; i++) {
      movements.add(Movement(player, departures[i], arrivals[i]));
    }
  }
  return movements;
}

/// The pip path a single checker travels from [fromPip] to [toPip] for
/// [player], decomposing the journey into [dice]-sized hops so a multi-die move
/// animates through each intermediate pip instead of sliding straight to the
/// end.
///
/// Returns the ordered pips `[fromPip, ...intermediate, toPip]`. A single-die
/// move (or one whose distance can't be formed from the available dice, e.g. a
/// bear-off overshoot) has no intermediate pip: just `[fromPip, toPip]`.
///
/// The dice actually used are REMOVED from [dice] (it is mutated), so a shared
/// pool can allocate dice across the several checkers a whole turn moves; when
/// no subset matches, nothing is consumed. Among subsets that sum to the
/// distance the fewest dice win, so an ambiguous distance isn't given invented
/// extra hops.
List<int> consumeHopPath({
  required int fromPip,
  required int toPip,
  required GammonPlayer player,
  required List<int> dice,
}) {
  // player one moves toward pip 1 (decreasing); player two toward 24.
  final dir = player == GammonPlayer.one ? -1 : 1;
  final distance = (toPip - fromPip) * dir;
  if (distance <= 0) return [fromPip, toPip]; // bar/off/degenerate: direct

  final chosen = _fewestDiceSummingTo(dice, distance);
  if (chosen == null) return [fromPip, toPip]; // can't decompose: direct
  chosen.forEach(dice.remove);
  if (chosen.length < 2) return [fromPip, toPip]; // single die: no hop

  chosen.sort((a, b) => b.compareTo(a)); // larger die first
  final path = <int>[fromPip];
  var pip = fromPip;
  for (var k = 0; k < chosen.length - 1; k++) {
    pip += chosen[k] * dir;
    path.add(pip);
  }
  path.add(toPip);
  return path;
}

// The fewest-element subset of [dice] summing to [target], or null if none.
List<int>? _fewestDiceSummingTo(List<int> dice, int target) {
  List<int>? best;
  for (var mask = 1; mask < (1 << dice.length); mask++) {
    var sum = 0;
    final subset = <int>[];
    for (var i = 0; i < dice.length; i++) {
      if (mask & (1 << i) != 0) {
        sum += dice[i];
        subset.add(dice[i]);
      }
    }
    if (sum == target && (best == null || subset.length < best.length)) {
      best = subset;
    }
  }
  return best;
}

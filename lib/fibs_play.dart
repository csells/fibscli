import 'fibs_board.dart';
import 'model.dart';

// Legal-move generation for a live FIBS game, so an autonomous/assisted player
// can pick legal moves. The engine (GammonRules) has a fixed orientation
// (negative=X toward 1, positive=O toward 24); a FIBS frame may be mirrored
// (see FibsBoard.isMirrored), so we normalize to the engine's frame, generate
// moves there, then translate each move back to absolute FIBS coordinates.
class FibsPlay {
  FibsPlay._();

  // FIBS pos <-> engine pos under the frame's orientation (self-inverse)
  static int _pos(FibsBoard fb, int p) => fb.isMirrored ? 25 - p : p;

  // Build the position in the engine's canonical frame from a FIBS board, as a
  // mutable board the engine can apply moves to.
  static List<List<int>> _canonicalBoard(FibsBoard fb) {
    final board = List<List<int>>.generate(26, (_) => <int>[]);
    var nx = 0;
    var no = 0;
    void place(int pos, int count) {
      for (var i = 0; i != count.abs(); ++i) {
        nx += count < 0 ? 1 : 0;
        no += count > 0 ? 1 : 0;
        board[pos].add(count < 0 ? -nx : no);
      }
    }

    for (var p = 1; p <= 24; ++p) {
      place(_pos(fb, p), fb.points[p]);
    }
    // bars/off go to canonical positions: X=player1 (bar 25, off 0),
    // O=player2 (bar 0, off 25) -- independent of mirroring.
    place(25, -fb.xBar);
    place(0, fb.oBar);
    place(0, -fb.xOff);
    place(25, fb.oOff);
    return board;
  }

  // Every individual legal move for the on-roll player, as FIBS `move` commands
  // (used for highlighting/validation, not for committing a turn).
  static List<String> legalMoveCommands(FibsBoard fb, {List<int>? dice}) {
    final d = dice ?? fb.activeDice;
    if (d.isEmpty || fb.turnPlayer == null) return const [];
    final byPip =
        GammonRules.getForcedLegalMoves(_canonicalBoard(fb), fb.turnPlayer, d);
    return [
      for (final moves in byPip.values)
        for (final m in moves) commandFor(fb, m),
    ];
  }

  // A COMPLETE legal turn for the on-roll player as one FIBS `move` command --
  // FIBS requires the whole turn at once (e.g. "move 24-18 13-11"), not one die
  // at a time. Greedily plays forced-legal moves until the dice are spent.
  static String? fullTurnCommand(FibsBoard fb, {List<int>? dice}) {
    final remaining = List<int>.of(dice ?? fb.activeDice);
    if (remaining.isEmpty || fb.turnPlayer == null) return null;
    final board = _canonicalBoard(fb);
    final player = fb.turnPlayer!;

    final chosen = <GammonMove>[];
    while (remaining.isNotEmpty) {
      final byPip = GammonRules.getForcedLegalMoves(board, player, remaining);
      if (byPip.isEmpty) break;
      final move = byPip.values.first.first;
      GammonRules.applyMove(board, move);
      chosen.add(move);
      for (final hop in move.hops) {
        remaining.remove(hop.abs());
      }
    }
    if (chosen.isEmpty) return null;
    // each commandFor yields "move a-b ..."; merge into one command
    final parts =
        chosen.map((m) => commandFor(fb, m).substring('move '.length));
    return 'move ${parts.join(' ')}';
  }

  // Translate one canonical GammonMove into a FIBS `move` command, mapping each
  // waypoint back to absolute FIBS coordinates (bar/off use keywords).
  static String commandFor(FibsBoard fb, GammonMove move) {
    final player = move.player;
    final barPip = GammonRules.barPipNoFor(player);
    final offPip = GammonRules.offPipNoFor(player);
    String label(int canonicalPos) {
      if (canonicalPos == barPip) return 'bar';
      if (canonicalPos == offPip) return 'off';
      return '${_pos(fb, canonicalPos)}';
    }

    final hops = <String>[];
    var pos = move.fromPipNo;
    for (final hop in move.hops) {
      var next = pos + hop;
      if (next < 0) next = 0;
      if (next > 25) next = 25;
      hops.add('${label(pos)}-${label(next)}');
      pos = next;
    }
    return 'move ${hops.join(' ')}';
  }
}

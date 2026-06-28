import 'fibs_board.dart';
import 'model.dart';
import 'pubeval.dart';

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
    final byPip = GammonRules.getForcedLegalMoves(
      _canonicalBoard(fb),
      fb.turnPlayer,
      d,
    );
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
    final parts = chosen.map(
      (m) => commandFor(fb, m).substring('move '.length),
    );
    return 'move ${parts.join(' ')}';
  }

  // The best complete legal turn as one FIBS `move` command, chosen by
  // Tesauro's pubeval position evaluator so we play to win (not just the first
  // legal turn). Enumerates the distinct full turns, scores each end board.
  static String? bestTurnCommand(FibsBoard fb, {List<int>? dice}) {
    final d = dice ?? fb.activeDice;
    if (d.isEmpty || fb.turnPlayer == null) return null;
    final player = fb.turnPlayer!;

    final turns = <List<GammonMove>>[];
    final endScores = <double>[];
    final seen = <String>{};

    void dfs(
      List<List<int>> board,
      List<int> remaining,
      List<GammonMove> path,
    ) {
      final forced = GammonRules.getForcedLegalMoves(board, player, remaining);
      if (forced.isEmpty) {
        if (path.isNotEmpty) {
          turns.add(List.of(path));
          endScores.add(PubEval.eval(board, player));
        }
        return;
      }
      // cap the search so doubles can't explode
      if (turns.length > 4000) return;
      for (final moves in forced.values) {
        for (final m in moves) {
          final next = List<List<int>>.generate(
            board.length,
            (i) => List<int>.from(board[i]),
          );
          GammonRules.applyMove(next, m);
          final rest = List<int>.of(remaining);
          for (final hop in m.hops) {
            rest.remove(hop.abs());
          }
          final key = '${_sig(next)}|${rest.toList()..sort()}';
          if (!seen.add(key)) continue; // prune transpositions
          path.add(m);
          dfs(next, rest, path);
          path.removeLast();
        }
      }
    }

    dfs(_canonicalBoard(fb), d, []);
    if (turns.isEmpty) return null;

    var best = 0;
    for (var i = 1; i < turns.length; ++i) {
      if (endScores[i] > endScores[best]) best = i;
    }
    final parts = turns[best].map(
      (m) => commandFor(fb, m).substring('move '.length),
    );
    return 'move ${parts.join(' ')}';
  }

  static String _sig(List<List<int>> board) {
    final sb = StringBuffer();
    for (final pip in board) {
      var c = 0;
      for (final id in pip) {
        c += GammonRules.playerFor(id) == GammonPlayer.one ? -1 : 1;
      }
      sb
        ..write(c)
        ..write(',');
    }
    return sb.toString();
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

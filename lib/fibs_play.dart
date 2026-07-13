import 'fibs_board.dart';
import 'fibs_move.dart';
import 'model.dart';

// Legal-move generation for a live FIBS game, so an autonomous/assisted player
// can pick legal moves. The engine (GammonRules) has a fixed orientation
// (negative=X toward 1, positive=O toward 24); a FIBS frame may be mirrored
// (see FibsBoard.isMirrored), so we normalize to the engine's frame, generate
// moves there, then translate each move back to absolute FIBS coordinates.
class FibsPlay {
  FibsPlay._();

  // Build the position in the engine's canonical frame from a FIBS board, as a
  // mutable board the engine can apply moves to. This is the SAME normalization
  // [FibsBoard.position] uses (both honor `mirror`), so the neutral/watched
  // board render and this move generation can't diverge. (The human tap path
  // renders its own perspective via viewerState; see fibs_board.dart.)
  static List<List<int>> _canonicalBoard(FibsBoard fb) => fb.position.toBoard();

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
    return _mergeTurn(fb, chosen);
  }

  // The best complete legal turn as one FIBS `move` command, chosen by
  // Tesauro's pubeval position evaluator so we play to win (not just the first
  // legal turn). Enumerates the distinct full turns, scores each end board.
  static String? bestTurnCommand(FibsBoard fb, {List<int>? dice}) {
    final d = dice ?? fb.activeDice;
    if (d.isEmpty || fb.turnPlayer == null) return null;
    final player = fb.turnPlayer!;

    // Standardized on the shared engine: enumerate the distinct legal turns and
    // pick the one whose end board pubeval scores best. (Equivalent to
    // bestTurnCommandWithAi(fb, PubevalAiPlayer()), but synchronous for the
    // tap-to-move / legacy callers.)
    List<GammonMove>? bestTurn;
    var bestScore = double.negativeInfinity;
    for (final turn in enumerateLegalTurns(_canonicalBoard(fb), player, d)) {
      if (turn.moves.isEmpty) continue; // dance
      final score = PubEval.eval(turn.board, player);
      if (score > bestScore) {
        bestScore = score;
        bestTurn = turn.moves;
      }
    }
    return bestTurn == null ? null : _mergeTurn(fb, bestTurn);
  }

  // The best complete legal turn as one FIBS `move` command, chosen by an
  // arbitrary [BgAiPlayer] (the spec's "Play for Me" unification). The AI works
  // in the engine's canonical frame, so we hand it a BgPosition built from the
  // FIBS board and translate its chosen turn back to FIBS coordinates. With a
  // PubevalAiPlayer this matches [bestTurnCommand]; any other engine (e.g. a
  // gnubg opponent) plugs in unchanged. Returns null for a dance / no dice.
  static Future<String?> bestTurnCommandWithAi(
    FibsBoard fb,
    BgAiPlayer ai, {
    List<int>? dice,
  }) async {
    final d = dice ?? fb.activeDice;
    if (d.isEmpty || fb.turnPlayer == null) return null;
    final turn = await ai.chooseTurn(
      BgPosition(board: _canonicalBoard(fb), onRoll: fb.turnPlayer!, dice: d),
    );
    if (turn.moves.isEmpty) return null; // dance
    return _mergeTurn(fb, turn.moves);
  }

  // Render a chosen turn (a list of single-hop moves) as one FIBS `move`
  // command, e.g. "move 24-18 13-11". Moves are in the canonical engine frame,
  // so each waypoint is mapped back to FIBS coordinates via fb.mirror.
  static String _mergeTurn(FibsBoard fb, Iterable<GammonMove> moves) {
    final pairs = moves.expand((m) => hopPairs(m, mapPip: fb.mirror));
    return 'move ${pairs.join(' ')}';
  }

  // Translate one canonical GammonMove into a FIBS `move` command, mapping each
  // waypoint back to absolute FIBS coordinates (bar/off use keywords). Shares
  // the one hop-walk renderer with the viewer path ([hopPairs]).
  static String commandFor(FibsBoard fb, GammonMove move) =>
      'move ${hopPairs(move, mapPip: fb.mirror).join(' ')}';
}

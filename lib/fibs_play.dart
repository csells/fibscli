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

  // Legal moves keyed by the on-roll player's REAL FIBS from-pip, for the UI to
  // highlight and gate tap-to-move. The engine generates moves in its canonical
  // (possibly mirrored) frame; we translate each back to absolute FIBS
  // coordinates so the highlights and the displayed board agree -- without
  // this, a mirrored game highlights moves in the wrong direction. Bar/off
  // moves are omitted here (the tap-off path handles bear-off); every move kept
  // is point-to-point with valid hops.
  static Map<int, List<GammonMove>> legalMovesByFibsPip(
    FibsBoard fb, {
    List<int>? dice,
  }) {
    final d = dice ?? fb.activeDice;
    if (d.isEmpty || fb.turnPlayer == null) return const {};
    final player = fb.turnPlayer!;
    final barPip = GammonRules.barPipNoFor(player);
    final offPip = GammonRules.offPipNoFor(player);
    final canonical = GammonRules.getForcedLegalMoves(
      _canonicalBoard(fb),
      player,
      d,
    );

    final result = <int, List<GammonMove>>{};
    for (final moves in canonical.values) {
      for (final m in moves) {
        if (m.fromPipNo == barPip || m.toPipNo == offPip) continue; // see above
        final from = _pos(fb, m.fromPipNo);
        // translate each waypoint to FIBS coords; the per-hop deltas keep their
        // magnitude (a valid die) but flip sign on a mirrored frame.
        final hops = <int>[];
        var pos = m.fromPipNo;
        for (final hop in m.hops) {
          final next = pos + hop;
          hops.add(_pos(fb, next) - _pos(fb, pos));
          pos = next;
        }
        (result[from] ??= []).add(
          GammonMove(fromPipNo: from, toPipNo: _pos(fb, m.toPipNo), hops: hops),
        );
      }
    }
    return result;
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
  // PubevalAiPlayer this matches [bestTurnCommand]; other engines (gnubg,
  // backgammon_ai) plug in unchanged. Returns null for a dance / no dice.
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
  // command, e.g. "move 24-18 13-11".
  static String _mergeTurn(FibsBoard fb, Iterable<GammonMove> moves) {
    final hops = moves.map((m) => commandFor(fb, m).substring('move '.length));
    return 'move ${hops.join(' ')}';
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

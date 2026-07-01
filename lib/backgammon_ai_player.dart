import 'package:backgammon_ai/backgammon_ai.dart' as bgai;
import 'package:bg_engine/bg_engine.dart';

// The adapter that lets the external backgammon_ai engine play behind our
// BgAiPlayer abstraction. It lives in the app (which depends on both bg_engine
// and backgammon_ai) rather than inside backgammon_ai, so that external package
// doesn't have to path-depend back into our pub workspace.
//
// backgammon_ai works in each player's own pip-distance frame (Player.a /
// Player.b, counts indexed by distance-to-bear-off). We map the on-roll player
// to Player.a, ask it to choose a move (it returns the resulting Board), then
// match that position back to a locally-enumerated legal turn by signature --
// the same robust pattern as the gnubg adapter -- so the returned GammonMoves
// always have valid hops.

// The engine pip that is pip-distance [d] (1..24) for [player]: player one
// counts up from pip 1 (bears off at 0); player two counts down from pip 24.
int _pipForDistance(GammonPlayer player, int d) =>
    player == GammonPlayer.one ? d : 25 - d;

/// Convert a canonical engine [board] to a backgammon_ai [bgai.Board] from
/// [onRoll]'s perspective (the on-roll player becomes Player A).
bgai.Board toBackgammonAiBoard(List<List<int>> board, GammonPlayer onRoll) {
  final opp = GammonRules.otherPlayer(onRoll);
  final a = List<int>.filled(24, 0);
  final b = List<int>.filled(24, 0);
  for (var d = 1; d <= 24; d++) {
    a[d - 1] = GammonRules.countAt(board, _pipForDistance(onRoll, d), onRoll);
    b[d - 1] = GammonRules.countAt(board, _pipForDistance(opp, d), opp);
  }
  return bgai.Board(
    aPoints: a,
    bPoints: b,
    aBar: GammonRules.countAt(board, GammonRules.barPipNoFor(onRoll), onRoll),
    bBar: GammonRules.countAt(board, GammonRules.barPipNoFor(opp), opp),
    aOff: GammonRules.countAt(board, GammonRules.offPipNoFor(onRoll), onRoll),
    bOff: GammonRules.countAt(board, GammonRules.offPipNoFor(opp), opp),
  );
}

/// The [positionSignature]-format fingerprint of a backgammon_ai [board] whose
/// Player A is [onRoll], so it can be compared against engine-board signatures.
List<int> backgammonAiBoardSignature(bgai.Board board, GammonPlayer onRoll) {
  final opp = GammonRules.otherPlayer(onRoll);
  final sig = List<int>.filled(52, 0);
  void add(int pip, GammonPlayer player, int count) {
    sig[pip * 2 + (player == GammonPlayer.one ? 0 : 1)] += count;
  }

  for (var d = 1; d <= 24; d++) {
    add(_pipForDistance(onRoll, d), onRoll, board.aPoints[d - 1]);
    add(_pipForDistance(opp, d), opp, board.bPoints[d - 1]);
  }
  add(GammonRules.barPipNoFor(onRoll), onRoll, board.aBar);
  add(GammonRules.barPipNoFor(opp), opp, board.bBar);
  add(GammonRules.offPipNoFor(onRoll), onRoll, board.aOff);
  add(GammonRules.offPipNoFor(opp), opp, board.bOff);
  return sig;
}

/// A [BgAiPlayer] backed by the external `backgammon_ai` engine (a bit-exact
/// port of the *Gary Gammon* AI).
class BackgammonAiPlayer extends BgAiPlayer {
  /// Creates a player at [level] (defaults to the strongest, level 8).
  BackgammonAiPlayer({bgai.AiLevel level = bgai.AiLevel.level8})
    : _engine = bgai.BackgammonAi.newGame(level: level),
      _level = level;

  final bgai.BackgammonAi _engine;
  final bgai.AiLevel _level;

  @override
  String get name => 'Gary Gammon';

  @override
  String? get description => "the engine — ${_level.name}";

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async {
    final turns = enumerateLegalTurns(
      position.board,
      position.onRoll,
      position.dice,
    );
    if (turns.isEmpty) return const BgTurn([]);

    final result = _engine.chooseMove(
      toBackgammonAiBoard(position.board, position.onRoll),
      bgai.Player.a, // the on-roll player is always Player A in our mapping
      position.dice,
    );
    if (result == null) return const BgTurn([]); // backgammon_ai forfeits

    final target = backgammonAiBoardSignature(result, position.onRoll);
    final match = matchTurnBySignature(turns, target);
    if (match != null) return BgTurn(match.moves);
    // no match (shouldn't happen) -> don't stall the game
    return BgTurn(turns.first.moves);
  }
}

/// Factory that builds [BackgammonAiPlayer]s; [levels] are the backgammon_ai
/// difficulty levels. Register it with the `AiRegistry`.
class BackgammonAiPlayerFactory extends BgAiPlayerFactory {
  @override
  String get name => 'Gary Gammon';

  @override
  String? get description => "the engine (levels 1-8)";

  @override
  List<String> get levels => [for (final l in bgai.AiLevel.values) l.name];

  @override
  BgAiPlayer create({String? level}) => BackgammonAiPlayer(
    level: bgai.AiLevel.values.firstWhere(
      (l) => l.name == level,
      orElse: () => bgai.AiLevel.level8,
    ),
  );
}

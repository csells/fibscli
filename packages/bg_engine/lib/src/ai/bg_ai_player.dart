import '../position.dart';
import '../rules.dart';

/// An immutable snapshot of a position handed to an AI for one decision.
///
/// Representation-neutral: it carries the canonical engine board so the
/// built-in [GammonRules]-based players need no conversion, while non-native
/// engines (e.g. a gnubg adapter) translate it at their own boundary. Callers
/// (the app's `GammonState`, or the FIBS board) build one of these.
class BgPosition {
  /// Creates a position snapshot for the player [onRoll] with [dice] to play.
  const BgPosition({
    required this.board,
    required this.onRoll,
    required this.dice,
    this.cubeValue = 1,
    this.cubeOwner,
  });

  /// The canonical 26-cell board (signed piece ids).
  final List<List<int>> board;

  /// The player to move.
  final GammonPlayer onRoll;

  /// The die values available to play (doubles expanded to four entries).
  final List<int> dice;

  /// The current doubling-cube value (a power of two, 1..64).
  final int cubeValue;

  /// Who owns the cube, or null when it is centered.
  final GammonPlayer? cubeOwner;

  /// The checker layout as a typed, immutable [Position] (the structured view
  /// of [board]).
  Position get position => Position.fromBoard(board);
}

/// A full chosen turn: the ordered checker moves to apply. An empty [moves]
/// list means the player cannot move (a dance).
class BgTurn {
  /// Creates a turn from the ordered [moves] to apply.
  const BgTurn(this.moves);

  /// The ordered moves making up the turn.
  final List<GammonMove> moves;

  /// True when there is no legal play (a dance).
  bool get isDance => moves.isEmpty;
}

/// A doubling-cube decision an AI can make.
enum BgCubeAction {
  /// Do not offer a double; just roll.
  noDouble,

  /// Offer a double to the opponent.
  offerDouble,

  /// Accept the opponent's double.
  take,

  /// Decline the opponent's double (drop).
  pass,
}

/// The base class every AI engine implements. Asynchronous so a remote engine
/// (an HTTP service) fits the same contract; in-process engines complete the
/// future synchronously. Cube/resign decisions are optional with conservative
/// defaults, so a moves-only engine needs only [chooseTurn].
abstract class BgAiPlayer {
  /// A human-readable name for this engine (shown in the AI picker).
  String get name;

  /// An optional one-line description of the engine.
  String? get description => null;

  /// Optional difficulty levels this engine exposes (empty == single strength).
  List<String> get levels => const [];

  /// Choose the checker play for [position]. Returns an empty [BgTurn] when
  /// there is no legal move (a dance).
  Future<BgTurn> chooseTurn(BgPosition position);

  /// The cube action when on roll, before rolling. Defaults to never doubling.
  Future<BgCubeAction> cubeDecision(BgPosition position) async =>
      BgCubeAction.noDouble;

  /// The response to the opponent's double. Defaults to taking.
  Future<BgCubeAction> respondToDouble(BgPosition position) async =>
      BgCubeAction.take;

  /// Release any resources held by the engine (e.g. an HTTP client).
  void dispose() {}
}

/// Creates [BgAiPlayer] instances. Registered with the `AiRegistry` so the UI
/// can list the available engines and let the user pick one (and a level).
abstract class BgAiPlayerFactory {
  /// The display name of the engine this factory builds.
  String get name;

  /// An optional one-line description shown next to [name].
  String? get description => null;

  /// The difficulty levels this engine offers (empty == single strength).
  List<String> get levels => const [];

  /// Build an instance, optionally at the given difficulty [level].
  BgAiPlayer create({String? level});
}

import 'package:meta/meta.dart';

import '../rules.dart';
import 'bg_ai_player.dart';
import 'turn_search.dart';

/// Thrown when gnubg cannot supply a decision: the service is unreachable
/// (after retries) or it answered with something that cannot be played. The
/// adapter NEVER substitutes a locally-chosen decision for gnubg's -- that
/// would misreport a heuristic play as gnubg's. Callers surface this to the
/// user (e.g. "the gnubg endpoint is unavailable").
class GnubgUnavailableException implements Exception {
  /// Creates the exception with a human-readable [message] and the underlying
  /// [cause] (the last transport error), when there was one.
  GnubgUnavailableException(this.message, [this.cause]);

  /// What went wrong, in user-facing terms.
  final String message;

  /// The last underlying error (e.g. a SocketException), if any.
  final Object? cause;

  @override
  String toString() =>
      'GnubgUnavailableException: $message${cause == null ? '' : ' ($cause)'}';
}

/// One chequer movement within a played move, in the service's numbering
/// convention: points 1..24 from the MOVER's perspective (the mover bears off
/// at 1 and enters at 24), 25 = the bar, 0 = off. There is one hop per segment
/// of gnubg's move notation, so a single hop may consume both dice where gnubg
/// collapses them into one segment (e.g. "bar/20" on a 4-1 is the one hop
/// 25 -> 20).
@immutable
class GnubgHop {
  /// Creates a hop.
  const GnubgHop({required this.from, required this.to});

  /// Start of the hop: the mover's point 1..24, or 25 for a chequer entering
  /// from the bar.
  final int from;

  /// End of the hop: the mover's point 1..24, or 0 for a chequer borne off.
  final int to;

  @override
  bool operator ==(Object other) =>
      other is GnubgHop && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);

  @override
  String toString() => 'GnubgHop($from -> $to)';
}

/// The ONE checker play a leveled gnubg opponent makes for a position: the
/// structured [hops] the adapter plays by, plus the same play as notation
/// text ([play], diagnostic only). A dance -- no legal play for the roll --
/// is a null [play] with empty [hops].
class GnubgPlayedMove {
  /// Creates a played move.
  const GnubgPlayedMove({required this.play, required this.hops});

  /// The play in standard notation, from the mover's perspective, or null
  /// when the roll dances. Carried for diagnostics; the [hops] are the
  /// structured form of the same play.
  final String? play;

  /// The play's chequer movements -- see [GnubgHop] for the numbering
  /// convention. Empty on a dance.
  final List<GnubgHop> hops;
}

/// What a leveled gnubg opponent resigns now: nothing, or one of the three
/// backgammon stakes.
enum GnubgResignStake {
  /// Keep playing; no resignation.
  none,

  /// Resign a single game.
  single,

  /// Resign a gammon.
  gammon,

  /// Resign a backgammon.
  backgammon,
}

/// The seam over the gnubg-service leveled-opponent endpoints
/// (`/v1/play/*`): each call returns the ONE decision a level-N opponent
/// makes for the position. The opponent's level and per-match seed are fixed
/// per client instance -- they identify the opponent, not the request. The
/// HTTP implementation encodes the position and calls the service; tests
/// inject a fake.
abstract class GnubgClient {
  /// The checker play the opponent makes for [position] (an in-roll decision
  /// point; [BgPosition.dice] is part of the request).
  Future<GnubgPlayedMove> playMove(BgPosition position);

  /// Whether the opponent, on roll before rolling, doubles from [position]
  /// (a pre-roll decision point; the dice are not part of the request).
  Future<bool> playCube(BgPosition position);

  /// Whether the opponent takes a double offered from [position], whose
  /// player on roll is the DOUBLER (the service's `/v1/play/take` contract).
  Future<bool> playTake(BgPosition position);

  /// What the opponent resigns now from [position], if anything (pre-roll).
  Future<GnubgResignStake> playResign(BgPosition position);

  /// Release any resources (e.g. an HTTP client).
  void dispose() {}
}

/// An AI player backed by GNU Backgammon's calibrated leveled opponent via
/// [GnubgClient]. It asks the service for the opponent's single decision,
/// applies the returned [GnubgHop]s to the position, and returns the
/// locally-enumerated legal turn that reaches the same position -- so the
/// returned [GammonMove]s always have valid hops, regardless of how gnubg
/// collapses segments. Cube and resignation decisions come from the service
/// too, overriding the base class's local `CubePolicy` defaults.
///
/// It NEVER fabricates a decision: if the service is unreachable (after
/// [retries] attempts) or answers with nothing playable, every decision
/// method throws [GnubgUnavailableException] so the caller can tell the user
/// the gnubg endpoint is unavailable, rather than silently passing off a
/// local heuristic as gnubg's.
class GnubgAiPlayer extends BgAiPlayer {
  /// Creates a player driven by [_client]. A transient transport failure is
  /// retried [retries] extra times, waiting [retryDelay] between attempts.
  /// [name] and [description] label the opponent in the UI.
  GnubgAiPlayer(
    this._client, {
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
    this.name = 'GNU Backgammon (gnubg)',
    this.description,
  });

  final GnubgClient _client;

  /// Extra attempts after the first if the service request fails transiently.
  final int retries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  /// The opponent's UI label.
  @override
  final String name;

  /// The opponent's UI caption (e.g. the level's tier name).
  @override
  final String? description;

  @override
  void dispose() => _client.dispose();

  @override
  Future<BgTurn> chooseTurn(BgPosition position) async {
    final turns = enumerateLegalTurns(
      position.board,
      position.onRoll,
      position.dice,
    );
    // No legal play (empty, or only a dance): pass without bothering the
    // service -- there is nothing for it to play, and nothing to fail on.
    if (turns.isEmpty || turns.every((t) => t.moves.isEmpty)) {
      return const BgTurn([]);
    }

    final played = await _withRetry(() => _client.playMove(position));
    if (played.hops.isNotEmpty) {
      final target = _signatureOfHops(
        position.board,
        position.onRoll,
        played.hops,
      );
      if (target != null) {
        final match = matchTurnBySignature(turns, target);
        if (match != null) return BgTurn(match.moves);
      }
    }
    // The service answered but its play cannot be matched to a legal turn
    // (or it reported a dance where legal turns exist). We will NOT invent
    // one -- report it so the user knows gnubg failed us.
    throw GnubgUnavailableException(
      'gnubg returned no usable move for this position',
    );
  }

  @override
  Future<BgCubeAction> cubeDecision(BgPosition position) async {
    // Hard cube rules, not heuristics: only a centred cube or one the mover
    // holds may be turned, and never past the maximum. Deciding these locally
    // skips a service call whose answer could not legally be played anyway.
    if (position.cubeValue >= DoublingCube.maxValue) {
      return BgCubeAction.noDouble;
    }
    final owner = position.cubeOwner;
    if (owner != null && owner != position.onRoll) return BgCubeAction.noDouble;

    final doubles = await _withRetry(() => _client.playCube(position));
    return doubles ? BgCubeAction.offerDouble : BgCubeAction.noDouble;
  }

  @override
  Future<BgCubeAction> respondToDouble(BgPosition position) async {
    // [position]'s onRoll is the doubler, matching `/v1/play/take`'s
    // contract: "the id is the position on which the double was offered".
    final takes = await _withRetry(() => _client.playTake(position));
    return takes ? BgCubeAction.take : BgCubeAction.pass;
  }

  @override
  Future<BgResignDecision> resignDecision(BgPosition position) async {
    final stake = await _withRetry(() => _client.playResign(position));
    return BgResignDecision.values[stake.index];
  }

  // Ask the service, retrying a transient transport failure. On exhaustion,
  // throw GnubgUnavailableException -- never a local fallback.
  Future<T> _withRetry<T>(Future<T> Function() call) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0 && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
      try {
        return await call();
      } on Exception catch (error) {
        lastError = error;
      }
    }
    throw GnubgUnavailableException(
      'the gnubg endpoint is unavailable',
      lastError,
    );
  }

  // Apply the service's structured [hops] for [player] to [board] and return
  // the resulting signature, or null if the hops reference illegal points /
  // can't be applied (e.g. moving a checker that isn't there).
  static List<int>? _signatureOfHops(
    List<List<int>> board,
    GammonPlayer player,
    List<GnubgHop> hops,
  ) {
    final moverIsOne = player == GammonPlayer.one;
    final p1 = List<int>.filled(26, 0);
    final p2 = List<int>.filled(26, 0);
    for (var i = 0; i < board.length; i++) {
      for (final id in board[i]) {
        if (id < 0) {
          p1[i]++;
        } else {
          p2[i]++;
        }
      }
    }
    final mover = moverIsOne ? p1 : p2;
    final opp = moverIsOne ? p2 : p1;
    final oppBar = moverIsOne ? 0 : 25; // player2 bar = 0, player1 bar = 25

    for (final hop in hops) {
      final from = _engPip(hop.from, player);
      final to = _engPip(hop.to, player);
      if (from == null || to == null) return null;
      if (mover[from] <= 0) return null; // nothing to move from there
      mover[from]--;
      // hits only happen on the 24 numbered points, not bar/off
      if (to >= 1 && to <= 24 && opp[to] == 1) {
        opp[to]--;
        opp[oppBar]++;
      }
      mover[to]++;
    }

    final sig = List<int>.filled(52, 0);
    for (var i = 0; i < 26; i++) {
      sig[i * 2] = p1[i];
      sig[i * 2 + 1] = p2[i];
    }
    return sig;
  }

  // Map a mover-perspective hop [point] to an engine pip. 25 (the bar) and 0
  // (off) map to the player's bar/off cells; a point N maps to N for player
  // one and 25-N for player two (each plays from their own 24..1 perspective).
  // Anything out of range maps to null.
  static int? _engPip(int point, GammonPlayer player) {
    if (point == 25) return GammonRules.barPipNoFor(player);
    if (point == 0) return GammonRules.offPipNoFor(player);
    if (point < 1 || point > 24) return null;
    return player == GammonPlayer.one ? point : 25 - point;
  }
}

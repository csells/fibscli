import 'package:meta/meta.dart';

import '../rules.dart';
import 'bg_ai_player.dart';
import 'turn_search.dart';

/// Thrown when gnubg cannot supply a move: the service is unreachable (after
/// retries) or it answered but none of its ranked plays matched a legal turn.
/// The adapter NEVER substitutes a locally-chosen move for gnubg's -- that
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

/// One chequer movement within a ranked move, in the service's numbering
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

/// One ranked move from gnubg: the structured [hops] the adapter plays by,
/// the same play as notation text ([play], diagnostic only), and its cubeless
/// equity (higher is better for the mover).
class GnubgRankedMove {
  /// Creates a ranked move.
  const GnubgRankedMove({
    required this.play,
    required this.hops,
    required this.equity,
  });

  /// The play in standard notation, from the mover's perspective. Carried for
  /// diagnostics; the [hops] are the structured form of the same play.
  final String play;

  /// The play's chequer movements — see [GnubgHop] for the numbering
  /// convention.
  final List<GnubgHop> hops;

  /// The move's equity (higher is better).
  final double equity;
}

/// gnubg's verdict for the on-roll player's cube decision, exactly as the
/// service's `/v1/cube` reports it.
enum GnubgCubeAction {
  /// Do not double (doubling loses equity; the opponent would take).
  noDouble,

  /// Double; the opponent should take.
  doubleTake,

  /// Double; the opponent should pass.
  doublePass,

  /// Too good to double: play on for the gammon (the opponent would pass).
  tooGoodToDouble,
}

/// The service's `/v1/cube` evaluation: the recommended [action] plus the
/// equities gnubg compared to reach it, all from the on-roll player's
/// perspective.
class GnubgCubeDecision {
  /// Creates a cube decision.
  const GnubgCubeDecision({
    required this.action,
    required this.cubelessEquity,
    required this.cubefulNoDouble,
    required this.cubefulDoubleTake,
    required this.cubefulDoublePass,
  });

  /// gnubg's recommended cube action for the player on roll.
  final GnubgCubeAction action;

  /// The position's cubeless equity.
  final double cubelessEquity;

  /// Cubeful equity of not doubling.
  final double cubefulNoDouble;

  /// Cubeful equity of double/take.
  final double cubefulDoubleTake;

  /// Cubeful equity of double/pass.
  final double cubefulDoublePass;
}

/// The service's `/v1/resign` evaluation for the on-roll player ("the mover"):
/// what they should resign now and — when the opponent has offered to resign —
/// whether to accept.
class GnubgResignDecision {
  /// Creates a resignation decision.
  const GnubgResignDecision({
    required this.resignAdvice,
    required this.equityPlayOn,
    this.accept,
  }) : assert(
         resignAdvice >= 0 && resignAdvice <= 3,
         'resignAdvice must be 0..3',
       );

  /// What the mover should resign NOW: 0 = play on, 1 = single, 2 = gammon,
  /// 3 = backgammon (gnubg's `getResignation` rule).
  final int resignAdvice;

  /// The mover's cubeless equity playing on (the advice baseline).
  final double equityPlayOn;

  /// Only when the request carried an offer: whether the mover should accept
  /// the opponent's offer to resign.
  final bool? accept;
}

/// The seam over the gnubg-service decision endpoints: given a position,
/// return gnubg's ranked moves (`/v1/eval`), cube verdict (`/v1/cube`), or
/// resignation verdict (`/v1/resign`). The HTTP implementation encodes the
/// position and calls the service; tests inject a fake.
abstract class GnubgClient {
  /// Rank the legal moves for [position] (best first). May be empty.
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position);

  /// gnubg's cube verdict for [position]'s player on roll (a pre-roll
  /// decision point; [BgPosition.dice] is not part of the request).
  Future<GnubgCubeDecision> cubeDecision(BgPosition position);

  /// gnubg's resignation verdict for [position]'s player on roll (pre-roll).
  /// With [offered] 1|2|3 the OPPONENT has offered to resign that many points
  /// (times the cube value) and the reply carries the accept verdict.
  Future<GnubgResignDecision> resignDecision(
    BgPosition position, {
    int offered = 0,
  });

  /// Release any resources (e.g. an HTTP client).
  void dispose() {}
}

/// An AI player backed by GNU Backgammon via [GnubgClient]. It asks gnubg to
/// rank the moves, applies each ranked move's structured [GnubgHop]s to the
/// position, and returns the locally-enumerated legal turn that reaches the
/// same position — so the returned [GammonMove]s always have valid hops,
/// regardless of how gnubg collapses segments. Cube and resignation decisions
/// come from the service too (`/v1/cube`, `/v1/resign`), overriding the base
/// class's local `CubePolicy` defaults.
///
/// It NEVER fabricates a decision: if the service is unreachable (after
/// [retries] attempts) or answers with nothing usable, every decision method
/// throws [GnubgUnavailableException] so the caller can tell the user the
/// gnubg endpoint is unavailable, rather than silently passing off a local
/// heuristic as gnubg's.
class GnubgAiPlayer extends BgAiPlayer {
  /// Creates a player driven by [_client]. A transient transport failure is
  /// retried [retries] extra times, waiting [retryDelay] between attempts.
  GnubgAiPlayer(
    this._client, {
    this.retries = 2,
    this.retryDelay = const Duration(milliseconds: 300),
  });

  final GnubgClient _client;

  /// Extra attempts after the first if the service request fails transiently.
  final int retries;

  /// Delay between retry attempts.
  final Duration retryDelay;

  @override
  String get name => 'GNU Backgammon (gnubg)';

  @override
  String? get description => 'World-class neural-net engine via gnubg-service';

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
    // service -- there is nothing for it to rank, and nothing to fail on.
    if (turns.isEmpty || turns.every((t) => t.moves.isEmpty)) {
      return const BgTurn([]);
    }

    final ranked = await _withRetry(() => _client.evalMoves(position));
    for (final move in ranked) {
      final target = _signatureOfHops(
        position.board,
        position.onRoll,
        move.hops,
      );
      if (target == null) continue;
      final match = matchTurnBySignature(turns, target);
      if (match != null) return BgTurn(match.moves);
    }
    // The service answered but none of its ranked plays matched a legal turn.
    // We will NOT invent one -- report it so the user knows gnubg failed us.
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

    final decision = await _withRetry(() => _client.cubeDecision(position));
    switch (decision.action) {
      case GnubgCubeAction.doubleTake:
      case GnubgCubeAction.doublePass:
        return BgCubeAction.offerDouble;
      case GnubgCubeAction.noDouble:
      case GnubgCubeAction.tooGoodToDouble:
        return BgCubeAction.noDouble;
    }
  }

  @override
  Future<BgCubeAction> respondToDouble(BgPosition position) async {
    final decision = await _withRetry(() => _client.cubeDecision(position));
    // [position]'s onRoll is the doubler. Drop exactly when gnubg judges their
    // position pass-strength: an outright double/pass, or too good to double
    // (they gain even more playing on than the pass would concede).
    switch (decision.action) {
      case GnubgCubeAction.doublePass:
      case GnubgCubeAction.tooGoodToDouble:
        return BgCubeAction.pass;
      case GnubgCubeAction.noDouble:
      case GnubgCubeAction.doubleTake:
        return BgCubeAction.take;
    }
  }

  @override
  Future<BgResignDecision> resignDecision(BgPosition position) async {
    final decision = await _withRetry(() => _client.resignDecision(position));
    return BgResignDecision.values[decision.resignAdvice];
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

/// Factory that builds [GnubgAiPlayer]s from a [GnubgClient] supplier. Register
/// it with the `AiRegistry` once a gnubg-service URL is configured.
class GnubgAiPlayerFactory extends BgAiPlayerFactory {
  /// Creates a factory that builds a fresh client per player via [_clientFor].
  GnubgAiPlayerFactory(this._clientFor);

  final GnubgClient Function() _clientFor;

  @override
  String get name => 'GNU Backgammon (gnubg)';

  @override
  String? get description => 'World-class neural-net engine via gnubg-service';

  @override
  BgAiPlayer create({String? level}) => GnubgAiPlayer(_clientFor());
}

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

/// One ranked move from gnubg: a standard-notation [play] (e.g. "8/5 6/5") and
/// its cubeless equity (higher is better for the mover).
class GnubgRankedMove {
  /// Creates a ranked move.
  const GnubgRankedMove({required this.play, required this.equity});

  /// The play in standard notation, from the mover's perspective.
  final String play;

  /// The move's equity (higher is better).
  final double equity;
}

/// The seam over the gnubg-service `/v1/eval` endpoint: given a position,
/// return gnubg's ranked moves (best first). The HTTP implementation encodes
/// the position and calls the service; tests inject a fake.
abstract class GnubgClient {
  /// Rank the legal moves for [position] (best first). May be empty.
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position);

  /// Release any resources (e.g. an HTTP client).
  void dispose() {}
}

/// An AI player backed by GNU Backgammon via [GnubgClient]. It asks gnubg to
/// rank the moves, then returns the locally-enumerated legal turn whose
/// resulting position matches gnubg's best playable choice — so the returned
/// [GammonMove]s always have valid hops, regardless of how gnubg collapses its
/// notation.
///
/// It NEVER fabricates a move: if the service is unreachable (after [retries]
/// attempts) or answers with nothing matchable, it throws
/// [GnubgUnavailableException] so the caller can tell the user the gnubg
/// endpoint is unavailable, rather than silently playing a local heuristic move
/// dressed up as gnubg's.
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

    final ranked = await _evalWithRetry(position);
    for (final move in ranked) {
      final target = _signatureOfPlay(
        position.board,
        position.onRoll,
        move.play,
      );
      if (target == null) continue;
      for (final turn in turns) {
        if (_listEquals(positionSignature(turn.board), target)) {
          return BgTurn(turn.moves);
        }
      }
    }
    // The service answered but none of its ranked plays matched a legal turn.
    // We will NOT invent one -- report it so the user knows gnubg failed us.
    throw GnubgUnavailableException(
      'gnubg returned no usable move for this position',
    );
  }

  // Ask the service, retrying a transient transport failure. On exhaustion,
  // throw GnubgUnavailableException -- never a local fallback.
  Future<List<GnubgRankedMove>> _evalWithRetry(BgPosition position) async {
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      if (attempt > 0 && retryDelay > Duration.zero) {
        await Future<void>.delayed(retryDelay);
      }
      try {
        return await _client.evalMoves(position);
      } on Exception catch (error) {
        lastError = error;
      }
    }
    throw GnubgUnavailableException(
      'the gnubg endpoint is unavailable',
      lastError,
    );
  }

  // Apply a standard-notation [play] for [player] to [board] and return the
  // resulting signature, or null if the play references illegal pips / can't be
  // applied (e.g. moving a checker that isn't there).
  static List<int>? _signatureOfPlay(
    List<List<int>> board,
    GammonPlayer player,
    String play,
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
    final offPip = GammonRules.offPipNoFor(player);
    final barPip = GammonRules.barPipNoFor(player);

    for (final token in play.trim().split(RegExp(r'\s+'))) {
      if (token.isEmpty) continue;
      var multiplier = 1;
      var body = token;
      final mult = RegExp(r'\((\d+)\)$').firstMatch(body);
      if (mult != null) {
        multiplier = int.parse(mult.group(1)!);
        body = body.substring(0, mult.start);
      }
      final pips = body.split('/');
      if (pips.length < 2) return null;
      for (var rep = 0; rep < multiplier; rep++) {
        for (var s = 0; s < pips.length - 1; s++) {
          final from = _engPip(pips[s], player, barPip, offPip);
          final to = _engPip(pips[s + 1], player, barPip, offPip);
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
      }
    }

    final sig = List<int>.filled(52, 0);
    for (var i = 0; i < 26; i++) {
      sig[i * 2] = p1[i];
      sig[i * 2 + 1] = p2[i];
    }
    return sig;
  }

  // Map a notation pip token to an engine pip. 'bar'/'off' map to the player's
  // bar/off cells; a number N maps to N for player one and 25-N for player two
  // (each plays from their own 24..1 perspective).
  static int? _engPip(
    String token,
    GammonPlayer player,
    int barPip,
    int offPip,
  ) {
    final t = token.toLowerCase();
    if (t == 'bar') return barPip;
    if (t == 'off') return offPip;
    final n = int.tryParse(t);
    if (n == null || n < 1 || n > 24) return null;
    return player == GammonPlayer.one ? n : 25 - n;
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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

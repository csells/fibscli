import 'package:bg_engine/bg_engine.dart';
import 'package:gnubg_service/gnubg_service.dart';

/// A [GnubgClient] backed by the gnubg-service's [GnubgSession]: the session
/// owns the generated OpenAPI client plus the attested session-token
/// lifecycle (publishable key + Turnstile -> `bg_tk_` tokens, minted lazily
/// and renewed invisibly), so this class only encodes positions as GNUBG ids
/// and maps the generated response types onto `bg_engine`'s seam types.
///
/// One client is one opponent: its [level] (1..7, the service's calibrated
/// ladder) and per-match [seed] are fixed at construction. Service errors
/// (`ApiException`) propagate untouched -- the adapter's retry loop and
/// never-fabricate discipline live in `GnubgAiPlayer`, not here.
class SessionGnubgClient implements GnubgClient {
  /// Creates a leveled opponent over [_session]. [seed], when set, varies
  /// play between matches at the weakened levels (1-4) while keeping one
  /// match internally consistent; levels 5-7 ignore it.
  SessionGnubgClient(this._session, {required this.level, this.seed})
    : assert(level >= 1 && level <= 7, 'level must be 1..7');

  final GnubgSession _session;

  /// The opponent's strength on the service's calibrated 1..7 ladder.
  final int level;

  /// The per-match variety seed, or null for fully deterministic play.
  final int? seed;

  @override
  Future<GnubgPlayedMove> playMove(BgPosition position) async {
    final resp = await _session.playMove(
      _gnubgId(position, preRoll: false),
      level,
      seed: seed,
    );
    return GnubgPlayedMove(
      play: resp.play,
      hops: [for (final hop in resp.hops) GnubgHop(from: hop.from, to: hop.to)],
    );
  }

  @override
  Future<bool> playCube(BgPosition position) async {
    final resp = await _session.playCube(
      _gnubgId(position, preRoll: true),
      level,
      seed: seed,
    );
    return resp.double_;
  }

  @override
  Future<bool> playTake(BgPosition position) async {
    final resp = await _session.playTake(
      _gnubgId(position, preRoll: true),
      level,
      seed: seed,
    );
    return resp.take;
  }

  @override
  Future<GnubgResignStake> playResign(BgPosition position) async {
    final resp = await _session.playResign(
      _gnubgId(position, preRoll: true),
      level,
      seed: seed,
    );
    final stake = _resignStakes[resp.resign];
    if (stake == null) {
      // The generated enum gained a member this map doesn't know: fail
      // loudly (an Exception, so the adapter reports gnubg as unavailable
      // rather than a decision being silently misread).
      throw StateError('unknown resign stake: ${resp.resign}');
    }
    return stake;
  }

  @override
  void dispose() => _session.dispose();

  static const _resignStakes = {
    ResignStake.none: GnubgResignStake.none,
    ResignStake.single: GnubgResignStake.single,
    ResignStake.gammon: GnubgResignStake.gammon,
    ResignStake.backgammon: GnubgResignStake.backgammon,
  };

  // Encode [position] as the service's canonical "PositionID:MatchID" id.
  // [preRoll] encodes dice 0,0 -- the cube/take/resign decision point --
  // instead of the dice the position carries.
  static String _gnubgId(BgPosition position, {required bool preRoll}) {
    final dice = position.dice;
    final positionId = gnubgPositionId(position.board, position.onRoll);
    final cubeOwner = position.cubeOwner;
    final matchId = gnubgMatchId(
      die0: preRoll ? 0 : dice.first,
      die1: preRoll ? 0 : (dice.length > 1 ? dice[1] : dice.first),
      cubeValue: position.cubeValue,
      // Match-ID seat 0 is the on-roll side (the Position ID's perspective).
      cubeOwner: cubeOwner == null
          ? null
          : (cubeOwner == position.onRoll ? 0 : 1),
    );
    return '$positionId:$matchId';
  }
}

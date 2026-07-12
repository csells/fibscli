import 'package:bg_engine/bg_engine.dart';
import 'package:gnubg_service/gnubg_service.dart';

/// A [GnubgClient] backed by the gnubg-service's [GnubgSession]: the session
/// owns the generated OpenAPI client plus the attested session-token
/// lifecycle (publishable key + Turnstile -> `bg_tk_` tokens, minted lazily
/// and renewed invisibly), so this class only encodes positions as GNUBG ids
/// and maps the generated response types onto `bg_engine`'s seam types.
///
/// One client is one opponent: its [level] (1..7, the service's calibrated
/// ladder) and per-match [seed] are fixed at construction. The session itself
/// is normally app-scoped and shared across games ([ownsSession] false), since
/// one token covers hundreds of decisions -- re-minting is an hourly event, not
/// a per-game one.
///
/// Failures are classified, not swallowed: a refused credential (401/403 -- a
/// bad key, or a human check Cloudflare declined) and an exhausted key quota
/// (429) are PERMANENT, so they surface as [GnubgUnavailableException] and the
/// adapter shows them instead of retrying (a retry would only re-run the
/// challenge). Everything else -- an outage, a network blip -- stays an
/// `ApiException` the adapter retries.
class SessionGnubgClient implements GnubgClient {
  /// Creates a leveled opponent over [_session]. [seed], when set, varies
  /// play between matches at the weakened levels (1-4) while keeping one
  /// match internally consistent; levels 5-7 ignore it. [ownsSession] false
  /// (the app default) leaves the shared session open when this opponent is
  /// disposed at the end of a game.
  SessionGnubgClient(
    this._session, {
    required this.level,
    this.seed,
    this.ownsSession = true,
  }) : assert(level >= 1 && level <= 7, 'level must be 1..7');

  final GnubgSession _session;

  /// Whether disposing this client closes the session it was built with.
  final bool ownsSession;

  /// The opponent's strength on the service's calibrated 1..7 ladder.
  final int level;

  /// The per-match variety seed, or null for fully deterministic play.
  final int? seed;

  /// Mint the session token now (answering the human check, if Cloudflare
  /// wants one) so it does not interrupt a turn later.
  @override
  Future<void> prepare() => _classified(_session.ensureToken);

  @override
  Future<GnubgPlayedMove> playMove(BgPosition position) =>
      _classified(() async {
        final resp = await _session.playMove(
          _gnubgId(position, preRoll: false),
          level,
          seed: seed,
        );
        return GnubgPlayedMove(
          play: resp.play,
          hops: [
            for (final hop in resp.hops) GnubgHop(from: hop.from, to: hop.to),
          ],
        );
      });

  @override
  Future<bool> playCube(BgPosition position) => _classified(() async {
    final resp = await _session.playCube(
      _gnubgId(position, preRoll: true),
      level,
      seed: seed,
    );
    return resp.double_;
  });

  @override
  Future<bool> playTake(BgPosition position) => _classified(() async {
    final resp = await _session.playTake(
      _gnubgId(position, preRoll: true),
      level,
      seed: seed,
    );
    return resp.take;
  });

  @override
  Future<GnubgResignStake> playResign(BgPosition position) =>
      _classified(() async {
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
      });

  @override
  void dispose() {
    if (ownsSession) _session.dispose();
  }

  // Run [call], turning the service's PERMANENT refusals into
  // GnubgUnavailableException (which the adapter surfaces without retrying --
  // re-running a declined human check just re-prompts). Transient failures
  // pass through as the ApiException they are, and the adapter retries them.
  // The session already re-mints an expired token / exhausted token budget
  // internally, so a 401/429 that still reaches here is key-level.
  Future<T> _classified<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on ApiException catch (e) {
      throw switch (e.code) {
        401 || 403 => GnubgUnavailableException(
          'gnubg refused this session (the human check was declined, or the '
          'key is not valid for this site)',
          e,
        ),
        429 => GnubgUnavailableException(
          'the gnubg service quota is exhausted; try again later',
          e,
        ),
        _ => e,
      };
    }
  }

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

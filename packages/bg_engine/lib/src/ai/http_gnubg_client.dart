import 'dart:convert';

import 'package:http/http.dart' as http;

import 'bg_ai_player.dart';
import 'gnubg_ai_player.dart';
import 'gnubg_id.dart';

/// Thrown when the gnubg-service returns a non-success response.
class GnubgServiceError implements Exception {
  /// Creates an error for HTTP [statusCode] with the response [body].
  GnubgServiceError(this.statusCode, this.body);

  /// The HTTP status code returned by the service.
  final int statusCode;

  /// The (truncated) response body, for diagnostics.
  final String body;

  @override
  String toString() => 'GnubgServiceError($statusCode): $body';
}

/// A [GnubgClient] that talks to a gnubg-service over HTTP. It encodes the
/// position — checkers, dice, and cube state — to a GNUBG id
/// (`PositionID:MatchID`, both verified bit-exact against gnubg) and POSTs it
/// to the decision endpoints: `/v1/eval` for the checker play, `/v1/cube` for
/// the doubling decision, `/v1/resign` for resignation. Cube and resign
/// requests encode a pre-roll match id (dice 0,0) — gnubg judges both before
/// the roll. The request/response plumbing is covered by MockClient tests.
class HttpGnubgClient extends GnubgClient {
  /// Creates a client targeting [baseUrl]. [apiKey], when set, is sent as
  /// `Authorization: Bearer <key>` (the service's auth contract). [plies] is
  /// the gnubg evaluation depth. A custom [httpClient] can be injected (e.g. a
  /// mock in tests).
  HttpGnubgClient({
    required this.baseUrl,
    this.apiKey,
    this.plies = 2,
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The gnubg-service base URL (the `/v1/...` paths are appended).
  final Uri baseUrl;

  /// Optional API key, sent as `Authorization: Bearer <key>`.
  final String? apiKey;

  /// gnubg evaluation depth (plies).
  final int plies;

  /// Bound the wait on the service so a hung/half-open connection surfaces as a
  /// `TimeoutException` (an Exception the retry loop handles) rather than
  /// leaving the AI turn frozen forever.
  final Duration timeout;

  final http.Client _http;

  @override
  void dispose() => _http.close();

  @override
  Future<List<GnubgRankedMove>> evalMoves(BgPosition position) async {
    final decoded = await _postJson('/v1/eval', {
      'gnubg_id': _gnubgId(position, preRoll: false),
      'plies': plies,
    });
    return _parseRankedMoves(decoded);
  }

  @override
  Future<GnubgCubeDecision> cubeDecision(BgPosition position) async {
    final decoded = await _postJson('/v1/cube', {
      'gnubg_id': _gnubgId(position, preRoll: true),
      'plies': plies,
    });
    return _parseCubeDecision(decoded);
  }

  @override
  Future<GnubgResignDecision> resignDecision(
    BgPosition position, {
    int offered = 0,
  }) async {
    final decoded = await _postJson('/v1/resign', {
      'gnubg_id': _gnubgId(position, preRoll: true),
      'plies': plies,
      'offered': offered,
    });
    return _parseResignDecision(decoded);
  }

  // Encode [position] as the service's canonical "PositionID:MatchID" id.
  // [preRoll] encodes dice 0,0 -- the cube/resign decision point -- instead of
  // the dice the position carries.
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

  // POST [body] to [path] and return the decoded 200 JSON object. Any other
  // status, non-JSON body, or non-object body throws GnubgServiceError.
  Future<Map<String, dynamic>> _postJson(
    String path,
    Map<String, Object?> body,
  ) async {
    final resp = await _http
        .post(
          baseUrl.resolve(path),
          headers: {
            'content-type': 'application/json',
            if (apiKey != null) 'authorization': 'Bearer $apiKey',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);

    if (resp.statusCode != 200) {
      final respBody = resp.body;
      throw GnubgServiceError(
        resp.statusCode,
        respBody.length > 200 ? respBody.substring(0, 200) : respBody,
      );
    }

    // Validate the response against the expected schema explicitly, so a
    // valid-HTTP-but-wrong-shape body fails with a message that names the
    // offending field (not an opaque cast TypeError) -- and as a catchable
    // Exception, so the adapter's retry / GnubgUnavailableException path
    // handles it rather than an Error escaping `on Exception catch`.
    final Object? decoded;
    try {
      decoded = jsonDecode(resp.body);
    } on FormatException catch (e) {
      throw GnubgServiceError(resp.statusCode, 'body is not valid JSON: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw _schemaError('expected a JSON object, got ${decoded.runtimeType}');
    }
    return decoded;
  }

  // A wrong-shape body is always on an HTTP 200 (any other status threw
  // before parsing), so schema errors carry that status.
  static GnubgServiceError _schemaError(String message) =>
      GnubgServiceError(200, message);

  // [field] of [map] as a double, or a schema error naming the field.
  static double _numField(Map<String, dynamic> map, String field) {
    final value = map[field];
    if (value is! num) {
      throw _schemaError('"$field" must be a number, got ${value.runtimeType}');
    }
    return value.toDouble();
  }

  static List<GnubgRankedMove> _parseRankedMoves(Map<String, dynamic> decoded) {
    final rawMoves = decoded['moves'];
    if (rawMoves is! List) {
      throw _schemaError('"moves" must be a list, got ${rawMoves.runtimeType}');
    }
    final moves = <GnubgRankedMove>[];
    for (final raw in rawMoves) {
      if (raw is! Map<String, dynamic>) {
        throw _schemaError(
          'each move must be an object, got ${raw.runtimeType}',
        );
      }
      final play = raw['play'];
      if (play is! String) {
        throw _schemaError(
          'move "play" must be a string, got ${play.runtimeType}',
        );
      }
      final equity = raw['equity'];
      if (equity != null && equity is! num) {
        throw _schemaError(
          'move "equity" must be a number, got ${equity.runtimeType}',
        );
      }
      moves.add(
        GnubgRankedMove(
          play: play,
          hops: _parseHops(raw['hops']),
          equity: (equity as num?)?.toDouble() ?? 0,
        ),
      );
    }
    return moves;
  }

  // A move's "hops": a list of {from, to} integer pairs in the service's
  // mover-perspective numbering (see [GnubgHop]).
  static List<GnubgHop> _parseHops(Object? rawHops) {
    if (rawHops is! List) {
      throw _schemaError(
        'move "hops" must be a list, got ${rawHops.runtimeType}',
      );
    }
    final hops = <GnubgHop>[];
    for (final raw in rawHops) {
      if (raw is! Map<String, dynamic>) {
        throw _schemaError(
          'each hop must be an object, got ${raw.runtimeType}',
        );
      }
      hops.add(
        GnubgHop(from: _hopField(raw, 'from'), to: _hopField(raw, 'to')),
      );
    }
    return hops;
  }

  // [field] of a hop object as an int, or a schema error naming the field.
  static int _hopField(Map<String, dynamic> hop, String field) {
    final value = hop[field];
    if (value is! int) {
      throw _schemaError(
        'hop "$field" must be an integer, got ${value.runtimeType}',
      );
    }
    return value;
  }

  // The service's snake_case action strings (serde's rendering of its
  // CubeAction enum), mapped to the client-side enum.
  static const _cubeActions = {
    'no_double': GnubgCubeAction.noDouble,
    'double_take': GnubgCubeAction.doubleTake,
    'double_pass': GnubgCubeAction.doublePass,
    'too_good_to_double': GnubgCubeAction.tooGoodToDouble,
  };

  static GnubgCubeDecision _parseCubeDecision(Map<String, dynamic> decoded) {
    final action = decoded['action'];
    final mapped = action is String ? _cubeActions[action] : null;
    if (mapped == null) {
      throw _schemaError(
        '"action" must be one of ${_cubeActions.keys.join('|')}, got $action',
      );
    }
    return GnubgCubeDecision(
      action: mapped,
      cubelessEquity: _numField(decoded, 'cubeless_equity'),
      cubefulNoDouble: _numField(decoded, 'cubeful_nodouble'),
      cubefulDoubleTake: _numField(decoded, 'cubeful_double_take'),
      cubefulDoublePass: _numField(decoded, 'cubeful_double_pass'),
    );
  }

  static GnubgResignDecision _parseResignDecision(
    Map<String, dynamic> decoded,
  ) {
    final advice = decoded['resign_advice'];
    if (advice is! int || advice < 0 || advice > 3) {
      throw _schemaError(
        '"resign_advice" must be an integer 0..3, got $advice',
      );
    }
    final accept = decoded['accept'];
    if (accept is! bool?) {
      throw _schemaError(
        '"accept" must be a boolean, got ${accept.runtimeType}',
      );
    }
    return GnubgResignDecision(
      resignAdvice: advice,
      equityPlayOn: _numField(decoded, 'equity_play_on'),
      accept: accept,
    );
  }
}

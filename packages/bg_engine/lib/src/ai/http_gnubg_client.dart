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
/// position to a GNUBG id (`PositionID:MatchID`) and POSTs it to `/v1/eval`.
///
/// The Position ID is verified bit-exact against gnubg; full live verification
/// of the Match ID + auth is the documented gnubg follow-on (the service is a
/// private Cloud Run instance). The request/response plumbing is covered by a
/// MockClient test.
class HttpGnubgClient extends GnubgClient {
  /// Creates a client targeting [baseUrl]. [apiKey], when set, is sent as the
  /// `x-api-key` header. [plies] is the gnubg evaluation depth. A custom
  /// [httpClient] can be injected (e.g. a mock in tests).
  HttpGnubgClient({
    required this.baseUrl,
    this.apiKey,
    this.plies = 2,
    this.timeout = const Duration(seconds: 10),
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The gnubg-service base URL (the `/v1/eval` path is appended).
  final Uri baseUrl;

  /// Optional API key, sent as `x-api-key`.
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
    final dice = position.dice;
    final positionId = gnubgPositionId(position.board, position.onRoll);
    final matchId = gnubgMatchId(
      die0: dice.first,
      die1: dice.length > 1 ? dice[1] : dice.first,
    );
    final id = '$positionId:$matchId';

    final resp = await _http
        .post(
          baseUrl.resolve('/v1/eval'),
          headers: {
            'content-type': 'application/json',
            if (apiKey != null) 'x-api-key': apiKey!,
          },
          body: jsonEncode({'gnubg_id': id, 'plies': plies}),
        )
        .timeout(timeout);

    if (resp.statusCode != 200) {
      final body = resp.body;
      throw GnubgServiceError(
        resp.statusCode,
        body.length > 200 ? body.substring(0, 200) : body,
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
    return _parseRankedMoves(decoded, resp.statusCode);
  }

  List<GnubgRankedMove> _parseRankedMoves(Object? decoded, int status) {
    if (decoded is! Map<String, dynamic>) {
      throw GnubgServiceError(
        status,
        'expected a JSON object, got ${decoded.runtimeType}',
      );
    }
    final rawMoves = decoded['moves'];
    if (rawMoves is! List) {
      throw GnubgServiceError(
        status,
        '"moves" must be a list, got ${rawMoves.runtimeType}',
      );
    }
    final moves = <GnubgRankedMove>[];
    for (final raw in rawMoves) {
      if (raw is! Map<String, dynamic>) {
        throw GnubgServiceError(
          status,
          'each move must be an object, got ${raw.runtimeType}',
        );
      }
      final play = raw['play'];
      if (play is! String) {
        throw GnubgServiceError(
          status,
          'move "play" must be a string, got ${play.runtimeType}',
        );
      }
      final equity = raw['equity'];
      if (equity != null && equity is! num) {
        throw GnubgServiceError(
          status,
          'move "equity" must be a number, got ${equity.runtimeType}',
        );
      }
      moves.add(
        GnubgRankedMove(play: play, equity: (equity as num?)?.toDouble() ?? 0),
      );
    }
    return moves;
  }
}

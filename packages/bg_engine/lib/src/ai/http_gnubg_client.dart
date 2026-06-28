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
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// The gnubg-service base URL (the `/v1/eval` path is appended).
  final Uri baseUrl;

  /// Optional API key, sent as `x-api-key`.
  final String? apiKey;

  /// gnubg evaluation depth (plies).
  final int plies;

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

    final resp = await _http.post(
      baseUrl.resolve('/v1/eval'),
      headers: {
        'content-type': 'application/json',
        if (apiKey != null) 'x-api-key': apiKey!,
      },
      body: jsonEncode({'gnubg_id': id, 'plies': plies}),
    );

    if (resp.statusCode != 200) {
      final body = resp.body;
      throw GnubgServiceError(
        resp.statusCode,
        body.length > 200 ? body.substring(0, 200) : body,
      );
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final moves = json['moves'] as List<dynamic>? ?? const [];
    return [
      for (final m in moves.cast<Map<String, dynamic>>())
        GnubgRankedMove(
          play: m['play'] as String,
          equity: (m['equity'] as num?)?.toDouble() ?? 0.0,
        ),
    ];
  }
}

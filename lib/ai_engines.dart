import 'package:bg_engine/bg_engine.dart';

/// The gnubg engine factory for [serviceUrl], or null when no URL is configured
/// -- so the third engine is offered only when a gnubg-service is actually
/// reachable. [apiKey], when non-empty, is sent to the service as `x-api-key`.
///
/// bootstrap reads the URL/key from --dart-define (gnubg_service_url /
/// gnubg_api_key) and registers the result with the [AiRegistry].
GnubgAiPlayerFactory? gnubgFactoryFor(String serviceUrl, {String apiKey = ''}) {
  if (serviceUrl.isEmpty) return null;
  final url = Uri.parse(serviceUrl);
  return GnubgAiPlayerFactory(
    () => HttpGnubgClient(baseUrl: url, apiKey: apiKey.isEmpty ? null : apiKey),
  );
}

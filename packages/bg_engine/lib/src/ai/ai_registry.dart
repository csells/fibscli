import 'package:collection/collection.dart';

import 'bg_ai_player.dart';
import 'pubeval_ai_player.dart';

/// The set of AI engines the app can offer. Ships with the built-in
/// [PubevalAiPlayer]; the host app registers additional engines (e.g. the
/// `backgammon_ai` package, or a gnubg-service adapter) at startup, and the UI
/// lists [available] for the user to pick from.
class AiRegistry {
  AiRegistry._();

  static final List<BgAiPlayerFactory> _factories = [PubevalAiPlayerFactory()];

  /// Register an engine. A later registration with the same `name` replaces the
  /// earlier one (so the app can override a built-in).
  static void register(BgAiPlayerFactory factory) {
    _factories.removeWhere((f) => f.name == factory.name);
    _factories.add(factory);
  }

  /// The registered engines, in registration order (pubeval first).
  static List<BgAiPlayerFactory> get available => List.unmodifiable(_factories);

  /// The factory with the given [name], or null if none is registered.
  static BgAiPlayerFactory? byName(String name) =>
      _factories.firstWhereOrNull((f) => f.name == name);
}

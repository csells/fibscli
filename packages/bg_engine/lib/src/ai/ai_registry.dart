import 'package:collection/collection.dart';

import 'bg_ai_player.dart';

/// The set of AI engines the app can offer. Empty until the host app registers
/// its engines at startup; the UI lists [available] for the user to pick from.
class AiRegistry {
  AiRegistry._();

  static final List<BgAiPlayerFactory> _factories = <BgAiPlayerFactory>[];

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

  /// Remove every registered engine (test isolation between cases).
  static void clear() => _factories.clear();
}

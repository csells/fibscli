import 'rules.dart';

/// A typed view over the 26-point board (`List<List<int>>`), giving the raw
/// list a named, domain-meaningful interface: which player owns a point, how
/// many checkers sit there, etc. -- instead of every caller re-deriving that
/// from bare indices and the sign convention.
///
/// It's a Dart 3 [extension type] that `implements List<List<int>>`, so it's
/// **zero-cost** (erases to the underlying list at runtime) and a drop-in
/// anywhere a `List<List<int>>` is expected. The board's representation is
/// unchanged: index 0 = player-one off / player-two bar, 1..24 = points,
/// index 25 = player-one bar / player-two off; each inner list holds signed
/// piece IDs (negative = player one), the magnitude being a stable per-checker
/// id used for animation tracking.
extension type GammonBoard(List<List<int>> points) implements List<List<int>> {
  /// The signed piece IDs on [pip].
  List<int> checkersAt(int pip) => points[pip];

  /// How many checkers sit on [pip].
  int countAt(int pip) => points[pip].length;

  /// Whether [pip] holds no checkers.
  bool isVacantAt(int pip) => points[pip].isEmpty;

  /// The player owning the checkers on [pip], or null when it's empty. A point
  /// only ever holds one player's checkers, so the first checker decides it.
  GammonPlayer? ownerAt(int pip) =>
      points[pip].isEmpty ? null : GammonRules.playerFor(points[pip].first);
}

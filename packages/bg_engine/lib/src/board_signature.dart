import 'rules.dart';

/// A position fingerprint independent of piece ids: the net signed checker
/// count per pip (negative = player one, positive = player two), joined into a
/// string. Two positions have the same signature iff the same checkers sit on
/// the same pips. One shared definition for both the transposition pruning in
/// turn enumeration and the memo keys in the exact race solver, so they can't
/// drift apart.
String netSignature(List<List<int>> board) {
  final sb = StringBuffer();
  for (final pip in board) {
    var net = 0;
    for (final id in pip) {
      net += GammonRules.playerFor(id) == GammonPlayer.one ? -1 : 1;
    }
    sb
      ..write(net)
      ..write(',');
  }
  return sb.toString();
}

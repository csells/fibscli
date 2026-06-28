import 'package:fibscli/model.dart';

/// Builds a 26-pip board from a concise spec.
///
/// Keys are pip numbers (0..25, matching the model's indexing where 0 ==
/// player1 off / player2 bar and 25 == player1 bar / player2 home). Values are
/// signed piece counts: a negative value places that many player1 pieces
/// (negative ids), a positive value places that many player2 pieces (positive
/// ids). Piece ids are generated uniquely per player so identity-based logic
/// keeps working.
List<List<int>> makeBoard(Map<int, int> spec) {
  final board = List<List<int>>.generate(26, (_) => <int>[]);
  var p1 = 0;
  var p2 = 0;
  for (final entry in spec.entries) {
    final pip = entry.key;
    final count = entry.value;
    if (count < 0) {
      for (var i = 0; i != -count; ++i) {
        ++p1;
        board[pip].add(-p1);
      }
    } else {
      for (var i = 0; i != count; ++i) {
        board[pip].add(++p2);
      }
    }
  }
  return board;
}

/// Convenience for asserting which pips a player occupies.
List<int> pipsOccupiedBy(List<List<int>> board, GammonPlayer player) => [
  for (var pip = 0; pip != board.length; ++pip)
    if (board[pip].any((id) => GammonRules.playerFor(id) == player)) pip,
];

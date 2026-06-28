import '../rules.dart';

// GNU Backgammon's base64 alphabet (standard order).
const _b64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

/// Encode [board] into a GNU Backgammon **Position ID** from [onRoll]'s
/// perspective (the 14-character string gnubg uses, e.g. the opening position
/// is `4HPwATDgc/ABMA`).
///
/// The key is built as gnubg's `PositionKey`: for each side (on-roll first,
/// then opponent), for each of that side's 25 points (point 0 = the ace point,
/// … point 23 = the 24-point, point 24 = the bar) write `count` 1-bits followed
/// by a 0 separator, packed LSB-first into 10 bytes; those bytes are then
/// emitted in gnubg's 9-bytes-as-base64 + final-byte-as-2-chars form.
String gnubgPositionId(List<List<int>> board, GammonPlayer onRoll) {
  final sides = [
    _sideCounts(board, onRoll),
    _sideCounts(board, GammonRules.otherPlayer(onRoll)),
  ];

  final key = List<int>.filled(10, 0);
  var bit = 0;
  for (final side in sides) {
    for (final count in side) {
      for (var n = 0; n < count; n++) {
        key[bit >> 3] |= 1 << (bit & 7);
        bit++;
      }
      bit++; // 0 separator
    }
  }

  final sb = StringBuffer();
  for (var i = 0; i < 3; i++) {
    final o = i * 3;
    sb.write(_b64[key[o] >> 2]);
    sb.write(_b64[((key[o] & 0x03) << 4) | (key[o + 1] >> 4)]);
    sb.write(_b64[((key[o + 1] & 0x0F) << 2) | (key[o + 2] >> 6)]);
    sb.write(_b64[key[o + 2] & 0x3F]);
  }
  sb.write(_b64[key[9] >> 2]);
  sb.write(_b64[(key[9] & 0x03) << 4]);
  return sb.toString();
}

// The 25 checker counts for [player] in gnubg's own-perspective point order:
// index 0 = the player's ace point, … index 23 = their 24-point, index 24 =
// their bar.
List<int> _sideCounts(List<List<int>> board, GammonPlayer player) {
  final counts = List<int>.filled(25, 0);
  for (var k = 0; k < 24; k++) {
    // gnubg point k (0-based) is the player's (k+1)-point; map to the engine
    // pip: player one counts up from pip 1, player two counts down from pip 24.
    final pip = player == GammonPlayer.one ? k + 1 : 24 - k;
    counts[k] = _countFor(board[pip], player);
  }
  counts[24] = _countFor(board[GammonRules.barPipNoFor(player)], player);
  return counts;
}

int _countFor(List<int> point, GammonPlayer player) {
  var n = 0;
  for (final id in point) {
    if (GammonRules.playerFor(id) == player) n++;
  }
  return n;
}

/// Encode a GNU Backgammon **Match ID** for a cubeless money-game position that
/// is mid-play with [die0]/[die1] showing (cube centred at 1, no crawford, no
/// resignation, scores 0-0). gnubg needs this alongside the Position ID so it
/// evaluates the right roll.
///
/// NOTE: the Position ID encoder is verified bit-exact against gnubg; this
/// Match-ID field layout is implemented from the published spec but its exact
/// bytes are only fully verified once run against live gnubg (the documented
/// gnubg follow-on). The dice/cube/state it carries are correct by construction.
String gnubgMatchId({required int die0, required int die1}) {
  final bits = <int>[];
  void put(int value, int width) {
    for (var i = 0; i < width; i++) {
      bits.add((value >> i) & 1);
    }
  }

  put(0, 4); // cube value: log2(1) = 0
  put(3, 2); // cube owner: 3 == centred
  put(0, 1); // player on move (side 0 == the on-roll side of the Position ID)
  put(0, 1); // crawford game: no
  put(1, 3); // game state: 1 == playing
  put(0, 1); // player on turn: side 0
  put(0, 1); // double offered: no
  put(0, 2); // resignation: none
  put(die0, 3); // dice die 0
  put(die1, 3); // dice die 1
  put(0, 15); // match length: 0 == money game
  put(0, 15); // player 0 score
  put(0, 15); // player 1 score

  final bytes = List<int>.filled(9, 0);
  for (var i = 0; i < bits.length; i++) {
    if (bits[i] == 1) bytes[i >> 3] |= 1 << (i & 7);
  }
  final sb = StringBuffer();
  for (var i = 0; i < 9; i += 3) {
    sb.write(_b64[bytes[i] >> 2]);
    sb.write(_b64[((bytes[i] & 0x03) << 4) | (bytes[i + 1] >> 4)]);
    sb.write(_b64[((bytes[i + 1] & 0x0F) << 2) | (bytes[i + 2] >> 6)]);
    sb.write(_b64[bytes[i + 2] & 0x3F]);
  }
  return sb.toString();
}

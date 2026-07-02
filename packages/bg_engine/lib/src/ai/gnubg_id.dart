import 'dart:math';

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
    counts[k] = GammonRules.countAt(board, pip, player);
  }
  counts[24] = GammonRules.countAt(
    board,
    GammonRules.barPipNoFor(player),
    player,
  );
  return counts;
}

/// Encode a GNU Backgammon **Match ID**: the 12-character companion to the
/// Position ID that carries the match state gnubg evaluates under — dice,
/// cube, whose roll it is, crawford, jacoby, match length and scores. The
/// bit layout is gnubg's `MatchID()` (matchid.c) and every field here is
/// verified bit-exact against live gnubg 1.08.003 (see `gnubg_id_test.dart`).
///
/// Players are gnubg's two seats, 0 and 1; [onRoll] names the seat on roll,
/// which is also the perspective the companion Position ID must be encoded
/// from. [score0]/[score1] are the seats' match scores and [cubeOwner] is the
/// seat holding the cube (null = centred). The state is always mid-game
/// ("playing", no double pending, no resignation on the table): cube and
/// resignation *decisions* are carried by the gnubg-service request, not the
/// id.
///
/// [die0]/[die1] are the roll to play; pass 0,0 for a pre-roll state (a cube
/// decision point). gnubg's canonical id always carries the higher die first,
/// so the pair is normalized to that order here. [jacoby] is the money-session
/// Jacoby rule and only exists when [matchLength] is 0 (a money session);
/// gnubg encodes a match as jacoby-off regardless, and so does this.
String gnubgMatchId({
  required int die0,
  required int die1,
  int cubeValue = 1,
  int? cubeOwner,
  int onRoll = 0,
  bool crawford = false,
  bool jacoby = false,
  int matchLength = 0,
  int score0 = 0,
  int score1 = 0,
}) {
  assert(die0 >= 0 && die0 <= 6 && die1 >= 0 && die1 <= 6, 'dice must be 0..6');
  assert(
    (die0 == 0) == (die1 == 0),
    'dice must be both set (rolled) or both 0 (pre-roll)',
  );
  assert(onRoll == 0 || onRoll == 1, 'onRoll must be seat 0 or 1');
  assert(
    cubeOwner == null || cubeOwner == 0 || cubeOwner == 1,
    'cubeOwner must be seat 0, seat 1, or null (centred)',
  );
  assert(
    cubeValue >= 1 && cubeValue <= 0x8000 && (cubeValue & (cubeValue - 1)) == 0,
    'cubeValue must be a power of two',
  );
  assert(
    matchLength >= 0 && matchLength <= 0x7fff,
    'matchLength must fit in 15 bits (0 == money session)',
  );
  assert(
    score0 >= 0 && score0 <= 0x7fff && score1 >= 0 && score1 <= 0x7fff,
    'scores must fit in 15 bits',
  );

  final bits = <int>[];
  void put(int value, int width) {
    for (var i = 0; i < width; i++) {
      bits.add((value >> i) & 1);
    }
  }

  put(cubeValue.bitLength - 1, 4); // cube value as log2
  put(cubeOwner ?? 3, 2); // cube owner seat; 3 == centred
  put(onRoll, 1); // seat on roll (gnubg's fMove)
  put(crawford ? 1 : 0, 1); // crawford game
  put(1, 3); // game state: 1 == playing
  put(onRoll, 1); // seat to act (fTurn) == the seat on roll
  put(0, 1); // double offered: no
  put(0, 2); // resignation: none
  put(max(die0, die1), 3); // dice, higher die first (gnubg's canonical order)
  put(min(die0, die1), 3);
  put(matchLength, 15); // match length: 0 == money session
  put(score0, 15); // seat 0 score
  put(score1, 15); // seat 1 score
  // gnubg's trailing Jacoby bit is inverted for backward compatibility
  // (0 == Jacoby in effect) and a match is always encoded jacoby-off.
  put(matchLength == 0 && jacoby ? 0 : 1, 1);

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

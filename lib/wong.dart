// based on https://bkgm.com/rgb/rgb.cgi?view+593
// ported from C to Dart
/*
 * Code for checking the legality of a backgammon move.
 *
 * by Gary Wong, 1997-8.
 *
 * Takes a starting position, ending position and dice roll as input,
 * and as output tells you whether the "move" to the end position was
 * legal, and if so, gives a chequer-by-chequer description of what the
 * move was.
 *
 * Boards are represented as arrays of 28 ints for the 24 points (0 is
 * the opponent's bar; 1 to 24 are the board points from the point of
 * view of the player moving; 25 is the player's bar; 26 is the player's
 * home and 27 is the opponent's home (unused)).  The player's chequers
 * are represented by positive integers and the opponent's by negatives.
 * This is compatible with FIBS or pubeval or something like that, I
 * forget who I originally stole it from :-)  The dice roll is an array of
 * 2 integers.  The function returns true if the move is legal (and fills
 * in the move array with up to 4 moves, as source/destination pairs),
 * and zero otherwise.  For instance, playing an opening 13 as 8/5 6/5
 * would be represented as:

 anBoardPre[] = { 0 -2 0 0 0 0 5 0 3 0 0 0 -5 5 0 0 0 -3 0 -5 0 0 0 0 2 0 0 0 }
anBoardPost[] = { 0 -2 0 0 0 2 4 0 2 0 0 0 -5 5 0 0 0 -3 0 -5 0 0 0 0 2 0 0 0 }
     anRoll[] = { 1 3 }

 * and LegalMove( anBoardPre, anBoardPost, anRoll, anMove ) would return true
 * and set anMove[] to { 8 5 6 5 0 0 0 0 }.
 */
import 'package:flutter/foundation.dart';

class _moveData {
  int fFound;
  int cMaxMoves;
  int cMaxPips;
  int cMoves;
  int cPips;
  List<int> anBoard;
  List<int> anRoll;
  List<int> anMove;
}

void _applyMove(List<int> anBoard, int iSrc, int nRoll) {
  var iDest = iSrc - nRoll;
  if (iDest < 1) iDest = 26;

  anBoard[iSrc]--;

  if (anBoard[iDest] < 0) {
    anBoard[iDest] = 1;
    anBoard[0]++;
  } else {
    anBoard[iDest]++;
  }
}

int _equalBoard(List<int> an0, List<int> an1) {
  for (var i = 0; i < 28; i++) if (an0[i] != an1[i]) return 0;
  return 1;
}

int _canMove(List<int> anBoard, int iSrc, int nPips) {
  var nBack = 0;
  final iDest = iSrc - nPips;

  if (iDest > 0) return (anBoard[iDest] >= -1) ? 1 : 0;

  for (var i = 1; i < 26; i++) if (anBoard[i] > 0) nBack = i;
  return (nBack <= 6 && (iSrc == nBack || iDest == 0)) ? 1 : 0;
}

void _saveMoves(int cMoves, int cPips, List<int> anBoard, List<int> anMove, _moveData pmd) {
  assert(anBoard.length == 28);
  assert(anMove.length == 8);

  if (cMoves < pmd.cMaxMoves || cPips < pmd.cMaxPips) return;

  pmd.cMaxMoves = cMoves;
  pmd.cMaxPips = cPips;

  if (_equalBoard(anBoard, pmd.anBoard) != 0) {
    pmd.fFound = 1;
    pmd.cMoves = cMoves;
    pmd.cPips = cPips;

    for (var i = 0; i < 8; i++) {
      pmd.anMove[i] = i < cMoves * 2 ? anMove[i] : 0;
    }
  } else if (pmd.cMaxMoves > pmd.cMoves || pmd.cMaxPips > pmd.cPips) {
    pmd.fFound = 0;
  }
}

int _generateMoves(List<int> anBoard, int nMoveDepth, int iPip, int cPip, List<int> anMove, _moveData pmd) {
  assert(anBoard.length == 28);
  assert(anMove.length == 8);
  var fUsed = 0;

  final anBoardNew = List<int>.filled(28, 0);

  if (nMoveDepth > 3 || pmd.anRoll[nMoveDepth] == 0) return -1;

  if (anBoard[25] != 0) {
    if (anBoard[25 - pmd.anRoll[nMoveDepth]] <= -2) return -1;

    anMove[nMoveDepth * 2] = 25;
    anMove[nMoveDepth * 2 + 1] = 25 - pmd.anRoll[nMoveDepth];

    for (var i = 0; i < 28; i++) anBoardNew[i] = anBoard[i];
    _applyMove(anBoardNew, 25, pmd.anRoll[nMoveDepth]);

    if (_generateMoves(anBoardNew, nMoveDepth + 1, 24, cPip + pmd.anRoll[nMoveDepth], anMove, pmd) != 0) {
      _saveMoves(nMoveDepth + 1, cPip + pmd.anRoll[nMoveDepth], anBoardNew, anMove, pmd);
    }

    return 0;
  } else {
    for (var i = iPip; i != 0; i--)
      if (anBoard[i] > 0 && _canMove(anBoard, i, pmd.anRoll[nMoveDepth]) != 0) {
        anMove[nMoveDepth * 2] = i;
        anMove[nMoveDepth * 2 + 1] = i - pmd.anRoll[nMoveDepth];

        if (anMove[nMoveDepth * 2 + 1] < 1) anMove[nMoveDepth * 2 + 1] = 26;

        for (var iCopy = 0; iCopy < 28; iCopy++) anBoardNew[iCopy] = anBoard[iCopy];
        _applyMove(anBoardNew, i, pmd.anRoll[nMoveDepth]);

        if (_generateMoves(
              anBoardNew,
              nMoveDepth + 1,
              pmd.anRoll[0] == pmd.anRoll[1] ? i : 24,
              cPip + pmd.anRoll[nMoveDepth],
              anMove,
              pmd,
            ) !=
            0) {
          _saveMoves(nMoveDepth + 1, cPip + pmd.anRoll[nMoveDepth], anBoardNew, anMove, pmd);
        }

        fUsed = 1;
      }
  }

  return fUsed != 0 ? 0 : -1;
}

int _legalMove(List<int> anBoardPre, List<int> anBoardPost, List<int> anRoll, List<int> anMove) {
  assert(anBoardPre != null);
  assert(anBoardPost != null);
  assert(anBoardPre.length == 28);
  assert(anBoardPost.length == 28);
  assert(anRoll.length == 2);
  assert(anMove.length == 8);

  final md = _moveData();
  final anMoveTemp = List<int>.filled(8, 0);
  final anRollRaw = List<int>.filled(4, 0);

  md.fFound = md.cMaxMoves = md.cMaxPips = md.cMoves = md.cPips = 0;
  md.anBoard = anBoardPost;
  md.anRoll = anRollRaw;
  md.anMove = anMove;

  anRollRaw[0] = anRoll[0];
  anRollRaw[1] = anRoll[1];
  anRollRaw[2] = anRollRaw[3] = (anRoll[0] == anRoll[1]) ? anRoll[0] : 0;

  var fLegalMoves = _generateMoves(anBoardPre, 0, 24, 0, anMoveTemp, md) == 0 ? 1 : 0;

  if (anRoll[0] != anRoll[1]) {
    // fixed: bug from original source
    var temp = anRollRaw[0];
    anRollRaw[0] = anRoll[1];
    anRollRaw[1] = temp;

    fLegalMoves |= _generateMoves(anBoardPre, 0, 24, 0, anMoveTemp, md) == 0 ? 1 : 0;
  }

  if (fLegalMoves == 0) {
    for (var i = 0; i < 8; i++) anMove[i] = 0;
    return _equalBoard(anBoardPre, anBoardPost);
  }

  return md.fFound;
}

/// given pre and post boards in Wong format with a roll, calculates the legal moves to get there
List<int> getLegalMoves({
  @required List<int> boardPre,
  @required List<int> boardPost,
  @required List<int> roll,
}) {
  final moves = List<int>.filled(8, 0);
  final result = _legalMove(boardPre, boardPost, roll, moves) != 0;
  return result ? moves : null;
}

/// giving a board and a set of moves in Wong format and a roll, calculates the legal board post-move
/// NOTE: this assumes player1 (black) and doesn't work for player2 (white)
List<int> checkLegalMoves({
  @required List<int> board,
  @required List<int> roll,
  @required List<int> moves,
}) {
  assert(board != null);
  assert(moves != null);
  assert(roll.length == 2);

  // create the raw roll (expand to 4 rolls for doubles)
  final rawRoll = List<int>.from(roll);
  if (roll[0] == roll[1]) rawRoll.addAll(roll);

  // possible to have dice you can't use (but oves are in pairs...)
  assert(rawRoll.length * 2 >= moves.length);

  // create the post-moves board
  final boardPost = List<int>.from(board);
  for (var i = 0; i != moves.length; i += 2) {
    if (moves[i] == 0) continue;
    var dest = moves[i] - roll[i ~/ 2];
    if (dest < 1) dest = 26;
    assert(dest == moves[i + 1]);
    _applyMove(boardPost, moves[i], rawRoll[i ~/ 2]);
  }

  final result = getLegalMoves(boardPre: board, boardPost: boardPost, roll: roll);
  return result != null ? boardPost : null;
}

/*
 * Wong boards are represented as arrays of 28 ints for the 24 points (0 is
 * the opponent's bar; 1 to 24 are the board points from the point of
 * view of the player moving; 25 is the player's bar; 26 is the player's
 * home and 27 is the opponent's home). The player's chequers
 * are represented by positive integers and the opponent's by negatives.
 * 
 * Model boards are represented as a list of lists of piece IDs, from 1-15,
 * negative in the case of player1 and positive in the case of player2.
 * Pip 0 is player1's home and player2's bar.
 * Pip 1-24 are board points.
 * Pip 25 is player's bar and player2's home.
*/

List<List<int>> toModel(List<int> wongBoard) {
  assert(wongBoard.length == 28);

  final modelBoard = List<List<int>>.generate(26, (i) => <int>[]);
  var p1pip = 15;
  var p2pip = 1;

  // player1 home
  for (var i = 0; i != wongBoard[26]; ++i) {
    modelBoard[0].add(-p1pip);
    p1pip--;
  }

  // player2 home
  for (var i = 0; i != wongBoard[27]; ++i) {
    modelBoard[25].add(p2pip);
    p2pip++;
  }

  // player1 bar
  for (var i = 0; i != wongBoard[25]; ++i) {
    modelBoard[25].add(-p1pip);
    p1pip--;
  }

  // player2 bar
  for (var i = 0; i != wongBoard[0]; ++i) {
    modelBoard[0].add(p2pip);
    p2pip++;
  }

  // board points
  for (var j = 1; j != 25; j++) {
    var count = wongBoard[j].abs();
    var player1 = wongBoard[j].sign == 1;
    for (var i = 0; i != count; ++i) {
      if (player1) {
        modelBoard[j].add(-p1pip);
        p1pip--;
      } else {
        modelBoard[j].add(p2pip);
        p2pip++;
      }
    }
  }

  assert(p1pip == 0);
  assert(p2pip == 16);
  return modelBoard;
}

List<int> fromModel(List<List<int>> modelBoard) {
  assert(modelBoard.length == 26);

  final wongBoard = List<int>.filled(28, 0);

  // player1 home
  wongBoard[26] = modelBoard[0].where((pid) => pid < 0).length;

  // player2 home
  wongBoard[27] = modelBoard[25].where((pid) => pid > 0).length;

  // player1 bar
  wongBoard[25] = modelBoard[25].where((pid) => pid < 0).length;

  // player2 bar
  wongBoard[0] = modelBoard[0].where((pid) => pid > 0).length;

  // board points
  for (var j = 1; j != 25; j++) {
    final count = modelBoard[j].length;
    if (count == 0) continue;

    final player1 = modelBoard[j][0] < 0;
    wongBoard[j] = player1 ? count : -count;
  }

  if (kDebugMode) {
    var p1pips = wongBoard[26] + wongBoard[25];
    var p2pips = wongBoard[27] + wongBoard[0];
    for (var j = 1; j != 25; j++) {
      final player1 = wongBoard[j] > 0;
      if (player1) {
        p1pips += wongBoard[j];
      } else {
        p2pips += wongBoard[j].abs(); // could be 0
      }
    }
    assert(p1pips == 15);
    assert(p2pips == 15);
  }

  return wongBoard;
}

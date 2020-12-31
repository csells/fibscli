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
class movedata {
  int fFound, cMaxMoves, cMaxPips, cMoves, cPips;
  List<int> anBoard;
  List<int> anRoll;
  List<int> anMove;
}

void ApplyMove(List<int> anBoard, int iSrc, int nRoll) {
  int iDest = iSrc - nRoll;

  if (iDest < 1) iDest = 26;

  anBoard[iSrc]--;

  if (anBoard[iDest] < 0) {
    anBoard[iDest] = 1;
    anBoard[0]++;
  } else
    anBoard[iDest]++;
}

int EqualBoard(List<int> an0, List<int> an1) {
  int i;

  for (i = 0; i < 28; i++) if (an0[i] != an1[i]) return 0;

  return 1;
}

int CanMove(List<int> anBoard, int iSrc, int nPips) {
  int i, nBack = 0, iDest = iSrc - nPips;

  if (iDest > 0) return (anBoard[iDest] >= -1) ? 1 : 0;

  for (i = 1; i < 26; i++) if (anBoard[i] > 0) nBack = i;

  return (nBack <= 6 && (iSrc == nBack || iDest == 0)) ? 1 : 0;
}

void SaveMoves(int cMoves, int cPips, List<int> anBoard, List<int> anMove, movedata pmd) {
  assert(anBoard.length == 28);
  assert(anMove.length == 8);

  int i;

  if (cMoves < pmd.cMaxMoves || cPips < pmd.cMaxPips) return;

  pmd.cMaxMoves = cMoves;
  pmd.cMaxPips = cPips;

  if (EqualBoard(anBoard, pmd.anBoard) != 0) {
    pmd.fFound = 1;
    pmd.cMoves = cMoves;
    pmd.cPips = cPips;

    for (i = 0; i < 8; i++) pmd.anMove[i] = i < cMoves * 2 ? anMove[i] : 0;
  } else if (pmd.cMaxMoves > pmd.cMoves || pmd.cMaxPips > pmd.cPips) pmd.fFound = 0;
}

int GenerateMoves(List<int> anBoard, int nMoveDepth, int iPip, int cPip, List<int> anMove, movedata pmd) {
  assert(anBoard.length == 28);
  assert(anMove.length == 8);
  int i, iCopy, fUsed = 0;

  var anBoardNew = List<int>.filled(28, 0);

  if (nMoveDepth > 3 || pmd.anRoll[nMoveDepth] == 0) return -1;

  if (anBoard[25] != 0) {
    if (anBoard[25 - pmd.anRoll[nMoveDepth]] <= -2) return -1;

    anMove[nMoveDepth * 2] = 25;
    anMove[nMoveDepth * 2 + 1] = 25 - pmd.anRoll[nMoveDepth];

    for (i = 0; i < 28; i++) anBoardNew[i] = anBoard[i];

    ApplyMove(anBoardNew, 25, pmd.anRoll[nMoveDepth]);

    if (GenerateMoves(anBoardNew, nMoveDepth + 1, 24, cPip + pmd.anRoll[nMoveDepth], anMove, pmd) != 0)
      SaveMoves(nMoveDepth + 1, cPip + pmd.anRoll[nMoveDepth], anBoardNew, anMove, pmd);

    return 0;
  } else {
    for (i = iPip; i != 0; i--)
      if (anBoard[i] > 0 && CanMove(anBoard, i, pmd.anRoll[nMoveDepth]) != 0) {
        anMove[nMoveDepth * 2] = i;
        anMove[nMoveDepth * 2 + 1] = i - pmd.anRoll[nMoveDepth];

        if (anMove[nMoveDepth * 2 + 1] < 1) anMove[nMoveDepth * 2 + 1] = 26;

        for (iCopy = 0; iCopy < 28; iCopy++) anBoardNew[iCopy] = anBoard[iCopy];

        ApplyMove(anBoardNew, i, pmd.anRoll[nMoveDepth]);

        if (GenerateMoves(
              anBoardNew,
              nMoveDepth + 1,
              pmd.anRoll[0] == pmd.anRoll[1] ? i : 24,
              cPip + pmd.anRoll[nMoveDepth],
              anMove,
              pmd,
            ) !=
            0) SaveMoves(nMoveDepth + 1, cPip + pmd.anRoll[nMoveDepth], anBoardNew, anMove, pmd);

        fUsed = 1;
      }
  }

  return fUsed != 0 ? 0 : -1;
}

int LegalMove(List<int> anBoardPre, List<int> anBoardPost, List<int> anRoll, List<int> anMove) {
  assert(anBoardPre.length == 28);
  assert(anBoardPost.length == 28);
  assert(anRoll.length == 2);
  assert(anMove.length == 8);

  var md = movedata();
  int i;
  var anMoveTemp = List<int>.filled(8, 0);
  var anRollRaw = List<int>.filled(4, 0);
  int fLegalMoves;

  md.fFound = md.cMaxMoves = md.cMaxPips = md.cMoves = md.cPips = 0;
  md.anBoard = anBoardPost;
  md.anRoll = anRollRaw;
  md.anMove = anMove;

  anRollRaw[0] = anRoll[0];
  anRollRaw[1] = anRoll[1];

  anRollRaw[2] = anRollRaw[3] = (anRoll[0] == anRoll[1]) ? anRoll[0] : 0;

  fLegalMoves = GenerateMoves(anBoardPre, 0, 24, 0, anMoveTemp, md) == 0 ? 1 : 0;

  if (anRoll[0] != anRoll[1]) {
    var temp = anRollRaw[0];
    anRollRaw[0] = anRoll[1];
    anRollRaw[1] = temp;

    fLegalMoves |= GenerateMoves(anBoardPre, 0, 24, 0, anMoveTemp, md) == 0 ? 1 : 0;
  }

  if (fLegalMoves == 0) {
    for (i = 0; i < 8; i++) anMove[i] = 0;

    return EqualBoard(anBoardPre, anBoardPost);
  }

  return md.fFound;
}

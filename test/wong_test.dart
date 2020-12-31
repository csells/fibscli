import 'package:fibscli/model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fibscli/wong.dart' as wong;

void main() {
  test('wong.getLegalMoves: simple', () {
    // Playing an opening 13 as 8/5 6/5:
    final boardPre = [0, -2, 0, 0, 0, 0, 5, 0, 3, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final boardPost = [0, -2, 0, 0, 0, 2, 4, 0, 2, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final roll = [1, 3];

    // get the legal move(s)
    final moves = wong.getLegalMoves(boardPre: boardPre, boardPost: boardPost, roll: roll);

    // LegalMove( boardPre, boardPost, roll, anMove ) would return true
    // anMove[] would be set to { 8 5 6 5 0 0 0 0 }
    expect(moves, [8, 5, 6, 5, 0, 0, 0, 0]);
  });

  test('wong.checkLegalMoves: simple', () {
    // Playing an opening 13 as 8/5 6/5:
    final boardPre = [0, -2, 0, 0, 0, 0, 5, 0, 3, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final boardPost = [0, -2, 0, 0, 0, 2, 4, 0, 2, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final roll = [3, 1];
    final sources = [8, 6];

    // check if moves are legal
    final board = wong.checkLegalMoves(board: boardPre, sources: sources, roll: roll);
    expect(board, boardPost);
  });

  test('wong.getLegalMoves: legal bearoff', () {
    final boardPre = [0, -2, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final boardPost = [0, -2, 0, 0, 0, 0, 14, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 1, 0];
    final roll = [6, 5];

    final moves = wong.getLegalMoves(boardPre: boardPre, boardPost: boardPost, roll: roll);
    expect(moves, [6, 26, 0, 0, 0, 0, 0, 0]);
  });

  test('wong.checkLegalMoves: legal bearoff', () {
    final boardPre = [0, -2, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final boardPost = [0, -2, 0, 0, 0, 0, 14, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 1, 0];
    final roll = [6, 5];
    final sources = [6];

    final board = wong.checkLegalMoves(board: boardPre, roll: roll, sources: sources);
    expect(board, boardPost);
  });

  test('wong.getLegalMoves: illegal bearoff', () {
    final boardPre = [0, -2, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, -5, 0, 0, 0, 10, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final boardPost = [0, -2, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, -5, 0, 0, 0, 10, -3, 0, -5, 0, 0, 0, 0, 0, 0, 1, 0];
    final roll = [6, 5];

    final moves = wong.getLegalMoves(boardPre: boardPre, boardPost: boardPost, roll: roll);
    expect(moves, null);
  });

  test('wong.checkLegalMoves: illegal bearoff', () {
    final boardPre = [0, -2, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, -5, 0, 0, 0, 10, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final roll = [6, 5];
    final sources = [6];

    final board = wong.checkLegalMoves(board: boardPre, roll: roll, sources: sources);
    expect(board, null);
  });

  test('wong.toModel: initial board', () {
    final wongBoard = [
      0, // 0: player2 bar
      -2, // 1: 2x white (player2)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      5, // 6: 5x black (player1)
      0, // 7
      3, // 8: 3x black (player1)
      0, // 9
      0, // 10
      0, // 11
      -5, // 12: 5x white (player2)
      5, // 13: 5x black (player1)
      0, // 14
      0, // 15
      0, // 16
      -3, // 17
      0, // 18
      -5, // 19: 5x white (player2)
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      2, // 24: 2x black (player1)
      0, // 25: player1 bar
      0, // 26: player1 home
      0, // 27: player2 home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = GammonRules.initialPips();
    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });

  test('wong.toModel: two bars, no home', () {
    final wongBoard = [
      1, // 0: 1x white (player2) bar
      -1, // 1: 1x white (player2)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      5, // 6: 5x black (player1)
      0, // 7
      3, // 8: 3x black (player1)
      0, // 9
      0, // 10
      0, // 11
      -5, // 12: 5x white (player2)
      5, // 13: 5x black (player1)
      0, // 14
      0, // 15
      0, // 16
      -3, // 17: 3x white (player1)
      0, // 18
      -5, // 19: 5x white (player2)
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      1, // 24: 1x black (player1)
      1, // 25: 1x black (player1) bar
      0, // 26: 0x black (player1) home
      0, // 27: 0x white (player2) home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = <List<int>>[
      [1], // 0: 0x black (player1) home, 1x white (player2) bar
      [2], // 1: 1x white (player2)
      [], // 2
      [], // 3
      [], // 4
      [], // 5
      [-14, -13, -12, -11, -10], // 6: 5x black (player1)
      [], // 7
      [-9, -8, -7], // 8: 3x black (player1)
      [], // 9
      [], // 10
      [], // 11
      [3, 4, 5, 6, 7], // 12: 5x white (player2)
      [-6, -5, -4, -3, -2], // 13: 5x black (player1)
      [], // 14
      [], // 15
      [], // 16
      [8, 9, 10], // 17: 3x white (player2)
      [], // 18
      [11, 12, 13, 14, 15], // 19: 5x white (player2)
      [], // 20
      [], // 21
      [], // 22
      [], // 23
      [-1], // 24: 1x black (player1)
      [-15], // 25: 1x black (player1) bar, 0x white (player2) home
    ];

    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });

  test('wong.toModel: one bar, no home', () {
    final wongBoard = [
      1, // 0: 1x white (player2) bar
      -1, // 1: 1x white (player2)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      5, // 6: 5x black (player1)
      0, // 7
      3, // 8: 3x black (player1)
      0, // 9
      0, // 10
      0, // 11
      -5, // 12: 5x white (player2)
      5, // 13: 5x black (player1)
      0, // 14
      0, // 15
      0, // 16
      -3, // 17: 3x white (player1)
      0, // 18
      -5, // 19: 5x white (player2)
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      2, // 24: 2x black (player1)
      0, // 25: 0x black (player1) bar
      0, // 26: 0x black (player1) home
      0, // 27: 0x white (player2) home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = <List<int>>[
      [1], // 0: 0x black (player1) home, 1x white (player2) bar
      [2], // 1: 2x white (player2)
      [], // 2
      [], // 3
      [], // 4
      [], // 5
      [-15, -14, -13, -12, -11], // 6: 5x black (player1)
      [], // 7
      [-10, -9, -8], // 8: 3x black (player1)
      [], // 9
      [], // 10
      [], // 11
      [3, 4, 5, 6, 7], // 12: 5x white (player2)
      [-7, -6, -5, -4, -3], // 13: 5x black (player1)
      [], // 14
      [], // 15
      [], // 16
      [8, 9, 10], // 17: 3x white (player2)
      [], // 18
      [11, 12, 13, 14, 15], // 19: 5x white (player2)
      [], // 20
      [], // 21
      [], // 22
      [], // 23
      [-2, -1], // 24: 2x black (player1)
      [], // 25: 0x black (player1) bar, 0x white (player2) home
    ];

    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });

  test('wong.toModel: no bar, two home', () {
    final wongBoard = [
      0, // 0: player2 bar
      14, // 1: 14x black (player1)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      0, // 6
      0, // 7
      0, // 8
      0, // 9
      0, // 10
      0, // 11
      0, // 12
      0, // 13
      0, // 14
      0, // 15
      0, // 16
      0, // 17
      0, // 18
      0, // 19
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      -14, // 24: 14x white (player2)
      0, // 25: player1 bar
      1, // 26: player1 home
      1, // 27: player2 home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = <List<int>>[
      [-15], // 0: player1 home, player2 bar
      [-14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1], // 1: 14x black (player1)
      [], // 2
      [], // 3
      [], // 4
      [], // 5
      [], // 6
      [], // 7
      [], // 8
      [], // 9
      [], // 10
      [], // 11
      [], // 12
      [], // 13
      [], // 14
      [], // 15
      [], // 16
      [], // 17
      [], // 18
      [], // 19
      [], // 20
      [], // 21
      [], // 22
      [], // 23
      [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], // 24: 14x white (player2)
      [1], // 25: player1 bar, player2 home
    ];

    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });

  test('wong.toModel: no bar, one home', () {
    final wongBoard = [
      0, // 0: player2 bar
      14, // 1: 14x black (player1)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      0, // 6
      0, // 7
      0, // 8
      0, // 9
      0, // 10
      0, // 11
      0, // 12
      0, // 13
      0, // 14
      0, // 15
      0, // 16
      0, // 17
      0, // 18
      0, // 19
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      -15, // 24: 15x white (player2)
      0, // 25: player1 bar
      1, // 26: 1x black (player1) home
      0, // 27: 0x white (player2) home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = <List<int>>[
      [-15], // 0: 1x black (player1) home, 0x white (player2) bar
      [-14, -13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1], // 1: 14x black (player1)
      [], // 2
      [], // 3
      [], // 4
      [], // 5
      [], // 6
      [], // 7
      [], // 8
      [], // 9
      [], // 10
      [], // 11
      [], // 12
      [], // 13
      [], // 14
      [], // 15
      [], // 16
      [], // 17
      [], // 18
      [], // 19
      [], // 20
      [], // 21
      [], // 22
      [], // 23
      [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], // 24: 15x white (player2)
      [], // 25: 0x black (player1) bar, 0x white (player2) home
    ];

    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });

  test('wong.toModel: bar, home', () {
    final wongBoard = [
      1, // 0: 1x white (player2) bar
      13, // 1: 13x black (player1)
      0, // 2
      0, // 3
      0, // 4
      0, // 5
      0, // 6
      0, // 7
      0, // 8
      0, // 9
      0, // 10
      0, // 11
      0, // 12
      0, // 13
      0, // 14
      0, // 15
      0, // 16
      0, // 17
      0, // 18
      0, // 19
      0, // 20
      0, // 21
      0, // 22
      0, // 23
      -13, // 24: 13x white (player2)
      1, // 25: player1 bar
      1, // 26: player1 home
      1, // 27: player2 home
    ];

    final modelBoard = wong.toModel(wongBoard);
    expect(modelBoard.length, 26);

    final expectedBoard = <List<int>>[
      [-15, 2], // 0: player1 home, player2 bar
      [-13, -12, -11, -10, -9, -8, -7, -6, -5, -4, -3, -2, -1], // 1: 13x black (player1)
      [], // 2
      [], // 3
      [], // 4
      [], // 5
      [], // 6
      [], // 7
      [], // 8
      [], // 9
      [], // 10
      [], // 11
      [], // 12
      [], // 13
      [], // 14
      [], // 15
      [], // 16
      [], // 17
      [], // 18
      [], // 19
      [], // 20
      [], // 21
      [], // 22
      [], // 23
      [3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], // 24: 13x white (player2)
      [1, -14], // 25: 1x black (player1) bar, 1x white (player2) home
    ];

    for (var pip = 0; pip != 26; ++pip) {
      expect(modelBoard[pip], expectedBoard[pip], reason: 'pip $pip');
    }

    final wongBoard2 = wong.fromModel(modelBoard);
    for (var pip = 0; pip != 28; ++pip) {
      expect(wongBoard2[pip], wongBoard[pip], reason: 'pip $pip');
    }
  });
}

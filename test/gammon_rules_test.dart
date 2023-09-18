// import 'package:fibscli/dice.dart';
// import 'package:flutter_test/flutter_test.dart';
// import 'package:fibscli/model.dart';
// import 'package:fibsboard/fibsboard.dart' as fb;

// rules from https://www.bkgm.com/rules.html
// TODO
// void main() {
//   test('one-hop move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 5);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(1));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 6);
//     expect(deltasForHops[0][0].toPipNo, 5);
//   });

//   test('one-hop move from open (white)', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 1, toPipNo: 5);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(1));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 1);
//     expect(deltasForHops[0][0].toPipNo, 5);
//   });

//   test('two-hop move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 13, toPipNo: 5, hops: [-6, -2]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(2));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 13);
//     expect(deltasForHops[0][0].toPipNo, 7);
//     expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[1][0].fromPipNo, 7);
//     expect(deltasForHops[1][0].toPipNo, 5);
//   });

//   test('three-hop move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 13, toPipNo: 7, hops: [-2, -2, -2]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(3));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 13);
//     expect(deltasForHops[0][0].toPipNo, 11);
//     expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[1][0].fromPipNo, 11);
//     expect(deltasForHops[1][0].toPipNo, 9);
//     expect(deltasForHops[2][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[2][0].fromPipNo, 9);
//     expect(deltasForHops[2][0].toPipNo, 7);
//   });

//   test('four-hop move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 13, toPipNo: 5, hops: [-2, -2, -2, -2]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(4));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 13);
//     expect(deltasForHops[0][0].toPipNo, 11);
//     expect(deltasForHops[1][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[1][0].fromPipNo, 11);
//     expect(deltasForHops[1][0].toPipNo, 9);
//     expect(deltasForHops[2][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[2][0].fromPipNo, 9);
//     expect(deltasForHops[2][0].toPipNo, 7);
//     expect(deltasForHops[3][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[3][0].fromPipNo, 7);
//     expect(deltasForHops[3][0].toPipNo, 5);
//   });

//   test('one-hop illegal move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 1);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('one-hop illegal move from open (white)', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 1, toPipNo: 6);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('two-hop illegal move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-1, -4]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('three-hop illegal move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 24, toPipNo: 6, hops: [-6, -6, -6]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('four-hop illegal move from open', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 19, toPipNo: 7, hops: [-3, -3, -3, -3]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('one-hop hit', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X           O  O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 2);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(1));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.hit);
//     expect(deltasForHops[0][0].fromPipNo, 6);
//     expect(deltasForHops[0][0].toPipNo, 2);
//     expect(deltasForHops[0][1].kind, GammonDeltaKind.bar);
//     expect(deltasForHops[0][1].fromPipNo, 2);
//     expect(deltasForHops[0][1].toPipNo, 0);
//   });

//   test('two-hop hit', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X           O  O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 2, hops: [-1, -3]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(2));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 6);
//     expect(deltasForHops[0][0].toPipNo, 5);
//     expect(deltasForHops[1][0].kind, GammonDeltaKind.hit);
//     expect(deltasForHops[1][0].fromPipNo, 5);
//     expect(deltasForHops[1][0].toPipNo, 2);
//     expect(deltasForHops[1][1].kind, GammonDeltaKind.bar);
//     expect(deltasForHops[1][1].fromPipNo, 2);
//     expect(deltasForHops[1][1].toPipNo, 0);
//   });

//   test('two hops, two hits', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X           O  O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 1, hops: [-4, -1]);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(2));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.hit);
//     expect(deltasForHops[0][0].fromPipNo, 6);
//     expect(deltasForHops[0][0].toPipNo, 2);
//     expect(deltasForHops[0][1].kind, GammonDeltaKind.bar);
//     expect(deltasForHops[0][1].fromPipNo, 2);
//     expect(deltasForHops[0][1].toPipNo, 0);
//     expect(deltasForHops[1][0].kind, GammonDeltaKind.hit);
//     expect(deltasForHops[1][0].fromPipNo, 2);
//     expect(deltasForHops[1][0].toPipNo, 1);
//     expect(deltasForHops[1][1].kind, GammonDeltaKind.bar);
//     expect(deltasForHops[1][1].fromPipNo, 1);
//     expect(deltasForHops[1][1].toPipNo, 0);
//   });

//   test('one coming off the bar', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   |                  |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    | X | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 25, toPipNo: 23);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isNotEmpty);
//     expect(deltasForHops, hasLength(1));
//     expect(deltasForHops[0][0].kind, GammonDeltaKind.move);
//     expect(deltasForHops[0][0].fromPipNo, 25);
//     expect(deltasForHops[0][0].toPipNo, 23);
//   });

//   test('illegal move w/ one on the bar', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   |                  |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    | X | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 6, toPipNo: 2);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('illegal hit w/ one on the bar', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   |                  |   |
// | O                |   |                  |   |
// | O           X    |   | X                |   |
// | O           X    |   | X                |   |
// | O           X  X | X | X  O           O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final move = GammonMove(fromPipNo: 7, toPipNo: 5);
//     final deltasForHops = GammonRules.checkLegalMove(board, move);
//     expect(deltasForHops, isEmpty);
//   });

//   test('illegal moves available w/ one on the bar', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   |                  |   |
// | O                |   |                  |   |
// | O           X    |   | X                |   |
// | O           X    |   | X                |   |
// | O           X  X | X | X  O           O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final moves = GammonRules.getAllLegalMoves(board, GammonPlayer.one, [4, 2]);
//     expect(moves, hasLength(1));
//   });

//   test('starting the game', () {
//     final lines = fb.linesFromString('''
// +13-14-15-16-17-18-+BAR+19-20-21-22-23-24-+OFF+
// | X           O    |   | O              X |   |
// | X           O    |   | O              X |   |
// | X           O    |   | O                |   |
// | X                |   | O                |   |
// | X                |   | O                |   |
// |                  |   |                  |   |
// | O                |   | X                |   |
// | O                |   | X                |   |
// | O           X    |   | X                |   |
// | O           X    |   | X              O |   |
// | O           X    |   | X              O |   |
// +12-11-10--9--8--7-+---+-6--5--4--3--2--1-+---+
// ''');

//     final board = fb.boardFromLines(lines);
//     final game = GammonState();

//     for (var i = 0; i != board.length; ++i) {
//       expect(game.board[i], hasLength(board[i].length));
//       if (game.board[i].isNotEmpty)
//         expect(GammonRules.playerFor(game.board[i][0]),
//             GammonRules.playerFor(board[i][0]));
//     }

//     expect(game.dice.length, 2);
//     expect(game.dice[0] != game.dice[1], isTrue);
//   });

//   test('ending the game (player1)', () {
//     final board = <List<int>>[
//       // player1 off, player2 bar
//       [
//         -15,
//         -14,
//         -13,
//         -12,
//         -11,
//         -10,
//         -9,
//         -8,
//         -7,
//         -6,
//         -5,
//         -4,
//         -3,
//         -2
//       ], // 0: 14x player1

//       // player1 home board
//       [1, 2], // 1: 2x player2
//       [-1], // 2: 1x player1
//       [], // 3:
//       [], // 4:
//       [], // 5:
//       [], // 6:

//       // player1 outer board
//       [], // 7:
//       [], // 8:
//       [], // 9:
//       [], // 10:
//       [], // 11:
//       [3, 4, 5, 6, 7], // 12: 5x player2

//       // player2 outer board
//       [], // 13:
//       [], // 14:
//       [], // 15:
//       [], // 16:
//       [8, 9, 10], // 17: 3x player2
//       [], // 18:

//       // player2 home board
//       [11, 12, 13, 14, 15], // 19: 5x player2
//       [], // 20:
//       [], // 21:
//       [], // 22:
//       [], // 23:
//       [], // 24:

//       // player1 off, player2 bar
//       [], // 25:
//     ];

//     fb.checkBoard(board);

//     final dice = [DieState(1), DieState(2)];
//     final game = GammonState.from(
//         board: board, dice: dice, turnPlayer: GammonPlayer.one);
//     final moves = game.getAllLegalMoves();

//     expect(moves, hasLength(1));
//     expect(moves.containsKey(2), isTrue);
//     expect(moves[2], hasLength(1));
//     expect(moves[2][0].fromPipNo, 2);
//     expect(moves[2][0].toPipNo, 0);
//     expect(moves[2][0].hops, hasLength(1));
//     expect(moves[2][0].hops[0], -2);
//     expect(game.gameOver, isFalse);

//     final deltas = game.applyMove(move: moves[2][0]);
//     expect(deltas.isNotEmpty, isTrue);
//     expect(game.gameOver, isTrue);
//   });

//   test('ending the game (player2)', () {
//     List<List<int>> board = <List<int>>[
//       // player1 off, player2 bar
//       [], // 0:

//       // player1 home board
//       [], // 1: 2x player2
//       [], // 2:
//       [], // 3:
//       [], // 4:
//       [], // 5:
//       [-15, -14, -13, -12, -11], // 6: 5x player1

//       // player1 outer board
//       [], // 7:
//       [-10, -9, -8], // 8: 3x player1
//       [], // 9:
//       [], // 10:
//       [], // 11:
//       [], // 12:

//       // player2 outer board
//       [-7, -6, -5, -4, -3], // 13: 5x player1
//       [], // 14:
//       [], // 15:
//       [], // 16:
//       [], // 17:
//       [], // 18:

//       // player2 home board
//       [], // 19:
//       [], // 20:
//       [], // 21:
//       [], // 22:
//       [1], // 23: 1x player2
//       [-2, -1], // 24: 2x player1

//       // player1 off, player2 bar
//       [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15], // 25: 14x player2
//     ];

//     fb.checkBoard(board);

//     final dice = [DieState(1), DieState(2)];
//     final game = GammonState.from(
//         board: board, dice: dice, turnPlayer: GammonPlayer.two);
//     final moves = game.getAllLegalMoves();

//     expect(moves, hasLength(1));
//     expect(moves.containsKey(23), isTrue);
//     expect(moves[23], hasLength(1));
//     expect(moves[23][0].fromPipNo, 23);
//     expect(moves[23][0].toPipNo, 25);
//     expect(moves[23][0].hops, hasLength(1));
//     expect(moves[23][0].hops[0], 2);
//     expect(game.gameOver, isFalse);

//     final deltas = game.applyMove(move: moves[23][0]);
//     expect(deltas.isNotEmpty, isTrue);
//     expect(game.gameOver, isTrue);
//   });
// }

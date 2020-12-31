import 'package:fibscli/wong.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LegalMove: basic', () {
    // Playing an opening 13 as 8/5 6/5:
    final anBoardPre = [0, -2, 0, 0, 0, 0, 5, 0, 3, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final anBoardPost = [0, -2, 0, 0, 0, 2, 4, 0, 2, 0, 0, 0, -5, 5, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 2, 0, 0, 0];
    final anRoll = [1, 3];

    // get the legal move
    final anMove = List<int>.filled(8, 0);
    final legalMove = LegalMove(anBoardPre, anBoardPost, anRoll, anMove);

    // LegalMove( anBoardPre, anBoardPost, anRoll, anMove ) would return true
    // anMove[] would be set to { 8 5 6 5 0 0 0 0 }
    expect(legalMove, 1);
    expect(anMove, [8, 5, 6, 5, 0, 0, 0, 0]);
  });

  test('LegalMove: legal bearoff', () {
    final anBoardPre = [0, -2, 0, 0, 0, 0, 15, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final anBoardPost = [0, -2, 0, 0, 0, 0, 14, 0, 0, 0, 0, 0, -5, 0, 0, 0, 0, -3, 0, -5, 0, 0, 0, 0, 0, 0, 1, 0];
    final anRoll = [6, 5];

    final anMove = List<int>.filled(8, 0);
    final legalMove = LegalMove(anBoardPre, anBoardPost, anRoll, anMove);

    expect(legalMove, 1);
    expect(anMove, [6, 26, 0, 0, 0, 0, 0, 0]);
    print(anMove);
  });

  test('LegalMove: illegal bearoff', () {
    final anBoardPre = [0, -2, 0, 0, 0, 0, 5, 0, 0, 0, 0, 0, -5, 0, 0, 0, 10, -3, 0, -5, 0, 0, 0, 0, 0, 0, 0, 0];
    final anBoardPost = [0, -2, 0, 0, 0, 0, 4, 0, 0, 0, 0, 0, -5, 0, 0, 0, 10, -3, 0, -5, 0, 0, 0, 0, 0, 0, 1, 0];
    final anRoll = [6, 5];

    final anMove = List<int>.filled(8, 0);
    final legalMove = LegalMove(anBoardPre, anBoardPost, anRoll, anMove);

    expect(legalMove, 0);
  });
}

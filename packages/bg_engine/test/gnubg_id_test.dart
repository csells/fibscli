import 'package:bg_engine/src/ai/gnubg_id.dart';
import 'package:bg_engine/src/rules.dart';
import 'package:test/test.dart';

void main() {
  group('gnubgPositionId', () {
    test('encodes the standard opening position to the known id', () {
      // The canonical GNU Backgammon Position ID for the opening position.
      expect(
        gnubgPositionId(GammonRules.initialBoard(), GammonPlayer.one),
        '4HPwATDgc/ABMA',
      );
    });

    test('is symmetric: the opening is the same id from either side', () {
      expect(
        gnubgPositionId(GammonRules.initialBoard(), GammonPlayer.two),
        '4HPwATDgc/ABMA',
      );
    });
  });

  group('gnubgMatchId', () {
    // Every expected id below is pinned bit-exact against live gnubg
    // 1.08.003 (the gnubg-service:dev docker image): each state was built
    // with gnubg commands (`new match`/`new session`, `set score`, `set
    // cube …`, `set crawford`, `set jacoby`, `set turn`, `set dice`) and
    // the id read back via the embedded Python `gnubg.matchid()`.

    test('money session, Jacoby off (the default), dice 3-1', () {
      expect(gnubgMatchId(die0: 3, die1: 1), 'MIEFAAAAAAAE');
    });

    test('money session, Jacoby rule in effect, dice 3-1', () {
      expect(gnubgMatchId(die0: 3, die1: 1, jacoby: true), 'MIEFAAAAAAAA');
    });

    test('7-point match at 0-0, dice 3-1', () {
      expect(gnubgMatchId(die0: 3, die1: 1, matchLength: 7), 'MIHlAAAAAAAE');
    });

    test('jacoby is meaningless in a match and does not change the id', () {
      expect(
        gnubgMatchId(die0: 3, die1: 1, matchLength: 7, jacoby: true),
        'MIHlAAAAAAAE',
      );
    });

    test('7-point match with player 1 on roll, dice 3-1', () {
      expect(
        gnubgMatchId(die0: 3, die1: 1, matchLength: 7, onRoll: 1),
        'cInlAAAAAAAE',
      );
    });

    test('7-point match, doubles 6-6', () {
      expect(gnubgMatchId(die0: 6, die1: 6, matchLength: 7), 'MAH7AAAAAAAE');
    });

    test('7-point match at 2-3, dice 3-1', () {
      expect(
        gnubgMatchId(die0: 3, die1: 1, matchLength: 7, score0: 2, score1: 3),
        'MIHlACAAGAAE',
      );
    });

    test('cube at 2 owned by player 0', () {
      expect(
        gnubgMatchId(
          die0: 3,
          die1: 1,
          matchLength: 7,
          score0: 2,
          score1: 3,
          cubeValue: 2,
          cubeOwner: 0,
        ),
        'AYHlACAAGAAE',
      );
    });

    test('cube at 2 owned by player 1', () {
      expect(
        gnubgMatchId(
          die0: 3,
          die1: 1,
          matchLength: 7,
          score0: 2,
          score1: 3,
          cubeValue: 2,
          cubeOwner: 1,
        ),
        'EYHlACAAGAAE',
      );
    });

    test('cube at 16 owned by player 1', () {
      expect(
        gnubgMatchId(
          die0: 3,
          die1: 1,
          matchLength: 7,
          score0: 2,
          score1: 3,
          cubeValue: 16,
          cubeOwner: 1,
        ),
        'FIHlACAAGAAE',
      );
    });

    test('crawford game at 6-3 in a 7-point match, dice 5-2', () {
      expect(
        gnubgMatchId(
          die0: 5,
          die1: 2,
          matchLength: 7,
          score0: 6,
          score1: 3,
          crawford: true,
        ),
        'sIHqAGAAGAAE',
      );
    });

    test('post-crawford at 6-3 in a 7-point match, dice 5-2', () {
      expect(
        gnubgMatchId(die0: 5, die1: 2, matchLength: 7, score0: 6, score1: 3),
        'MIHqAGAAGAAE',
      );
    });

    test('1-point match, dice 3-1', () {
      expect(gnubgMatchId(die0: 3, die1: 1, matchLength: 1), 'MIElAAAAAAAE');
    });

    test('25-point match at double match point, dice 2-1', () {
      expect(
        gnubgMatchId(die0: 2, die1: 1, matchLength: 25, score0: 24, score1: 24),
        'MAElA4ABwAAE',
      );
    });

    test('pre-roll (no dice): a cube-decision state in a 7-point match', () {
      expect(gnubgMatchId(die0: 0, die1: 0, matchLength: 7), 'MAHgAAAAAAAE');
    });

    test('pre-roll money state matches the gnubg-service cube fixture', () {
      // gnubg-service's e2e golden `/v1/cube` request uses this exact id.
      expect(gnubgMatchId(die0: 0, die1: 0, onRoll: 1), 'cAkAAAAAAAAE');
    });

    test('dice are normalized to gnubg canonical order, higher die first', () {
      // gnubg emits the same id for a 2-5 and a 5-2 roll (higher die first);
      // 'MIEKAAAAAAAA' is gnubg.matchid() for `set dice 2 5` in a Jacoby
      // money session.
      expect(gnubgMatchId(die0: 2, die1: 5, jacoby: true), 'MIEKAAAAAAAA');
      expect(
        gnubgMatchId(die0: 5, die1: 2, jacoby: true),
        gnubgMatchId(die0: 2, die1: 5, jacoby: true),
      );
    });

    test('money 4-1 with Jacoby matches the gnubg-service eval fixture', () {
      // gnubg-service's e2e golden `/v1/eval` request uses this exact id.
      expect(
        gnubgMatchId(die0: 4, die1: 1, onRoll: 1, jacoby: true),
        'cAkGAAAAAAAA',
      );
    });
  });
}

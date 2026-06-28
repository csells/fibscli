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
}

import 'package:backgammon_ai/backgammon_ai.dart' as bgai;
import 'package:fibscli/backgammon_ai_player.dart';
import 'package:fibscli/model.dart'; // GammonRules/BgPosition/positionSignature
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('board conversion', () {
    test('opening engine board -> backgammon_ai standard board', () {
      final b = toBackgammonAiBoard(
        GammonRules.initialBoard(),
        GammonPlayer.one,
      );
      final std = bgai.Board.standard();
      expect(b.aPoints, std.aPoints);
      expect(b.bPoints, std.bPoints);
      expect(b.aBar, 0);
      expect(b.bBar, 0);
      expect(b.aOff, 0);
      expect(b.bOff, 0);
    });

    test('the conversion preserves the position signature', () {
      final eng = GammonRules.initialBoard();
      final converted = backgammonAiBoardSignature(
        toBackgammonAiBoard(eng, GammonPlayer.one),
        GammonPlayer.one,
      );
      expect(converted, positionSignature(eng));
    });

    test('player two converts from its own pip-distance frame', () {
      final eng = GammonRules.initialBoard();
      final sig = backgammonAiBoardSignature(
        toBackgammonAiBoard(eng, GammonPlayer.two),
        GammonPlayer.two,
      );
      expect(sig, positionSignature(eng));
    });
  });

  group('BackgammonAiPlayer.chooseTurn', () {
    test('plays a legal both-dice turn from the opening', () async {
      final ai = BackgammonAiPlayer();
      final turn = await ai.chooseTurn(
        BgPosition(
          board: GammonRules.initialBoard(),
          onRoll: GammonPlayer.one,
          dice: [3, 1],
        ),
      );
      expect(turn.isDance, isFalse);
      final hops = turn.moves.fold<int>(0, (s, m) => s + m.hops.length);
      expect(hops, 2);
      ai.dispose();
    });

    test('returns a dance when backgammon_ai forfeits the turn', () async {
      // player two on the bar with points 1..6 blocked -> no entry
      final board = GammonRules.initialBoard();
      board[0]
        ..clear()
        ..add(50); // a player2 checker on the bar
      for (var pip = 1; pip <= 6; ++pip) {
        board[pip]
          ..clear()
          ..addAll([-100 - pip, -200 - pip]);
      }
      final turn = await BackgammonAiPlayer().chooseTurn(
        BgPosition(board: board, onRoll: GammonPlayer.two, dice: [6, 6, 6, 6]),
      );
      expect(turn.isDance, isTrue);
    });

    test('the factory exposes difficulty levels and builds a player', () {
      final factory = BackgammonAiPlayerFactory();
      expect(factory.levels, isNotEmpty);
      expect(
        factory.create(level: factory.levels.last),
        isA<BackgammonAiPlayer>(),
      );
    });
  });
}

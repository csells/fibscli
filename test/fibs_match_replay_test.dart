import 'package:fibscli/fibs_state.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_transport.dart';

// our own game, our turn: player1 "You" (X), an in-progress board.
String boardLine() =>
    'board:You:MonteCarlo:2:0:0:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0'
    ':0:0:2:0:1:0:0:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  // A protocol-accurate replay of a two-game match: play a game, win it, the
  // next game starts, lose it, then lose the match and return to the lobby.
  // Exercises the whole game-end arc as ONE flow -- FIBS announces each result
  // as a text message, and a fresh board between games clears the prior result.
  test(
    'a two-game match plays through both games and ends at the lobby',
    () async {
      final fake = FakeTransport();
      final fibs = FibsState.withTransport(fake);
      await fibs.login(user: 'joe_grammer', pass: 'x');

      // --- game 1: in progress, then we win ---
      fake.feed(boardLine());
      await _settle();
      expect(fibs.gameState, isNotNull);
      expect(fibs.isGameOver, isFalse);

      fake.feed('You win the game and get 1 point.');
      await _settle();
      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isTrue);

      // --- game 2: the next board clears the result and play resumes ---
      fake.feed(boardLine());
      await _settle();
      expect(
        fibs.isGameOver,
        isFalse,
        reason: 'result cleared for the next game',
      );
      expect(fibs.gameState, isNotNull);

      fake.feed('MonteCarlo wins the game and gets 1 point. Sorry.');
      await _settle();
      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isFalse);

      // --- match end ---
      fake.feed('MonteCarlo wins the 2 point match 2-1 .');
      await _settle();
      expect(fibs.isGameOver, isTrue);
      expect(fibs.didIWin, isFalse);

      // back to the lobby
      fibs.returnToLobby();
      expect(fibs.gameState, isNull);
      expect(fibs.isGameOver, isFalse);
    },
  );
}

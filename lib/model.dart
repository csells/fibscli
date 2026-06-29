import 'dart:math';

import 'package:bg_engine/bg_engine.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/foundation.dart';

import 'dice.dart';

// Re-export the pure engine so existing importers of model.dart keep
// seeing GammonRules/GammonMove/GammonPlayer/etc. unchanged.
export 'package:bg_engine/bg_engine.dart';

// Per-player tallies shown in the end-game summary (issue #10).
class GammonStats {
  int rolls = 0;
  int doubles = 0;
  int pips = 0; // total of all dice rolled

  void record(List<int> diceRolls) {
    if (diceRolls.isEmpty) return;
    ++rolls;
    pips += diceRolls.fold<int>(0, (sum, r) => sum + r);
    if (diceRolls.length >= 2 && diceRolls.every((r) => r == diceRolls.first)) {
      ++doubles;
    }
  }
}

class GammonState extends ChangeNotifier {
  GammonState() {
    _setState(
      board: GammonRules.initialBoard(),
      dice: <DieState>[],
      turnPlayer: null,
    );
    _firstTurn();
  }

  GammonState.from({
    required List<List<int>> board,
    required List<DieState> dice,
    required GammonPlayer? turnPlayer,
    int moveNo = 1,
  }) {
    _setState(board: board, dice: dice, turnPlayer: turnPlayer);
    _moveNo = moveNo;
  }
  static final _rand = Random();

  // index: 1-24 == board, 0 == player1 home/player2 bar, 25 == player1 bar/player2 home
  // value: list of piece ids, <0 == player1, >0 == player2
  final _board = List<List<int>>.filled(26, List<int>.empty());

  final _dice = <DieState>[]; // dice rolls and whether they're still available
  GammonPlayer? _turnPlayer;
  late GammonState _undoState; // state for implementing undo
  var _moveNo = 1;
  var _gameOver = false;
  final _stats = <GammonPlayer, GammonStats>{
    GammonPlayer.one: GammonStats(),
    GammonPlayer.two: GammonStats(),
  };

  GammonStats statsFor(GammonPlayer player) => _stats[player]!;

  final cube = DoublingCube();

  // A player may offer a double when it's their turn, before they've moved
  // (all dice still available), and the cube allows it (issue #12).
  bool canOfferDouble(GammonPlayer? player) =>
      !_gameOver &&
      player != null &&
      player == _turnPlayer &&
      cube.canDoubleBy(player) &&
      _dice.every((d) => d.available);

  // The opponent accepts the double offered by the player on roll: play
  // continues with a higher stake.
  void acceptDouble() {
    if (_gameOver) throw Exception('game over');
    cube.applyTake(_turnPlayer!);
    notifyListeners();
  }

  // The opponent declines the double: the doubler (current turn player) wins.
  void declineDouble() {
    if (_gameOver) throw Exception('game over');
    _gameOver = true;
    notifyListeners();
  }

  void _setState({
    required List<List<int>> board,
    required List<DieState> dice,
    required GammonPlayer? turnPlayer,
  }) {
    for (var i = 0; i < board.length; ++i) {
      _board[i] = List.from(board[i]);
    }

    _dice.clear();
    _dice.addAll(dice.map((d) => DieState(d.roll)).toList());

    _turnPlayer = turnPlayer;
  }

  List<List<int>> get board => List.unmodifiable(_board);
  List<DieState> get dice => List.unmodifiable(_dice);
  GammonPlayer? get turnPlayer => _turnPlayer;
  bool get gameOver => _gameOver;

  void _firstTurn() {
    assert(_dice.isEmpty);
    assert(_turnPlayer == null);
    assert(_moveNo == 1);
    assert(!_gameOver);

    do {
      _rollDice(disableUnusableDice: false); // all dice initally usable
    } while (_dice[0].roll == _dice[1].roll);

    _turnPlayer = _dice[0].roll > _dice[1].roll
        ? GammonPlayer.one
        : GammonPlayer.two;
    _recordRoll(_turnPlayer!);
    _undoState = GammonState.from(
      board: _board,
      dice: dice,
      turnPlayer: _turnPlayer,
    );
    _moveNo = 1;
  }

  void _recordRoll(GammonPlayer player) {
    _stats[player]!.record(_dice.map((d) => d.roll).toList());
  }

  void commitTurn() {
    if (_gameOver) throw Exception('game over');

    _turnPlayer = GammonRules.otherPlayer(_turnPlayer);
    _rollDice(); // roll dice before capturing updo state
    _recordRoll(_turnPlayer!);
    _undoState = GammonState.from(
      board: _board,
      dice: dice,
      turnPlayer: _turnPlayer,
    );
    ++_moveNo; // can't be undone, so not capturing it
  }

  void undoTurn() {
    if (_gameOver) throw Exception('game over');

    _setState(
      board: _undoState._board,
      dice: _undoState._dice,
      turnPlayer: _undoState._turnPlayer,
    );

    notifyListeners();
  }

  Map<int, List<GammonMove>> getAllLegalMoves() {
    if (_gameOver) return {};

    final rolls = _dice.where((d) => d.available).map((d) => d.roll).toList();
    return GammonRules.getForcedLegalMoves(board, _turnPlayer, rolls);
  }

  List<List<GammonDelta>> applyMove({required GammonMove move}) {
    if (_gameOver) throw Exception('game over');

    final deltas = GammonRules.applyMove(board, move);

    if (deltas.isNotEmpty) {
      // update used dice
      for (final hop in move.hops) {
        _useDie(hop.abs());
      }

      // check for game over
      final offPipNo = GammonRules.offPipNoFor(_turnPlayer);
      final offPips = _board[offPipNo].sumBy(
        (pid) => GammonRules.playerFor(pid) == _turnPlayer ? 1 : 0,
      );
      if (offPips == 15) _gameOver = true;

      notifyListeners();
    }

    return deltas;
  }

  int get moveNo => _moveNo;

  // auto bear-off is offered only in a pure race (issue #11)
  bool get canAutoBearOff => !_gameOver && GammonRules.isRace(board);

  // Play the rest of the game greedily. Only meaningful in a pure race, where
  // no decision affects the outcome, so the player can skip clicking out every
  // bear-off. Mutates state directly (no per-move animation).
  void autoBearOff() {
    if (_gameOver) return;

    while (!_gameOver) {
      // play every available die greedily for the current turn
      while (true) {
        final available = _dice
            .where((d) => d.available)
            .map((d) => d.roll)
            .toList();
        if (available.isEmpty) break;

        GammonMove? chosen;
        for (final die in available) {
          chosen = GammonRules.greedyMoveForDie(board, _turnPlayer, die);
          if (chosen != null) break;
        }
        if (chosen == null) break; // no legal move for any remaining die

        final deltas = applyMove(move: chosen);
        if (deltas.isEmpty) break; // safety: avoid spinning
      }

      if (_gameOver) break;
      commitTurn();
    }
  }

  // [player]'s pip count: the distance their checkers must travel to bear off
  // (a checker on the bar is 25 pips; borne-off checkers are 0). Delegates to
  // the one [Position.pipCountFor] the cube policy also uses, so there is a
  // single, correct implementation instead of two.
  int pipCountFor(GammonPlayer player) =>
      Position.fromBoard(board).pipCountFor(player);

  // Win probability for [player], always complementary between the two players
  // (issue #14). In a pure race this is the exact value from the race solver;
  // with contact it falls back to the pip-count heuristic.
  double winProbabilityFor(GammonPlayer player) {
    final onRollPlayer = _turnPlayer;
    if (onRollPlayer == null) return 0.5;

    final onRollWins = CubePolicy.winProbability(board, onRollPlayer);
    return player == onRollPlayer ? onRollWins : 1.0 - onRollWins;
  }

  // The recommended cube action for the player currently on roll (issue #14).
  // Exact in a pure race; heuristic with contact. Shares the one [CubePolicy]
  // the AI uses, so the advice the UI shows matches how the AI plays the cube.
  CubeAction get recommendedCubeAction => CubePolicy.recommendedAction(
    board: board,
    onRoll: _turnPlayer!,
    cubeValue: cube.value,
    cubeOwner: cube.owner,
  );

  // True when the win chances and cube action are exact (a pure race) rather
  // than a pip-count estimate, so the UI can label them honestly (issue #14).
  bool get hasExactOdds =>
      RaceEval.winProbabilityOrNull(board, _turnPlayer ?? GammonPlayer.one) !=
      null;

  void _useDie(int roll) {
    _dice.firstWhere((d) => d.roll == roll && d.available).available = false;
    _disableUnusableDice();
  }

  void _rollDice({bool disableUnusableDice = true}) {
    final roll1 = _rand.nextInt(6) + 1;
    final roll2 = _rand.nextInt(6) + 1;
    final rolls = [
      roll1,
      roll2,
      if (roll1 == roll2) ...[roll1, roll1],
    ];

    _dice.clear();
    _dice.addAll([for (final roll in rolls) DieState(roll)]);
    if (disableUnusableDice) _disableUnusableDice();

    notifyListeners();
  }

  void _disableUnusableDice() {
    // check all the pips for legal moves (forced-move rules applied so that a
    // die the player is not allowed to play counts as unusable; issue #4)
    final rolls = _dice.where((d) => d.available).map((d) => d.roll).toList();
    final moves = GammonRules.getForcedLegalMoves(board, _turnPlayer, rolls);

    // find all of the possible hops
    final hops = <int>[
      for (final moveList in moves.values)
        for (final move in moveList)
          for (final hop in move.hops) hop.abs(),
    ];

    // remove dice that aren't usable
    for (final die in _dice.where((d) => d.available)) {
      if (!hops.contains(die.roll)) die.available = false;
    }
  }
}

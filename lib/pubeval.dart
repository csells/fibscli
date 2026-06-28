import 'model.dart';

// Tesauro's `pubeval` — the public-domain backgammon position evaluator he
// released in 1993 as a benchmark opponent (roughly 1650 FIBS strength). It is
// a linear evaluation over a 122-feature encoding, with separate weight vectors
// for contact and pure-race positions. We use it to pick moves: enumerate the
// legal full turns, evaluate each resulting position from our perspective, and
// take the best.
//
// The weight arrays and the `setx`/`pubeval` logic are ported verbatim from the
// canonical pubeval.c. The only adaptation is `_posFor`, which maps the
// engine's canonical board (lib/model.dart: index 0 = player1 off / player2
// bar; 1..24 points; 25 = player1 bar / player2 off; negative ids = player1/X
// moving 24->1, positive ids = player2/O moving 1->24) into pubeval's
// `pos[0..27]` array, always from the on-roll player's point of view.
class PubEval {
  PubEval._();

  // race weights (no contact)
  static const _wr = <double>[
    0,
    -0.17160,
    0.27010,
    0.29906,
    -0.08471,
    0,
    -1.40375,
    -1.05121,
    0.07217,
    -0.01351,
    0,
    -1.29506,
    -2.16183,
    0.13246,
    -1.03508,
    0,
    -2.29847,
    -2.34631,
    0.17253,
    0.08302,
    0,
    -1.27266,
    -2.87401,
    -0.07456,
    -0.34240,
    0,
    -1.34640,
    -2.46556,
    -0.13022,
    -0.01591,
    0,
    0.27448,
    0.60015,
    0.48302,
    0.25236,
    0,
    0.39521,
    0.68178,
    0.05281,
    0.09266,
    0,
    0.24855,
    -0.06844,
    -0.37646,
    0.05685,
    0,
    0.17405,
    0.00430,
    0.74427,
    0.00576,
    0,
    0.12392,
    0.31202,
    -0.91035,
    -0.16270,
    0,
    0.01418,
    -0.10839,
    -0.02781,
    -0.88035,
    0,
    1.07274,
    2.00366,
    1.16242,
    0.22520,
    0,
    0.85631,
    1.06349,
    1.49549,
    0.18966,
    0,
    0.37183,
    -0.50352,
    -0.14818,
    0.12039,
    0,
    0.13681,
    0.13978,
    1.11245,
    -0.12707,
    0,
    -0.22082,
    0.20178,
    -0.06285,
    -0.52728,
    0,
    -0.13597,
    -0.19412,
    -0.09308,
    -1.26062,
    0,
    3.05454,
    5.16874,
    1.50680,
    5.35000,
    0,
    2.19605,
    3.85390,
    0.88296,
    2.30052,
    0,
    0.92321,
    1.08744,
    -0.11696,
    -0.78560,
    0,
    -0.09795,
    -0.83050,
    -1.09167,
    -4.94251,
    0,
    -1.00316,
    -3.66465,
    -2.56906,
    -9.67677,
    0,
    -2.77982,
    -7.26713,
    -3.40177,
    -12.32252,
    0,
    3.42040,
  ];

  // contact weights
  static const _wc = <double>[
    0.25696,
    -0.66937,
    -1.66135,
    -2.02487,
    -2.53398,
    -0.16092,
    -1.11725,
    -1.06654,
    -0.92830,
    -1.99558,
    -1.10388,
    -0.80802,
    0.09856,
    -0.62086,
    -1.27999,
    -0.59220,
    -0.73667,
    0.89032,
    -0.38933,
    -1.59847,
    -1.50197,
    -0.60966,
    1.56166,
    -0.47389,
    -1.80390,
    -0.83425,
    -0.97741,
    -1.41371,
    0.24500,
    0.10970,
    -1.36476,
    -1.05572,
    1.15420,
    0.11069,
    -0.38319,
    -0.74816,
    -0.59244,
    0.81116,
    -0.39511,
    0.11424,
    -0.73169,
    -0.56074,
    1.09792,
    0.15977,
    0.13786,
    -1.18435,
    -0.43363,
    1.06169,
    -0.21329,
    0.04798,
    -0.94373,
    -0.22982,
    1.22737,
    -0.13099,
    -0.06295,
    -0.75882,
    -0.13658,
    1.78389,
    0.30416,
    0.36797,
    -0.69851,
    0.13003,
    1.23070,
    0.40868,
    -0.21081,
    -0.64073,
    0.31061,
    1.59554,
    0.65718,
    0.25429,
    -0.80789,
    0.08240,
    1.78964,
    0.54304,
    0.41174,
    -1.06161,
    0.07851,
    2.01451,
    0.49786,
    0.91936,
    -0.90750,
    0.05941,
    1.83120,
    0.58722,
    1.28777,
    -0.83711,
    -0.33248,
    2.64983,
    0.52698,
    0.82132,
    -0.58897,
    -1.18223,
    3.35809,
    0.62017,
    0.57353,
    -0.07276,
    -0.36214,
    4.37655,
    0.45481,
    0.21746,
    0.10504,
    -0.61977,
    3.54001,
    0.04612,
    -0.18108,
    0.63211,
    -0.87046,
    2.47673,
    -0.48016,
    -1.27157,
    0.86505,
    -1.11342,
    1.24612,
    -0.82385,
    -2.77082,
    1.23606,
    -1.59529,
    0.10438,
    -1.30206,
    -4.11520,
    5.62596,
    -2.75800,
  ];

  static List<double> get raceWeights => _wr;
  static List<double> get contactWeights => _wc;

  // pubeval's setx(): encode pos[] into the 122-element feature vector.
  static List<double> _setx(List<int> pos) {
    final x = List<double>.filled(122, 0);
    for (var j = 1; j <= 24; ++j) {
      final jm1 = j - 1;
      final n = pos[25 - j];
      if (n != 0) {
        if (n == -1) x[5 * jm1 + 0] = 1;
        if (n == 1) x[5 * jm1 + 1] = 1;
        if (n >= 2) x[5 * jm1 + 2] = 1;
        if (n == 3) x[5 * jm1 + 3] = 1;
        if (n >= 4) x[5 * jm1 + 4] = (n - 3) / 2;
      }
    }
    x[120] = -pos[0] / 2;
    x[121] = pos[26] / 15;
    return x;
  }

  // pubeval(): linear score; higher is better for the on-roll player in [pos].
  static double _pubeval(bool race, List<int> pos) {
    if (pos[26] == 15) return 99999999; // all our men off -> win
    final x = _setx(pos);
    final w = race ? _wr : _wc;
    var score = 0.0;
    for (var i = 0; i < 122; ++i) {
      score += w[i] * x[i];
    }
    return score;
  }

  static int _count(List<int> cell, GammonPlayer p) =>
      cell.where((id) => GammonRules.playerFor(id) == p).length;

  // Map the engine's canonical board to pubeval's pos[0..27] for [me].
  // pos[k] (k=1..24) is from [me]'s perspective: point 1 = [me]'s ace point
  // (nearest home), positive = [me]'s men, negative = opponent's men.
  static List<int> _posFor(List<List<int>> board, GammonPlayer me) {
    final opp = GammonRules.otherPlayer(me);
    final pos = List<int>.filled(28, 0);
    final one = me == GammonPlayer.one; // player1/X bears off toward index 0
    for (var k = 1; k <= 24; ++k) {
      // [me]'s point k maps to an engine index: X's point k == engine k;
      // O's point k == engine 25-k (O bears off at the high end).
      final eng = one ? k : 25 - k;
      pos[k] = _count(board[eng], me) - _count(board[eng], opp);
    }
    // pubeval stores the opponent's bar (pos[0]) and off (pos[27]) as NEGATIVE
    // integers; ours (pos[25], pos[26]) are positive.
    if (one) {
      // X: bar at engine 25, off at engine 0; O bar at 0, O off at 25
      pos[0] = -_count(board[0], opp); // opponent (O) on bar
      pos[25] = _count(board[25], me); // our (X) bar
      pos[26] = _count(board[0], me); //  our (X) off
      pos[27] = -_count(board[25], opp); // opponent (O) off
    } else {
      // O: bar at engine 0, off at engine 25; X bar at 25, X off at 0
      pos[0] = -_count(board[25], opp); // opponent (X) on bar
      pos[25] = _count(board[0], me); //  our (O) bar
      pos[26] = _count(board[25], me); // our (O) off
      pos[27] = -_count(board[0], opp); // opponent (X) off
    }
    return pos;
  }

  // True when the two sides can no longer hit each other (a pure race), so the
  // race weights apply. Anyone on the bar means contact.
  static bool isRace(List<List<int>> board) {
    final xBar = _count(board[25], GammonPlayer.one);
    final oBar = _count(board[0], GammonPlayer.two);
    if (xBar > 0 || oBar > 0) return false;
    // X (player1) moves 24->1, so its rearmost is its highest occupied point;
    // O (player2) moves 1->24, so its rearmost is its lowest occupied point.
    var xBack = 0;
    var oBack = 25;
    for (var i = 1; i <= 24; ++i) {
      if (_count(board[i], GammonPlayer.one) > 0 && i > xBack) xBack = i;
      if (_count(board[i], GammonPlayer.two) > 0 && i < oBack) oBack = i;
    }
    return xBack <= oBack; // disengaged -> race
  }

  // Evaluate [board] from [me]'s perspective (higher is better for [me]).
  static double eval(List<List<int>> board, GammonPlayer me) =>
      _pubeval(isRace(board), _posFor(board, me));
}

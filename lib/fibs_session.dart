import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_board.dart';
import 'fibs_crumb_keys.dart';
import 'model.dart';

enum SavedMatchAvailability { unknown, offline, online, ready }

@immutable
class SavedMatchInfo {
  const SavedMatchInfo({
    required this.opponent,
    this.score1,
    this.score2,
    this.matchLength,
    this.availability = SavedMatchAvailability.unknown,
  });

  final String opponent;
  final int? score1;
  final int? score2;
  final int? matchLength;
  final SavedMatchAvailability availability;

  bool get isReady => availability == SavedMatchAvailability.ready;

  String get availabilityLabel => switch (availability) {
    SavedMatchAvailability.ready => 'Ready to resume',
    SavedMatchAvailability.online => 'Online, not ready',
    SavedMatchAvailability.offline => 'Offline',
    SavedMatchAvailability.unknown => 'Saved',
  };

  String? get scoreLabel {
    final length = matchLength;
    final left = score1;
    final right = score2;
    if (left != null && right != null && length != null) {
      return '$left-$right to $length';
    }
    if (left != null && right != null) return '$left-$right';
    if (length != null) return '$length-point match';
    return null;
  }
}

// The pure, immutable game/turn state of a FIBS session. Every piece of display
// state the UI needs -- whose turn it is, the dice to play, whether we can roll
// or move -- is DERIVED from a small set of authoritative fields, so there is
// exactly one source of truth. Inbound FIBS cookies fold in via [reduce]; our
// own actions (we rolled, we committed a turn, we left) fold in via the small
// intent helpers below. FibsState is then just a ChangeNotifier shell that
// holds one of these and re-publishes it.
//
// Lobby roster and chat are deliberately NOT part of the session -- those are
// growing collections with their own notifier semantics; this type models the
// single board/turn state as one immutable snapshot.
@immutable
class FibsSession {
  const FibsSession({
    this.user,
    this.board,
    this.myDice = const [],
    this.opponentDice = const [],
    this.rollOrDoublePrompted = false,
    this.rolling = false,
    this.committedTurn = false,
    this.doubleOffered = false,
    this.resumeRequestFrom,
    this.mustJoin = false,
    this.savedMatches = const {},
    this.gameEnded = false,
    this.iWon,
    this.resultMessage,
  });

  // --- authoritative state (the only real sources of truth) -----------------

  final String? user; // our FIBS login name (needed to find our color)
  final FibsBoard? board; // the latest board frame (null when not in a game)

  // the dice we rolled this turn, captured from FIBS_YouRoll. FIBS doesn't
  // always re-send the board with our dice after a roll, so we track them here.
  final List<int> myDice;

  // the dice the other player rolled, captured from FIBS_PlayerRolls. The next
  // board frame often arrives after those dice have disappeared from the frame,
  // so the renderer captures them from this session state before that board.
  final List<int> opponentDice;

  // FIBS explicitly prompts before it accepts `roll` or `double`. A plain board
  // frame that says "our turn, no dice" is not enough because FIBS can
  // immediately auto-roll for us and send FIBS_YouRoll instead.
  final bool rollOrDoublePrompted;

  // transient "command in flight" flags so canRoll/canMoveNow stop being true
  // the instant we act while we wait for FIBS to acknowledge the turn.
  // _rolling: we sent `roll`, awaiting our dice (a FIBS_YouRoll clears it).
  // _committedTurn: we sent a whole move, awaiting the next turn signal.
  final bool rolling;
  final bool committedTurn;

  final bool doubleOffered; // the opponent doubled us; we must accept/reject
  final String? resumeRequestFrom; // an opponent asks to resume a saved match
  final bool mustJoin; // FIBS asks us to type 'join' to continue
  final Map<String, SavedMatchInfo> savedMatches;

  // Set by any game/match-result cookie: FIBS announces the result as a text
  // message (not a 15-off board), so this is the game-over signal.
  final bool gameEnded;

  // The result when known: true = we won, false = the opponent won, null =
  // in progress OR ended with an undisambiguated winner (shows a generic
  // "Game over").
  final bool? iWon;

  // The FIBS result line for a finished game/match, when FIBS announced one.
  final String? resultMessage;

  // --- derived display state (single source of truth) -----------------------

  GammonPlayer? get myColor =>
      board == null || user == null ? null : board!.colorFor(user!);

  bool get isMyTurn =>
      board != null && myColor != null && board!.turnPlayer == myColor;

  // the dice currently being played: roll-cookie dice when present, otherwise
  // the board's dice for fresh board frames such as the opening roll.
  List<int> get effectiveDice {
    if (board == null) return const [];
    if (board!.turnPlayer == null) return const [];
    final rolledDice = isMyTurn ? myDice : opponentDice;
    if (rolledDice.isNotEmpty) return rolledDice;
    return board!.activeDice;
  }

  // it's our turn and we have dice and we haven't already committed this turn
  bool get canMoveNow => isMyTurn && effectiveDice.isNotEmpty && !committedTurn;

  // it's our turn, FIBS has prompted for roll/double, no dice yet, and we
  // haven't already rolled -> we may choose roll or double
  bool get canRoll =>
      isMyTurn &&
      effectiveDice.isEmpty &&
      rollOrDoublePrompted &&
      !rolling &&
      !committedTurn;

  bool get canOfferDouble {
    final me = myColor;
    return canRoll && me != null && (board?.mayDoubleFor(me) ?? false);
  }

  // the current game has finished: FIBS announced a result, or the board shows
  // all 15 borne off
  bool get isGameOver => gameEnded || (board?.isGameOver ?? false);

  // The rendered game model (+ our just-rolled dice when FIBS delivered them
  // via "You roll x and y" without a fresh board). In a game WE play it's the
  // viewer board -- we are always engine player one, so the fixed renderer puts
  // us at the bottom with our home/off-tray in the lower-right whatever color
  // FIBS dealt us. When only watching, there's no "us", so it's the raw board.
  GammonState? get gameState {
    final b = board;
    if (b == null) return null;
    final displayDice = effectiveDice;
    final dice = displayDice.isNotEmpty ? displayDice : null;
    return myColor == null
        ? b.toGammonState(diceOverride: dice)
        : b.viewerState(me: myColor!, diceOverride: dice);
  }

  // --- event-sourced transitions --------------------------------------------

  // Fold an inbound FIBS cookie into the session. Pure: returns the next
  // session (or [this] unchanged for cookies this state machine ignores).
  FibsSession reduce(CookieMessage cm) =>
      _cookieReducers[cm.cookie]?.call(this, cm) ?? this;

  static bool reducesCookie(FibsCookie cookie) =>
      _cookieReducers.containsKey(cookie);

  static final Map<
    FibsCookie,
    FibsSession Function(FibsSession session, CookieMessage cm)
  >
  _cookieReducers = {
    FibsCookie.FIBS_RollOrDouble: (session, _) => session._afterRollOrDouble(),
    FibsCookie.FIBS_YouRoll: (session, cm) => session._afterYouRoll(cm),
    FibsCookie.FIBS_PlayerRolls: (session, cm) => session._afterPlayerRolls(cm),
    FibsCookie.FIBS_Turn: (session, cm) => session._afterTurn(cm),
    FibsCookie.FIBS_PleaseMove: (session, _) => session._afterMovePrompt(),
    FibsCookie.FIBS_YourTurnToMove: (session, _) => session._afterMovePrompt(),
    FibsCookie.FIBS_PlayerCantMove: (session, cm) => session._afterCantMove(cm),
    FibsCookie.FIBS_CantMove: (session, cm) => session._afterCantMove(cm),
    FibsCookie.FIBS_Board: (session, cm) => session._afterBoard(cm),
    // FIBS announces the game/match result as a text message, not a 15-off
    // board, so these are the authoritative game-over signal. Includes the
    // resignation outcomes from our perspective.
    FibsCookie.FIBS_YouWinGame: (session, cm) =>
        session._winResult(cm, iWon: true),
    FibsCookie.FIBS_YouWinMatch: (session, cm) =>
        session._winResult(cm, iWon: true),
    FibsCookie.FIBS_ResignYouWin: (session, cm) =>
        session._winResult(cm, iWon: true),
    FibsCookie.FIBS_YouAcceptAndWin: (session, cm) =>
        session._winResult(cm, iWon: true),
    FibsCookie.FIBS_PlayerWinsGame: (session, cm) =>
        session._winResult(cm, iWon: false),
    FibsCookie.FIBS_PlayerWinsMatch: (session, cm) =>
        session._winResult(cm, iWon: false),
    FibsCookie.FIBS_AcceptWins: (session, cm) =>
        session._winResult(cm, iWon: false),
    // Ended, winner not disambiguated here (a general "X gives up" line).
    FibsCookie.FIBS_ResignWins: (session, cm) =>
        session._winResult(cm, iWon: null),
    FibsCookie.FIBS_AcceptRejectDouble: (session, _) =>
        session.copyWith(doubleOffered: true),
    FibsCookie.FIBS_SavedMatch: (session, cm) =>
        session._withSavedMatch(cm, SavedMatchAvailability.offline),
    FibsCookie.FIBS_SavedMatchPlaying: (session, cm) =>
        session._withSavedMatch(cm, SavedMatchAvailability.online),
    FibsCookie.FIBS_SavedMatchReady: (session, cm) =>
        session._withSavedMatch(cm, SavedMatchAvailability.ready),
    FibsCookie.FIBS_NoSavedGames: (session, _) =>
        session.copyWith(savedMatches: const {}),
    FibsCookie.FIBS_ResumeMatchRequest: (session, cm) {
      final opponent = cm.crumbOrNull(FibsCrumbKeys.name);
      return session
          .withSavedOpponent(
            opponent,
            availability: SavedMatchAvailability.ready,
          )
          .copyWith(resumeRequestFrom: opponent);
    },
    FibsCookie.FIBS_TypeJoin: (session, cm) => session._withJoinPrompt(cm),
    FibsCookie.FIBS_JoinNextGame: (session, _) =>
        session.copyWith(mustJoin: true),
    FibsCookie.FIBS_ResumeMatchAck0: (session, cm) =>
        session._removeSavedMatch(cm),
    FibsCookie.FIBS_ResumeMatchAck5: (session, cm) =>
        session._removeSavedMatch(cm),
  };

  FibsSession _winResult(CookieMessage cm, {required bool? iWon}) =>
      copyWith(gameEnded: true, iWon: iWon, resultMessage: _resultText(cm));

  FibsSession _removeSavedMatch(CookieMessage cm) => copyWith(
    savedMatches: {...savedMatches}
      ..remove(cm.crumbOrNull(FibsCrumbKeys.opponent)),
  );

  FibsSession _afterRollOrDouble() {
    var b = board;
    final me = myColor;
    if (me != null && b != null && b.turnPlayer != me) {
      b = b.copyWith(turnColor: _turnColorFor(me));
    }
    return copyWith(
      board: b,
      myDice: const [],
      opponentDice: const [],
      rollOrDoublePrompted: true,
      rolling: false,
      committedTurn: false,
    );
  }

  FibsSession _afterYouRoll(CookieMessage cm) {
    final dice = _diceFromRoll(cm);
    // A YouRoll proves it's OUR turn. FIBS sometimes sends it WITHOUT a fresh
    // board (e.g. it auto-rolls for us after the opponent dances), leaving the
    // last board showing the opponent on roll -- which would wrongly play the
    // opponent's checkers. Reconcile to our turn.
    var b = board;
    final me = myColor;
    if (me != null && b != null && b.turnPlayer != me) {
      b = b.copyWith(turnColor: _turnColorFor(me));
    }
    return copyWith(
      board: b,
      myDice: dice,
      opponentDice: const [],
      rollOrDoublePrompted: false,
      rolling: false,
      committedTurn: false,
    );
  }

  FibsSession _afterPlayerRolls(CookieMessage cm) {
    final dice = _diceFromRoll(cm);
    var b = board;
    final roller = cm.crumbOrNull(FibsCrumbKeys.opponent);
    final rollerColor = b == null || roller == null
        ? null
        : _colorForExactBoardName(b, roller);
    if (b != null && rollerColor != null && b.turnPlayer != rollerColor) {
      b = b.copyWith(turnColor: _turnColorFor(rollerColor));
    }
    return copyWith(
      board: b,
      myDice: const [],
      opponentDice: dice,
      rollOrDoublePrompted: false,
      rolling: false,
      committedTurn: false,
    );
  }

  FibsSession _afterTurn(CookieMessage cm) {
    final b = board;
    if (b == null) return this;
    final player = cm.crumbOrNull(FibsCrumbKeys.name);
    final color = player == null
        ? null
        : _colorForBoardTurnName(b, player, user);
    if (color == null) return this;
    return copyWith(
      board: b.copyWith(turnColor: _turnColorFor(color)),
      myDice: const [],
      opponentDice: const [],
      rollOrDoublePrompted: false,
      rolling: false,
      committedTurn: false,
    );
  }

  FibsSession _afterMovePrompt() {
    var b = board;
    final me = myColor;
    if (me != null && b != null && b.turnPlayer != me) {
      b = b.copyWith(turnColor: _turnColorFor(me));
    }
    return copyWith(
      board: b,
      rollOrDoublePrompted: false,
      rolling: false,
      committedTurn: false,
    );
  }

  FibsSession _afterCantMove(CookieMessage cm) {
    final player =
        cm.crumbOrNull(FibsCrumbKeys.player) ??
        cm.crumbOrNull(FibsCrumbKeys.name);
    if (!_isMe(player)) return this;
    return copyWith(
      myDice: const [],
      rollOrDoublePrompted: false,
      rolling: false,
      committedTurn: true,
    );
  }

  FibsSession _afterBoard(CookieMessage cm) {
    final b = FibsBoard.fromCrumbs(cm.crumbs!);
    // A board is the AUTHORITATIVE dice state: its activeDice are our dice for
    // this turn (empty => we must roll). Drop any dice captured from a bare
    // YouRoll, or stale dice would make us try to move on a fresh "your turn,
    // no dice" board.
    final me = user == null ? null : b.colorFor(user!);
    // Keep "we rolled, awaiting our dice" only on a same-state refresh (still
    // our turn, still no dice), so we don't roll twice; anything else settles.
    final settled = b.turnPlayer != me || b.activeDice.isNotEmpty;
    final keepsRollPrompt =
        rollOrDoublePrompted &&
        b.turnPlayer == me &&
        b.activeDice.isEmpty &&
        !settled;
    return copyWith(
      board: b,
      myDice: const [],
      opponentDice: const [],
      rollOrDoublePrompted: keepsRollPrompt,
      doubleOffered: false, // a fresh board supersedes a pending offer
      resumeRequestFrom: null, // we're in a game now
      mustJoin: false,
      committedTurn: false, // this board is the response to our move
      rolling: !settled && rolling,
      // a fresh, in-progress board means the next game started -> clear a prior
      // result; a game-over board keeps whatever result was announced
      gameEnded: b.isGameOver && gameEnded,
      iWon: b.isGameOver ? iWon : null,
      resultMessage: b.isGameOver ? resultMessage : null,
    );
  }

  FibsSession _withSavedMatch(
    CookieMessage cm,
    SavedMatchAvailability availability,
  ) {
    final opponent =
        cm.crumbOrNull(FibsCrumbKeys.player1) ??
        cm.crumbOrNull(FibsCrumbKeys.opponent) ??
        cm.crumbOrNull(FibsCrumbKeys.name);
    if (opponent == null || opponent.isEmpty) return this;
    final existing = savedMatches[opponent];
    return copyWith(
      savedMatches: {
        ...savedMatches,
        opponent: SavedMatchInfo(
          opponent: opponent,
          score1: _intCrumb(cm, 'score1') ?? existing?.score1,
          score2: _intCrumb(cm, 'score2') ?? existing?.score2,
          matchLength:
              _intCrumb(cm, 'something') ??
              _intCrumb(cm, 'matchLength') ??
              existing?.matchLength,
          availability: availability,
        ),
      },
    );
  }

  FibsSession withSavedOpponent(
    String? opponent, {
    SavedMatchAvailability availability = SavedMatchAvailability.unknown,
  }) {
    if (opponent == null || opponent.isEmpty) return this;
    final existing = savedMatches[opponent];
    return copyWith(
      savedMatches: {
        ...savedMatches,
        opponent: SavedMatchInfo(
          opponent: opponent,
          score1: existing?.score1,
          score2: existing?.score2,
          matchLength: existing?.matchLength,
          availability: availability,
        ),
      },
    );
  }

  FibsSession _withJoinPrompt(CookieMessage cm) {
    final opponent = cm.crumbOrNull(FibsCrumbKeys.opponent);
    if (opponent == null || opponent.isEmpty) return this;
    if (!savedMatches.containsKey(opponent) && resumeRequestFrom != opponent) {
      return this;
    }
    return withSavedOpponent(
      opponent,
      availability: SavedMatchAvailability.ready,
    ).copyWith(resumeRequestFrom: opponent);
  }

  // our own actions, as explicit transitions (the optimistic in-flight flags)
  FibsSession startedRolling() =>
      copyWith(rolling: true, rollOrDoublePrompted: false);
  FibsSession committed() =>
      copyWith(committedTurn: true, rollOrDoublePrompted: false);
  FibsSession commandRejected() =>
      copyWith(committedTurn: false, rolling: false);
  FibsSession joined() => copyWith(mustJoin: false, resumeRequestFrom: null);
  FibsSession doubleResolved() => copyWith(doubleOffered: false);
  FibsSession loggedInAs(String user) => copyWith(user: user);

  bool _isMe(String? name) {
    if (name == null) return false;
    if (name == 'You') return true;
    return user != null && name.toLowerCase() == user!.toLowerCase();
  }

  // out of a game: watching, leaving, or switching whom we watch
  FibsSession outOfGame({String? savedOpponent}) =>
      withSavedOpponent(savedOpponent).copyWith(
        board: null,
        myDice: const [],
        opponentDice: const [],
        rollOrDoublePrompted: false,
        rolling: false,
        committedTurn: false,
        gameEnded: false, // leaving clears any announced result
        iWon: null,
        resultMessage: null,
      );

  static const _unset = Object();

  FibsSession copyWith({
    Object? user = _unset,
    Object? board = _unset,
    List<int>? myDice,
    List<int>? opponentDice,
    bool? rollOrDoublePrompted,
    bool? rolling,
    bool? committedTurn,
    bool? doubleOffered,
    Object? resumeRequestFrom = _unset,
    bool? mustJoin,
    Map<String, SavedMatchInfo>? savedMatches,
    bool? gameEnded,
    Object? iWon = _unset,
    Object? resultMessage = _unset,
  }) => FibsSession(
    user: user == _unset ? this.user : user as String?,
    board: board == _unset ? this.board : board as FibsBoard?,
    myDice: myDice ?? this.myDice,
    opponentDice: opponentDice ?? this.opponentDice,
    rollOrDoublePrompted: rollOrDoublePrompted ?? this.rollOrDoublePrompted,
    rolling: rolling ?? this.rolling,
    committedTurn: committedTurn ?? this.committedTurn,
    doubleOffered: doubleOffered ?? this.doubleOffered,
    resumeRequestFrom: resumeRequestFrom == _unset
        ? this.resumeRequestFrom
        : resumeRequestFrom as String?,
    mustJoin: mustJoin ?? this.mustJoin,
    savedMatches: savedMatches ?? this.savedMatches,
    gameEnded: gameEnded ?? this.gameEnded,
    iWon: iWon == _unset ? this.iWon : iWon as bool?,
    resultMessage: resultMessage == _unset
        ? this.resultMessage
        : resultMessage as String?,
  );
}

String _resultText(CookieMessage cm) {
  final compact = cm.raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  return compact.replaceAllMapped(RegExp(r'\s+([.!?,])'), (m) => m[1]!);
}

List<int> _diceFromRoll(CookieMessage cm) {
  final d1 = int.parse(cm.crumb(FibsCrumbKeys.die1));
  final d2 = int.parse(cm.crumb(FibsCrumbKeys.die2));
  return d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
}

int? _intCrumb(CookieMessage cm, String key) {
  final value = cm.crumbOrNull(key);
  return value == null ? null : int.tryParse(value);
}

int _turnColorFor(GammonPlayer player) => player == GammonPlayer.one ? -1 : 1;

GammonPlayer? _colorForExactBoardName(FibsBoard board, String name) {
  final player1 = board.player1Color == -1
      ? GammonPlayer.one
      : GammonPlayer.two;
  final player2 = player1 == GammonPlayer.one
      ? GammonPlayer.two
      : GammonPlayer.one;
  if (board.player1Name == name) return player1;
  if (board.player2Name == name) return player2;
  return null;
}

GammonPlayer? _colorForBoardTurnName(
  FibsBoard board,
  String name,
  String? user,
) {
  final folded = name.toLowerCase();
  final player1 = board.player1Color == -1
      ? GammonPlayer.one
      : GammonPlayer.two;
  final player2 = player1 == GammonPlayer.one
      ? GammonPlayer.two
      : GammonPlayer.one;
  if (name == 'You') {
    return user == null ? player1 : board.colorFor(user);
  }
  if (user != null && folded == user.toLowerCase()) {
    return board.colorFor(user);
  }
  if (board.player1Name.toLowerCase() == folded) return player1;
  if (board.player2Name.toLowerCase() == folded) return player2;
  return null;
}

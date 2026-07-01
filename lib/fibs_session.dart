import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/foundation.dart';

import 'fibs_board.dart';
import 'model.dart';

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
// single board/turn state machine that used to be a tangle of mutable flags.
@immutable
class FibsSession {
  const FibsSession({
    this.user,
    this.board,
    this.myDice = const [],
    this.rolling = false,
    this.committedTurn = false,
    this.doubleOffered = false,
    this.resumeRequestFrom,
    this.mustJoin = false,
    this.savedMatches = const {},
  });

  // --- authoritative state (the only real sources of truth) -----------------

  final String? user; // our FIBS login name (needed to find our color)
  final FibsBoard? board; // the latest board frame (null when not in a game)

  // the dice we rolled this turn, captured from FIBS_YouRoll. FIBS doesn't
  // always re-send the board with our dice after a roll, so we track them here.
  final List<int> myDice;

  // transient "command in flight" flags so canRoll/canMoveNow stop being true
  // the instant we act (FIBS has moreboards off, so it does NOT echo a board
  // after our own roll/move). _rolling: we sent `roll`, awaiting our dice (a
  // FIBS_YouRoll clears it). _committedTurn: we sent a whole move, awaiting the
  // next board.
  final bool rolling;
  final bool committedTurn;

  final bool doubleOffered; // the opponent doubled us; we must accept/reject
  final String? resumeRequestFrom; // an opponent asks to resume a saved match
  final bool mustJoin; // FIBS asks us to type 'join' to continue
  final Set<String> savedMatches; // opponents we have an unfinished match with

  // --- derived display state (single source of truth) -----------------------

  GammonPlayer? get myColor =>
      board == null || user == null ? null : board!.colorFor(user!);

  bool get isMyTurn =>
      board != null && myColor != null && board!.turnPlayer == myColor;

  // the dice we have to play: the board's dice if present (e.g. the opening),
  // otherwise the dice we just rolled (FIBS_YouRoll)
  List<int> get effectiveDice {
    if (board == null) return const [];
    final boardDice = board!.activeDice;
    if (boardDice.isNotEmpty) return boardDice;
    return isMyTurn ? myDice : const [];
  }

  // it's our turn and we have dice and we haven't already committed this turn
  bool get canMoveNow => isMyTurn && effectiveDice.isNotEmpty && !committedTurn;

  // it's our turn, no dice yet, and we haven't already rolled -> we must roll
  bool get canRoll =>
      isMyTurn && effectiveDice.isEmpty && !rolling && !committedTurn;

  // The rendered game model (+ our just-rolled dice when FIBS delivered them
  // via "You roll x and y" without a fresh board). In a game WE play it's the
  // viewer board -- we are always engine player one, so the fixed renderer puts
  // us at the bottom with our home/off-tray in the lower-right whatever color
  // FIBS dealt us. When only watching, there's no "us", so it's the raw board.
  GammonState? get gameState {
    final b = board;
    if (b == null) return null;
    final dice = myDice.isNotEmpty ? myDice : null;
    return myColor == null
        ? b.toGammonState(diceOverride: dice)
        : b.viewerState(me: myColor!, diceOverride: dice);
  }

  // --- event-sourced transitions --------------------------------------------

  // Fold an inbound FIBS cookie into the session. Pure: returns the next
  // session (or [this] unchanged for cookies this state machine ignores).
  FibsSession reduce(CookieMessage cm) => switch (cm.cookie) {
    FibsCookie.FIBS_YouRoll => _afterYouRoll(cm),
    FibsCookie.FIBS_Board => _afterBoard(cm),
    FibsCookie.FIBS_AcceptRejectDouble => copyWith(doubleOffered: true),
    FibsCookie.FIBS_SavedMatch => _withSavedMatch(cm.crumbOrNull('player1')),
    FibsCookie.FIBS_NoSavedGames => copyWith(savedMatches: const {}),
    FibsCookie.FIBS_ResumeMatchRequest => copyWith(
      resumeRequestFrom: cm.crumbOrNull('name'),
    ),
    FibsCookie.FIBS_JoinNextGame => copyWith(mustJoin: true),
    FibsCookie.FIBS_ResumeMatchAck0 ||
    FibsCookie.FIBS_ResumeMatchAck5 => copyWith(
      savedMatches: {...savedMatches}..remove(cm.crumbOrNull('opponent')),
    ),
    _ => this,
  };

  FibsSession _afterYouRoll(CookieMessage cm) {
    final d1 = int.parse(cm.crumb('die1'));
    final d2 = int.parse(cm.crumb('die2'));
    final dice = d1 == d2 ? [d1, d1, d1, d1] : [d1, d2];
    // A YouRoll proves it's OUR turn. FIBS sometimes sends it WITHOUT a fresh
    // board (e.g. it auto-rolls for us after the opponent dances), leaving the
    // last board showing the opponent on roll -- which would wrongly play the
    // opponent's checkers. Reconcile to our turn.
    var b = board;
    final me = myColor;
    if (me != null && b != null && b.turnPlayer != me) {
      b = b.copyWith(turnColor: me == GammonPlayer.one ? -1 : 1);
    }
    return copyWith(board: b, myDice: dice, rolling: false);
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
    return copyWith(
      board: b,
      myDice: const [],
      doubleOffered: false, // a fresh board supersedes a pending offer
      resumeRequestFrom: null, // we're in a game now
      mustJoin: false,
      committedTurn: false, // this board is the response to our move
      rolling: !settled && rolling,
    );
  }

  FibsSession _withSavedMatch(String? opponent) =>
      (opponent == null || opponent.isEmpty)
      ? this
      : copyWith(savedMatches: {...savedMatches, opponent});

  // our own actions, as explicit transitions (the optimistic in-flight flags)
  FibsSession startedRolling() => copyWith(rolling: true);
  FibsSession committed() => copyWith(committedTurn: true);
  FibsSession joined() => copyWith(mustJoin: false, resumeRequestFrom: null);
  FibsSession doubleResolved() => copyWith(doubleOffered: false);
  FibsSession loggedInAs(String user) => copyWith(user: user);

  // out of a game: watching, leaving, or switching whom we watch
  FibsSession outOfGame() => copyWith(
    board: null,
    myDice: const [],
    rolling: false,
    committedTurn: false,
  );

  static const _unset = Object();

  FibsSession copyWith({
    Object? user = _unset,
    Object? board = _unset,
    List<int>? myDice,
    bool? rolling,
    bool? committedTurn,
    bool? doubleOffered,
    Object? resumeRequestFrom = _unset,
    bool? mustJoin,
    Set<String>? savedMatches,
  }) => FibsSession(
    user: user == _unset ? this.user : user as String?,
    board: board == _unset ? this.board : board as FibsBoard?,
    myDice: myDice ?? this.myDice,
    rolling: rolling ?? this.rolling,
    committedTurn: committedTurn ?? this.committedTurn,
    doubleOffered: doubleOffered ?? this.doubleOffered,
    resumeRequestFrom: resumeRequestFrom == _unset
        ? this.resumeRequestFrom
        : resumeRequestFrom as String?,
    mustJoin: mustJoin ?? this.mustJoin,
    savedMatches: savedMatches ?? this.savedMatches,
  );
}

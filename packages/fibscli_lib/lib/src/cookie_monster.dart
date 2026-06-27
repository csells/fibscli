// From http://www.fibs.com/fcm/
// FIBS Client Protocol Detailed Specification: http://www.fibs.com/fibs_interface.html
// ignore_for_file: public_member_api_docs, constant_identifier_names

/*
 *---  FIBSCookieMonster.c --------------------------------------------------
 *
 *  Created by Paul Ferguson on Tue Dec 24 2002. Copyright (c) 2003 Paul
 *  Ferguson. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * * Redistributions of source code must retain the above copyright notice, this
 *   list of conditions and the following disclaimer.
 *
 * * Redistributions in binary form must reproduce the above copyright notice,
 *   this list of conditions and the following disclaimer in the documentation
 *   and/or other materials provided with the distribution.
 *
 * * The name of Paul D. Ferguson may not be used to endorse or promote products
 *   derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 * POSSIBILITY OF SUCH DAMAGE.
 *
 *---------------------------------------------------------------------------
 * Oct, 2016, csells ported this to C# as part of Fibs.Net, added some useful
 * features http://github.com/csells/fibs.net Oct, 2020, csells ported this to
 * Dart as part of a FIBS Backgammon client for Flutter
 * http://github.com/csells/fibscli
 */

import 'package:quiver/strings.dart';

class CookieMessage {
  CookieMessage(this.cookie, this.raw, this.crumbs, this.eatState)
      :
        // Cannot have zero-length crumb dictionary. Pass null instead.
        assert(crumbs == null || crumbs.isNotEmpty);

  final FibsCookie cookie;
  final String raw;
  Map<String, String>? crumbs;
  final CookieMonsterState eatState;

  @override
  String toString() =>
      '{cookie: $cookie, crumbs: $crumbs, eatState: $eatState}';
}

// A simple state model
enum CookieMonsterState {
  FIBS_LOGIN_STATE,
  FIBS_MOTD_STATE,
  FIBS_RUN_STATE,
  FIBS_LOGOUT_STATE
}

// Principle data structure. Used internally--clients never see the dough,
// just the finished cookie.
class _CookieDough {
  _CookieDough({required this.cookie, required this.re, this.extras});

  final FibsCookie cookie;
  final RegExp re;
  final Map<String, String>? extras;
}

class CookieMonster {
  CookieMonsterState messageState = CookieMonsterState.FIBS_LOGIN_STATE;
  CookieMonsterState? oldMessageState;

  static CookieMessage? _makeCookie(
      List<_CookieDough> batch, String raw, CookieMonsterState eatState) {
    assert(!raw.contains('\n'));

    for (final dough in batch) {
      final match = dough.re.firstMatch(raw);
      if (match != null) {
        final crumbs = <String, String>{};
        final namedGroups =
            match.groupNames.where((n) => !isDigit(n.codeUnitAt(0)));
        for (final name in namedGroups) {
          final value = match.namedGroup(name)!.trim();
          crumbs[name] = value;

          // only "message" values are allowed to be empty
          assert((name == 'message') || value.isNotEmpty,
              '${dough.cookie}: missing crumb "$name"');
        }

        // drop in hard-coded extra name-value pairs
        if (dough.extras != null) {
          for (final pair in dough.extras!.entries) {
            crumbs[pair.key] = pair.value;

            // only "message" values are allowed to be empty
            assert((pair.key == 'message') || pair.value.isNotEmpty,
                '${dough.cookie}: missing crumb "{pair.Key}"');
          }
        }

        return CookieMessage(
            dough.cookie, raw, crumbs.isEmpty ? null : crumbs, eatState);
      }
    }

    return null;
  }

  // Returns a cookie message
  // NOTE: The incoming FIBS message should NOT include line terminators.
  CookieMessage eatCookie(String raw) {
    final eatState = messageState;
    CookieMessage? cm;

    switch (messageState) {
      case CookieMonsterState.FIBS_RUN_STATE:
        if (raw.isEmpty) {
          cm = CookieMessage(FibsCookie.FIBS_Empty, raw, null, eatState);
          break;
        }

        final s0 = raw.substring(0, 1);
        // CLIP messages and miscellaneous numeric messages
        if (isDigit(s0.codeUnitAt(0))) {
          cm = _makeCookie(numericBatch, raw, eatState);
        }
        // '** ' messages
        else if (s0 == '*') {
          cm = _makeCookie(starsBatch, raw, eatState);
        }
        // all other messages
        else {
          cm = _makeCookie(alphaBatch, raw, eatState);
        }

        if (cm != null && cm.cookie == FibsCookie.FIBS_Goodbye) {
          messageState = CookieMonsterState.FIBS_LOGOUT_STATE;
        }

      case CookieMonsterState.FIBS_LOGIN_STATE:
        cm = _makeCookie(loginBatch, raw, eatState);
        assert(cm != null); // there's a catch all
        if (cm!.cookie == FibsCookie.CLIP_MOTD_BEGIN) {
          messageState = CookieMonsterState.FIBS_MOTD_STATE;
        }

      case CookieMonsterState.FIBS_MOTD_STATE:
        cm = _makeCookie(motdBatch, raw, eatState);
        assert(cm != null); // there's a catch all
        if (cm!.cookie == FibsCookie.CLIP_MOTD_END) {
          messageState = CookieMonsterState.FIBS_RUN_STATE;
        }

      case CookieMonsterState.FIBS_LOGOUT_STATE:
        cm = CookieMessage(
            FibsCookie.FIBS_PostGoodbye, raw, {'message': raw}, eatState);
    }

    cm ??= CookieMessage(FibsCookie.FIBS_Unknown, raw, {'raw': raw}, eatState);

    // output the initial state if no state has been shown at all
    // ignore: prefer_conditional_assignment
    if (oldMessageState == null) {
      // Logger.root.log(Level.FINE, 'State= $eatState');
      // print('State= $eatState');
      oldMessageState = eatState;
    }

    // Logger.root.log(Level.FINE, 'State= $eatState');
    // print('State= $eatState');
    // if (cm.crumbs != null) {
    // final crumbs = cm.crumbs.keys.map(
    //  (key) => '$key= ${cm.crumbs[key]}').join(', ');
    // Logger.root.log(Level.FINE, '\t$crumbs');
    // print('\t$crumbs');
    // }

    // output the new state as soon as we transition
    if (oldMessageState != messageState) {
      // Logger.root.log(Level.FINE, 'State= $messageState');
      // print('State= $messageState');
      oldMessageState = messageState;
    }

    return cm;
  }

  // "-" returned as null
  static String? parseOptional(String s) => s.trim() == '-' ? null : s;

  static bool parseBool(String? s) => s == '1' || s == 'YES';
  static String? parseBoardTurn(String s) => parseTurnColor(int.parse(s));
  static String parseBoardColorInt(int i) => i == -1 ? 'X' : 'O';
  static String parseBoardColorString(String s) =>
      parseBoardColorInt(int.parse(s));

  static DateTime parseTimestamp(String timestamp) =>
      DateTime(1970, 1, 1, 0, 0, 0)
          .add(Duration(seconds: int.parse(timestamp)));

  static String? parseTurnColor(int i) {
    if (i == -1) {
      return 'X';
    } else if (i == 1) {
      return 'O';
    } else {
      return null;
    }
  }

  // Initialize stuff, ready to start pumping out cookies by the thousands.
  // Note that the order of items in this function is important, in some cases
  // messages are very similar and are differentiated by depending on the
  // order the batch is processed.

  static final catchAllIntoMessageRegex = RegExp('(?<message>.*)');

  // for RUN_STATE
  static final alphaBatch = [
    _CookieDough(
      cookie: FibsCookie.FIBS_Board,
      re: RegExp(
          r'^board:(?<player1>[^:]+):(?<player2>[^:]+):(?<matchLength>\d+):(?<player1Score>\d+):(?<player2Score>\d+):(?<board>([-0-9]+:){25}\d+):(?<turnColor>-1|0|1):(?<player1Dice>\d:\d):(?<player2Dice>\d:\d):(?<doublingCube>\d+):(?<player1MayDouble>[0-1]):(?<player2MayDouble>[0-1]):(?<wasDoubled>[0-1]):(?<player1Color>-?1):(?<direction>-?1):\d+:\d+:(?<player1Home>\d+):(?<player2Home>\d+):(?<player1Bar>\d+):(?<player2Bar>\d+):(?<canMove>[0-4]):\d+:\d+:(?<redoubles>\d+)$'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouRoll,
      re: RegExp('^You roll (?<die1>[1-6]) and (?<die2>[1-6])'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerRolls,
      re: RegExp(
          '^(?<opponent>[a-zA-Z_<>]+) rolls (?<die1>[1-6]) and (?<die2>[1-6])'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RollOrDouble,
      re: RegExp(r"^It's your turn to roll or double\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RollOrDouble,
      re: RegExp(r"^It's your turn\. Please roll or double"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_AcceptRejectDouble,
      re: RegExp(
          r"^(?<opponent>[a-zA-Z_<>]+) doubles\. Type 'accept' or 'reject'\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Doubles,
      re: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) doubles\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
      re: RegExp(r'(?<opponent>^[a-zA-Z_<>]+) accepts the double\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PleaseMove,
      re: RegExp(r'^Please move (?<pieces>[1-4]) pieces?\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerMoves,
      re: RegExp('^(?<player>[a-zA-Z_<>]+) moves (?<moves>[0-9- ]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerCantMove,
      re: RegExp("^(?<player>[a-zA-Z_<>]+) can't move"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_BearingOff,
      re: RegExp('^Bearing off: (?<bearing>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouReject,
      re: RegExp(r'^You reject\. The game continues\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouStopWatching,
      re: RegExp(
          r"(?<name>[a-zA-Z_<>]+) logs out\. You're not watching anymore\."),
    ), // overloaded	//PLAYER logs out. You're not watching anymore.
    _CookieDough(
      cookie: FibsCookie.FIBS_OpponentLogsOut,
      re: RegExp(r'^(?<opponent>[a-zA-Z_<>]+) logs out\. The game was saved'),
    ), // PLAYER logs out. The game was saved.
    _CookieDough(
      cookie: FibsCookie.FIBS_OpponentLogsOut,
      re: RegExp(
          r'^(?<opponent>[a-zA-Z_<>]+) drops connection\. The game was saved'),
    ), // PLAYER drops connection. The game was saved.
    _CookieDough(
      cookie: FibsCookie.FIBS_OnlyPossibleMove,
      re: RegExp('^The only possible move is (?<move>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_FirstRoll,
      re: RegExp(
          '(?<opponent>[a-zA-Z_<>]+) rolled (?<opponentDie>[1-6]).+rolled '
          '(?<yourDie>[1-6])'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MakesFirstMove,
      re: RegExp(r'(?<opponent>[a-zA-Z_<>]+) makes the first move\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouDouble,
      re: RegExp(
          r'^You double\. Please wait for (?<opponent>[a-zA-Z_<>]+) to accept or reject'),
    ), // You double. Please wait for PLAYER to accept or reject.
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerWantsToResign,
      re: RegExp(
          r"^(?<opponent>[a-zA-Z_<>]+) wants to resign\. You will win (?<points>[0-9]+) points?\. Type 'accept' or 'reject'\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WatchResign,
      re: RegExp(r'^(?<player1>[a-zA-Z_<>]+) wants to resign\. '
          '(?<player2>[a-zA-Z_<>]+) will win (?<points>[0-9]+) points'),
    ), // PLAYER wants to resign. PLAYER2 will win 2 points.  (ORDER MATTERS)
    _CookieDough(
      cookie: FibsCookie.FIBS_YouResign,
      re: RegExp('^You want to resign. (?<opponent>[a-zA-Z_<>]+) will win '
          '(?<points>[0-9]+)'),
    ), // You want to resign. PLAYER will win 1 .
    _CookieDough(
      cookie: FibsCookie.FIBS_ResumeMatchAck5,
      re: RegExp(
          r'^You are now playing with (?<opponent>[a-zA-Z_<>]+)\. Your running match was loaded'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_JoinNextGame,
      re: RegExp(
          r"^Type 'join' if you want to play the next game, type 'leave' if you don't\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NewMatchRequest,
      re: RegExp(
          r'^(?<name>[a-zA-Z_<>]+) wants to play a (?<points>[0-9]+) point match with you\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WARNINGSavedMatch,
      re: RegExp("^WARNING: Don't accept if you want to continue"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ResignRefused,
      re: RegExp(r'^(?<opponent>[a-zA-Z_<>]+) rejects\. The game continues\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MatchLength,
      re: RegExp('^match length: (?<length>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_TypeJoin,
      re: RegExp(r"^Type 'join (?<opponent>[a-zA-Z_<>]+)' to accept\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouAreWatching,
      re: RegExp("^You're now watching (?<name>[a-zA-Z_<>]+)"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouStopWatching,
      re: RegExp('^You stop watching (?<name>[a-zA-Z_<>]+)'),
    ), // overloaded
    _CookieDough(
      cookie: FibsCookie.FIBS_NotDoingAnything,
      re: RegExp(r'^(?<name>[a-zA-Z_<>]+) is not doing anything interesting\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerStartsWatching,
      re: RegExp(
          '(?<player1>[a-zA-Z_<>]+) starts watching (?<player2>[a-zA-Z_<>]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerStartsWatching,
      re: RegExp('(?<name>[a-zA-Z_<>]+) is watching you'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerStopsWatching,
      re: RegExp(
          '(?<name>[a-zA-Z_<>]+) stops watching (?<player>[a-zA-Z_<>]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerIsWatching,
      re: RegExp('(?<name>[a-zA-Z_<>]+) is watching '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerLeftGame,
      re: RegExp('(?<player1>[a-zA-Z_<>]+) has left the game with '
          '(?<player2>[a-zA-Z_<>]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ResignWins,
      re: RegExp(
          r'^(?<player1>[a-zA-Z_<>]+) gives up\. (?<player2>[a-zA-Z_<>]+) wins (?<points>[0-9]+) points?'),
    ), // PLAYER1 gives up. PLAYER2 wins 1 point.
    _CookieDough(
      cookie: FibsCookie.FIBS_ResignYouWin,
      re: RegExp(
          r'^(?<opponent>[a-zA-Z_<>]+) gives up\. You win (?<points>[0-9]+) points'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouAcceptAndWin,
      re: RegExp('^You accept and win (?<something>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_AcceptWins,
      re: RegExp(
          '^(?<opponent>[a-zA-Z_<>]+) accepts and wins (?<points>[0-9]+) '
          'point'),
    ), // PLAYER accepts and wins N points.
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayersStartingMatch,
      re: RegExp(
          '^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start a '
          '(?<points>[0-9]+) point match'),
    ), // PLAYER and PLAYER start a <n> point match.
    _CookieDough(
      cookie: FibsCookie.FIBS_StartingNewGame,
      re: RegExp('^Starting a  game with (?<opponent>[a-zA-Z_<>]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouGiveUp,
      re: RegExp('^You give up'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouWinMatch,
      re: RegExp('^You win the (?<points>[0-9]+) point match '
          '(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerWinsMatch,
      re: RegExp(
          '^(?<opponent>[a-zA-Z_<>]+) wins the (?<points>[0-9]+) point match '
          '(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)'),
    ), //PLAYER wins the 3 point match 3-0 .
    _CookieDough(
      cookie: FibsCookie.FIBS_ResumingUnlimitedMatch,
      re: RegExp(
          r'^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their unlimited match\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ResumingLimitedMatch,
      re: RegExp(
          r'^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) are resuming their (?<points>[0-9]+)-point match\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MatchResult,
      re: RegExp(
          '^(?<winner>[a-zA-Z_<>]+) wins a (?<points>[0-9]+) point match '
          'against (?<loser>[a-zA-Z_<>]+) '
          '+(?<winnerScore>[0-9]+)-(?<loserScore>[0-9]+)'),
    ), //PLAYER wins a 9 point match against PLAYER  11-6 .
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerWantsToResign,
      re: RegExp(r'^(?<name>[a-zA-Z_<>]+) wants to resign\.'),
    ), //  Same as a longline in an actual game  This is just for watching.
    _CookieDough(
      cookie: FibsCookie.FIBS_BAD_AcceptDouble,
      re: RegExp(
          r'^(?<name>[a-zA-Z_<>]+) accepts? the double\. The cube shows (?<cube>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouAcceptDouble,
      re: RegExp(r'^You accept the double\. The cube shows (?<cube>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
      re: RegExp(
          r'(?<name>^[a-zA-Z_<>]+) accepts the double\. The cube shows (?<cube>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerAcceptsDouble,
      re: RegExp('^(?<name>[a-zA-Z_<>]+) accepts the double'),
    ), // while watching
    _CookieDough(
      cookie: FibsCookie.FIBS_ResumeMatchRequest,
      re: RegExp(
          '^(?<name>[a-zA-Z_<>]+) wants to resume a saved match with you'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ResumeMatchAck0,
      re: RegExp(
          r'^(?<opponent>[a-zA-Z_<>]+) has joined you\. Your running match was loaded'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouWinGame,
      re: RegExp('^You win the game and get (?<points>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_UnlimitedInvite,
      re: RegExp(
          '^(?<name>[a-zA-Z_<>]+) wants to play an unlimted match with you'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerWinsGame,
      re: RegExp(
          '^(?<opponent>[a-zA-Z_<>]+) wins the game and gets (?<points>[0-9]+) '
          'points?. Sorry'),
    ),
    // CookieDough (cookie: FibsCookie.FIBS_PlayerWinsGame, regex: RegExp(r"^[a-zA-Z_<>]+ wins the game and gets [0-9] points?."),), // (when watching)
    _CookieDough(
      cookie: FibsCookie.FIBS_WatchGameWins,
      re: RegExp('^(?<name>[a-zA-Z_<>]+) wins the game and gets '
          '(?<points>[0-9]+) points'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayersStartingUnlimitedMatch,
      re: RegExp(
          '^(?<player1>[a-zA-Z_<>]+) and (?<player2>[a-zA-Z_<>]+) start an '
          'unlimited match'),
    ), // PLAYER_A and PLAYER_B start an unlimited match.
    _CookieDough(
      cookie: FibsCookie.FIBS_ReportLimitedMatch,
      re: RegExp('^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) '
          '(?<points>[0-9]+) point match (?<score1>[0-9]+)-(?<score2>[0-9]+)'),
    ), // PLAYER_A        -       PLAYER_B (5 point match 2-2)
    _CookieDough(
      cookie: FibsCookie.FIBS_ReportUnlimitedMatch,
      re: RegExp(
          r'^(?<player1>[a-zA-Z_<>]+) +- +(?<player2>[a-zA-Z_<>]+) \(unlimited (?<something>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesStart,
      re: RegExp(
          '^(?<playerX>[a-zA-Z_<>]+) is X - (?<playerO>[a-zA-Z_<>]+) is O'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesRoll,
      re: RegExp(r'^[XO]: \([1-6]'),
    ), // ORDER MATTERS HERE
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesWins,
      re: RegExp('^[XO]: wins'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesDoubles,
      re: RegExp('^[XO]: doubles'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesAccepts,
      re: RegExp('^[XO]: accepts'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesRejects,
      re: RegExp('^[XO]: rejects'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ShowMovesOther,
      re: RegExp('^[XO]:'),
    ), // AND HERE
    _CookieDough(
      cookie: FibsCookie.FIBS_ScoreUpdate,
      re: RegExp('^score in (?<points>[0-9]+) point match:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MatchStart,
      re: RegExp(
          r'^Score is (?<score1>[0-9]+)-(?<score2>[0-9]+) in a (?<points>[0-9]+) point match\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsHeader,
      re: RegExp('^Settings of variables:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp(
          '^(?<name>allowpip|autoboard|autodouble|automove|bell|crawford|double'
          '|moreboards|moves|greedy|notify|ratings|ready|report|silent|telnet|'
          'wrap) +(?<value>YES|NO)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Turn,
      re: RegExp('^turn:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>boardstyle): +(?<value>[1-3])'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(r"^Value of '(?<name>boardstyle)' set to (?<value>[1-3])\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>linelength): +(?<value>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(r"^Value of '(?<name>linelength)' set to (?<value>[0-9]+)\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>pagelength): +(?<value>[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(r"^Value of '(?<name>pagelength)' set to (?<value>[0-9]+)\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>redoubles): +(?<value>none|unlimited|[0-9]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(
          r"^Value of '(?<name>redoubles)' set to '?(?<value>none|unlimited|[0-9]+)'?\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>sortwho): +(?<value>login|name|rating|rrating)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp("^Value of '(?<name>sortwho)' set to "
          '(?<value>login|name|rating|rrating)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsValue,
      re: RegExp('^(?<name>timezone): +(?<value>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(r"^Value of '(?<name>timezone)' set to (?<value>.*)\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantMove,
      re: RegExp("^(?<name>[a-zA-Z_<>]+) can't move"),
    ), // PLAYER can't move || You can't move
    _CookieDough(
      cookie: FibsCookie.FIBS_ListOfGames,
      re: RegExp('^List of games:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerInfoStart,
      re: RegExp('^Information about'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_EmailAddress,
      re: RegExp('^  Email address:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoEmail,
      re: RegExp('^  No email address'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WavesAgain,
      re: RegExp('^(?<name>[a-zA-Z_<>]+) waves goodbye again'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Waves,
      re: RegExp('^(?<name>[a-zA-Z_<>]+) waves goodbye'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Waves,
      re: RegExp('^You wave goodbye'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WavesAgain,
      re: RegExp('^You wave goodbye again and log out'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoSavedGames,
      re: RegExp('^no saved games'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SavedMatch,
      re: RegExp(
          '^  (?<player1>[a-zA-Z_<>]+) +(?<score1>[0-9]+) +(?<score2>[0-9]+) '
          '+- +(?<something>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SavedMatchPlaying,
      re: RegExp(r'^ \*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +'),
    ),
    // NOTE: for FIBS_SavedMatchReady, see the Stars message, because it will
    // appear to be one of those (has asterisk at index 0).
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerIsWaitingForYou,
      re: RegExp(r'^[a-zA-Z_<>]+ is waiting for you to log in\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_IsAway,
      re: RegExp('^[a-zA-Z_<>]+ is away: '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Junk,
      re: RegExp('^Closed old connection with user'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Done,
      re: RegExp(r'^Done\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YourTurnToMove,
      re: RegExp(r"^It's your turn to move\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SavedMatchesHeader,
      re: RegExp(
          r'^  opponent          matchlength   score \(your points first\)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MessagesForYou,
      re: RegExp('^There are messages for you:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_DoublingCubeNow,
      re: RegExp('^The number on the doubling cube is now [0-9]+'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_FailedLogin,
      re: RegExp('^> [0-9]+'),
    ), // bogus CLIP messages sent after a failed login
    _CookieDough(
      cookie: FibsCookie.FIBS_Average,
      re: RegExp('^Time (UTC)  average min max'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_DiceTest,
      re: RegExp('^[nST]: '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_LastLogout,
      re: RegExp('^  Last logout:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcStart,
      re: RegExp('^rating calculation:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('^Probability that underdog wins:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('is 1-Pu if underdog wins'),
    ), // P=0.505861 is 1-Pu if underdog wins and Pu if favorite wins
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('^Experience: '),
    ), // Experience: fergy 500 - jfk 5832
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp(r'^K=max\(1'),
    ), // K=max(1 ,		-Experience/100+5) for fergy: 1.000000
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('^rating difference'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('^change for'),
    ), // change for fergy: 4*K*sqrt(N)*P=2.023443
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingCalcInfo,
      re: RegExp('^match length  '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WatchingHeader,
      re: RegExp('^Watching players:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsHeader,
      re: RegExp('^The current settings are:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_AwayListHeader,
      re: RegExp('^The following users are away:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingExperience,
      re: RegExp(r'^  Rating: +[0-9]+\.'),
    ), // Rating: 1693.11 Experience: 5781
    _CookieDough(
      cookie: FibsCookie.FIBS_NotLoggedIn,
      re: RegExp(r'^  Not logged in right now\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_IsPlayingWith,
      re: RegExp('is playing with'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SavedScoreHeader,
      re: RegExp('^opponent +matchlength'),
    ), //	opponent          matchlength   score (your points first)
    _CookieDough(
      cookie: FibsCookie.FIBS_StillLoggedIn,
      re: RegExp(r'^  Still logged in\.'),
    ), //  Still logged in. 2:12 minutes idle.
    _CookieDough(
      cookie: FibsCookie.FIBS_NoOneIsAway,
      re: RegExp(r'^None of the users is away\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerListHeader,
      re: RegExp('^No  S  username        rating  exp login    idle  from'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_RatingsHeader,
      re: RegExp('^ rank name            rating    Experience'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_ClearScreen,
      re: RegExp(r'^.\[, },H.\[2J'),
    ), // ANSI clear screen sequence
    _CookieDough(
      cookie: FibsCookie.FIBS_Timeout,
      re: RegExp(r'^Connection timed out\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Goodbye,
      re: RegExp(r'(?<message>           Goodbye\.)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_LastLogin,
      re: RegExp('^  Last login:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoInfo,
      re: RegExp('^No information found on user'),
    ),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^You're away\. Please type 'back'"),
        extras: {'name': 'away', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^Welcome back\.'),
        extras: {'name': 'away', 'value': 'NO'}),
  ];

  //--- Numeric messages ---------------------------------------------------
  static final numericBatch = [
    _CookieDough(
      cookie: FibsCookie.CLIP_WHO_INFO,
      re: RegExp(
          r'^5 (?<name>[^ ]+) (?<opponent>[^ ]+) (?<watching>[^ ]+) (?<ready>[01]) (?<away>[01]) (?<rating>[0-9]+\.[0-9]+) (?<experience>[0-9]+) (?<idle>[0-9]+) (?<login>[0-9]+) (?<hostName>[^ ]+) (?<client>[^ ]+) (?<email>[^ ]+)'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Average,
      re: RegExp('^[0-9][0-9]:[0-9][0-9]-'),
    ), // output of average command
    _CookieDough(
      cookie: FibsCookie.FIBS_DiceTest,
      re: RegExp('^[1-6]-1 [0-9]'),
    ), // output of dicetest command
    _CookieDough(
      cookie: FibsCookie.FIBS_DiceTest,
      re: RegExp('^[1-6]: [0-9]'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Stat,
      re: RegExp('^[0-9]+ bytes'),
    ), // output from stat command
    _CookieDough(
      cookie: FibsCookie.FIBS_Stat,
      re: RegExp('^[0-9]+ accounts'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Stat,
      re: RegExp('^[0-9]+ ratings saved. reset log'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Stat,
      re: RegExp('^[0-9]+ registered users.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Stat,
      re: RegExp(r'^[0-9]+\([0-9]+\) saved games check by cron'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_WHO_END,
      re: RegExp(r'^6$'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_SHOUTS,
      re: RegExp('^13 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_SAYS,
      re: RegExp('^12 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_WHISPERS,
      re: RegExp('^14 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_KIBITZES,
      re: RegExp('^15 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_YOU_SAY,
      re: RegExp('^16 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_YOU_SHOUT,
      re: RegExp('^17 (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_YOU_WHISPER,
      re: RegExp('^18 (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_YOU_KIBITZ,
      re: RegExp('^19 (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_LOGIN,
      re: RegExp('^7 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_LOGOUT,
      re: RegExp('^8 (?<name>[a-zA-Z_<>]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_MESSAGE,
      re: RegExp('^9 (?<from>[a-zA-Z_<>]+) (?<time>[0-9]+) (?<message>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_MESSAGE_DELIVERED,
      re: RegExp(r'^10 (?<name>[a-zA-Z_<>]+)$'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_MESSAGE_SAVED,
      re: RegExp(r'^11 (?<name>[a-zA-Z_<>]+)$'),
    ),
  ];

  //--- '**' messages ------------------------------------------------------
  static final starsBatch = [
    _CookieDough(
      cookie: FibsCookie.FIBS_Username,
      re: RegExp(r'^\*\* User'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Junk,
      re: RegExp(r'^\*\* You tell '),
    ), // "** You tell PLAYER: xxxxx"
    _CookieDough(
      cookie: FibsCookie.FIBS_YouGag,
      re: RegExp(r'^\*\* You gag'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouUngag,
      re: RegExp(r'^\*\* You ungag'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouBlind,
      re: RegExp(r'^\*\* You blind'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouUnblind,
      re: RegExp(r'^\*\* You unblind'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_UseToggleReady,
      re: RegExp(r"^\*\* Use 'toggle ready' first"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NewMatchAck9,
      re: RegExp(r'^\*\* You are now playing an unlimited match with '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NewMatchAck10,
      re: RegExp(r'^\*\* You are now playing a [0-9]+ point match with '),
    ), // ** You are now playing a 5 point match with PLAYER
    _CookieDough(
      cookie: FibsCookie.FIBS_NewMatchAck2,
      re: RegExp(
          r'^\*\* Player (?<name>[a-zA-Z_<>]+) has joined you for a (?<points>[0-9]+) point match'),
    ), // ** Player PLAYER has joined you for a 2 point match.
    _CookieDough(
      cookie: FibsCookie.FIBS_YouTerminated,
      re: RegExp(r'^\*\* You terminated the game'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_OpponentLeftGame,
      re: RegExp(
          r'^\*\* Player [a-zA-Z_<>]+ has left the game. The game was saved\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerLeftGame,
      re: RegExp(r'has left the game\.'),
    ), // overloaded
    _CookieDough(
      cookie: FibsCookie.FIBS_YouInvited,
      re: RegExp(r'^\*\* You invited'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YourLastLogin,
      re: RegExp(r'^\*\* Last login:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoOne,
      re: RegExp(r'^\*\* There is no one called (?<name>[a-zA-Z_<>]+)'),
    ),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You allow the use the server's 'pip' command\."),
        extras: {'name': 'allowpip', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(
            r"^\*\* You don't allow the use of the server's 'pip' command\."),
        extras: {'name': 'allowpip', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* The board will be refreshed'),
        extras: {'name': 'autoboard', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* The board won't be refreshed"),
        extras: {'name': 'autoboard', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You agree that doublets'),
        extras: {'name': 'autodouble', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You don't agree that doublets"),
        extras: {'name': 'autodouble', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* Forced moves will'),
        extras: {'name': 'automove', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* Forced moves won't"),
        extras: {'name': 'automove', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* Your terminal will ring'),
        extras: {'name': 'bell', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* Your terminal won't ring"),
        extras: {'name': 'bell', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You insist on playing with the Crawford rule\.'),
        extras: {'name': 'crawford', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(
            r'^\*\* You would like to play without using the Crawford rule\.'),
        extras: {'name': 'crawford', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You will be asked if you want to double\.'),
        extras: {'name': 'double', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You won't be asked if you want to double\."),
        extras: {'name': 'double', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* Will use automatic greedy bearoffs\.'),
        extras: {'name': 'greedy', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* Won't use automatic greedy bearoffs\."),
        extras: {'name': 'greedy', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* Will send rawboards after rolling\.'),
        extras: {'name': 'moreboards', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* Won't send rawboards after rolling\."),
        extras: {'name': 'moreboards', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You want a list of moves after this game\.'),
        extras: {'name': 'moves', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You won't see a list of moves after this game\."),
        extras: {'name': 'moves', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You'll be notified"),
        extras: {'name': 'notify', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You won't be notified"),
        extras: {'name': 'notify', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You'll see how the rating changes are calculated\."),
        extras: {'name': 'ratings', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(
            r"^\*\* You won't see how the rating changes are calculated\."),
        extras: {'name': 'ratings', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You're now ready to invite or join someone\."),
        extras: {'name': 'ready', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You're now refusing to play with someone\."),
        extras: {'name': 'ready', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You will be informed'),
        extras: {'name': 'report', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You won't be informed"),
        extras: {'name': 'report', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You will hear what other players shout\.'),
        extras: {'name': 'silent', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r"^\*\* You won't hear what other players shout\."),
        extras: {'name': 'silent', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You use telnet'),
        extras: {'name': 'telnet', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* You use a client program'),
        extras: {'name': 'telnet', 'value': 'NO'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* The server will wrap'),
        extras: {'name': 'wrap', 'value': 'YES'}),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsChange,
        re: RegExp(r'^\*\* Your terminal knows how to wrap'),
        extras: {'name': 'wrap', 'value': 'NO'}),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerRefusingGames,
      re: RegExp(r'^\*\* [a-zA-Z_<>]+ is refusing games\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NotWatching,
      re: RegExp(r"^\*\* You're not watching\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NotWatchingPlaying,
      re: RegExp(r"^\*\* You're not watching or playing\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NotPlaying,
      re: RegExp(r"^\*\* You're not playing\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoUser,
      re: RegExp(r'^\*\* There is no one called '),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_AlreadyPlaying,
      re: RegExp('is already playing with'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_DidntInvite,
      re: RegExp(r"^\*\* [a-zA-Z_<>]+ didn't invite you."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_BadMove,
      re: RegExp(r"^\*\* You can't remove this piece"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantMoveFirstMove,
      re: RegExp(r"^\*\* You can't move "),
    ), // ** You can't move 3 points in your first move
    _CookieDough(
      cookie: FibsCookie.FIBS_CantShout,
      re: RegExp(r"^\*\* Please type 'toggle silent' again before you shout\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MustMove,
      re: RegExp(r'^\*\* You must give [1-4] moves'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MustComeIn,
      re: RegExp(
          r'^\*\* You have to remove pieces from the bar in your first move\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_UsersHeardYou,
      re: RegExp(r'^\*\* [0-9]+ users? heard you\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Junk,
      re: RegExp(r'^\*\* Please wait for [a-zA-Z_<>]+ to join too\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_SavedMatchReady,
      re: RegExp(r'^\*\*[a-zA-Z_<>]+ +[0-9]+ +[0-9]+ +- +[0-9]+'),
    ), // double star before a name indicates a saved game with this player
    _CookieDough(
      cookie: FibsCookie.FIBS_NotYourTurnToRoll,
      re: RegExp(r"^\*\* It's not your turn to roll the dice\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NotYourTurnToMove,
      re: RegExp(r"^\*\* It's not your turn to move\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_YouStopWatching,
      re: RegExp(r'^\*\* You stop watching'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_UnknownCommand,
      re: RegExp(r'^\*\* Unknown command: (?<command>.*)$'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantWatch,
      re: RegExp(r"^\*\* You can't watch another game while you're playing\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantInviteSelf,
      re: RegExp(r"^\*\* You can't invite yourself\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_DontKnowUser,
      re: RegExp(r"^\*\* Don't know user"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_MessageUsage,
      re: RegExp(r'^\*\* usage: message <user> <text>'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_PlayerNotPlaying,
      re: RegExp(r'^\*\* [a-zA-Z_<>]+ is not playing\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantTalk,
      re: RegExp(r"^\*\* You can't talk if you won't listen\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WontListen,
      re: RegExp(r"^\*\* [a-zA-Z_<>]+ won't listen to you\."),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_Why,
      re: RegExp('Why would you want to do that'),
    ), // (not sure about ** vs *** at front of line.)
    _CookieDough(
      cookie: FibsCookie.FIBS_Ratings,
      re: RegExp(r'^\* *[0-9]+ +[a-zA-Z_<>]+ +[0-9]+\.[0-9]+ +[0-9]+'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_NoSavedMatch,
      re: RegExp(r"^\*\* There's no saved match with "),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WARNINGSavedMatch,
      re: RegExp(r"^\*\* WARNING: Don't accept if you want to continue"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantGagYourself,
      re: RegExp(r"^\*\* You talk too much, don't you\?"),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_CantBlindYourself,
      re: RegExp(r"^\*\* You can't read this message now, can you\?"),
    ),
    _CookieDough(
        cookie: FibsCookie.FIBS_SettingsValue,
        re: RegExp(r"^\*\* You're not away\."),
        extras: {'name': 'away', 'value': 'NO'}),
  ];

  // for LOGIN_STATE
  static final loginBatch = [
    _CookieDough(
      cookie: FibsCookie.FIBS_LoginPrompt,
      re: RegExp('^login:'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_WARNINGAlreadyLoggedIn,
      re: RegExp(r'^\*\* Warning: You are already logged in\.'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_WELCOME,
      re: RegExp(
          '^1 (?<name>[a-zA-Z_<>]+) (?<lastLogin>[0-9]+) (?<lastHost>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_OWN_INFO,
      re: RegExp(
          r'^2 (?<name>[a-zA-Z_<>]+) (?<allowpip>[01]) (?<autoboard>[01]) (?<autodouble>[01]) (?<automove>[01]) (?<away>[01]) (?<bell>[01]) (?<crawford>[01]) (?<double>[01]) (?<experience>[0-9]+) (?<greedy>[01]) (?<moreboards>[01]) (?<moves>[01]) (?<notify>[01]) (?<rating>[0-9]+\.[0-9]+) (?<ratings>[01]) (?<ready>[01]) (?<redoubles>[0-9a-zA-Z]+) (?<report>[01]) (?<silent>[01]) (?<timezone>.*)'),
    ),
    _CookieDough(
      cookie: FibsCookie.CLIP_MOTD_BEGIN,
      re: RegExp(r'^3$'),
    ),
    _CookieDough(
      cookie: FibsCookie.FIBS_FailedLogin,
      re: RegExp('^> [0-9]+'),
    ), // bogus CLIP messages sent after a failed login
    _CookieDough(
      cookie: FibsCookie.FIBS_FailedLogin,
      re: RegExp('^Login incorrect'),
    ), // JIBS
    _CookieDough(
        cookie: FibsCookie.FIBS_PreLogin,
        re: catchAllIntoMessageRegex), // catch all
  ];

  // Only interested in one message here, but we still use a message list for
  // simplicity and consistency. for MOTD_STATE
  static final motdBatch = [
    _CookieDough(
      cookie: FibsCookie.CLIP_MOTD_END,
      re: RegExp(r'^4$'),
    ),
    _CookieDough(
        cookie: FibsCookie.FIBS_MOTD,
        re: catchAllIntoMessageRegex), // catch all
  ];
}

enum FibsCookie {
  CLIP_NONE, // = 0
  CLIP_WELCOME, // = 1,
  CLIP_OWN_INFO, // = 2,
  CLIP_MOTD_BEGIN, // = 3,
  CLIP_MOTD_END, // = 4,
  CLIP_WHO_INFO, // = 5,
  CLIP_WHO_END, // = 6,
  CLIP_LOGIN, // = 7,
  CLIP_LOGOUT, // = 8,
  CLIP_MESSAGE, // = 9,
  CLIP_MESSAGE_DELIVERED, // = 10,
  CLIP_MESSAGE_SAVED, // = 11,
  CLIP_SAYS, // = 12,
  CLIP_SHOUTS, // = 13,
  CLIP_WHISPERS, // = 14,
  CLIP_KIBITZES, // = 15,
  CLIP_YOU_SAY, // = 16,
  CLIP_YOU_SHOUT, // = 17,
  CLIP_YOU_WHISPER, // = 18,
  CLIP_YOU_KIBITZ, // = 19,
  FIBS_PreLogin, // the ASCII "FIBS" art, etc.
  FIBS_LoginPrompt,
  FIBS_WARNINGAlreadyLoggedIn, // csells: already logged in warning
  FIBS_FailedLogin, // use this to detect a failed login (e.g. wrong password)
  FIBS_MOTD,
  FIBS_Goodbye,
  FIBS_PostGoodbye, // "send cookies", etc.
  FIBS_Unknown, // don't know the type, probably can ignore
  FIBS_Empty, // empty string
  FIBS_Junk, // a message we don't care about, but is not unknown
  FIBS_ClearScreen,
  FIBS_BAD_AcceptDouble, // DANGER! See notes in .c file about these 2 cookies!
  FIBS_Average,
  FIBS_DiceTest,
  FIBS_Stat,
  FIBS_Why,
  FIBS_NoInfo,
  FIBS_LastLogout,
  FIBS_RatingCalcStart,
  FIBS_RatingCalcInfo,
  FIBS_SettingsHeader,
  FIBS_PlayerListHeader,
  FIBS_AwayListHeader,
  FIBS_RatingExperience,
  FIBS_NotLoggedIn,
  FIBS_StillLoggedIn,
  FIBS_NoOneIsAway,
  FIBS_RatingsHeader,
  FIBS_IsPlayingWith,
  FIBS_Timeout,
  FIBS_UnknownCommand,
  FIBS_Username,
  FIBS_LastLogin,
  FIBS_YourLastLogin,
  FIBS_Registered,
  FIBS_ONEUSERNAME,
  FIBS_EnterUsername,
  FIBS_EnterPassword,
  FIBS_TypeInNo,
  FIBS_SavedScoreHeader,
  FIBS_NoSavedGames,
  FIBS_UsersHeardYou,
  FIBS_MessagesForYou,
  FIBS_IsAway,
  FIBS_OpponentLogsOut,
  FIBS_Waves,
  FIBS_WavesAgain,
  FIBS_YouGag,
  FIBS_YouUngag,
  FIBS_YouBlind,
  FIBS_YouUnblind,
  FIBS_WatchResign,
  FIBS_UseToggleReady,
  FIBS_WARNINGSavedMatch,
  FIBS_NoSavedMatch,
  FIBS_AlreadyPlaying,
  FIBS_DidntInvite,
  FIBS_WatchingHeader,
  FIBS_NotWatching,
  FIBS_NotWatchingPlaying,
  FIBS_NotPlaying,
  FIBS_PlayerNotPlaying,
  FIBS_NoUser,
  FIBS_CantInviteSelf,
  FIBS_CantWatch,
  FIBS_CantTalk,
  FIBS_CantBlindYourself,
  FIBS_CantGagYourself,
  FIBS_WontListen,
  FIBS_NoOne,
  FIBS_BadMove,
  FIBS_MustMove,
  FIBS_MustComeIn,
  FIBS_CantShout,
  FIBS_DontKnowUser,
  FIBS_MessageUsage,
  FIBS_Done,
  FIBS_SavedMatchesHeader,
  FIBS_NotYourTurnToRoll,
  FIBS_NotYourTurnToMove,
  FIBS_YourTurnToMove,
  FIBS_Ratings,
  FIBS_PlayerInfoStart,
  FIBS_EmailAddress,
  FIBS_NoEmail,
  FIBS_ListOfGames,
  FIBS_SavedMatch,
  FIBS_SavedMatchPlaying,
  FIBS_SavedMatchReady,
  FIBS_YouAreWatching,
  FIBS_YouStopWatching,
  FIBS_PlayerStartsWatching,
  FIBS_PlayerStopsWatching,
  FIBS_PlayerIsWatching,
  FIBS_ReportUnlimitedMatch,
  FIBS_ReportLimitedMatch,
  FIBS_RollOrDouble,
  FIBS_YouWinMatch,
  FIBS_PlayerWinsMatch,
  FIBS_YouReject,
  FIBS_YouResign,
  FIBS_ResumeMatchRequest,
  FIBS_ResumeMatchAck0,
  FIBS_ResumeMatchAck5,
  FIBS_NewMatchRequest,
  FIBS_UnlimitedInvite,
  FIBS_YouInvited,
  FIBS_NewMatchAck9,
  FIBS_NewMatchAck10,
  FIBS_NewMatchAck2,
  FIBS_YouTerminated,
  FIBS_OpponentLeftGame,
  FIBS_PlayerLeftGame,
  FIBS_PlayerRefusingGames,
  FIBS_TypeJoin,
  FIBS_ShowMovesStart,
  FIBS_ShowMovesWins,
  FIBS_ShowMovesRoll,
  FIBS_ShowMovesDoubles,
  FIBS_ShowMovesAccepts,
  FIBS_ShowMovesRejects,
  FIBS_ShowMovesOther,
  FIBS_Board,
  FIBS_YouRoll,
  FIBS_PlayerRolls,
  FIBS_PlayerMoves,
  FIBS_PlayerCantMove,
  FIBS_Doubles,
  FIBS_AcceptRejectDouble,
  FIBS_StartingNewGame,
  FIBS_PlayerAcceptsDouble,
  FIBS_YouAcceptDouble,
  FIBS_Turn,
  FIBS_FirstRoll,
  FIBS_DoublingCubeNow,
  FIBS_CantMove,
  FIBS_CantMoveFirstMove,
  FIBS_ResignRefused,
  FIBS_YouWinGame,
  FIBS_OnlyPossibleMove,
  FIBS_AcceptWins,
  FIBS_ResignWins,
  FIBS_ResignYouWin,
  FIBS_WatchGameWins,
  FIBS_ScoreUpdate,
  FIBS_MatchStart,
  FIBS_YouAcceptAndWin,
  FIBS_OnlyMove,
  FIBS_BearingOff,
  FIBS_PleaseMove,
  FIBS_MakesFirstMove,
  FIBS_YouDouble,
  FIBS_MatchLength,
  FIBS_PlayerWantsToResign,
  FIBS_PlayerWinsGame,
  FIBS_JoinNextGame,
  FIBS_ResumingUnlimitedMatch,
  FIBS_ResumingLimitedMatch,
  FIBS_PlayersStartingMatch,
  FIBS_PlayersStartingUnlimitedMatch,
  FIBS_MatchResult,
  FIBS_YouGiveUp,
  FIBS_PlayerIsWaitingForYou,
  FIBS_SettingsValue, // csells
  FIBS_SettingsChange, // csells
  FIBS_NotDoingAnything, // csells
}

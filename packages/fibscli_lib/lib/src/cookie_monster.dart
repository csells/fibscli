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

part 'cookie_tables.dart';
part 'fibs_cookie.dart';

class CookieMessage {
  CookieMessage(this.cookie, this.raw, this.crumbs, this.eatState)
    : // Cannot have zero-length crumb dictionary. Pass null instead.
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
  FIBS_LOGOUT_STATE,
}

// Principle data structure. Used internally--clients never see the dough,
// just the finished cookie.
class _CookieDough {
  _CookieDough({required this.cookie, required this.re, this.extras});

  final FibsCookie cookie;
  final RegExp re;
  final Map<String, String>? extras;
}

// A boolean-setting acknowledgement row: FIBS confirms a toggle with a prose
// message, which we normalize to a FIBS_SettingsChange cookie carrying the
// setting name and YES/NO. Collapses the otherwise-identical toggle-ack rows.
_CookieDough _setting(String name, String value, String pattern) =>
    _CookieDough(
      cookie: FibsCookie.FIBS_SettingsChange,
      re: RegExp(pattern),
      extras: {'name': name, 'value': value},
    );

class CookieMonster {
  CookieMonsterState messageState = CookieMonsterState.FIBS_LOGIN_STATE;
  CookieMonsterState? oldMessageState;

  static CookieMessage? _makeCookie(
    List<_CookieDough> batch,
    String raw,
    CookieMonsterState eatState,
  ) {
    assert(!raw.contains('\n'));

    for (final dough in batch) {
      final match = dough.re.firstMatch(raw);
      if (match != null) {
        final crumbs = <String, String>{};
        final namedGroups = match.groupNames.where(
          (n) => !isDigit(n.codeUnitAt(0)),
        );
        for (final name in namedGroups) {
          final value = match.namedGroup(name)!.trim();
          crumbs[name] = value;

          // only "message" values are allowed to be empty
          assert(
            (name == 'message') || value.isNotEmpty,
            '${dough.cookie}: missing crumb "$name"',
          );
        }

        // drop in hard-coded extra name-value pairs
        if (dough.extras != null) {
          for (final pair in dough.extras!.entries) {
            crumbs[pair.key] = pair.value;

            // only "message" values are allowed to be empty
            assert(
              (pair.key == 'message') || pair.value.isNotEmpty,
              '${dough.cookie}: missing crumb "{pair.Key}"',
            );
          }
        }

        return CookieMessage(
          dough.cookie,
          raw,
          crumbs.isEmpty ? null : crumbs,
          eatState,
        );
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
          cm = _makeCookie(_numericBatch, raw, eatState);
        }
        // '** ' messages
        else if (s0 == '*') {
          cm = _makeCookie(_starsBatch, raw, eatState);
        }
        // all other messages
        else {
          cm = _makeCookie(_alphaBatch, raw, eatState);
        }

        if (cm != null && cm.cookie == FibsCookie.FIBS_Goodbye) {
          messageState = CookieMonsterState.FIBS_LOGOUT_STATE;
        }

      case CookieMonsterState.FIBS_LOGIN_STATE:
        cm = _makeCookie(_loginBatch, raw, eatState);
        assert(cm != null); // there's a catch all
        if (cm!.cookie == FibsCookie.CLIP_MOTD_BEGIN) {
          messageState = CookieMonsterState.FIBS_MOTD_STATE;
        }

      case CookieMonsterState.FIBS_MOTD_STATE:
        cm = _makeCookie(_motdBatch, raw, eatState);
        assert(cm != null); // there's a catch all
        if (cm!.cookie == FibsCookie.CLIP_MOTD_END) {
          messageState = CookieMonsterState.FIBS_RUN_STATE;
        }

      case CookieMonsterState.FIBS_LOGOUT_STATE:
        cm = CookieMessage(FibsCookie.FIBS_PostGoodbye, raw, {
          'message': raw,
        }, eatState);
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

  static DateTime parseTimestamp(String timestamp) => DateTime(
    1970,
    1,
    1,
    0,
    0,
    0,
  ).add(Duration(seconds: int.parse(timestamp)));

  static String? parseTurnColor(int i) {
    if (i == -1) {
      return 'X';
    } else if (i == 1) {
      return 'O';
    } else {
      return null;
    }
  }
}

import 'package:fibscli_lib/fibscli_lib.dart';

import 'bot_policy.dart';
import 'tinystate.dart';

// The FIBS lobby roster: the live who-list plus the bot-only queries the UI
// uses to find invite/watch targets. Kept separate from FibsState so the
// session/connection machinery doesn't also own roster bookkeeping.
class FibsLobby {
  // everyone currently visible in the who-list
  final entries = NotifierList<WhoInfo>();

  // add or replace [who] (login names are unique on FIBS)
  void upsert(WhoInfo who) {
    remove(who.user);
    entries.add(who);
  }

  // remove the entry for [user], if present
  void remove(String user) {
    for (var i = 0; i != entries.length; ++i) {
      if (entries[i].user == user) {
        entries.removeAt(i);
        break;
      }
    }
  }

  // drop every entry (e.g. on logout/reset)
  void clear() => entries.clear();

  // bots that are free to invite: bot client, ready, not already in a game.
  // Precision-first so we only ever invite a bot, never a human.
  List<WhoInfo> get availableBots => [
    for (final who in entries)
      if (who.isBot && who.ready && who.opponent.isEmpty) who,
  ];

  // bots currently in a game that can be watched (their opponent may be human,
  // which is fine for watching)
  List<WhoInfo> get watchableBots => [
    for (final who in entries)
      if (who.isBot && who.opponent.isNotEmpty) who,
  ];
}

// flutter: {
//  cookie: FibsCookie.CLIP_WHO_INFO,
//
//  crumbs: {
//    name: chris,
//    opponent: -,
//    watching: -,
//    ready: 1,
//    away: 0,
//    rating: 1500.0,
//    experience: 0,
//    idle: 0,
//    login: 1601853512515,
//    hostName: localhost,
//    client: flutter-fibs,
//    email: -
//  }
//
// name: 	The login name for the user this line is referring to.
//
// opponent: 	The login name of the person the user is currently playing
//  against, or a hyphen if they are not playing anyone.
//
// watching: 	The login name of the person the user is currently watching,
//  or a hyphen if they are not watching anyone.
//
// ready: 	1 if the user is ready to start playing, 0 if not.
//  Note that the ready status can be set to 1 even while the user is playing
//  a game and thus, technically unavailable. Refer to Toggle Ready.
//
// away: 	1 for yes, 0 for no. Refer to Away.
//
// rating: 	The user's rating as a number with two decimal places.
//
// experience: 	The user's experience.
//
// idle: 	The number of seconds the user has been idle.
//
// login: 	The time the user logged in as the number of seconds since
//  midnight, January 1, 1970 UTC.
//
// hostname: 	The host name or IP address the user is logged in from.
//  Note that the host name can change from an IP address to a host name due
//  to the way FIBS host name resolving works.
//
// client: 	The client the user is using (see login) or a hyphen if not
//  specified. See notes below.
//
// email: 	The user's email address, or a hyphen if not specified.
//  Refer to Address.
class WhoInfo {
  WhoInfo({
    required this.user,
    required this.opponent,
    required this.watching,
    required this.ready,
    required this.away,
    required this.rating,
    required this.experience,
    required this.lastActive,
    required this.lastLogin,
    required this.hostname,
    required this.client,
    required this.email,
  });

  factory WhoInfo.from(CookieMessage cm) {
    assert(cm.cookie == FibsCookie.CLIP_WHO_INFO);
    return WhoInfo(
      user: cm.crumb('name'),
      opponent: CookieMonster.parseOptional(cm.crumb('opponent')) ?? '',
      watching: CookieMonster.parseOptional(cm.crumb('watching')) ?? '',
      ready: CookieMonster.parseBool(cm.crumbOrNull('ready')),
      away: CookieMonster.parseBool(cm.crumbOrNull('away')),
      rating: double.parse(cm.crumb('rating')),
      experience: int.parse(cm.crumb('experience')),
      lastActive: DateTime.now().add(
        Duration(seconds: int.parse(cm.crumb('idle'))),
      ),
      lastLogin: CookieMonster.parseTimestamp(cm.crumb('login')),
      hostname: cm.crumb('hostName'),
      client: CookieMonster.parseOptional(cm.crumb('client')) ?? '',
      email: CookieMonster.parseOptional(cm.crumb('email')) ?? '',
    );
  }
  final String user;
  final String opponent;
  final String watching;
  final bool ready;
  final bool away;
  final double rating;
  final int experience;
  final DateTime lastActive;
  final DateTime lastLogin;
  final String hostname;
  final String client;
  final String email;

  // whether this user is a bot (precision-first; see BotPolicy)
  bool get isBot => BotPolicy.isBot(client: client, user: user);

  // whether this bot only accepts 1-point matches (see BotPolicy)
  bool get playsOnePointOnly =>
      BotPolicy.playsOnePointOnly(client: client, user: user);
}

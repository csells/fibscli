import 'package:fibscli/main.dart';
import 'package:fibscli/tinystate.dart';
import 'package:fibscli_lib/fibscli_lib.dart';
import 'package:flutter/material.dart';

class FibsState {
  final fibs = ValueNotifier<FibsConnection>(null);
  final whoInfos = NotifierList<WhoInfo>();
  static var _fibshash = 0;

  void _streamItem(CookieMessage cm) {
    print(cm);

    // ignore: missing_enum_constant_in_switch
    switch (cm.cookie) {
      case FibsCookie.CLIP_WHO_INFO:
        App.fibsState.addWho(WhoInfo.from(cm));
        break;
    }
  }

  FibsState() {
    fibs.addListener(() {
      if (fibs.value != null) {
        if (fibs.value.hashCode != _fibshash) {
          fibs.value.stream.listen(_streamItem);
          _fibshash = fibs.value.hashCode;
        }
      } else {
        _fibshash = 0;
      }
    });
  }

  void addWho(WhoInfo whoInfo) {
    for (var i = 0; i != whoInfos.length; ++i) {
      if (whoInfos[i].user == whoInfo.user) {
        whoInfos.removeAt(i);
        break;
      }
    }
    whoInfos.add(whoInfo);
  }
}

// flutter: {cookie: FibsCookie.CLIP_WHO_INFO, crumbs: {name: chris, opponent: -, watching: -, ready: 1, away: 0, rating: 1500.0, experience: 0, idle: 0, login: 1601853512515, hostName: localhost, client: flutter-fibs, email: -}
// name: 	The login name for the user this line is referring to.
// opponent: 	The login name of the person the user is currently playing against, or a hyphen if they are not playing anyone.
// watching: 	The login name of the person the user is currently watching, or a hyphen if they are not watching anyone.
// ready: 	1 if the user is ready to start playing, 0 if not. Note that the ready status can be set to 1 even while the user is playing a game and thus, technically unavailable. Refer to Toggle Ready.
// away: 	1 for yes, 0 for no. Refer to Away.
// rating: 	The user's rating as a number with two decimal places.
// experience: 	The user's experience.
// idle: 	The number of seconds the user has been idle.
// login: 	The time the user logged in as the number of seconds since midnight, January 1, 1970 UTC.
// hostname: 	The host name or IP address the user is logged in from. Note that the host name can change from an IP address to a host name due to the way FIBS host name resolving works.
// client: 	The client the user is using (see login) or a hyphen if not specified. See notes below.
// email: 	The user's email address, or a hyphen if not specified. Refer to Address.
class WhoInfo {
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
  WhoInfo({
    this.user,
    this.opponent,
    this.watching,
    this.ready,
    this.away,
    this.rating,
    this.experience,
    this.lastActive,
    this.lastLogin,
    this.hostname,
    this.client,
    this.email,
  })  : assert(user != null),
        assert(opponent != null),
        assert(watching != null),
        assert(ready != null),
        assert(away != null),
        assert(rating != null),
        assert(experience != null),
        assert(lastActive != null),
        assert(lastLogin != null),
        assert(hostname != null),
        assert(client != null),
        assert(email != null);

  factory WhoInfo.from(CookieMessage cm) {
    assert(cm.cookie == FibsCookie.CLIP_WHO_INFO);
    return WhoInfo(
      user: cm.crumbs['name'],
      opponent: CookieMonster.parseOptional(cm.crumbs['opponent'])??'',
      watching: CookieMonster.parseOptional(cm.crumbs['watching'])??'',
      ready: CookieMonster.parseBool(cm.crumbs['ready']),
      away: CookieMonster.parseBool(cm.crumbs['away']),
      rating: double.parse(cm.crumbs['rating']),
      experience: int.parse(cm.crumbs['experience']),
      lastActive: DateTime.now().add(Duration(seconds: int.parse(cm.crumbs['idle']))),
      lastLogin: CookieMonster.parseTimestamp(cm.crumbs['login']),
      hostname: cm.crumbs['hostname']??'',
      client: CookieMonster.parseOptional(cm.crumbs['client'])??'',
      email: CookieMonster.parseOptional(cm.crumbs['email'])??'',
    );
  }
}
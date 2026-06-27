// ignore_for_file: lines_longer_than_80_chars

import 'package:fibscli_lib/src/cookie_monster.dart';
import 'package:test/test.dart';

void main() {
  CookieMonster createLoggedInCookieMonster() {
    final monster = CookieMonster();
    monster.eatCookie('3'); // simulate MOTD
    monster.eatCookie('4'); // simulate MOTD end
    return monster;
  }

  test('FIBS_WARNINGAlreadyLoggedIn', () {
    final monster = CookieMonster();
    const s = '** Warning: You are already logged in.';
    final cm = monster.eatCookie(s);
    expect(cm.cookie, FibsCookie.FIBS_WARNINGAlreadyLoggedIn);
  });

  test('FIBS_UnknownCommand', () {
    final monster = createLoggedInCookieMonster();
    const s = "** Unknown command: 'fizzbuzz'";
    final cm = monster.eatCookie(s);
    expect(cm.cookie, FibsCookie.FIBS_UnknownCommand);
    expect(cm.crumbs!['command'], "'fizzbuzz'");
  });

  test('CLIP_WELCOME', () {
    final monster = CookieMonster();
    const s = '1 myself 1041253132 192.168.1.308';
    final cm = monster.eatCookie(s);

    expect(cm.cookie, FibsCookie.CLIP_WELCOME);
    expect(cm.crumbs!['name'], 'myself');
    final lastLogin = CookieMonster.parseTimestamp(cm.crumbs!['lastLogin']!);
    expect(lastLogin, DateTime.parse('2002-12-30 12:58:52'));
    expect(cm.crumbs!['lastHost'], '192.168.1.308');
  });

  test('CLIP_OWN_INFO', () {
    final monster = CookieMonster();
    const s =
        '2 myself 1 1 0 0 0 0 1 1 2396 0 1 0 1 3457.85 0 0 0 0 0 Australia/Melbourne';
    final cm = monster.eatCookie(s);

    expect(cm.cookie, FibsCookie.CLIP_OWN_INFO);
    expect(cm.crumbs!['name'], 'myself');
    expect(true, CookieMonster.parseBool(cm.crumbs!['allowpip']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['autoboard']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['autodouble']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['automove']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['away']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['bell']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['crawford']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['double']));
    expect(2396, int.parse(cm.crumbs!['experience']!));
    expect(false, CookieMonster.parseBool(cm.crumbs!['greedy']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['moreboards']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['moves']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['notify']));
    expect(3457.85, double.parse(cm.crumbs!['rating']!));
    expect(false, CookieMonster.parseBool(cm.crumbs!['ratings']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['ready']));
    expect('0', cm.crumbs!['redoubles']);
    expect(false, CookieMonster.parseBool(cm.crumbs!['report']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['silent']));
    expect('Australia/Melbourne', cm.crumbs!['timezone']);
  });

  test('CLIP_MOTD_BEGIN', () {
    final monster = CookieMonster();
    const s = '3';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_MOTD_BEGIN, cm.cookie);
  });

  test('FIBS_MOTD1', () {
    final monster = CookieMonster();
    monster.eatCookie('3');
    const s =
        '+--------------------------------------------------------------------+';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_MOTD, cm.cookie);
    expect(s, cm.raw);
  });

  test('FIBS_MOTD2', () {
    final monster = CookieMonster();
    monster.eatCookie('3');
    const s =
        '| It was a dark and stormy night in Oakland.  Outside, the rain      |';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_MOTD, cm.cookie);
    expect(s, cm.raw);
  });

  test('CLIP_MOTD_END', () {
    final monster = CookieMonster();
    monster.eatCookie('3');
    const s = '4';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_MOTD_END, cm.cookie);
  });

  test('CLIP_WHO_INFO', () {
    final monster = createLoggedInCookieMonster();
    const s =
        '5 someplayer mgnu_advanced - 0 0 1418.61 23 1914 1041253132 192.168.40.3 MacFIBS someplayer@somewhere.com';
    final cm = monster.eatCookie(s);

    expect(FibsCookie.CLIP_WHO_INFO, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('mgnu_advanced', cm.crumbs!['opponent']);
    expect(null, CookieMonster.parseOptional(cm.crumbs!['watching']!));
    expect(false, CookieMonster.parseBool(cm.crumbs!['ready']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['away']));
    expect(double.parse(cm.crumbs!['rating']!), 1418.61);
    expect(23, int.parse(cm.crumbs!['experience']!));
    expect(1914, int.parse(cm.crumbs!['idle']!));
    expect(DateTime.parse('2002-12-30 12:58:52'),
        CookieMonster.parseTimestamp(cm.crumbs!['login']!));
    expect('192.168.40.3', cm.crumbs!['hostName']);
    expect('MacFIBS', CookieMonster.parseOptional(cm.crumbs!['client']!));
    expect('someplayer@somewhere.com',
        CookieMonster.parseOptional(cm.crumbs!['email']!));
  });

  test('CLIP_WHO_END', () {
    final monster = createLoggedInCookieMonster();
    const s = '6';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_WHO_END, cm.cookie);
  });

  test('CLIP_LOGIN', () {
    final monster = createLoggedInCookieMonster();
    const s = '7 someplayer someplayer logs in.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_LOGIN, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('someplayer logs in.', cm.crumbs!['message']);
  });

  test('CLIP_LOGOUT', () {
    final monster = createLoggedInCookieMonster();
    const s = '8 someplayer someplayer drops connection.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_LOGOUT, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('someplayer drops connection.', cm.crumbs!['message']);
  });

  test('CLIP_MESSAGE', () {
    final monster = createLoggedInCookieMonster();
    const s =
        "9 someplayer 1041253132 I'll log in at 10pm if you want to finish that game.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_MESSAGE, cm.cookie);
    expect('someplayer', cm.crumbs!['from']);
    expect(DateTime.parse('2002-12-30 12:58:52'),
        CookieMonster.parseTimestamp(cm.crumbs!['time']!));
    expect("I'll log in at 10pm if you want to finish that game.",
        cm.crumbs!['message']);
  });

  test('CLIP_MESSAGE_DELIVERED', () {
    final monster = createLoggedInCookieMonster();
    const s = '10 someplayer';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_MESSAGE_DELIVERED, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
  });

  test('CLIP_MESSAGE_SAVED', () {
    final monster = createLoggedInCookieMonster();
    const s = '11 someplayer';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_MESSAGE_SAVED, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
  });

  test('CLIP_SAYS', () {
    final monster = createLoggedInCookieMonster();
    const s = '12 someplayer Do you want to play a game?';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_SAYS, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('Do you want to play a game?', cm.crumbs!['message']);
  });

  test('CLIP_SHOUTS', () {
    final monster = createLoggedInCookieMonster();
    const s = '13 someplayer Anybody for a 5 point match?';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_SHOUTS, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('Anybody for a 5 point match?', cm.crumbs!['message']);
  });

  test('CLIP_WHISPERS', () {
    final monster = createLoggedInCookieMonster();
    const s = '14 someplayer I think he is using loaded dice :-)';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_WHISPERS, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect('I think he is using loaded dice :-)', cm.crumbs!['message']);
  });

  test('CLIP_KIBITZES', () {
    final monster = createLoggedInCookieMonster();
    const s = "15 someplayer G'Day and good luck from Hobart, Australia.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_KIBITZES, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect(
        "G'Day and good luck from Hobart, Australia.", cm.crumbs!['message']);
  });

  test('CLIP_YOU_SAY', () {
    final monster = createLoggedInCookieMonster();
    const s = "16 someplayer What's this \"G'Day\" stuff you hick? :-)";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_YOU_SAY, cm.cookie);
    expect('someplayer', cm.crumbs!['name']);
    expect("What's this \"G'Day\" stuff you hick? :-)", cm.crumbs!['message']);
  });

  test('CLIP_YOU_SHOUT', () {
    final monster = createLoggedInCookieMonster();
    const s = "17 Watch out for someplayer.  He's a Tasmanian.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_YOU_SHOUT, cm.cookie);
    expect(
        "Watch out for someplayer.  He's a Tasmanian.", cm.crumbs!['message']);
  });

  test('CLIP_YOU_WHISPER', () {
    final monster = createLoggedInCookieMonster();
    const s = '18 Hello and hope you enjoy watching this game.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_YOU_WHISPER, cm.cookie);
    expect(
        'Hello and hope you enjoy watching this game.', cm.crumbs!['message']);
  });

  test('CLIP_YOU_KIBITZ', () {
    final monster = createLoggedInCookieMonster();
    const s = "19 Are you sure those dice aren't loaded?";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.CLIP_YOU_KIBITZ, cm.cookie);
    expect("Are you sure those dice aren't loaded?", cm.crumbs!['message']);
  });

  test('FIBS_Unknown', () {
    final monster = createLoggedInCookieMonster();
    const s = 'something sump something';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_Unknown, cm.cookie);
    expect('something sump something', cm.crumbs!['raw']);
  });

  test('FIBS_PlayerLeftGame', () {
    final monster = createLoggedInCookieMonster();
    const s = 'bob has left the game with alice.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerLeftGame, cm.cookie);
    expect('bob', cm.crumbs!['player1']);
    expect('alice', cm.crumbs!['player2']);
  });

  test('FIBS_PreLogin', () {
    final monster = CookieMonster();
    const s =
        'Saturday, October 15 17:01:02 MEST   ( Sat Oct 15 15:01:02 2016 UTC )';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PreLogin, cm.cookie);
    expect(s, cm.crumbs!['message']);
  });

  test('FIBS_Goodbye', () {
    final monster = createLoggedInCookieMonster();
    const s = '           Goodbye.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_Goodbye, cm.cookie);
    expect('Goodbye.', cm.crumbs!['message']);
  });

  test('FIBS_PostGoodbye', () {
    final monster = createLoggedInCookieMonster();
    monster.eatCookie('           Goodbye.');
    const s = 'If you enjoyed using this server please send picture postcards,';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PostGoodbye, cm.cookie);
    expect(s, cm.crumbs!['message']);
  });

  test('FIBS_MatchResult', () {
    final monster = createLoggedInCookieMonster();
    const s = 'BlunderBot wins a 1 point match against LunaRossa  1-0 .';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_MatchResult, cm.cookie);
    expect('BlunderBot', cm.crumbs!['winner']);
    expect('LunaRossa', cm.crumbs!['loser']);
    expect(1, int.parse(cm.crumbs!['points']!));
    expect(1, int.parse(cm.crumbs!['winnerScore']!));
    expect(0, int.parse(cm.crumbs!['loserScore']!));
  });

  test('FIBS_PlayersStartingMatch', () {
    final monster = createLoggedInCookieMonster();
    const s = 'BlunderBot_IV and eggieegg start a 1 point match.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayersStartingMatch, cm.cookie);
    expect('BlunderBot_IV', cm.crumbs!['player1']);
    expect('eggieegg', cm.crumbs!['player2']);
    expect(1, int.parse(cm.crumbs!['points']!));
  });

  test('FIBS_ResumingLimitedMatch', () {
    final monster = createLoggedInCookieMonster();
    const s = 'inim and utah are resuming their 2-point match.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_ResumingLimitedMatch, cm.cookie);
    expect('inim', cm.crumbs!['player1']);
    expect('utah', cm.crumbs!['player2']);
    expect(2, int.parse(cm.crumbs!['points']!));
  });

  test('FIBS_NoOne', () {
    final monster = createLoggedInCookieMonster();
    const s = '** There is no one called playerOne.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_NoOne, cm.cookie);
    expect('playerOne', cm.crumbs!['name']);
  });

  test('FIBS_SettingsValueYes', () {
    final monster = createLoggedInCookieMonster();
    const s = 'allowpip        YES';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('allowpip', cm.crumbs!['name']);
    expect(true, CookieMonster.parseBool(cm.crumbs!['value']));
  });

  test('FIBS_SettingsValueNo', () {
    final monster = createLoggedInCookieMonster();
    const s = 'autodouble      NO';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('autodouble', cm.crumbs!['name']);
    expect(false, CookieMonster.parseBool(cm.crumbs!['value']));
  });

  test('FIBS_SettingsYoureNotAway', () {
    final monster = createLoggedInCookieMonster();
    const s = "** You're not away.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('away', cm.crumbs!['name']);
    expect(false, CookieMonster.parseBool(cm.crumbs!['value']));
  });

  test('FIBS_SettingsValueChangeToYes', () {
    final monster = createLoggedInCookieMonster();
    final settingPhrases = {
      'allowpip': "** You allow the use the server's 'pip' command.",
      'autoboard': '** The board will be refreshed after every move.',
      'autodouble':
          '** You agree that doublets during opening double the cube.',
      'automove': '** Forced moves will be done automatically.',
      'away': "You're away. Please type 'back'",
      'bell':
          '** Your terminal will ring the bell if someone talks to you or invites you',
      'crawford': '** You insist on playing with the Crawford rule.',
      'double': '** You will be asked if you want to double.',
      'greedy': '** Will use automatic greedy bearoffs.',
      'moreboards': '** Will send rawboards after rolling.',
      'moves': '** You want a list of moves after this game.',
      'notify': "** You'll be notified when new users log in.",
      'ratings': "** You'll see how the rating changes are calculated.",
      'ready': "** You're now ready to invite or join someone.",
      'report': '** You will be informed about starting and ending matches.',
      'silent': '** You will hear what other players shout.',
      'telnet': "** You use telnet and don't need extra 'newlines'.",
      'wrap': '** The server will wrap long lines.',
    };

    for (final pair in settingPhrases.entries) {
      final cm = monster.eatCookie(pair.value);
      expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
      expect(pair.key, cm.crumbs!['name']);
      expect(
          true,
          CookieMonster.parseBool(cm.crumbs![
              'value'])); //, $"{cm.crumbs["name"]}= {cm.crumbs["value"]}");
    }
  });

  test('FIBS_SettingsValueChangeToNo', () {
    final monster = createLoggedInCookieMonster();
    final settingPhrases = {
      'allowpip': "** You don't allow the use of the server's 'pip' command.",
      'autoboard': "** The board won't be refreshed after every move.",
      'autodouble':
          "** You don't agree that doublets during opening double the cube.",
      'automove': "** Forced moves won't be done automatically.",
      'away': 'Welcome back.',
      'bell': "** Your terminal won't ring the bell if someone talks to you "
          'or invites you',
      'crawford': '** You would like to play without using the Crawford rule.',
      'double': "** You won't be asked if you want to double.",
      'greedy': "** Won't use automatic greedy bearoffs.",
      'moreboards': "** Won't send rawboards after rolling.",
      'moves': "** You won't see a list of moves after this game.",
      'notify': "** You won't be notified when new users log in.",
      'ratings': "** You won't see how the rating changes are calculated.",
      'ready': "** You're now refusing to play with someone.",
      'report': "** You won't be informed about starting and ending matches.",
      'silent': "** You won't hear what other players shout.",
      'telnet':
          "** You use a client program and will receive extra 'newlines'.",
      'wrap': '** Your terminal knows how to wrap long lines.',
    };

    for (final pair in settingPhrases.entries) {
      final cm = monster.eatCookie(pair.value);
      expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
      expect(pair.key, cm.crumbs!['name']);
      expect(
          false,
          CookieMonster.parseBool(cm.crumbs![
              'value'])); //, $"{cm.crumbs["name"]}= {cm.crumbs["value"]}");
    }
  });

  test('FIBS_RedoublesChangeToNone', () {
    final monster = createLoggedInCookieMonster();
    const s = "Value of 'redoubles' set to 'none'.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('redoubles', cm.crumbs!['name']);
    expect('none', cm.crumbs!['value']);
  });

  test('FIBS_RedoublesChangeToNumber', () {
    final monster = createLoggedInCookieMonster();
    const s = "Value of 'redoubles' set to 42.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('redoubles', cm.crumbs!['name']);
    expect(42, int.parse(cm.crumbs!['value']!));
  });

  test('FIBS_RedoublesChangeToUnlimited', () {
    final monster = createLoggedInCookieMonster();
    const s = "Value of 'redoubles' set to 'unlimited'.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('redoubles', cm.crumbs!['name']);
    expect('unlimited', cm.crumbs!['value']);
  });

  test('FIBS_TimezoneChange', () {
    final monster = createLoggedInCookieMonster();
    const s = "Value of 'timezone' set to America/Los_Angeles.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('timezone', cm.crumbs!['name']);
    expect('America/Los_Angeles', cm.crumbs!['value']);
  });

  test('FIBS_Board', () {
    // from http://www.fibs.com/fibs_interface.html#board_state
    final monster = createLoggedInCookieMonster();
    const s =
        'board:You:someplayer:3:0:1:0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0:2:0:1:6:2:0:0:1:1:1:0:1:-1:0:25:0:0:0:0:2:0:0:0';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_Board, cm.cookie);
    expect('You', cm.crumbs!['player1']);
    expect('someplayer', cm.crumbs!['player2']);
    expect(3, int.parse(cm.crumbs!['matchLength']!));
    expect(0, int.parse(cm.crumbs!['player1Score']!));
    expect(1, int.parse(cm.crumbs!['player2Score']!));
    expect('0:-2:0:0:0:0:5:0:3:0:0:0:-5:5:0:0:0:-3:0:-5:0:0:0:0:2:0',
        cm.crumbs!['board']);
    expect('O', CookieMonster.parseBoardTurn(cm.crumbs!['turnColor']!));
    expect('6:2', cm.crumbs!['player1Dice']);
    expect('0:0', cm.crumbs!['player2Dice']);
    expect(1, int.parse(cm.crumbs!['doublingCube']!));
    expect(true, CookieMonster.parseBool(cm.crumbs!['player1MayDouble']));
    expect(true, CookieMonster.parseBool(cm.crumbs!['player2MayDouble']));
    expect(false, CookieMonster.parseBool(cm.crumbs!['wasDoubled']));
    expect(
        'O', CookieMonster.parseBoardColorString(cm.crumbs!['player1Color']!));
    expect(-1, int.parse(cm.crumbs!['direction']!));
    expect(0, int.parse(cm.crumbs!['player1Home']!));
    expect(0, int.parse(cm.crumbs!['player2Home']!));
    expect(0, int.parse(cm.crumbs!['player1Bar']!));
    expect(0, int.parse(cm.crumbs!['player2Bar']!));
    expect(2, int.parse(cm.crumbs!['canMove']!));
    expect(0, int.parse(cm.crumbs!['redoubles']!));
  });

  test('FIBS_SettingsValue_Set', () {
    final monster = createLoggedInCookieMonster();
    CookieMessage cm;

    cm = monster.eatCookie('Settings of variables:');
    expect(FibsCookie.FIBS_SettingsHeader, cm.cookie);

    cm = monster.eatCookie('boardstyle: 3');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('boardstyle', cm.crumbs!['name']);
    expect(3, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie('linelength: 0');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('linelength', cm.crumbs!['name']);
    expect(0, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie('pagelength: 0');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('pagelength', cm.crumbs!['name']);
    expect(0, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie('redoubles:  none');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('redoubles', cm.crumbs!['name']);
    expect('none', cm.crumbs!['value']);

    cm = monster.eatCookie('sortwho:    login');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('sortwho', cm.crumbs!['name']);
    expect('login', cm.crumbs!['value']);

    cm = monster.eatCookie('timezone:   America/Los_Angeles');
    expect(FibsCookie.FIBS_SettingsValue, cm.cookie);
    expect('timezone', cm.crumbs!['name']);
    expect('America/Los_Angeles', cm.crumbs!['value']);
  });

  test('FIBS_SettingsChange_Set', () {
    final monster = createLoggedInCookieMonster();
    CookieMessage cm;

    cm = monster.eatCookie("Value of 'boardstyle' set to 3.");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('boardstyle', cm.crumbs!['name']);
    expect(3, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie("Value of 'linelength' set to 0.");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('linelength', cm.crumbs!['name']);
    expect(0, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie("Value of 'pagelength' set to 0.");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('pagelength', cm.crumbs!['name']);
    expect(0, int.parse(cm.crumbs!['value']!));

    cm = monster.eatCookie("Value of 'redoubles' set to 'none'.");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('redoubles', cm.crumbs!['name']);
    expect('none', cm.crumbs!['value']);

    cm = monster.eatCookie("Value of 'sortwho' set to login");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('sortwho', cm.crumbs!['name']);
    expect('login', cm.crumbs!['value']);

    cm = monster.eatCookie("Value of 'timezone' set to America/Los_Angeles.");
    expect(FibsCookie.FIBS_SettingsChange, cm.cookie);
    expect('timezone', cm.crumbs!['name']);
    expect('America/Los_Angeles', cm.crumbs!['value']);
  });

  test('FIBS_YouAreWatching', () {
    final monster = createLoggedInCookieMonster();
    const s = "You're now watching bonehead.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_YouAreWatching, cm.cookie);
    expect('bonehead', cm.crumbs!['name']);
  });

  test('FIBS_YouStopWatching', () {
    final monster = createLoggedInCookieMonster();
    const s = 'You stop watching bonehead.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_YouStopWatching, cm.cookie);
    expect('bonehead', cm.crumbs!['name']);
  });

  test('FIBS_NotDoingAnything', () {
    final monster = createLoggedInCookieMonster();
    const s = 'bonehead is not doing anything interesting.';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_NotDoingAnything, cm.cookie);
    expect('bonehead', cm.crumbs!['name']);
  });

  test('FIBS_PlayerMoves4', () {
    final monster = createLoggedInCookieMonster();
    const s = 'Tyke moves 19-23 19-23 20-24 20-24 .';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerMoves, cm.cookie);
    expect('Tyke', cm.crumbs!['player']);
    expect('19-23 19-23 20-24 20-24', cm.crumbs!['moves']);
  });

  test('FIBS_PlayerMoves1', () {
    final monster = createLoggedInCookieMonster();
    const s = 'Tyke moves 19-23 .';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerMoves, cm.cookie);
    expect('Tyke', cm.crumbs!['player']);
    expect('19-23', cm.crumbs!['moves']);
  });

  test('FIBS_PlayerMoves2', () {
    final monster = createLoggedInCookieMonster();
    const s = 'Tyke moves 19-23 19-23 .';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerMoves, cm.cookie);
    expect('Tyke', cm.crumbs!['player']);
    expect('19-23 19-23', cm.crumbs!['moves']);
  });

  test('FIBS_PlayerMoves3', () {
    final monster = createLoggedInCookieMonster();
    const s = 'Tyke moves 19-23 19-23 20-24 .';
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerMoves, cm.cookie);
    expect('Tyke', cm.crumbs!['player']);
    expect('19-23 19-23 20-24', cm.crumbs!['moves']);
  });

  test('FIBS_PlayerCantMove', () {
    final monster = createLoggedInCookieMonster();
    const s = "smilingeyes can't move.";
    final cm = monster.eatCookie(s);
    expect(FibsCookie.FIBS_PlayerCantMove, cm.cookie);
    expect('smilingeyes', cm.crumbs!['player']);
  });
}

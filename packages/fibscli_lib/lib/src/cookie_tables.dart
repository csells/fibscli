part of 'cookie_monster.dart';

// ignore_for_file: public_member_api_docs

// The CLIP/FIBS message pattern tables: each _CookieDough maps a regex to
// the cookie it produces. Ordering matters -- earlier patterns win.

// Initialize stuff, ready to start pumping out cookies by the thousands.
// Note that the order of items in this function is important, in some cases
// messages are very similar and are differentiated by depending on the
// order the batch is processed.

final _catchAllIntoMessageRegex = RegExp('(?<message>.*)');

//--- Numeric messages ---------------------------------------------------
final _numericBatch = [
  _CookieDough(
    cookie: FibsCookie.CLIP_WHO_INFO,
    re: RegExp(
      r'^5 (?<name>[^ ]+) (?<opponent>[^ ]+) (?<watching>[^ ]+) (?<ready>[01]) (?<away>[01]) (?<rating>[0-9]+\.[0-9]+) (?<experience>[0-9]+) (?<idle>[0-9]+) (?<login>[0-9]+) (?<hostName>[^ ]+) (?<client>[^ ]+) (?<email>[^ ]+)',
    ),
  ),
  _CookieDough(
    cookie: FibsCookie.FIBS_Average,
    re: RegExp('^[0-9][0-9]:[0-9][0-9]-'),
  ), // output of average command
  _CookieDough(
    cookie: FibsCookie.FIBS_DiceTest,
    re: RegExp('^[1-6]-1 [0-9]'),
  ), // output of dicetest command
  _CookieDough(cookie: FibsCookie.FIBS_DiceTest, re: RegExp('^[1-6]: [0-9]')),
  _CookieDough(
    cookie: FibsCookie.FIBS_Stat,
    re: RegExp('^[0-9]+ bytes'),
  ), // output from stat command
  _CookieDough(cookie: FibsCookie.FIBS_Stat, re: RegExp('^[0-9]+ accounts')),
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
  _CookieDough(cookie: FibsCookie.CLIP_WHO_END, re: RegExp(r'^6$')),
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

// for LOGIN_STATE
final _loginBatch = [
  _CookieDough(cookie: FibsCookie.FIBS_LoginPrompt, re: RegExp('^login:')),
  _CookieDough(
    cookie: FibsCookie.FIBS_WARNINGAlreadyLoggedIn,
    re: RegExp(r'^\*\* Warning: You are already logged in\.'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_WELCOME,
    re: RegExp('^1 (?<name>[a-zA-Z_<>]+) (?<lastLogin>[0-9]+) (?<lastHost>.*)'),
  ),
  _CookieDough(
    cookie: FibsCookie.CLIP_OWN_INFO,
    re: RegExp(
      r'^2 (?<name>[a-zA-Z_<>]+) (?<allowpip>[01]) (?<autoboard>[01]) (?<autodouble>[01]) (?<automove>[01]) (?<away>[01]) (?<bell>[01]) (?<crawford>[01]) (?<double>[01]) (?<experience>[0-9]+) (?<greedy>[01]) (?<moreboards>[01]) (?<moves>[01]) (?<notify>[01]) (?<rating>[0-9]+\.[0-9]+) (?<ratings>[01]) (?<ready>[01]) (?<redoubles>[0-9a-zA-Z]+) (?<report>[01]) (?<silent>[01]) (?<timezone>.*)',
    ),
  ),
  _CookieDough(cookie: FibsCookie.CLIP_MOTD_BEGIN, re: RegExp(r'^3$')),
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
    re: _catchAllIntoMessageRegex,
  ), // catch all
];

// Only interested in one message here, but we still use a message list for
// simplicity and consistency. for MOTD_STATE
final _motdBatch = [
  _CookieDough(cookie: FibsCookie.CLIP_MOTD_END, re: RegExp(r'^4$')),
  _CookieDough(
    cookie: FibsCookie.FIBS_MOTD,
    re: _catchAllIntoMessageRegex,
  ), // catch all
];

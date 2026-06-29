// Deciding whether a FIBS user is a bot. Precision-first: the client only ever
// invites/accepts bots, never a human, so a false positive (calling a human a
// bot) is the dangerous error and a false negative (missing a bot) is merely a
// lost opponent. Kept out of FibsState so this policy -- and its allowlists --
// can evolve without touching the connection/state machine. Pure (plain
// strings in, bool out) so it needs no FIBS types and is trivially testable.
class BotPolicy {
  const BotPolicy._();

  // A bot is identified primarily by its reported CLIENT string, not its name.
  // Live FIBS data shows bots self-report a bot-framework client while humans
  // report GUI clients (3DFiBs, MGOnline, Padgammon, FIBzilla, ...). Name is
  // unreliable both ways: it misses bots like octopus/pubeval/wildbg and
  // wrongly flags TourneyBot (a tournament organizer). This allowlist
  // deliberately excludes bots that report no client (e.g. MonteCarlo,
  // client '-') -- those are caught by name below.
  static const _botClients = <String>{
    'ParlorBot', // GammonBot / BlunderBot family
    'Computer_player', // octopus, pubeval, PureTD
    'bot_1p_matches_only', // wildbg, udacity_capstone
  };

  // Belt-and-suspenders for bots that might report no client (FIBS has no
  // protocol "isBot" flag). The client allowlist above already auto-catches the
  // whole live roster; these are confirmed exact bot names (from the live
  // who-list plus research against the fibs.com/bots.html and ParlorBot
  // rosters) so a known bot is still caught if its client field is missing.
  // MonteCarlo is the key case: a 1-point-match bot that reports no client.
  // Numbered variants (BlunderBot_IX, GammonBot_XV, ...) are covered by the
  // client allowlist, so only base/singleton names are listed. Names are unique
  // on FIBS, so exact-name matching never catches a human.
  static const _knownBotNames = <String>{
    'MonteCarlo',
    'BlunderBot',
    'GammonBot',
    'octopus',
    'pubeval',
    'PureTD',
    'wildbg',
  };

  // True when a user reporting [client] and login [user] is a bot.
  static bool isBot({required String client, required String user}) =>
      _botClients.contains(client) || _knownBotNames.contains(user);

  // Bots that report no client but are known to only play 1-point matches.
  // (Client-based 1-point bots are caught by the 'bot_1p_matches_only' client.)
  static const _onePointBotNames = <String>{'MonteCarlo'};

  // True when a bot only accepts 1-point matches -- either it advertises this
  // in its client string ('bot_1p_matches_only', e.g. wildbg/udacity_capstone)
  // or it is a known clientless 1-point bot (MonteCarlo). Used to warn the user
  // before they invite it to a longer match (which it would decline).
  static bool playsOnePointOnly({
    required String client,
    required String user,
  }) => client == 'bot_1p_matches_only' || _onePointBotNames.contains(user);
}

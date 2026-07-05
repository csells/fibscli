// The FIBS cookie crumb keys, named in ONE place instead of as string literals
// scattered across the who-list, session, and state parsers. Each mirrors a
// regex group name in fibscli_lib's cookie tables (the source of truth); if a
// consumer and the regex ever drift apart, CookieMessage.crumb throws a clear
// MissingCrumbError rather than a silent '' or a distant null-deref.
abstract final class FibsCrumbKeys {
  static const name = 'name';
  static const opponent = 'opponent';
  static const watching = 'watching';
  static const ready = 'ready';
  static const away = 'away';
  static const rating = 'rating';
  static const experience = 'experience';
  static const idle = 'idle';
  static const login = 'login';
  static const hostName = 'hostName';
  static const client = 'client';
  static const email = 'email';
  static const from = 'from';
  static const message = 'message';
  static const player1 = 'player1';
  static const player = 'player';
  static const die1 = 'die1';
  static const die2 = 'die2';
}

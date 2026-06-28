import 'package:fibscli/bot_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detects bots by their reported client string', () {
    expect(BotPolicy.isBot(client: 'ParlorBot', user: 'BlunderBot_IX'), isTrue);
    expect(BotPolicy.isBot(client: 'Computer_player', user: 'octopus'), isTrue);
  });

  test('detects clientless bots by their known name', () {
    // MonteCarlo reports no client ('-') but is a known bot
    expect(BotPolicy.isBot(client: '-', user: 'MonteCarlo'), isTrue);
  });

  test('precision-first: a human with a GUI client is never a bot', () {
    expect(BotPolicy.isBot(client: '3DFiBs', user: 'alice'), isFalse);
    // TourneyBot is a human tournament organizer despite the name
    expect(BotPolicy.isBot(client: 'MGOnline', user: 'TourneyBot'), isFalse);
  });
}

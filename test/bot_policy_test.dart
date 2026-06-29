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

  test('flags 1-point-only bots by client string or known name', () {
    // wildbg / udacity_capstone advertise it in their client string
    expect(
      BotPolicy.playsOnePointOnly(
        client: 'bot_1p_matches_only',
        user: 'wildbg',
      ),
      isTrue,
    );
    // MonteCarlo reports no client but is a known 1-point bot
    expect(
      BotPolicy.playsOnePointOnly(client: '-', user: 'MonteCarlo'),
      isTrue,
    );
    // the BlunderBot family plays multi-point matches
    expect(
      BotPolicy.playsOnePointOnly(client: 'ParlorBot', user: 'BlunderBot_II'),
      isFalse,
    );
  });
}

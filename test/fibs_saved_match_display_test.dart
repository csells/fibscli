import 'package:fibscli/fibs_lobby.dart';
import 'package:fibscli/fibs_saved_match_display.dart';
import 'package:fibscli/fibs_session.dart';
import 'package:flutter_test/flutter_test.dart';

WhoInfo _who(String user, {String opponent = '', bool ready = true}) => WhoInfo(
  user: user,
  opponent: opponent,
  watching: '',
  ready: ready,
  away: false,
  rating: 1500,
  experience: 1000,
  lastActive: DateTime(2020),
  lastLogin: DateTime(2020),
  hostname: '',
  client: 'ParlorBot',
  email: '',
);

void main() {
  test('saved-match projection merges live games against current user', () {
    final matches = projectSavedMatchInfos(
      savedMatches: const [
        SavedMatchInfo(
          opponent: 'blunderbot',
          score1: 3,
          score2: 2,
          matchLength: 7,
          availability: SavedMatchAvailability.offline,
        ),
      ],
      whoInfos: [
        _who('joe_grammer', opponent: 'someone_else'),
        _who('BlunderBot', opponent: 'joe_grammer'),
      ],
      currentUser: 'joe_grammer',
    );

    expect(matches, hasLength(1));
    expect(matches.single.opponent, 'blunderbot');
    expect(matches.single.availability, SavedMatchAvailability.ready);
    expect(matches.single.scoreLabel, '3-2 to 7');
  });

  test('saved-match projection sorts by availability then folded name', () {
    final matches = projectSavedMatchInfos(
      savedMatches: const [
        SavedMatchInfo(
          opponent: 'zeta',
          availability: SavedMatchAvailability.offline,
        ),
        SavedMatchInfo(
          opponent: 'bravo',
          availability: SavedMatchAvailability.unknown,
        ),
        SavedMatchInfo(
          opponent: 'Alpha',
          availability: SavedMatchAvailability.online,
        ),
        SavedMatchInfo(
          opponent: 'delta',
          availability: SavedMatchAvailability.ready,
        ),
        SavedMatchInfo(
          opponent: 'Beta',
          availability: SavedMatchAvailability.ready,
        ),
      ],
      whoInfos: const [],
      currentUser: null,
    );

    expect(matches.map((match) => match.opponent), [
      'Beta',
      'delta',
      'Alpha',
      'bravo',
      'zeta',
    ]);
  });
}

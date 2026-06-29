import 'model.dart';

// Translate a local [GammonMove] into the FIBS `move` command.
//
// Validated against live FIBS data and the meowbg OSS client: FIBS move
// coordinates are absolute board positions, identical to our pip numbering, so
// each hop becomes a `from-to` pair (dash-joined, space-separated for multiple
// hops). The bar uses the keyword `bar` and bearing off uses `off`; an
// overshooting bear-off clamps onto the off tray.
//
// e.g. GammonMove(13 -> 7, hops [-4,-2])  =>  "move 13-9 9-7"
//      GammonMove(3 -> off, hops [-3])    =>  "move 3-off"
//      GammonMove(bar -> 22, hops [-3])   =>  "move bar-22"
String fibsMoveCommand(GammonMove move) => 'move ${_hopPairs(move).join(' ')}';

// The `from-to` pairs (one per die) for a move, e.g. ['13-9', '9-7'], with the
// bar/off keywords. Shared by fibsMoveCommand and fibsTurnCommand.
List<String> _hopPairs(GammonMove move) {
  final player = move.player;
  final barPip = GammonRules.barPipNoFor(player);
  final offPip = GammonRules.offPipNoFor(player);
  String label(int pip) {
    if (pip == barPip) return 'bar';
    if (pip == offPip) return 'off';
    return '$pip';
  }

  final hops = <String>[];
  var pos = move.fromPipNo;
  for (final hop in move.hops) {
    var next = pos + hop;
    // a bear-off can overshoot past the off tray; clamp onto it
    if (next < 0) next = 0;
    if (next > 25) next = 25;
    hops.add('${label(pos)}-${label(next)}');
    pos = next;
  }
  return hops;
}

// A whole turn as ONE FIBS `move` command (e.g. "move 8-4 6-4"). FIBS wants the
// complete turn submitted at once -- it rejects a partial turn with "** You
// must give N moves" -- so tap-to-move builds the turn locally and submits it
// here when the player taps the dice to commit. An empty turn (a dance) is just
// "move".
String fibsTurnCommand(List<GammonMove> moves) =>
    'move ${moves.expand(_hopPairs).join(' ')}'.trimRight();

// A single-die FIBS move from one absolute pip to another, for tap-to-move
// (the player moves one checker one die at a time and the server validates).
// [player] is the mover, used to render the bar/off keywords correctly.
String fibsRawMove(int fromPip, int toPip, GammonPlayer player) {
  final barPip = GammonRules.barPipNoFor(player);
  final offPip = GammonRules.offPipNoFor(player);
  String label(int pip) {
    if (pip == barPip) return 'bar';
    if (pip == offPip) return 'off';
    return '$pip';
  }

  return 'move ${label(fromPip)}-${label(toPip)}';
}

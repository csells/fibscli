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
String fibsMoveCommand(GammonMove move) {
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

  return 'move ${hops.join(' ')}';
}

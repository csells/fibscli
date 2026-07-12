/// Pure-Dart backgammon engine: rules + move generation and the move
/// evaluators. The pluggable AI-player abstraction is layered on top.
library;

export 'src/ai/ai_registry.dart';
export 'src/ai/bg_ai_player.dart';
export 'src/ai/gnubg_ai_player.dart';
export 'src/ai/gnubg_id.dart';
export 'src/ai/pubeval_ai_player.dart';
export 'src/ai/turn_search.dart';
export 'src/board.dart';
export 'src/board_signature.dart';
export 'src/cube_policy.dart';
export 'src/movements.dart';
export 'src/position.dart';
export 'src/pubeval.dart';
export 'src/race_eval.dart';
export 'src/rules.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'model.dart';

/// Mediates between [GammonState] and the rendered game screen: it owns the
/// board-orientation and AI-busy flags, DERIVES the app-bar/FAB enable state
/// from the bound game (so it can't desync), and exposes command hooks the
/// `GameView` wires up. Extracted from game_play_page.dart so the view file
/// isn't also home to this ChangeNotifier.
class GameViewController extends ChangeNotifier {
  bool _reversed = false;
  GammonState? _game;
  bool _disposed = false;

  // command hooks the GameView injects; invoked by the matching methods below
  late void Function() onUndo;
  late void Function() onNewGame;
  late void Function() onAutoBearOff;
  late void Function() onShowOdds;

  // Bind the current game so the button-enable state is DERIVED, not mirrored:
  // the controller listens to the game and re-notifies its own listeners (the
  // app bar / FAB), so canUndo/canAutoBearOff can never desync from a forgotten
  // setter call. Re-attaching on a new game swaps the listener.
  void attach(GammonState game) {
    if (identical(_game, game)) return;
    _game?.removeListener(_notifySafely);
    _game = game..addListener(_notifySafely);
    _notifySafely();
  }

  // Notify listeners, but never during a build/layout pass -- the first attach
  // happens inside GameView.initState (while the app bar above is still
  // building), and a game change could also land mid-frame. Defer to after the
  // frame in those cases.
  void _notifySafely() {
    if (_disposed) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        // guard against a deferred notify landing after teardown
        if (!_disposed) notifyListeners();
      });
    }
  }

  // True while the computer is playing its turn (the view drives this). The
  // board is already locked by IgnorePointer; the app-bar/FAB actions must lock
  // too, or the human could undo/new-game/auto-bear-off mid-AI-turn and mutate
  // the board out from under the AI's already-computed move plan.
  bool _busy = false;
  bool get busy => _busy;
  set busy(bool busy) {
    if (_busy == busy) return;
    _busy = busy;
    // build-safe: the AI can start (busy = true) from _maybePlayAi during the
    // initState-driven first build, when a raw notifyListeners would mark the
    // app bar dirty mid-build.
    _notifySafely();
  }

  // undo is available while a game is in progress (nothing to undo once over),
  // and never while the AI is mid-turn.
  bool get canUndo => !_busy && _game != null && !_game!.gameOver;
  bool get canAutoBearOff => !_busy && (_game?.canAutoBearOff ?? false);

  bool get reversed => _reversed;
  set reversed(bool reversed) {
    if (_reversed == reversed) return;
    _reversed = reversed;
    notifyListeners();
  }

  void undo() => onUndo();
  void newGame() => onNewGame();
  void autoBearOff() => onAutoBearOff();
  void showOdds() => onShowOdds();

  @override
  void dispose() {
    _disposed = true;
    _game?.removeListener(_notifySafely);
    super.dispose();
  }
}

import 'package:fibscli_lib/fibscli_lib.dart';

enum FibsProtocolCookieRoute { ignore, protocol }

FibsProtocolCookieRoute fibsProtocolRouteFor(FibsCookie cookie) =>
    switch (cookie) {
      FibsCookie.CLIP_OWN_INFO ||
      FibsCookie.FIBS_YouRoll ||
      FibsCookie.FIBS_PlayerRolls ||
      FibsCookie.FIBS_Turn ||
      FibsCookie.FIBS_PleaseMove ||
      FibsCookie.FIBS_YourTurnToMove ||
      FibsCookie.FIBS_PlayerMoves ||
      FibsCookie.FIBS_PlayerCantMove ||
      FibsCookie.FIBS_CantMove ||
      FibsCookie.FIBS_RollOrDouble ||
      FibsCookie.FIBS_Board ||
      FibsCookie.FIBS_YouWinGame ||
      FibsCookie.FIBS_PlayerWinsGame ||
      FibsCookie.FIBS_YouWinMatch ||
      FibsCookie.FIBS_PlayerWinsMatch ||
      FibsCookie.FIBS_ResignYouWin ||
      FibsCookie.FIBS_YouAcceptAndWin ||
      FibsCookie.FIBS_AcceptWins ||
      FibsCookie.FIBS_ResignWins ||
      FibsCookie.FIBS_WatchGameWins ||
      FibsCookie.FIBS_AcceptRejectDouble ||
      FibsCookie.FIBS_SavedMatch ||
      FibsCookie.FIBS_SavedMatchPlaying ||
      FibsCookie.FIBS_SavedMatchReady ||
      FibsCookie.FIBS_NoSavedGames ||
      FibsCookie.FIBS_ResumeMatchRequest ||
      FibsCookie.FIBS_TypeJoin ||
      FibsCookie.FIBS_JoinNextGame ||
      FibsCookie.FIBS_ResumeMatchAck0 ||
      FibsCookie.FIBS_ResumeMatchAck5 => FibsProtocolCookieRoute.protocol,
      FibsCookie.CLIP_KIBITZES ||
      FibsCookie.CLIP_MESSAGE ||
      FibsCookie.CLIP_SAYS ||
      FibsCookie.CLIP_SHOUTS ||
      FibsCookie.CLIP_WHISPERS => FibsProtocolCookieRoute.protocol,
      FibsCookie.FIBS_BadMove ||
      FibsCookie.FIBS_CantMoveFirstMove ||
      FibsCookie.FIBS_MustComeIn ||
      FibsCookie.FIBS_MustMove => FibsProtocolCookieRoute.protocol,
      FibsCookie.FIBS_OpponentLogsOut ||
      FibsCookie.FIBS_OpponentLeftGame => FibsProtocolCookieRoute.protocol,
      FibsCookie.FIBS_NoSavedMatch ||
      FibsCookie.FIBS_NoOne ||
      FibsCookie.FIBS_NoUser ||
      FibsCookie.FIBS_PlayerRefusingGames ||
      FibsCookie.FIBS_AlreadyPlaying ||
      FibsCookie.FIBS_DidntInvite ||
      FibsCookie.FIBS_DontKnowUser ||
      FibsCookie.FIBS_NotYourTurnToMove ||
      FibsCookie.FIBS_NotYourTurnToRoll ||
      FibsCookie.FIBS_NotPlaying ||
      FibsCookie.FIBS_NotWatchingPlaying ||
      FibsCookie.FIBS_UnknownCommand => FibsProtocolCookieRoute.protocol,
      _ => FibsProtocolCookieRoute.ignore,
    };

import 'analytics.dart';

class FibsAnalyticsCounts {
  const FibsAnalyticsCounts({
    required this.whoInfoCount,
    required this.availableBotCount,
    required this.watchableBotCount,
    required this.savedMatchCount,
    required this.messageCount,
  });

  final int whoInfoCount;
  final int availableBotCount;
  final int watchableBotCount;
  final int savedMatchCount;
  final int messageCount;
}

extension FibsAnalyticsTracking on AppAnalytics {
  void trackFibs(
    String event, {
    required FibsAnalyticsCounts counts,
    String? screen,
    String? mode,
    String result = 'accepted',
    bool includeWhoInfoCount = true,
    bool includeAvailableBotCount = true,
    bool includeWatchableBotCount = true,
    bool includeSavedMatchCount = true,
    bool includeMessageCount = true,
  }) {
    track(
      event,
      screen: screen,
      mode: mode,
      result: result,
      whoInfoCount: includeWhoInfoCount ? counts.whoInfoCount : null,
      availableBotCount: includeAvailableBotCount
          ? counts.availableBotCount
          : null,
      watchableBotCount: includeWatchableBotCount
          ? counts.watchableBotCount
          : null,
      savedMatchCount: includeSavedMatchCount ? counts.savedMatchCount : null,
      messageCount: includeMessageCount ? counts.messageCount : null,
    );
  }
}

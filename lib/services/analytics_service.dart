import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  static final _a = FirebaseAnalytics.instance;

  static Future<void> logClothingAdded({
    required String category,
    required bool hasImage,
    required bool aiUsed,
  }) =>
      _a.logEvent(name: 'clothing_added', parameters: {
        'category': category,
        'has_image': hasImage ? 1 : 0,
        'ai_used': aiUsed ? 1 : 0,
      });

  static Future<void> logAiClassificationUsed({required bool success}) =>
      _a.logEvent(name: 'ai_classification_used', parameters: {
        'success': success ? 1 : 0,
      });

  static Future<void> logOutfitRecorded({required int clothesCount}) =>
      _a.logEvent(name: 'outfit_recorded', parameters: {
        'clothes_count': clothesCount,
      });

  static Future<void> logSeasonTransition({
    required String direction,
    required int count,
  }) =>
      _a.logEvent(name: 'season_transition', parameters: {
        'direction': direction,
        'count': count,
      });

  static Future<void> logTabViewed(String tabName) =>
      _a.logEvent(name: 'tab_viewed', parameters: {'tab_name': tabName});
}

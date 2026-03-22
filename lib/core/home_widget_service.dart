// Basic home widget update service.
// Saves D-day and schedule data for home widget display.
// Native iOS/Android widget setup is required separately before
// the commented HomeWidget calls can be activated.

import 'package:flutter/foundation.dart';

class HomeWidgetService {
  HomeWidgetService._();

  // ignore: unused_field
  static const _appGroupId = 'group.com.coupleapp';
  // ignore: unused_field
  static const _iOSWidgetName = 'CoupleWidget';
  // ignore: unused_field
  static const _androidWidgetName = 'CoupleWidgetProvider';

  /// Update home widget data (D-days, partner name, today's schedule).
  ///
  /// Uncomment the HomeWidget calls below once native widget targets
  /// are configured for iOS (WidgetKit extension) and Android
  /// (AppWidgetProvider).
  static Future<void> updateWidget({
    required int dDays,
    required String partnerName,
    String? mySchedule,
    String? partnerSchedule,
  }) async {
    try {
      // await HomeWidget.setAppGroupId(_appGroupId);          // iOS only
      // await HomeWidget.saveWidgetData('d_days', dDays);
      // await HomeWidget.saveWidgetData('partner_name', partnerName);
      // await HomeWidget.saveWidgetData('my_schedule', mySchedule ?? '일정 없음');
      // await HomeWidget.saveWidgetData('partner_schedule', partnerSchedule ?? '일정 없음');
      // await HomeWidget.updateWidget(
      //   iOSName: _iOSWidgetName,
      //   androidName: _androidWidgetName,
      // );
      debugPrint('HomeWidget updated: D+$dDays with $partnerName');
    } catch (e) {
      debugPrint('HomeWidget update failed: $e');
    }
  }
}

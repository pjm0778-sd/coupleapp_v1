import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  HomeWidgetService._();

  static const _appGroupId      = 'group.com.coupleapp';
  static const _iOSWidgetName   = 'CoupleWidget';
  static const _androidSmall    = 'CoupleWidgetProvider';
  static const _androidMedium   = 'CoupleWidgetProviderMedium';

  /// 앱 시작 시 1회 호출 (iOS App Group 초기화)
  static Future<void> init() async {
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e) {
      debugPrint('[HomeWidget] init error: $e');
    }
  }

  /// 홈 화면 위젯 데이터 업데이트
  static Future<void> updateWidget({
    required int    dDays,
    required String partnerName,
    required String mySchedule,
    required String partnerSchedule,
    String  myWeather       = '',   // "서울 🌤 18°" 형식
    String  partnerWeather  = '',
    int     nextDateDays    = -1,   // -1 = 없음, 0 = 오늘
    String  nextDateLabel   = '',   // "3월 28일"
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData('d_days',           dDays),
        HomeWidget.saveWidgetData('partner_name',     partnerName),
        HomeWidget.saveWidgetData('my_schedule',      mySchedule),
        HomeWidget.saveWidgetData('partner_schedule', partnerSchedule),
        HomeWidget.saveWidgetData('my_weather',       myWeather),
        HomeWidget.saveWidgetData('partner_weather',  partnerWeather),
        HomeWidget.saveWidgetData('next_date_days',   nextDateDays),
        HomeWidget.saveWidgetData('next_date_label',  nextDateLabel),
      ]);
      // Small / Medium 둘 다 업데이트
      await HomeWidget.updateWidget(
        iOSName:     _iOSWidgetName,
        androidName: _androidSmall,
      );
      await HomeWidget.updateWidget(
        iOSName:     _iOSWidgetName,
        androidName: _androidMedium,
      );
      debugPrint('[HomeWidget] updated — D+$dDays, $partnerName');
    } catch (e) {
      debugPrint('[HomeWidget] update failed: $e');
    }
  }

  /// WMO weather code → 이모지
  static String weatherEmoji(int code) {
    if (code == 0)                         return '☀️';
    if (code <= 3)                         return '🌤';
    if (code == 45 || code == 48)          return '🌫';
    if (code >= 51 && code <= 67)          return '🌧';
    if (code >= 71 && code <= 77)          return '❄️';
    if (code >= 80 && code <= 82)          return '🌦';
    if (code >= 95 && code <= 99)          return '⛈';
    return '🌡';
  }

  /// WeatherData → 위젯용 문자열 ("서울 🌤 18°")
  static String formatWeather({
    required String city,
    required double temperature,
    required int    weatherCode,
  }) {
    final emoji = weatherEmoji(weatherCode);
    final temp  = temperature.round();
    return '$city $emoji $temp°';
  }
}

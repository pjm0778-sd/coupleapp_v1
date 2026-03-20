import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/city_coordinates.dart';
import '../models/weather_data.dart';

class WeatherService {
  // 메모리 캐시: cityName → (data, fetchedAt)
  static final Map<String, _CacheEntry> _cache = {};
  static const _cacheDuration = Duration(minutes: 30);

  /// 도시 이름으로 현재 날씨 조회 (캐시 30분)
  Future<WeatherData?> getWeather(String city) async {
    final cached = _cache[city];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.data;
    }

    final coords = cityCoordinates[city];
    if (coords == null) return null;

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${coords.lat}'
        '&longitude=${coords.lng}'
        '&current=temperature_2m,weather_code,relative_humidity_2m'
        '&timezone=Asia%2FSeoul'
        '&forecast_days=1',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;

      final data = WeatherData(
        city: city,
        temperature: (current['temperature_2m'] as num).toDouble(),
        weatherCode: (current['weather_code'] as num).toInt(),
        humidity: (current['relative_humidity_2m'] as num).toInt(),
      );

      _cache[city] = _CacheEntry(data: data, fetchedAt: DateTime.now());
      return data;
    } catch (_) {
      return null;
    }
  }

  void clearCache() => _cache.clear();
}

class _CacheEntry {
  final WeatherData data;
  final DateTime fetchedAt;
  _CacheEntry({required this.data, required this.fetchedAt});
}

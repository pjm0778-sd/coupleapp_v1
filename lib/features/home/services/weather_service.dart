import 'dart:convert';
import 'package:http/http.dart' as http;
import '../data/city_coordinates.dart';
import '../models/weather_data.dart';

class WeatherService {
  // 메모리 캐시: cityName → (data, fetchedAt)
  static final Map<String, _CacheEntry> _cache = {};
  static final Map<String, _ForecastCacheEntry> _forecastCache = {};
  static final Map<String, _CacheEntry> _historicalCache = {};
  static final Map<String, _HourlyCacheEntry> _hourlyCache = {};
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

  /// 도시 + 날짜 기준 날씨 조회 (예보 캐시 30분)
  Future<WeatherData?> getWeatherForDate(String city, DateTime date) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);

    // 오늘은 current API 재사용
    if (normalizedDate == normalizedToday) {
      return getWeather(city);
    }

    // 과거 날짜는 archive API 사용
    if (normalizedDate.isBefore(normalizedToday)) {
      return _getHistoricalWeatherForDate(city, normalizedDate);
    }

    final cached = _forecastCache[city];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return _mapForecastToWeather(city, normalizedDate, cached.data);
    }

    final coords = cityCoordinates[city];
    if (coords == null) return null;

    try {
      final uri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=${coords.lat}'
        '&longitude=${coords.lng}'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=Asia%2FSeoul'
        '&forecast_days=16',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final forecast = _ForecastDaily(
        dates: (daily['time'] as List<dynamic>).cast<String>(),
        weatherCodes: (daily['weather_code'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toInt())
            .toList(),
        maxTemps: (daily['temperature_2m_max'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
        minTemps: (daily['temperature_2m_min'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
      );

      _forecastCache[city] = _ForecastCacheEntry(
        data: forecast,
        fetchedAt: DateTime.now(),
      );

      return _mapForecastToWeather(city, normalizedDate, forecast);
    } catch (_) {
      return null;
    }
  }

  Future<WeatherData?> _getHistoricalWeatherForDate(
    String city,
    DateTime date,
  ) async {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final cacheKey = '$city|$dateKey';
    final cached = _historicalCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.data;
    }

    final coords = cityCoordinates[city];
    if (coords == null) return null;

    try {
      final uri = Uri.parse(
        'https://archive-api.open-meteo.com/v1/archive'
        '?latitude=${coords.lat}'
        '&longitude=${coords.lng}'
        '&daily=weather_code,temperature_2m_max,temperature_2m_min'
        '&timezone=Asia%2FSeoul'
        '&start_date=$dateKey'
        '&end_date=$dateKey',
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final forecast = _ForecastDaily(
        dates: (daily['time'] as List<dynamic>).cast<String>(),
        weatherCodes: (daily['weather_code'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toInt())
            .toList(),
        maxTemps: (daily['temperature_2m_max'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
        minTemps: (daily['temperature_2m_min'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
      );

      final data = _mapForecastToWeather(city, date, forecast);
      if (data != null) {
        _historicalCache[cacheKey] = _CacheEntry(
          data: data,
          fetchedAt: DateTime.now(),
        );
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  WeatherData? _mapForecastToWeather(
    String city,
    DateTime date,
    _ForecastDaily forecast,
  ) {
    final dateKey =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final index = forecast.dates.indexOf(dateKey);
    if (index < 0) return null;

    final maxTemp = forecast.maxTemps[index];
    final minTemp = forecast.minTemps[index];
    final weatherCode = forecast.weatherCodes[index];
    if (maxTemp == null || minTemp == null || weatherCode == null) {
      return null;
    }
    final representativeTemp = (maxTemp + minTemp) / 2;

    return WeatherData(
      city: city,
      temperature: representativeTemp,
      weatherCode: weatherCode,
      humidity: 0,
    );
  }

  Future<List<HourlyWeatherData>?> getHourlyWeatherForDate(
    String city,
    DateTime date,
  ) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateKey =
        '${normalizedDate.year.toString().padLeft(4, '0')}-${normalizedDate.month.toString().padLeft(2, '0')}-${normalizedDate.day.toString().padLeft(2, '0')}';
    final cacheKey = '$city|$dateKey';

    final cached = _hourlyCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.data;
    }

    final coords = cityCoordinates[city];
    if (coords == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isPast = normalizedDate.isBefore(today);

    try {
      final uri = isPast
          ? Uri.parse(
              'https://archive-api.open-meteo.com/v1/archive'
              '?latitude=${coords.lat}'
              '&longitude=${coords.lng}'
              '&hourly=temperature_2m,relative_humidity_2m,weather_code,precipitation'
              '&timezone=Asia%2FSeoul'
              '&start_date=$dateKey'
              '&end_date=$dateKey',
            )
          : Uri.parse(
              'https://api.open-meteo.com/v1/forecast'
              '?latitude=${coords.lat}'
              '&longitude=${coords.lng}'
              '&hourly=temperature_2m,relative_humidity_2m,weather_code,precipitation_probability'
              '&timezone=Asia%2FSeoul'
              '&start_date=$dateKey'
              '&end_date=$dateKey',
            );

      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>?;
      if (hourly == null) return null;

      final times = (hourly['time'] as List<dynamic>).cast<String>();
      final temps = (hourly['temperature_2m'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toDouble())
          .toList();
      final humidities = (hourly['relative_humidity_2m'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toInt())
          .toList();
      final weatherCodes = (hourly['weather_code'] as List<dynamic>)
          .map((e) => e == null ? null : (e as num).toInt())
          .toList();
      final precipProbabilities = (hourly['precipitation_probability'] as List<dynamic>?)
              ?.map((e) => e == null ? null : (e as num).toInt())
              .toList() ??
          <int?>[];
      final precipitations = (hourly['precipitation'] as List<dynamic>?)
              ?.map((e) => e == null ? null : (e as num).toDouble())
              .toList() ??
          <double?>[];

      final length = [
        times.length,
        temps.length,
        humidities.length,
        weatherCodes.length,
      ].reduce((a, b) => a < b ? a : b);

      final items = <HourlyWeatherData>[];
      for (var i = 0; i < length; i++) {
        final t = temps[i];
        final h = humidities[i];
        final c = weatherCodes[i];
        if (t == null || h == null || c == null) continue;
        final time = DateTime.tryParse(times[i]);
        if (time == null) continue;

        final p = i < precipProbabilities.length ? precipProbabilities[i] : null;
        final mm = i < precipitations.length ? precipitations[i] : null;

        items.add(
          HourlyWeatherData(
            time: time,
            temperature: t,
            humidity: h,
            weatherCode: c,
            precipitationProbability: p,
            precipitationMm: mm,
          ),
        );
      }

      _hourlyCache[cacheKey] = _HourlyCacheEntry(
        data: items,
        fetchedAt: DateTime.now(),
      );
      return items;
    } catch (_) {
      return null;
    }
  }

  Future<WeatherData?> getWeatherForDateByCoordinates({
    required String label,
    required double latitude,
    required double longitude,
    required DateTime date,
  }) async {
    final normalizedDate = DateTime(date.year, date.month, date.day);
    final dateKey =
        '${normalizedDate.year.toString().padLeft(4, '0')}-${normalizedDate.month.toString().padLeft(2, '0')}-${normalizedDate.day.toString().padLeft(2, '0')}';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final cacheKey = 'coord:$latitude,$longitude|$dateKey';
    final cached = _historicalCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) < _cacheDuration) {
      return cached.data;
    }

    final isPast = normalizedDate.isBefore(today);
    final uri = isPast
        ? Uri.parse(
            'https://archive-api.open-meteo.com/v1/archive'
            '?latitude=$latitude'
            '&longitude=$longitude'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min'
            '&timezone=Asia%2FSeoul'
            '&start_date=$dateKey'
            '&end_date=$dateKey',
          )
        : Uri.parse(
            'https://api.open-meteo.com/v1/forecast'
            '?latitude=$latitude'
            '&longitude=$longitude'
            '&daily=weather_code,temperature_2m_max,temperature_2m_min'
            '&timezone=Asia%2FSeoul'
            '&start_date=$dateKey'
            '&end_date=$dateKey',
          );

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      if (daily == null) return null;

      final forecast = _ForecastDaily(
        dates: (daily['time'] as List<dynamic>).cast<String>(),
        weatherCodes: (daily['weather_code'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toInt())
            .toList(),
        maxTemps: (daily['temperature_2m_max'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
        minTemps: (daily['temperature_2m_min'] as List<dynamic>)
            .map((e) => e == null ? null : (e as num).toDouble())
            .toList(),
      );

      final mapped = _mapForecastToWeather(label, normalizedDate, forecast);
      if (mapped != null) {
        _historicalCache[cacheKey] = _CacheEntry(
          data: mapped,
          fetchedAt: DateTime.now(),
        );
      }
      return mapped;
    } catch (_) {
      return null;
    }
  }

  void clearCache() {
    _cache.clear();
    _forecastCache.clear();
    _historicalCache.clear();
    _hourlyCache.clear();
  }
}

class _CacheEntry {
  final WeatherData data;
  final DateTime fetchedAt;
  _CacheEntry({required this.data, required this.fetchedAt});
}

class _ForecastCacheEntry {
  final _ForecastDaily data;
  final DateTime fetchedAt;
  _ForecastCacheEntry({required this.data, required this.fetchedAt});
}

class _HourlyCacheEntry {
  final List<HourlyWeatherData> data;
  final DateTime fetchedAt;
  _HourlyCacheEntry({required this.data, required this.fetchedAt});
}

class _ForecastDaily {
  final List<String> dates;
  final List<int?> weatherCodes;
  final List<double?> maxTemps;
  final List<double?> minTemps;

  const _ForecastDaily({
    required this.dates,
    required this.weatherCodes,
    required this.maxTemps,
    required this.minTemps,
  });
}

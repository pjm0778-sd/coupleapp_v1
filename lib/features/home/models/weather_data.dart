class WeatherData {
  final String city;
  final double temperature;
  final int weatherCode;
  final int humidity;

  const WeatherData({
    required this.city,
    required this.temperature,
    required this.weatherCode,
    required this.humidity,
  });
}

class HourlyWeatherData {
  final DateTime time;
  final double temperature;
  final int humidity;
  final int weatherCode;
  final int? precipitationProbability;
  final double? precipitationMm;

  const HourlyWeatherData({
    required this.time,
    required this.temperature,
    required this.humidity,
    required this.weatherCode,
    this.precipitationProbability,
    this.precipitationMm,
  });
}

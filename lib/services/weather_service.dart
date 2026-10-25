import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../channels/platform_channels.dart';

class WeatherService {
  static Future<void> syncWeather({double lat = 3.1390, double lon = 101.6869}) async {
    await Future.wait([
      _fetchForecast(lat, lon),
      _fetchAirQuality(lat, lon),
      _fetchRainRadar(),
    ]);
  }

  static Future<void> _fetchForecast(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,is_day&daily=weather_code,temperature_2m_max,temperature_2m_min&timezone=auto',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final weatherCode = (current['weather_code'] as num?)?.toInt() ?? 0;
        final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 30.0;
        final isDay = (current['is_day'] as num?)?.toInt() == 1;

        final weatherMap = {
          'temp': temp.round(),
          'code': weatherCode,
          'isDay': isDay,
          'icon': getWeatherSvgName(weatherCode, isDay),
          'desc': getWeatherDescription(weatherCode),
          'humidity': current['relative_humidity_2m'] ?? 75,
          'wind': current['wind_speed_10m'] ?? 10,
        };
        await PlatformChannels.updateWeather(weatherMap);

        // Process hourly forecast (next 12 hours)
        final hourly = data['hourly'] as Map<String, dynamic>? ?? {};
        final hourlyTimes = (hourly['time'] as List<dynamic>? ?? []).cast<String>();
        final hourlyTemps = (hourly['temperature_2m'] as List<dynamic>? ?? []).cast<num>();
        final hourlyCodes = (hourly['weather_code'] as List<dynamic>? ?? []).cast<num>();
        final hourlyIsDays = (hourly['is_day'] as List<dynamic>? ?? []).cast<num>();

        final nowIso = DateTime.now().toIso8601String().substring(0, 13);
        int startIndex = hourlyTimes.indexWhere((t) => t.startsWith(nowIso));
        if (startIndex < 0) startIndex = 0;

        final hoursList = <Map<String, dynamic>>[];
        for (int i = startIndex; i < (startIndex + 12).clamp(0, hourlyTimes.length); i++) {
          final timeStr = hourlyTimes[i];
          final hourPart = timeStr.contains('T') ? timeStr.split('T')[1].substring(0, 5) : timeStr;
          hoursList.add({
            'time': hourPart,
            'temp': hourlyTemps[i].round(),
            'code': hourlyCodes[i].toInt(),
            'isDay': hourlyIsDays.isNotEmpty ? hourlyIsDays[i].toInt() == 1 : true,
          });
        }

        // Process daily forecast (next 7 days)
        final daily = data['daily'] as Map<String, dynamic>? ?? {};
        final dailyTimes = (daily['time'] as List<dynamic>? ?? []).cast<String>();
        final dailyCodes = (daily['weather_code'] as List<dynamic>? ?? []).cast<num>();
        final dailyMax = (daily['temperature_2m_max'] as List<dynamic>? ?? []).cast<num>();
        final dailyMin = (daily['temperature_2m_min'] as List<dynamic>? ?? []).cast<num>();

        final daysList = <Map<String, dynamic>>[];
        for (int i = 0; i < dailyTimes.length.clamp(0, 7); i++) {
          final dt = DateTime.tryParse(dailyTimes[i]) ?? DateTime.now().add(Duration(days: i));
          final dayName = DateFormat('E').format(dt);
          daysList.add({
            'day': dayName,
            'min': dailyMin[i].round(),
            'max': dailyMax[i].round(),
            'code': dailyCodes[i].toInt(),
          });
        }

        await PlatformChannels.updateForecast({
          'hours': hoursList,
          'days': daysList,
        });
      }
    } catch (_) {}
  }

  static Future<void> _fetchAirQuality(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=us_aqi,pm2_5,uv_index',
      );
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final current = data['current'] as Map<String, dynamic>? ?? {};
        final aqi = (current['us_aqi'] as num?)?.toDouble() ?? 42.0;
        final pm25 = (current['pm2_5'] as num?)?.toDouble() ?? 10.5;
        final uv = (current['uv_index'] as num?)?.toDouble() ?? 4.0;

        await PlatformChannels.updateAir({
          'aqi': aqi.round(),
          'pm25': pm25.round(),
          'uv': uv.round(),
        });
      }
    } catch (_) {
      // Fallback air quality
      await PlatformChannels.updateAir({
        'aqi': 42,
        'pm25': 12,
        'uv': 5,
      });
    }
  }

  static Future<void> _fetchRainRadar() async {
    try {
      final url = Uri.parse('https://api.rainviewer.com/public/weather-maps.json');
      final resp = await http.get(url).timeout(const Duration(seconds: 8));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as Map<String, dynamic>;
        final host = data['host'] as String? ?? 'https://tilecache.rainviewer.com';
        final radar = data['radar'] as Map<String, dynamic>? ?? {};
        final past = radar['past'] as List<dynamic>? ?? [];
        if (past.isNotEmpty) {
          final latest = past.last as Map<String, dynamic>;
          final path = latest['path'] as String? ?? '';
          await PlatformChannels.updateRadar({
            'host': host,
            'path': path,
          });
        }
      }
    } catch (_) {}
  }

  static String getWeatherSvgName(int code, bool isDay) {
    final suffix = isDay ? 'day' : 'night';
    if (code == 0) return 'clear-$suffix';
    if (code <= 3) return 'partly-cloudy-$suffix';
    if (code <= 48) return 'fog-$suffix';
    if (code <= 57) return 'drizzle';
    if (code <= 67) return 'rain';
    if (code <= 82) return 'partly-cloudy-$suffix-rain';
    if (code <= 99) return 'thunderstorms-$suffix-rain';
    return 'overcast-$suffix';
  }

  static String getWeatherDescription(int code) {
    if (code == 0) return 'Clear';
    if (code <= 3) return 'Partly Cloudy';
    if (code <= 48) return 'Hazy';
    if (code <= 57) return 'Drizzle';
    if (code <= 67) return 'Rain';
    if (code <= 82) return 'Showers';
    if (code <= 99) return 'Thunderstorm';
    return 'Cloudy';
  }
}

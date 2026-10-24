import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';

class WeatherData {
  final double temp;
  final double apparentTemp;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final String condition;
  final String conditionMalay;
  final double uvIndex;
  final int isDay;
  final String rainSummary;
  final int aqi;
  final String aqiCategory;
  final List<HourlyForecast> hourly;
  final String? radarPath;
  final String radarTime;

  WeatherData({
    required this.temp,
    required this.apparentTemp,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.condition,
    required this.conditionMalay,
    required this.uvIndex,
    required this.isDay,
    required this.rainSummary,
    required this.aqi,
    required this.aqiCategory,
    required this.hourly,
    this.radarPath,
    required this.radarTime,
  });

  factory WeatherData.initial() {
    return WeatherData(
      temp: 28.0,
      apparentTemp: 32.0,
      humidity: 75,
      windSpeed: 8.0,
      weatherCode: 2,
      condition: 'Partly Cloudy',
      conditionMalay: 'Sebahagian mendung',
      uvIndex: 4.0,
      isDay: 1,
      rainSummary: 'No rain expected soon',
      aqi: 45,
      aqiCategory: 'Good',
      hourly: [],
      radarTime: 'Live',
    );
  }
}

class HourlyForecast {
  final String time;
  final double temp;
  final int weatherCode;
  final int pop;
  final int isDay;

  HourlyForecast({
    required this.time,
    required this.temp,
    required this.weatherCode,
    required this.pop,
    required this.isDay,
  });
}

class WeatherService {
  static const String _forecastBase = 'https://api.open-meteo.com/v1/forecast';
  static const String _airQualityBase = 'https://air-quality-api.open-meteo.com/v1/air-quality';
  static const String _rainViewerBase = 'https://api.rainviewer.com/public/weather-maps.json';

  static WeatherData? _cachedData;
  static DateTime? _lastFetch;

  static Future<String> _httpGet(String urlStr) async {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final request = await client.getUrl(Uri.parse(urlStr));
      request.headers.set('User-Agent', 'DashMate-App/1.0');
      final response = await request.close();
      if (response.statusCode == 200) {
        return await response.transform(utf8.decoder).join();
      }
    } finally {
      client.close();
    }
    return '';
  }

  static Future<WeatherData> fetchWeather({double lat = 3.139, double lon = 101.68685, bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh && _cachedData != null && _lastFetch != null && now.difference(_lastFetch!).inMinutes < 15) {
      return _cachedData!;
    }

    try {
      // 1. Fetch Forecast from Open-Meteo
      final forecastUrl = '$_forecastBase?latitude=$lat&longitude=$lon'
          '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day,uv_index'
          '&hourly=temperature_2m,precipitation_probability,weather_code,is_day'
          '&minutely_15=precipitation'
          '&forecast_days=2&timezone=auto';

      final forecastResp = await _httpGet(forecastUrl);

      // 2. Fetch Air Quality from Open-Meteo
      final airUrl = '$_airQualityBase?latitude=$lat&longitude=$lon&current=european_aqi,us_aqi,pm2_5,pm10';
      final airResp = await _httpGet(airUrl).catchError((_) => '');

      // 3. Fetch RainViewer radar maps
      String? radarUrl;
      String radarTime = 'Live';
      try {
        final radarResp = await _httpGet(_rainViewerBase);
        if (radarResp.isNotEmpty) {
          final radarJson = jsonDecode(radarResp);
          final host = radarJson['host'] ?? 'https://tilecache.rainviewer.com';
          final radarArr = radarJson['radar']?['past'] as List?;
          if (radarArr != null && radarArr.isNotEmpty) {
            final latest = radarArr.last;
            final path = latest['path'];
            final timeEpoch = latest['time'] as int?;
            if (timeEpoch != null) {
              final d = DateTime.fromMillisecondsSinceEpoch(timeEpoch * 1000);
              radarTime = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
            }
            if (path != null) {
              radarUrl = '$host$path/256/3/6/3/2/1_1.png';
            }
          }
        }
      } catch (_) {}

      if (forecastResp.isNotEmpty) {
        final fJson = jsonDecode(forecastResp);
        final current = fJson['current'] ?? {};
        final hourlyObj = fJson['hourly'] ?? {};
        final minutely = fJson['minutely_15'] ?? {};

        final double temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
        final double appTemp = (current['apparent_temperature'] as num?)?.toDouble() ?? temp;
        final int humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 75;
        final double wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 8.0;
        final int code = (current['weather_code'] as num?)?.toInt() ?? 1;
        final double uv = (current['uv_index'] as num?)?.toDouble() ?? 0.0;
        final int isDay = (current['is_day'] as num?)?.toInt() ?? 1;

        final condTuple = _parseWeatherCode(code);

        // Calculate rain summary from minutely_15
        String rainSummary = 'No rain in the next 2 h';
        final precips = minutely['precipitation'] as List?;
        if (precips != null && precips.isNotEmpty) {
          int rainIndex = -1;
          for (int i = 0; i < precips.length && i < 8; i++) {
            if (((precips[i] as num?)?.toDouble() ?? 0.0) > 0.1) {
              rainIndex = i;
              break;
            }
          }
          if (rainIndex == 0) {
            int stopIndex = -1;
            for (int i = 1; i < precips.length; i++) {
              if (((precips[i] as num?)?.toDouble() ?? 0.0) <= 0.1) {
                stopIndex = i;
                break;
              }
            }
            if (stopIndex > 0) {
              rainSummary = 'Raining · stops in ~${stopIndex * 15} min';
            } else {
              rainSummary = 'Raining for the next 2 hours';
            }
          } else if (rainIndex > 0) {
            rainSummary = 'Rain in ~${rainIndex * 15} min';
          }
        }

        // Parse Air Quality
        int aqi = 42;
        String aqiCat = 'Good';
        if (airResp.isNotEmpty) {
          final aJson = jsonDecode(airResp);
          final aCurrent = aJson['current'] ?? {};
          aqi = (aCurrent['us_aqi'] as num?)?.toInt() ?? (aCurrent['european_aqi'] as num?)?.toInt() ?? 42;
          if (aqi <= 50) {
            aqiCat = 'Good';
          } else if (aqi <= 100) {
            aqiCat = 'Moderate';
          } else if (aqi <= 150) {
            aqiCat = 'Sensitive';
          } else if (aqi <= 200) {
            aqiCat = 'Unhealthy';
          } else {
            aqiCat = 'Very Unhealthy';
          }
        }

        // Parse Hourly
        final List<HourlyForecast> hourlyList = [];
        final hTimes = hourlyObj['time'] as List?;
        final hTemps = hourlyObj['temperature_2m'] as List?;
        final hCodes = hourlyObj['weather_code'] as List?;
        final hPops = hourlyObj['precipitation_probability'] as List?;
        final hDays = hourlyObj['is_day'] as List?;

        if (hTimes != null && hTemps != null && hCodes != null) {
          final curHourStr = now.hour.toString().padLeft(2, '0');
          int startIdx = 0;
          for (int i = 0; i < hTimes.length; i++) {
            final t = hTimes[i].toString();
            if (t.contains('T$curHourStr:')) {
              startIdx = i;
              break;
            }
          }

          for (int i = startIdx; i < hTimes.length && (i - startIdx) < 12; i++) {
            final tStr = hTimes[i].toString();
            final hourLabel = (i == startIdx)
                ? 'Now'
                : (tStr.length >= 16 ? tStr.substring(11, 16) : '$i:00');
            final hT = (hTemps[i] as num?)?.toDouble() ?? 28.0;
            final hC = (hCodes[i] as num?)?.toInt() ?? 1;
            final hP = (hPops != null && i < hPops.length) ? ((hPops[i] as num?)?.toInt() ?? 0) : 0;
            final hD = (hDays != null && i < hDays.length) ? ((hDays[i] as num?)?.toInt() ?? 1) : 1;

            hourlyList.add(HourlyForecast(
              time: hourLabel,
              temp: hT,
              weatherCode: hC,
              pop: hP,
              isDay: hD,
            ));
          }
        }

        final result = WeatherData(
          temp: temp,
          apparentTemp: appTemp,
          humidity: humidity,
          windSpeed: wind,
          weatherCode: code,
          condition: condTuple.$1,
          conditionMalay: condTuple.$2,
          uvIndex: uv,
          isDay: isDay,
          rainSummary: rainSummary,
          aqi: aqi,
          aqiCategory: aqiCat,
          hourly: hourlyList,
          radarPath: radarUrl,
          radarTime: radarTime,
        );

        _cachedData = result;
        _lastFetch = now;
        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        print('WeatherService fetch error: $e');
      }
    }

    return _cachedData ?? WeatherData.initial();
  }

  static (String, String) _parseWeatherCode(int code) {
    switch (code) {
      case 0:
        return ('Clear Sky', 'Cerah');
      case 1:
        return ('Mainly Clear', 'Cerah sebahagian');
      case 2:
        return ('Partly Cloudy', 'Sebahagian mendung');
      case 3:
        return ('Overcast', 'Mendung');
      case 45:
      case 48:
        return ('Foggy', 'Berkabus');
      case 51:
      case 53:
      case 55:
        return ('Drizzle', 'Hujan renyai');
      case 61:
      case 63:
      case 65:
        return ('Rain', 'Hujan');
      case 80:
      case 81:
      case 82:
        return ('Heavy Rain', 'Hujan lebat');
      case 95:
      case 96:
      case 99:
        return ('Thunderstorm', 'Ribut petir');
      default:
        return ('Clear', 'Cerah');
    }
  }
}

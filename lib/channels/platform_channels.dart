import 'package:flutter/services.dart';
import '../models/media_state.dart';

class PlatformChannels {
  static const MethodChannel browser = MethodChannel('drivedeck/car_browser');
  static const MethodChannel carState = MethodChannel('drivedeck/car_state');
  static const MethodChannel nowPlaying = MethodChannel('drivedeck/now_playing');
  static const MethodChannel welcome = MethodChannel('drivedeck/welcome');
  static const MethodChannel calendar = MethodChannel('drivedeck/calendar');
  static const MethodChannel legacy = MethodChannel('com.dashmate.dashmate/channel');

  // Media controls
  static Future<MediaState> getNowPlayingState() async {
    try {
      final res = await nowPlaying.invokeMethod<Map<dynamic, dynamic>>('getState');
      return MediaState.fromMap(res);
    } catch (_) {
      try {
        await legacy.invokeMethod<String>('getState');
        return MediaState();
      } catch (_) {
        return MediaState();
      }
    }
  }

  static Future<void> play() async => nowPlaying.invokeMethod('play');
  static Future<void> pause() async => nowPlaying.invokeMethod('pause');
  static Future<void> skipNext() async => nowPlaying.invokeMethod('skipNext');
  static Future<void> skipPrevious() async => nowPlaying.invokeMethod('skipPrevious');

  static Future<bool> isNotificationAccessGranted() async {
    try {
      final res = await nowPlaying.invokeMethod<bool>('isNotificationAccessGranted');
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openNotificationAccessSettings() async {
    try {
      await nowPlaying.invokeMethod('openNotificationAccessSettings');
    } catch (_) {}
  }

  // Car browser
  static Future<void> setCarPage(String page) async {
    try {
      await browser.invokeMethod('setPage', {'page': page});
    } catch (_) {}
    try {
      await legacy.invokeMethod('setPage', {'page': page});
    } catch (_) {}
  }

  static Future<void> openCarUrl(String url) async {
    try {
      await browser.invokeMethod('openUrl', {'url': url});
    } catch (_) {}
  }

  static Future<void> updateWeather(Map<String, dynamic> weather) async {
    try {
      await carState.invokeMethod('updateWeather', {'weather': weather});
    } catch (_) {}
  }

  static Future<void> updateForecast(Map<String, dynamic> forecast) async {
    try {
      await carState.invokeMethod('updateForecast', {'forecast': forecast});
    } catch (_) {}
  }

  static Future<void> updateAir(Map<String, dynamic> air) async {
    try {
      await carState.invokeMethod('updateAir', {'air': air});
    } catch (_) {}
  }

  static Future<void> updateRadar(Map<String, dynamic> radar) async {
    try {
      await carState.invokeMethod('updateRadar', {'radar': radar});
    } catch (_) {}
  }

  static Future<void> updateFuel(Map<String, dynamic> fuel) async {
    try {
      await carState.invokeMethod('updateFuel', {'fuel': fuel});
    } catch (_) {}
    try {
      await legacy.invokeMethod('updateFuel', {'fuel': fuel});
    } catch (_) {}
  }

  static Future<void> updateEv(Map<String, dynamic> ev) async {
    try {
      await carState.invokeMethod('updateEv', {'ev': ev});
    } catch (_) {}
  }

  static Future<void> updateLayout(String layoutJson) async {
    try {
      await carState.invokeMethod('updateLayout', {'layout': layoutJson});
    } catch (_) {}
    try {
      await legacy.invokeMethod('saveLayoutSettings', {'layout': layoutJson});
    } catch (_) {}
  }

  static Future<void> updateScores(Map<String, dynamic> scores) async {
    try {
      await carState.invokeMethod('updateScores', {'scores': scores});
    } catch (_) {}
  }

  static Future<void> playWelcomeChime() async {
    try {
      await welcome.invokeMethod('playChime');
    } catch (_) {}
  }

  static Future<void> setCustomPageMode(String mode) async {
    try {
      await carState.invokeMethod('setCustomPageMode', {'mode': mode});
    } catch (_) {}
    try {
      await legacy.invokeMethod('setCustomPageMode', {'mode': mode});
    } catch (_) {}
  }

  static Future<String> getThemeMode() async {
    try {
      final res = await browser.invokeMethod<String>('getThemeMode');
      if (res != null && res.isNotEmpty) return res;
    } catch (_) {}
    try {
      final res = await legacy.invokeMethod<String>('getThemeMode');
      if (res != null && res.isNotEmpty) return res;
    } catch (_) {}
    return 'auto';
  }

  static Future<void> setThemeMode(String mode) async {
    try {
      await browser.invokeMethod('setThemeMode', {'mode': mode});
    } catch (_) {}
    try {
      await legacy.invokeMethod('setThemeMode', {'mode': mode});
    } catch (_) {}
    try {
      await carState.invokeMethod('setThemeMode', {'mode': mode});
    } catch (_) {}
  }
}

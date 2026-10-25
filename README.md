# DashMate Deck

Android Auto dashboard for Malaysia. It has two parts:

- **Phone app (Flutter):** settings and setup, in `lib/`.
- **Android Auto side (Kotlin):** code in `android/app/src/main/kotlin/com/dashmate/dashmate/`; car-screen HTML pages in `android/app/src/main/assets/`.

## Build

You need the Flutter SDK (3.4x stable) and JDK 17. You also need the Android SDK with platform 36.

```bash
flutter pub get
flutter build apk --release --target-platform android-arm64
# output: build/app/outputs/flutter-apk/app-release.apk (~19 MB)
```

The release build is signed with the local debug key; see `android/app/build.gradle.kts`. Before sharing the app outside your own phone, give it a real release keystore.

## Install and run in the car

1. Install the APK on the phone.
2. Android Auto (phone) → Settings → tap **Version** 10× → ⋮ → Developer settings → turn on **Unknown sources**.
3. In the car, open the **DashMate** icon. The phone's "Customise Launcher" list does not show sideloaded navigation apps; this is normal.

To test without a car, use the Desktop Head Unit. Install it with `sdkmanager "extras;google;auto"`. On the phone: AA ⋮ → Start head unit server. Then run `adb forward tcp:5277 tcp:5277` and `./desktop-head-unit`.

## Where things are

| Feature | Code |
|---|---|
| Car session / surface | `DashMateCarAppService`, `DashMateSession`, `DashMateCarScreen`, `DashMatePresentation` |
| Dock bar, car keyboard | `DashMateDockBar`, `DashMateCarKeyboard` |
| Shared state → car pages | `DashMateStateBridge` (`buildStateJson`) |
| Media card + radio | `DashMateMediaCardService`, `deck/radio/RadioPlayer`, `deck/RadioStations` (edit the station list here) |
| Radio page (car) | `assets/dashmate_radio.html` + `RadioJsInterface` |
| Fuel prices | `deck/FuelPriceManager` (data.gov.my, weekly) |
| Prayer times + alerts | `deck/PrayerTimesManager`, `deck/PrayerAlertManager` |
| Auto parking | `deck/ParkingAutoSaver`, `deck/ParkingManager` |
| Navigate to masjid / petrol / car | `CarNav`, `deck/NearbyFinder` (hands off to Waze, falls back to Google Maps) |
| Car pages | `assets/drivedeck_home.html`, `drivedeck_prayer.html`, `drivedeck_lyrics.html`, `dashmate_radio.html` |

## Notes

- `lib/core/secrets.dart` holds the football-data.org API key. Keep this file private.
- Comments marked `RECONSTRUCTED:` show where the original code had to be rebuilt by hand from the decompiled APK.
- Some on-screen text, the `drivedeck_*` pages and the `window.AutoDeck` bridge name come from the third-party app "AutoDeck". Rewrite them before publishing the app.

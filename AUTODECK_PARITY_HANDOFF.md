# AutoDeck 2.0.0 Parity & Architecture Handoff

> This document details the complete reverse-engineered architecture, routing table, native platform channels, and persistent configuration keys from **AutoDeck 2.0.0** (`AutoDeck_2.0.0.apks`) and their exact implementations in **DashMate**.

---

## 1. Project Overview & Current State

- **Target App Reference**: AutoDeck 2.0.0 (`com.nasri.autodeck` / `com.dataflows.drivedeck`)
- **APK Sources Location**: `C:\Project\AAmate\apk\AutoDeck_2.0.0.apks`
- **Current Git Head**: `a1b471f AutoDeck-remaining-settings-parity`
- **Build Status**: Verified debug APK generated at `DashMate-debug.apk` and `build\app\outputs\flutter-apk\app-debug.apk`.
- **Direct Download Link**: [https://temp.sh/OAIvP/DashMate-debug.apk](https://temp.sh/OAIvP/DashMate-debug.apk)

---

## 2. Complete Router & Screen Matrix

AutoDeck utilizes a central Flutter routing table mapped to the following screens:

| Route | Screen File | Screen Title | Purpose & Implementation Details |
| :--- | :--- | :--- | :--- |
| `/` | `dashboard_screen.dart` | **Dashboard** | Single scrollable root screen with amber welcome trial card, carousel chips, Lyrics full-width card, 2x2 grid (Prayer, Browse, Custom page, Parking), live car preview box, and grouped car settings. |
| `/settings` | `settings_screen.dart` | **Settings** | Root settings view featuring user license card, car settings group, Apps Settings (Prayer & Football), permissions listeners, and legal disclaimers. |
| `/settings/buttons` | `button_size_screen.dart` | **Car button size** | Slider for car button size (80%–130%), live floating button idle look preview box, opacity slider (10%–100%), and 7 color swatches. |
| `/settings/welcome` | `welcome_sound_screen.dart` | **Welcome sound** | 3-way mode switch (`Off`, `Chime`, `Custom`), voice greeting toggle, optional text field with tokens (`{name}`, `{prayer}`, `{prayer_time}`, `{time}`, `{now}`, `{rain}`), voice speed/pitch/volume sliders, and test audio button. |
| `/settings/menu` | `floating_menu_screen.dart` | **Car menu** | Reorderable list of 5 floating car shortcuts (`Home`, `Lyrics`, `Prayer`, `Custom page`, `Browse`) with drag grip handles (`:::`) and on/off switches. |
| `/settings/carcard` | `car_card_screen.dart` | **Car card (next to the map)** | `Show AutoDeck Card` toggle to stop intercepting OEM steering wheel controls and digital gauge cluster maps, plus 4 mode choices: `✓ Auto`, `Lyrics`, `Next prayer`, `Football`. |
| `/settings/background`| `background_screen.dart` | **Car home background** | Interactive car head unit preview frame with 3 background modes: `Cover` (blurred live album art), `Plain` (minimalist dark luxury cockpit), and `Photo` (curated driving landscapes). |
| `/settings/prayer` | `prayer_screen.dart` | **Prayer** | `Show prayer times` toggle, JAKIM e-Solat zone picker (`assets/data/zones.json`), Azan audio chime toggle, and reminder minute offsets. |
| `/settings/football` | `football_settings_screen.dart` | **Football settings** | League checkboxes (`PL`, `CL`, `PD`, `SA`, `BL1`, `FL1`), favourite clubs selector (`Pasukan saya`), and `football-data.org` API token field. |
| `/widgets` | `widgets_screen.dart` | **Car home widgets** | In-car HUD widget layout editor (`car_layouts_current`). |
| `/browse` | `browse_screen.dart` | **Browse** | In-car web browser with quick-launch buttons (YouTube, RTM Klik, Google, Waze) and URL bar. |
| `/lyrics` | `lyrics_screen.dart` | **Lyrics** | Real-time synchronized LRC lyrics viewer with karaoke scrolling. |
| `/custom` | `custom_page_screen.dart` | **Custom page** | Live Open-Meteo weather, air quality index (AQI), RainViewer interactive radar, and sports scores. |
| `/parking` | `parking_screen.dart` | **Parking** | GPS parking spot saver with floor level, bay number, notes, and Google Maps navigate-back integration. |

---

## 3. Platform Channels & Native Communication

Communication between Flutter and the Android Auto head unit runtime is managed via the following platform channels in `MainActivity.kt`:

### Methods Implemented on Channels:
1. **`drivedeck/car_browser`**:
   - `setNavScale(scale)`: Adjusts size multiplier of in-car dock.
   - `setNavStyle(opacity, color)`: Updates translucency and accent color.
   - `setMenuItems(items)`: Dynamic injection of shortcuts array.
   - `setCarTemplate(template)`: Changes car wallpaper mode (`cover`, `plain`, `photo`).
   - `clearBrowserData()`: Clears WebStorage and cookies.
2. **`drivedeck/welcome`**:
   - `playChime()`: Plays `assets/dd_welcome_chime.wav` on presentation startup.
   - `testVoiceGreeting(text, speed, pitch, volume)`: Speaks via `android.speech.tts.TextToSpeech`.
3. **`com.dashmate.dashmate/channel`**:
   - `getButtonPrefs` / `setNavScale`
   - `getWelcomePrefs` / `setWelcomePrefs`
   - `getMenuItems` / `setMenuItems`
   - `getCarCardMode` / `setCarCardMode`
   - `getBgPrefs` / `setBgMode`
   - `getFootballPrefs` / `setFootballPrefs`
   - `getPrayerData` / `setPrayerZone`
   - `saveParkingSpot` / `getParkingSpot` / `clearParkingSpot`

---

## 4. Persistent Configuration Matrix

The following `SharedPreferences` keys are used across the native Android and Flutter layers:

| SharedPreferences Key | Type | Default Value | Description |
| :--- | :--- | :--- | :--- |
| `nav_scale` | `float` | `1.0f` | Car floating button size multiplier (0.80 to 1.30). |
| `nav_opacity` | `float` | `0.92f` | Idle opacity of in-car floating launcher. |
| `nav_color_idx` | `int` | `0` | Color index for the launcher (0=Teal, 1=Green, etc.). |
| `menu_items` | `String (JSON)` | `["home","lyrics","prayer","custom","web"]` | Enabled shortcuts and order. |
| `welcome_mode` | `int` | `1` | 0=Off, 1=Chime, 2=Custom greeting. |
| `welcome_voice` | `boolean` | `true` | Whether TTS speech greeting plays after chime. |
| `welcome_text` | `String` | `""` | Custom greeting text with token placeholders. |
| `welcome_speed` | `float` | `1.0f` | Speech rate multiplier. |
| `welcome_pitch` | `float` | `1.0f` | Speech pitch multiplier. |
| `welcome_volume` | `float` | `0.8f` | Speech audio volume. |
| `car_card_show` | `boolean` | `true` | Toggles whether Android Auto side-card is registered. |
| `car_card_mode` | `String` | `"Auto"` | Active side-card view: `Auto`, `Lyrics`, `Next prayer`, `Football`. |
| `bg_mode` | `String` | `"cover"` | Car home wallpaper: `cover`, `plain`, `photo`. |
| `bg_url` | `String` | `""` | Custom photo wallpaper URL. |
| `football_comps` | `String (JSON)` | `["PL", "CL"]` | Followed competition codes. |
| `football_teams` | `String (JSON)` | `["Arsenal", "Liverpool"]` | Favorite teams list. |
| `football_api_key` | `String` | `""` | `football-data.org` user API token. |
| `prayer_zone` | `String` | `"WLY01"` | Selected JAKIM prayer zone code. |
| `show_prayer` | `boolean` | `true` | Global toggle for prayer times countdown. |

---

## 5. Verification & Build Commands

To re-analyze or build new artifacts on Windows:

```powershell
# Analyze codebase
cmd /c flutter analyze

# Build debug APK
cmd /c flutter build apk --debug

# Copy built APK to root
cmd /c "copy /Y build\app\outputs\flutter-apk\app-debug.apk DashMate-debug.apk"
```

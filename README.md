# DashMate 🚗⚡

**DashMate** is an advanced automotive dashboard platform for **Android Auto** and Android phones, inspired by and architected identically to **AutoDeck**.

It bypasses standard Android Auto template constraints by combining a **Flutter companion app**, a native **Kotlin Android Auto Navigation Service**, and a high-performance **HTML5/CSS3 glassmorphic dashboard** rendered via `VirtualDisplay` and `Presentation`.

---

## 🏗️ Architecture

```
 ┌───────────────────────────┐         ┌──────────────────────────────┐
 │    Flutter Phone App      │ ◄─────► │     DashMateStateBridge      │
 │  (Controls, Themes, Hub)  │         │   (Kotlin Event / Hub)       │
 └───────────────────────────┘         └──────────────┬───────────────┘
                                                      │
                                                      ▼ Live JSON state updates
 ┌────────────────────────────────────────────────────────────────────┐
 │                       Android Auto Car Display                     │
 │                                                                    │
 │   DashMateCarAppService (NAVIGATION category)                      │
 │      └── DashMateCarScreen (SurfaceCallback)                       │
 │             └── DisplayManager.createVirtualDisplay(Surface)       │
 │                    └── DashMatePresentation                        │
 │                           └── Hardware-Accelerated WebView         │
 │                                  └── dashmate_deck.html            │
 └────────────────────────────────────────────────────────────────────┘
```

### Key Technical Pillars:
1. **Navigation Surface Masquerade**: Registers with `<category android:name="androidx.car.app.category.NAVIGATION"/>` and `<uses-permission android:name="androidx.car.app.ACCESS_SURFACE"/>`. Android Auto grants direct raw hardware `Surface` access exclusively to Navigation apps.
2. **VirtualDisplay & Presentation Engine**: Creates a virtual display directly connected to the car's native surface (`DisplayManager.createVirtualDisplay(...)`), hosting a hardware-accelerated Android `WebView`.
3. **Synthetic Touch Injection**: Touch events received from the vehicle screen (`SurfaceCallback.onClick(x, y)` and scroll events) are transformed into real Android `MotionEvent` instances and dispatched directly into the WebView.
4. **Media Notification Listener**: `DashMateMediaListenerService` listens to Android's active media sessions (Spotify, YouTube Music, Tidal, etc.) to capture live track details, artist names, and playback state without requiring individual app APIs.
5. **Real-time YouTube Streaming**: Supports passing YouTube video IDs directly from the phone companion app to stream into the car deck.

---

## 📁 Project Structure

* **`lib/main.dart`**: Flutter companion app with live dashboard controls, simulated speed slider, theme selector, YouTube video sender, and setup instructions.
* **`android/app/src/main/assets/dashmate_deck.html`**: The car dashboard web deck with dark glassmorphism styling, speedometer gauge, clock, weather, media player, navigation shortcuts, and YouTube player.
* **`android/app/src/main/kotlin/com/dashmate/dashmate/`**:
  * `DashMateCarAppService.kt`: Car app entry point with `ALLOW_ALL_HOSTS_VALIDATOR`.
  * `DashMateCarScreen.kt`: Manages `SurfaceCallback`, `VirtualDisplay`, and touch routing.
  * `DashMatePresentation.kt`: Manages the car display `WebView` and JavaScript bridge.
  * `DashMateStateBridge.kt`: Event hub connecting Flutter and Native Android.
  * `DashMateMediaListenerService.kt`: Intercepts system media notifications for Now Playing.
  * `MainActivity.kt`: Flutter `MethodChannel` handler.
* **`android/app/src/main/res/xml/automotive_app_desc.xml`**: Automotive capability descriptors.

---

## 🚀 How to Run & Test

### 1. Build the APK
```bash
cmd /c "flutter build apk --debug"
```

### 2. Enable Android Auto Developer Mode on Phone
1. Open **Settings** on your Android phone and search for **Android Auto**.
2. Scroll to the bottom and tap **Version** 10 times consecutively.
3. Accept the prompt: **"Allow development settings?"**.
4. Tap the **3 dots menu** in the top right corner -> **Developer settings**.
5. Enable **Unknown sources** (this permits sideloaded apps to appear on your car display).

### 3. Test with Android Auto Desktop Head Unit (DHU)
If you do not have a car available:
1. In Android Auto Developer settings, start the **Head unit server**.
2. Run Google's Desktop Head Unit emulator:
   ```bash
   adb forward tcp:5277 tcp:5277
   desktop-head-unit
   ```
3. DashMate Deck will launch on the DHU emulator window!

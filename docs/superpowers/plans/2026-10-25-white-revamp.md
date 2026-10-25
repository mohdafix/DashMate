# DashMate White UI Revamp Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the DashMate car deck, dock and phone app to a white, clean, modern look with an automatic night variant, keeping every function and making the car side smoother.

**Architecture:** One token set (`design/tokens.json`) defines the day and night colours. Car HTML pages use CSS variables switched by `<html data-theme>`; a native `DashMateTheme` object tracks AA night mode and tells the pages and dock. The Flutter app gets light + dark `ThemeData` plus an `AppTokens` theme extension, and screens read colours from the theme.

**Tech Stack:** Android Car App Library 1.4.0 (Kotlin), WebView HTML/CSS/JS, Flutter 3.47 (Dart 3.13), Node (checks), headless Chrome (screenshots).

**Spec:** `docs/superpowers/specs/2026-10-25-white-revamp-design.md`

## Global Constraints

- Keep every function and interaction; styling changes only. No new features, no moved buttons, no copy changes.
- Never remove or rename: element IDs, `data-*` attributes, JS functions, `window.*` globals, JS bridge methods, prefs keys (`dashmate_layout`, `dashmate_layout_portrait`, `dd_car_browser`, …).
- `drivedeck_home.html` layout JS (`pickLayout`, `applyLayout`, `ddSetLayout`, `customLayout`, `ddUpdate`) must not change behaviour.
- Contrast ≥ 4.5:1 for text, ≥ 3:1 for large text/icons, both themes.
- No `backdrop-filter`; ≤ 1 `box-shadow` per element, none at night; animate only `opacity`/`transform`, 150–250ms.
- System font only (Google Sans / Roboto); bundled clock fonts stay.
- Each agent edits only the files its task lists. Commit with `git add <own files>`; if `index.lock` exists, wait 2s and retry.
- Shell setup: `export PATH="$HOME/development/flutter/bin:$PATH"; export JAVA_HOME=$HOME/development/jdk17/Contents/Home`.
- Snapshot to compare against: commit `735760e` (or the "d4 done" commit from Task 0, if later).

## Review Focus

1. **Photo / song-cover background with white tiles:** text must stay readable on a bright photo and a dark photo → screenshot check in Task 2 with both test images.
2. **Night switch while driving (AA flips day→night mid-session):** the page and dock recolour without reloading or losing the current page → Task 4 DHU step toggles night mode.
3. **Pages reloaded after the browser panel (`exitBrowserToHome`, `onSwitchPage`):** the theme is correct on first paint, no white flash at night → Task 1 hook reads `AutoDeck.theme()` synchronously; Task 4 verifies on DHU.
4. **Phone widget editor preview of `drivedeck_home.html` (no AutoDeck bridge):** the preview follows the phone's light/dark mode → hook falls back to `prefers-color-scheme`; Task 5 checks it in the editor.
5. **Portrait J7 layout (from session d4):** the restyle must not break tall layouts → Task 2/3 screenshots at 720×1280.

---

### Task 0: Wait for session d4, then snapshot

- [ ] **Step 1:** Wait for the "done" message from session `software-development-d4`.
- [ ] **Step 2:** `git add -A && git commit -m "Snapshot: d4 portrait/J7 + widget editor (1.0.4)"` Record this commit hash as `BASE` in the agent board.

### Task 1: Tokens, theme hook and checks (lead, before agents)

**Files:**
- Create: `design/tokens.json`, `tool/ui_checks.mjs`, `tool/shoot.sh`, `tool/fixtures/state.json`, `tool/test-photos/bright.jpg`, `tool/test-photos/dark.jpg` (generate with `~/.local/bin/cf-image`, or crop any existing car photo)

**Interfaces:**
- Produces `design/tokens.json`: `{ "light": {bg, surface, surface2, border, ink, ink2, ink3, accent, onAccent, danger, ok}, "dark": {…} }` with the spec's palette values.
- Produces the **theme hook**, copied verbatim into the `<head>` of every car page, before any `<style>`:

```html
<script>(function(){var q=/[?&]theme=(dark|light)/.exec(location.search),m=q&&q[1];
try{if(!m&&window.AutoDeck&&AutoDeck.theme)m=AutoDeck.theme();}catch(e){}
if(!m)m=matchMedia('(prefers-color-scheme: dark)').matches?'dark':'light';
document.documentElement.dataset.theme=m;
window.ddTheme=function(t){document.documentElement.dataset.theme=(t==='dark'?'dark':'light');};})();</script>
```

- Produces CSS variable names for every page: `--bg --surface --surface-2 --border --ink --ink-2 --ink-3 --accent --on-accent --danger --ok --shadow`, defined in `:root` (light) and `:root[data-theme="dark"]`.
- Produces `node tool/ui_checks.mjs [--base <commit>]`, exit 0 = pass. Checks, per file in `android/app/src/main/assets/*.html`:
  1. `parity`: the sets of `id="…"`, `data-[a-z-]+` attribute names, `function NAME`, `window.NAME =` and `AutoDeck.NAME` / `DashMateRadio.NAME` calls in `git show <base>:<file>` are all still present.
  2. `no-blur`: no `backdrop-filter`.
  3. `theme-hook`: contains `window.ddTheme=` and `:root[data-theme="dark"]`.
  4. `tokens`: each token's hex from `tokens.json` appears in the file's `:root` block for its theme.
  5. `contrast`: computed from `tokens.json`: ink/ink2 on bg, surface and surface2 ≥ 4.5; ink3 on surface ≥ 3; onAccent on accent ≥ 4.5; danger on surface ≥ 4.5 (both themes).
- Produces `tool/fixtures/state.json`: a realistic sample of the JSON `DashMateStateBridge.buildStateJson` sends (all widgets on, music playing, football live, prayer, fuel, weather), built by reading that function.
- Produces `tool/shoot.sh <page.html> <outdir> [--photo <img>]`: copies the page and its asset folder into `build/shots/tmp/`, appends a `<script>` that calls `ddUpdate(<state.json>)` after load (and with `--photo`, sets the photo background mode to `<img>`), then uses headless Chrome (`/Applications/Google Chrome.app/Contents/MacOS/Google Chrome --headless=new --screenshot --virtual-time-budget=3000`) at 800×480, 1280×720 and 720×1280 for both `?theme=light` and `?theme=dark`. It writes `<outdir>/<page>[-photo]-<w>x<h>-<theme>.png`. The shipped page itself gets no test code.

- [ ] **Step 1:** Write `tokens.json` and `ui_checks.mjs`; run `node tool/ui_checks.mjs --base BASE`. Expected: FAIL on `no-blur`, `theme-hook` and `tokens` for the current pages, and PASS on `parity` and `contrast`.
- [ ] **Step 2:** Write `shoot.sh`; run it on `drivedeck_home.html` into `build/shots/before/`. Expected: 6 PNGs.
- [ ] **Step 3:** Commit `design/ tool/`.

### Task 2: Car home page restyle (agent car-home)

**Files:** Modify `android/app/src/main/assets/drivedeck_home.html` (CSS, the theme hook, and static colours in JS strings only).

**Interfaces:** Consumes Task 1's hook, variable names and checks.

- [ ] **Step 1:** Run `node tool/ui_checks.mjs --base BASE` and confirm it fails for this file (Task 1 Step 1).
- [ ] **Step 2:** Add the hook and the token blocks. Alias the old variables onto the new ones (`--ink`, `--dim → --ink-2`, `--glass → --surface-2`, `--edge → --border`, `--accent`, `--red → --danger`, `--green → --ok`, `--violet → --accent`).
- [ ] **Step 3:** Restyle:
  - `.tile`: `background: var(--surface)`, 1px `var(--border)`, `var(--shadow)`, no blur, no inset highlight. Over a photo/cover (`body.mode-photo|mode-upload|mode-cover`), the tile is the surface colour at 94% (day) or 90% (night).
  - `#plain`: `var(--bg)`, no gradient blobs.
  - `#dim` / `#shade`: only on photo/cover backgrounds.
  - Clock: on the plain background, `var(--ink)` with no text-shadow. On photos, it keeps white plus a soft shadow.
  - Football tile: a red-tinted surface (`color-mix(in srgb, var(--danger) 8%, var(--surface))`).
  - Music controls/progress: `var(--accent)`.
  - Replace every remaining hardcoded `#fff`/`rgba(255,…)` text colour with tokens.
- [ ] **Step 4:** Make it smoother:
  - Remove `backdrop-filter`.
  - Make sure no `transition` targets width, height, top, left or box-shadow.
  - Make `clock()` (≈line 1586) write `textContent` only when the string changed.
  - Leave the layout JS untouched.
- [ ] **Step 5:** Run `node tool/ui_checks.mjs --base BASE`. Expected: PASS for this file.
- [ ] **Step 6:** Run `tool/shoot.sh` into `build/shots/after/`, then again with `--photo tool/test-photos/bright.jpg` and with `--photo tool/test-photos/dark.jpg`. Look at every PNG. Every tile's text must be readable at all three sizes in both themes.
- [ ] **Step 7:** Commit.

### Task 3: Other car pages (agent car-pages)

**Files:** Modify `android/app/src/main/assets/drivedeck_prayer.html`, `drivedeck_lyrics.html`, `dashmate_radio.html`, `dashmate_deck.html`.

**Interfaces:** Same as Task 2.

- [ ] **Step 1:** Run the checks and confirm these files fail.
- [ ] **Step 2:** In each page: add the hook and token blocks, and replace hardcoded colours with tokens. Lyrics: the active line uses `--ink`, other lines `--ink-3`. Radio: the station list uses surface rows, and the playing station gets an `--accent` left bar. Prayer: the next prayer is highlighted with `--accent` and the countdown uses tabular numbers.
- [ ] **Step 3:** Remove `backdrop-filter`. The `setInterval` loops (prayer `render`, radio `render`, deck `updateClock`) write to the DOM only when the text changes.
- [ ] **Step 4:** Run the checks. Expected: PASS for all four files.
- [ ] **Step 5:** Take screenshots of each page in both themes and check them.
- [ ] **Step 6:** Commit.

### Task 4: Native night switch + dock (agent car-native)

**Files:**
- Create: `android/app/src/main/kotlin/com/dashmate/dashmate/DashMateTheme.kt`
- Modify: `DashMateSession.kt`, `DashMatePresentation.kt` (bridge method + listener only), `DashMateDockBar.kt` (colours only), `CarPreviewActivity.kt` (theme source only)

**Interfaces:**
- `object DashMateTheme { @Volatile var isDark: Boolean; fun mode(): String /* "dark"|"light" */; fun addListener(l: (Boolean) -> Unit); fun removeListener(l: (Boolean) -> Unit); fun set(dark: Boolean) /* notifies only on change, on main thread */ }`
- `DashMateSession`: `DashMateTheme.set(carContext.isDarkMode)` in `onCreate`, and again in `override fun onCarConfigurationChanged(newConfiguration: Configuration)`.
- `AutoDeckJsInterface`: `@JavascriptInterface fun theme(): String = DashMateTheme.mode()`.
- `DashMatePresentation`: registers a listener in `onCreate` and removes it in `dismiss`. On change it runs `deckWebView.evaluateJavascript("window.ddTheme&&ddTheme('<mode>')")` and calls `dock.applyTheme(dark)`.
- `DashMateDockBar.applyTheme(dark: Boolean)`: day uses dock bg #FFFFFF at 96% with a #E2E8F0 stroke, inactive button #F1F5F9 with #0F172A icons, and active #0F766E with #FFFFFF icons. Night uses #181B21, #2A2F37 and #20242B with #F1F5F9 icons, and active #2DD4BF with #042F2E icons. Exit stays red (#DC2626 day, #F87171 night) with a white or #1F0A0A icon. Buttons, order, sizes, touch handling and animations stay unchanged.
- `CarPreviewActivity`: `DashMateTheme.set(phone uiMode is night)` on create. It must not override the car value while a car session is live, so it should check whether a `DashMateSession` is active, with a `@Volatile var carSessionActive` set by the session.

- [ ] **Step 1:** Write `DashMateTheme.kt` and wire up the Session.
- [ ] **Step 2:** Add the bridge method, the Presentation listener, and `applyTheme` in the dock. Call `applyTheme(DashMateTheme.isDark)` once the dock is built.
- [ ] **Step 3:** Run `flutter build apk --debug --target-platform android-arm64`. Expected: BUILD SUCCESSFUL.
- [ ] **Step 4:** Commit.

### Task 5: Phone theme + screen group A (agent phone-a)

**Files:**
- Create: `lib/theme/app_tokens.dart`, `lib/theme/app_theme.dart`, `test/theme_test.dart`
- Modify: `lib/main.dart`, `lib/screens/dashboard_screen.dart`, `settings_screen.dart`, `widgets_screen.dart`, `background_screen.dart`, `button_size_screen.dart`, `floating_menu_screen.dart`, `car_card_screen.dart`
- Keep: `lib/theme/app_colors.dart` unchanged until Task 7 (group B still uses it).

**Interfaces:**
- `class AppTokens extends ThemeExtension<AppTokens>`: Color fields `bg, surface, surface2, border, ink, ink2, ink3, accent, onAccent, danger, ok`, `static const light`, `static const dark` (values from `design/tokens.json`), plus `copyWith` and `lerp`.
- `extension AppTokensX on BuildContext { AppTokens get tokens; }`
- `class AppTheme { static ThemeData light(); static ThemeData dark(); }`: Material 3, `fontFamily: 'Roboto'`, the ColorScheme mapped from the tokens (primary = accent, surface = surface, outline = border, error = danger), card/list/switch/slider/appBar themes on tokens, and `extensions: [AppTokens.light|dark]`.
- `main.dart`: `theme: AppTheme.light(), darkTheme: AppTheme.dark(), themeMode: ThemeMode.system`.

- [ ] **Step 1:** Write the failing `test/theme_test.dart`:
  - `light and dark ThemeData carry AppTokens`: `AppTheme.light().extension<AppTokens>() == AppTokens.light`, and the same for dark.
  - `token contrast`: the luminance ratio of ink on bg, surface and surface2 is ≥ 4.5, and onAccent on accent is ≥ 4.5, for both themes.
  - `group A screens have no hardcoded colours`: reads each group-A file and expects no matches for `Colors\.(white|black)\b`, `Color\(0x[0-9A-Fa-f]{8}\)` or `AppColors\.` (`Colors.transparent` is allowed).
- [ ] **Step 2:** Run `flutter test test/theme_test.dart`. Expected: FAIL (AppTokens is not defined).
- [ ] **Step 3:** Write `app_tokens.dart`, `app_theme.dart` and `main.dart`. Commit this **first** with the message `feat: phone theme tokens` so phone-b can start.
- [ ] **Step 4:** Convert the group-A screens to `context.tokens` / `Theme.of(context)`. Drop `const` where a widget now reads the theme. Widget trees, callbacks and setting keys stay unchanged.
- [ ] **Step 5:** Run `flutter test` and `flutter analyze`. Expected: all PASS and no new issues.
- [ ] **Step 6:** Commit.

### Task 6: Phone screen group B (agent phone-b, after Task 5 Step 3)

**Files:** Modify `lib/screens/prayer_screen.dart`, `lyrics_screen.dart`, `parking_screen.dart`, `football_settings_screen.dart`, `browse_screen.dart`, `custom_page_screen.dart`, `welcome_sound_screen.dart`; Test: `test/theme_group_b_test.dart`.

**Interfaces:** Consumes `AppTokens`, `context.tokens` and `AppTheme` from Task 5.

- [ ] **Step 1:** Write `test/theme_group_b_test.dart` with the same "no hardcoded colours" test as Task 5, for the group-B files. Run it. Expected: FAIL.
- [ ] **Step 2:** Convert the screens, under the same rules as Task 5 Step 4.
- [ ] **Step 3:** Run `flutter test` and `flutter analyze`. Expected: PASS.
- [ ] **Step 4:** Commit.

### Task 7: Review, clean-up, 1.0.5 (reviewer + lead)

**Files:** Delete or slim `lib/theme/app_colors.dart` (only if nothing references it). Modify `pubspec.yaml` (`version: 1.0.5+6`) and the README "Where things are" table (add `DashMateTheme`, `design/tokens.json`, `tool/`).

- [ ] **Step 1:** Reviewer (read-only) checks the diff `BASE..HEAD`:
  - Every check passes: `node tool/ui_checks.mjs --base BASE`, `flutter test` and `flutter analyze`.
  - No removed callbacks or prefs keys in Dart (`git diff BASE -- lib | grep '^-'`, then inspect every removed `onTap`/`onChanged`/`setString`/`getString` line).
  - Review the before/after screenshots.
- [ ] **Step 2:** Fix the findings. Remove `AppColors` if it's unused. Bump the version and update the README.
- [ ] **Step 3:** Run `flutter build apk --release --target-platform android-arm64` and copy the APK to `../DashMateDeck-1.0.5.apk`.
- [ ] **Step 4:** Ask the owner first, then run the DHU test:
  - Day and night: toggle the DHU night mode and check that the deck and dock recolour without reloading.
  - Tap every dock button, including Navigation and then "⌂ Deck", and check for a white flash.
  - Check a photo background and the music tile.
  - Compare responsiveness with 1.0.4.
- [ ] **Step 5:** Commit, then update the `dashmate-aa` memory.

### Agent board (lead, alongside Tasks 2–7)

Publish a live artifact with an avatar per agent (car-home, car-pages, car-native, phone-a, phone-b, reviewer). Each avatar moves between lanes (Waiting → Reading → Editing → Testing → Done) and shows a speech bubble with its current step. Agents report through the artifact's shared database, so the board updates while they work.

# DashMate white UI revamp — design

Date: 2026-10-25 · Approved direction: owner (chat, 2026-10-25)

## Goal

Restyle DashMate (car deck + dock + phone app) to a white, clean, modern look.
Keep every function and every interaction exactly as it is. Make the car side feel smoother.

**Success means:**
- Every screen, button, setting and page flow that works in 1.0.4 still works the same way.
- Day: white look. Night: matching soft-charcoal look, switched automatically.
- Text contrast is at least 4.5:1 in both themes (3:1 for large text and icons).
- No blur effects on the car side; the car deck scrolls, switches pages and updates without visible stutter.

## Out of scope

New features, layout changes, moving buttons, changing copy (except fixing text that becomes unreadable),
renaming the `drivedeck_*` / `window.AutoDeck` bridge.

## Palette (semantic tokens)

| Token | Day | Night | Use |
|---|---|---|---|
| `bg` | #F8FAFC | #0F1115 | page background |
| `surface` | #FFFFFF | #181B21 | cards / tiles / dock |
| `surface-2` | #F1F5F9 | #20242B | inactive buttons, chips, inputs |
| `border` | #E2E8F0 | #2A2F37 | 1px hairlines |
| `ink` | #0F172A | #F1F5F9 | main text |
| `ink-2` | #475569 | #A3ACB9 | secondary text |
| `ink-3` | #64748B | #7C8594 | hints (large text only) |
| `accent` | #0F766E | #2DD4BF | active state, links, progress |
| `on-accent` | #FFFFFF | #042F2E | text/icons on accent |
| `danger` | #DC2626 | #F87171 | Exit, live score, errors |
| `ok` | #15803D | #4ADE80 | in-range / success |
| `shadow` | 0 1px 2px rgba(15,23,42,.06), 0 4px 12px rgba(15,23,42,.06) | none (border only) | one shadow, cards only |

Radius: cards 16px (car: scales with `--u`), buttons 12px, chips 999px. Font: system (Google Sans / Roboto), no new font downloads.
Clock fonts the user picks in settings stay available; their colour follows `ink`.

## Night switch

- **Car:** Car App Library `carContext.isDarkMode` (follows car headlights / AA night mode). Read on session start and on
  configuration change; pass to every deck WebView as `document.documentElement.dataset.theme = "dark" | "light"`
  (a tiny `window.ddTheme(mode)` function in each page). Dock bar recolours from the same flag.
- **Phone:** `MaterialApp(theme: light, darkTheme: dark, themeMode: ThemeMode.system)`.
- **Car preview on phone** (`CarPreviewActivity`): follows the phone's light/dark mode.

## Backgrounds (photo / song cover / plain)

- Plain: `bg` colour (no gradient blobs).
- Photo / cover: picture stays; tiles become near-solid `surface` plates (day ~94% opacity, night ~90%) so text is readable on
  any picture. The floating clock (no tile) keeps a soft text shadow so it stays readable on photos; on plain background it uses `ink` with no shadow.

## Car smoothness rules

1. No `backdrop-filter` anywhere.
2. At most one `box-shadow` per tile; none in night mode; no inset highlights.
3. Animate only `opacity` and `transform`; transitions 150–250ms; nothing loops forever except the music progress bar.
4. Clock and countdown timers write to the DOM only when the shown text changes.
5. No layout reads inside the update loops (avoid forced reflow).
6. Before/after check on the Desktop Head Unit (owner's phone, with permission).

## Phone app

- `lib/theme/app_colors.dart` becomes a light + dark token set exposed through `ThemeData`/`ColorScheme` and a
  `ThemeExtension` for custom tokens; screens read colours from the theme, not constants.
- Replace hardcoded `Colors.white`, `Color(0xFF14E0C1)`, `Color(0xFF1BE3B0)`, etc. with tokens.
- Keep every widget tree, callback and setting key; only styling changes.

## Must not change (load-bearing)

- `drivedeck_home.html` grid/layout JS: `pickLayout`, `applyLayout`, `ddSetLayout`, `customLayout`, `ddUpdate`, element IDs, `data-*` attributes.
- Dock buttons, their order and behaviour (Navigation, Exit), `DashMatePresentation` touch handling.
- Prefs keys (`dashmate_layout`, `dashmate_layout_portrait`, `dd_car_browser`, …) and all JS bridges.

## Work split (agents)

Starts only after the other session (d4, portrait/J7 + widget editor) says "done".

| Agent | Files |
|---|---|
| car-home | `assets/drivedeck_home.html` (CSS + theme hook only) |
| car-pages | `assets/drivedeck_prayer.html`, `drivedeck_lyrics.html`, `dashmate_radio.html`, `dashmate_deck.html` |
| car-native | `DashMateDockBar.kt`, `DashMatePresentation.kt`/`DashMateCarScreen.kt` (theme flag only), `CarPreviewActivity.kt`, dock drawables if needed |
| phone-a | `lib/theme/*`, `lib/main.dart`, dashboard, settings, widgets, background, button_size, floating_menu, car_card screens |
| phone-b | prayer, lyrics, parking, football_settings, browse, custom_page, welcome_sound screens |
| reviewer | read-only: contrast check, function-parity check vs. the git snapshot, `flutter analyze`, release build |

Each agent owns only its files. phone-b starts after phone-a lands the theme tokens.
A live "agent board" artifact shows each agent's avatar and current step.

## Testing

- `flutter analyze` clean; release APK builds (`flutter build apk --release --target-platform android-arm64`).
- Render each car HTML page in a desktop browser at 800×480, 1280×720 and portrait 720×1280 in both themes; screenshot.
- Diff review: no removed IDs, functions, handlers or prefs keys versus the snapshot commit.
- DHU test on the owner's phone (ask first): day + night, each dock button, photo background, music tile.
- Ship as 1.0.5.

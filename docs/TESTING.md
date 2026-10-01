# Testing Guide

Prism Music has four test tiers. Run the first three locally with one
command; the fourth needs a device.

| Tier | Location | Command | Runs in CI |
|------|----------|---------|------------|
| Unit / BLoC | `test/` | `flutter test` | ✅ |
| Widget | `test/widgets/` | `flutter test` | ✅ |
| Golden | `test/goldens/` | `flutter test` | ✅ |
| Integration | `integration_test/` | `flutter test integration_test` | ❌ (needs device) |

## Test inventory (current)

- **Unit / BLoC (~45 tests)**
  - `test/blocs/library_bloc_test.dart` — load aggregation and failure,
    create/delete playlist, add/remove song reload, import success
    persisting through the library repository, import failure reporting,
    duplicate re-import updating in place, progress emissions, like
    toggle, download flow.
  - `test/blocs/search_bloc_test.dart` — history lifecycle, debounce,
    short-query short-circuit, per-filter routing, failure surfacing,
    filter re-search, suggestions, pagination stub.
  - `test/blocs/theme_bloc_test.dart` — initial mode, persistence,
    dynamic-color toggle, direct-color application, layout mode, reset.
  - `test/services/` — SettingsService defaults/round-trips/clamps,
    ChartService definitions + cache behaviour, StreamCacheService
    hit/miss/TTL/stats.
  - `test/lyrics_matching_test.dart` — title/artist normalization, LRC
    parsing (multi-timestamp, comma decimals), candidate scoring, local
    lyrics cache round-trip and eviction.
  - `test/spotify_datasource_test.dart` — embed-page parsing against a
    real page fixture.
- **Widget tests (24)** — `test/widgets/`: PrismSongTile, LikedSongsPage,
  LibraryTab, ChartsHubPage, ChartPage, SearchPage, HomeTab, PlayerPage,
  PlayerLyricsView.
- **Golden tests (12)** — `test/goldens/`: song tile (light/dark ×
  small/large phones), mini player, synced lyrics, liked songs page and
  charts hub in both themes.
- **Integration (1 flow)** — `integration_test/app_flow_test.dart`:
  search → play → background → notification metadata → next track.

## Running tests

```bash
# Everything except integration tests (analyze is enforced separately):
flutter analyze
flutter test

# A single suite:
flutter test test/blocs/library_bloc_test.dart

# Integration flow — needs a booted emulator/device with internet:
flutter devices                     # confirm a device is attached
flutter test integration_test/app_flow_test.dart
```

### Conventions

- **Fakes live in `test/helpers/fakes.dart`** — one canonical fake set
  (previously duplicated per file), plus `song()`/`playlist()` builders,
  `buildTestPlayerBloc()` (a real PlayerBloc wired to offline fakes),
  `registerTestGetIt()` and the `pumpTestWidget` widget harness (app
  theme + bloc providers at fixed phone sizes).
  Every fake is offline; no test touches the network.
- **Never `pumpAndSettle`** pages that can show skeletons or the
  playing-bars indicator — their repeating animations never settle. Use
  fixed `await tester.pump(duration)` cycles.
- **Hive in tests** is bootstrapped to a unique temp directory per
  process (`initTestHive` / `ensureWidgetTestHive`) so parallel or
  re-run processes never contend on Windows Hive lock files.
- Widget tests read blocs through `BlocProvider.value` with blocs the
  test owns (created + closed in the test), and fabricated states are
  pushed with `bloc.emit(...)`.

## Golden tests

Goldens lock the visual output of key surfaces across **dark/light
themes** and **common phone sizes** (360×800 and 412×915).

- Determinism: `GoogleFonts.config.allowRuntimeFetching = false` — text
  renders with Flutter's bundled test font, which draws identically on
  every platform, so goldens generated on Windows pass on Linux CI.
- All fixtures use empty artwork (no network images).

After an **intentional** UI change, regenerate and commit:

```bash
flutter test --update-goldens test/goldens
git add test/goldens/goldens
```

If a golden fails unexpectedly, inspect the diff image at
`test/goldens/goldens/<name>/diff.png` before regenerating — a golden
failure is a rendering regression until proven otherwise. (They already
caught one real bug: the charts-hub card overflowing on narrow phones.)

## Real-device regression checks

Run this matrix on **physical devices** (or emulators as a fallback)
before every release. Current targets: **Android 13, 14, 15**.

| Check | Android 13 | Android 14 | Android 15 |
|---|---|---|---|
| Fresh install of the release APK | ☐ | ☐ | ☐ |
| Update-in-place from the previous release (same signing key — no uninstall) | ☐ | ☐ | ☐ |
| Update from a pre-0.2.21 debug-signed build fails cleanly (package conflict), uninstall → install works | ☐ | ☐ | ☐ |
| Search returns results; tapping plays audio | ☐ | ☐ | ☐ |
| Media notification appears with correct title/artist and play/pause works from the shade | ☐ | ☐ | ☐ |
| Background the app → audio continues; kill from recents → audio stops | ☐ | ☐ | ☐ |
| Device locked → audio continues; Bluetooth headphones connect/disconnect without killing playback | ☐ | ☐ | ☐ |
| Battery optimization prompt (if shown) — allow, then verify background playback | ☐ | ☐ | ☐ |
| Download a song → offline playback works in airplane mode | ☐ | ☐ | ☐ |
| Spotify + YouTube playlist imports fill with tracks | ☐ | ☐ | ☐ |
| Lyrics load, sync highlights the current line, refresh works | ☐ | ☐ | ☐ |
| Dark and light themes render correctly (compare against goldens) | ☐ | ☐ | ☐ |
| App cold-start after force-stop restores library (playlists/likes) | ☐ | ☐ | ☐ |

Notes:
- Android 14+ shows a foreground-service notification permission prompt
  on first playback — accept it, or the media notification silently
  disappears.
- Android 15 enforces stricter foreground-service policies; verify the
  notification survives "swipe away" of the app (audio should keep
  playing).

## Known gaps / next steps

- Integration coverage is one flow; candidates for more: download
  → offline playback, import flows end-to-end, cold-start restore.
- No CI emulator yet — the integration test runs manually. Wiring an
  Android emulator into GitHub Actions (reusable runner) is the next
  automation step.
- Coverage measurement (`flutter test --coverage`) is not wired into CI
  yet; the suite is meaningful-first rather than percentage-driven.

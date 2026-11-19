# Prism Music — Full App Audit Report

**Date:** 19 November 2026 · **Version audited:** `0.2.96+132` · **Branch:** `arena/f0ada971-prism-music`
**Scope:** every Dart file in `lib/` (227 files, ~65,275 lines), plus `android/`, `ios/`, CI workflows, and the test suite (145 test files).
**Method:** line-by-line read of the playback path (`main.dart` → `PlayerBloc` → `MediaResolverService` → `StreamLoaderService` → resolvers → `AudioPlayerService` → `YouTubeAudioSource`), plus targeted greps across UI, security, storage, and platform layers.

---

## 0. How Prism Music works (the 60-second version)

```
Search / Home / Library (UI, BLoC)
        │  PlaySongEvent(song, queue, index)
        ▼
PlayerBloc  ── generation counter guards stale async work ──► MediaResolverService
        │                                                        │  1. downloaded file?  → local path
        │                                                        │  2. direct stream URL? → use as-is
        │                                                        │  3. else StreamLoaderService
        │                                                        ▼
        │                                              StreamLoaderService (sequential fallback)
        │                                                JioSaavn → YouTube Explode → Piped → Invidious
        │                                                (9s per resolver, 22s total budget, circuit breaker)
        ▼
AudioPlayerService (just_audio)
   • queue.length > 1  → ConcatenatingAudioSource (native auto-advance)
   • queue.length == 1 → setUrl() single-track
   • YouTube tracks    → YouTubeAudioSource (StreamAudioSource: fetches the
                         youtube_explode manifest lazily, then proxies byte ranges over HTTP)
        ▼
PrismAudioHandler (audio_service) → lock-screen / notification controls
```

State lives in 4 BLoCs (`PlayerBloc`, `SearchBloc`, `LibraryBloc`, `ThemeBloc`), DI via GetIt (`lib/core/di/injection.dart`), persistence via Hive boxes + `SettingsService`. Downloads go through `DownloadService` (Dio → temp file → validate → atomic rename → Hive record).

---

## 1. Root-cause analysis: the 3 bugs you reported

### 🔴 Bug A — "Downloaded songs can't play when the net is off" — CONFIRMED, root cause found

**Root cause: `loadQueue()` classifies every queued song with a non-empty `videoId` as a YouTube track — including local downloaded files.**

The chain:

1. `DownloadsPage._playSong` maps Hive records via `DownloadService.mapDownloadToSong` (`lib/core/services/download_service.dart:747`), which sets `id = playableId`, `youtubeId = null`, `streamUrl = localPath` (a raw filesystem path like `/storage/emulated/0/.../file.m4a`).
2. `PlayerBloc._onPlaySong` resolves **only the current song** through `MediaResolverService` (correctly returns the local path, `videoId: null`). For the rest of the queue, `_loadAudioQueueSafe` (`lib/presentation/blocs/player/player_bloc.dart:2158`) builds payloads with `'videoId': s.playableId` — **non-empty for every song** — and `'url': s.streamUrl` (the local path).
3. `AudioPlayerService.loadQueue` (`lib/core/services/audio_player_service.dart:754`) computes:
   ```dart
   final isYouTube = (videoId != null && videoId.isNotEmpty) || ...;
   if (isYouTube) {
     source = YouTubeAudioSource(videoId: ..., initialStreamUrl: url /* local path! */);
   }
   ```
   Every downloaded song is wrapped in a `YouTubeAudioSource` whose `initialStreamUrl` is a **filesystem path**. `YouTubeAudioSource.request()` then does `http.Request('GET', Uri.parse('/storage/...'))` — an invalid HTTP request that fails all 3 retries. The track never plays. Nothing is shown to the user (the error surfaces only in debug logs / the generic error stream).

**Why single-song playback can appear to work:** with `queue.length == 1`, `setUrl()` is called with `videoId: null` (from the offline `ResolvedMediaSource`), so `isYouTube` is false and the local-file branch (`Uri.file(url)`) runs correctly. The bug only bites in queue mode — which is exactly how the Downloads page plays (full queue). This matches your report precisely.

**Secondary offline bugs found while tracing:**
- `appendToQueue()` (`audio_player_service.dart:856`) uses `Uri.parse(url)` on raw paths instead of `Uri.file(url)` — relative-URI failure for local files.
- `PlayerBloc` lines 835/843 call `isDownloaded(songToPlay.id)` while everywhere else uses `playableId`. For songs where `id != playableId` (e.g. `youtubeId` set), the "Offline • Downloaded" badge logic misfires (cosmetic, but the same id confusion class).
- `MediaResolverService` keys downloads by `playableId` (`youtubeId ?? jioSaavnId ?? id`). If a song is downloaded from one provider context and played from another where the id fields differ, `isDownloaded` misses and the app tries the network while offline.

**Fix direction:** in `loadQueue`/`addToQueue`/`appendToQueue`, detect local paths *before* the YouTube check (mirror `setUrl`'s `isLikelyLocalPath` logic) and build `AudioSource.uri(Uri.file(path))`. Also resolve local paths for **all** queue entries in `_loadAudioQueueSafe`, not just the current song.

---

### 🔴 Bug B — "One song after search plays, the next doesn't come properly, takes a lot of time" — CONFIRMED, structural

**Root cause: queue-mode auto-advance does a full lazy manifest fetch per track, and the prefetch system prefetches the wrong thing.**

1. `_loadAudioQueueSafe` resolves **only the current song**. Every other song gets `url: s.streamUrl ?? ''` — search results carry no `streamUrl`, so all upcoming tracks are `YouTubeAudioSource` with `initialStreamUrl: null`.
2. `YouTubeAudioSource.request()` (`lib/core/services/youtube_audio_source.dart:185`) fetches a fresh `youtube_explode` manifest **at track-change time**, trying up to 4 clients sequentially (3.5s + 5s + 6s + 6s ≈ up to 20s worst case), then an HTTP range request (15s timeout, 3 retries with backoff).
3. The prefetch path (`_prefetchAhead`, `player_bloc.dart:455`) only calls `MediaResolverService.preResolveSong`, which caches a `StreamInfo` URL in `_preResolved` — **but in queue mode that cache is never consumed**. Native auto-advance goes through `_onIndexChanged`, which performs no resolution at all. The prefetch work is discarded. Additionally it only prefetches **one** song ahead, after a 3-second delay, and only if still playing.
4. `StreamLoaderService._fetchOptimized` (`lib/core/services/stream_loader_service.dart:192`) is **sequential**, despite the class comment claiming "parallel fetching": JioSaavn (search API call + per-CDN HEAD probes at 1.5s each) → YouTube Explode → Piped → Invidious, each up to 9s, inside a 22s overall budget. A JioSaavn miss alone can burn ~10s before YouTube is even tried.
5. If a queued track's manifest fetch fails, `just_audio` stalls in `loading`; `PlayerBloc._onPlayerError` **explicitly ignores errors during `loading` status** (`player_bloc.dart:1680`), so there is no recovery — the UI sits on a spinner until the user manually skips.

Net effect: every track transition costs a full manifest resolution (seconds to tens of seconds on slow networks), with no effective prefetch and no failure recovery. Exactly the "next song not coming properly / taking lotta time" you describe.

**Fix direction:** (a) pre-resolve the next 2–3 tracks' `StreamInfo` *and* pass those URLs as `initialStreamUrl` into the queued `YouTubeAudioSource`s (or pre-warm `YouTubeAudioSource.prewarmCache`); (b) make `StreamLoaderService` race resolvers with `Future.any` instead of sequential fallback; (c) handle native queue-track failures in `_onIndexChanged` (verify the new track actually reaches `playing`, else skip/re-resolve).

---

### 🔴 Bug C — "It goes back to the first song" — CONFIRMED, multiple contributing causes

1. **Bloc queue vs native queue desync (primary suspect).** `_onAddRecommendations` (`player_bloc.dart:2009`) appends recommendations to the **bloc** queue only — it never calls `_audioPlayer.appendToQueue()`. The native `ConcatenatingAudioSource` stays shorter than the bloc queue. When the native queue ends, `completed` fires; `_onCompleted` sees `state.hasNext == true` (bloc queue is longer) and fires `NextEvent`; `_onNext` finds native `hasNext == false`, falls into the bloc branch, and **rebuilds the entire native queue from scratch** via `_loadAudioQueueSafe`. During that rebuild the bloc emits `queueIndex` optimistically; if any index event is missed or the rebuild lands on a stale index, playback restarts from index 0 — the "back to first song" symptom.
2. **Repeat-all loops to `queue.first`** in both `_onNext` (`player_bloc.dart:1096`) and `_onCompleted` (`:1655`). If repeat-all is on (easy to enable from the notification), every queue end restarts at song 1. Combined with recommendation top-ups (queue rarely ends), the loop point keeps moving — feels like random jumps to the first song.
3. **`_onPlaySong` early-return** (`player_bloc.dart:568`): if a `PlaySongEvent` arrives for the song already playing, it only updates `queueIndex` and returns. A stale event carrying `queueIndex: 0` (e.g. a delayed retry/auto-advance) silently resets the bloc index to 0 while native playback continues elsewhere — the next manual skip then rebuilds from the wrong position.
4. **Queue rebuild on every non-queue-mode Next.** If `loadQueue` failed and fell back to single-track `setUrl`, `_playlist == null`, so every Next tap tears down and rebuilds the whole queue (full re-resolve). Slow, and any failure mid-rebuild leaves the player in a half-built state.

**Fix direction:** keep bloc queue and native queue in lock-step (call `appendToQueue` when recommendations are added; never let bloc `queueIndex` exceed native length); make `_onIndexChanged` the single source of truth for index; drop the early-return index overwrite; surface repeat state clearly in the UI.

---

## 2. Section-by-section audit

### 2.1 🎨 UI (design system & widgets)

**✅ Good**
- Consistent "Prism" design system: `PrismSongTile`, `PrismArtwork`, `PrismCollectionHeader`, `PrismSkeleton`, `PrismEmptyState`, `PrismDialog/Sheet/Snackbar` — reused across pages instead of one-off widgets.
- Dynamic theming via `palette_generator` (artwork-derived colors), light/dark themes, `ThemeBloc` persisted through `SettingsService`.
- Player has 3 layouts (classic / vinyl / landscape) + ambient background + visualizer — genuinely polished.
- Skeleton loading states and staggered list animations exist (`prism_skeleton.dart`, `staggered_list_animation.dart`).
- `CachedNetworkImage` used for artwork (14 call sites) with cache manager.

**❌ Bad**
- Only **9 `Semantics`/`semanticsLabel` usages** across the whole presentation layer — screen-reader support is thin for a 23-page app.
- No shared error-state widget in use on 10 of 23 pages (charts hub, genre browse/detail, home, library tab, onboarding, podcasts, settings, smart playlists) — failures there render as blank/spinner, not `PrismErrorState`.
- `palette_generator` is a discontinued package (per prior audit) — a future Flutter upgrade will break dynamic theming with no maintained replacement wired in.
- `google_fonts` is a dependency but `GoogleFonts.config.allowRuntimeFetching = false` (`main.dart:27`) — the package is effectively dead weight; bundled Inter is what's actually used.

**➕ Needs adding**
- A global `PrismErrorState` + retry pattern applied to every async page.
- Semantic labels on all icon-only buttons (play, next, like, download) — accessibility + Play Store listing quality.
- A shared "streaming failed" banner component so playback errors are visible (today they mostly live in debug logs).

**📌 TODO**
- Replace `palette_generator` with a maintained color-extraction package or vendor the algorithm.
- Remove or actually use `google_fonts`.

**🔮 Future**
- Per-artist / per-album dynamic theme accents; animated artwork (video backgrounds) in the player; tablet two-pane layouts beyond the current adaptive breakpoints.

---

### 2.2 📡 Streaming & playback engine

**✅ Good**
- Genuinely resilient design: 4-resolver fallback (JioSaavn → YouTube Explode → Piped → Invidious) with per-source circuit breaker (`PlaybackReliabilityService`), 403-stale-URL recovery (invalidate + one fresh resolve), generation counters that kill stale async playback attempts, and 45s resolve/set-source timeouts so the UI can't hang in `loading` forever.
- `YouTubeAudioSource` (localhost `StreamAudioSource`) avoids raw `googlevideo.com` URLs in ExoPlayer — the right call for IP-bound streams.
- Stream cache with TTL + `expire`-param parsing (`StreamCacheService`), prefetch queue with invalidation, provider-health sheet for diagnostics.
- Audio focus orchestration, crossfade, loudness normalization, native EQ binding to the Android audio session ID, sleep timer with bedtime fade.

**❌ Bad**
- The three bugs in §1: local files misclassified as YouTube in queue mode; sequential (not parallel) resolver fallback; prefetch that warms a cache the queue path never reads; bloc/native queue desync; errors ignored during `loading`.
- `StreamLoaderService` comment says "parallel fetching" but `_fetchOptimized` is a sequential `for` loop — misleading for future maintainers.
- JioSaavn resolution does a **search API call per song** plus sequential CDN HEAD probes — expensive on every cold play.
- `YouTubeAudioSource` duplicates the 4-client manifest chain that `YouTubeMusicDataSource` also implements — two copies to keep in sync.
- `setUrl`'s branch logic (`isYouTube` derived from "any non-empty videoId") is fragile: any caller passing a videoId for a non-YouTube track silently routes to the YouTube path.

**➕ Needs adding**
- Parallel resolver racing (`Future.any` with first-success-wins) + per-resolver timeouts.
- Real prefetch: resolve next 2–3 tracks and inject URLs into queued sources; pre-warm `YouTubeAudioSource` manifests.
- Native queue-track failure detection (watchdog: if index changed but `playing` never becomes true within N seconds → skip + re-resolve).
- A single `isLocalPath` / `isYouTubeTrack` classifier shared by `setUrl`, `loadQueue`, `addToQueue`, `appendToQueue`.

**📌 TODO**
- Dedupe the manifest-fetch chain into one helper used by both `YouTubeAudioSource` and `YouTubeMusicDataSource`.
- Make `StreamLoaderService` actually parallel, or fix the comment.

**🔮 Future**
- Adaptive bitrate switching mid-track; gapless preloading of next track's first bytes; background pre-resolution of the full queue on Wi-Fi; DASH/HLS native support instead of byte-range proxying.

---

### 2.3 🧭 UX (flows, feedback, states)

**✅ Good**
- Optimistic UI: queue/index update immediately on tap before resolution completes.
- Offline banner (`offline_banner.dart`), offline-mode auto-switch to local library, restored-session paused (no surprise autoplay), queue persistence across restarts.
- Search has debounce + generation guards + ranking engine; history, stats, and "not interested" feedback loop into recommendations.
- Startup error screen (`StartupErrorApp`) with retry — the app never white-screens on init failure.

**❌ Bad**
- Playback failures are nearly invisible: errors go to `errorStream` → `PlayerErrorEvent`, which is dropped during `loading` and in terminal `error` state. Users see a spinner or a frozen mini-player, not "this song failed, skipped to next".
- No "now loading: song X" affordance tied to the actual resolution stage (resolve vs buffer vs manifest) — users can't tell a 2s resolve from a 20s hang.
- Repeat/shuffle state lives in the notification and player but there's no persistent visual indicator on the mini-player; repeat-all looping to song 1 reads as a bug (§1C).
- First-run onboarding exists, but there's no in-app explanation of the offline/download model (what "downloaded" guarantees, where files live).

**➕ Needs adding**
- User-visible error toasts/snackbars for skipped/failed tracks ("Couldn't play X — skipped").
- A loading-stage indicator (Resolving → Buffering → Playing) in the player.
- Repeat-mode badge on mini-player + a "queue ended" state instead of silent loop/pause.

**📌 TODO**
- Wire `PrismErrorState` into the 10 pages missing it.
- Add empty states for search-with-no-results per filter tab.

**🔮 Future**
- "Why this song?" explanations in radio/queue; listening-session recap; collaborative queue UX (backend exists — `CollaborativeQueueService` — but no obvious entry point).

---

### 2.4 🔒 Security & privacy

**✅ Good**
- Cleartext denied globally (`network_security_config.xml`, loopback-only exception) with a test (`test/security/cleartext_policy_test.dart`).
- Last.fm secrets via `--dart-define` + `FlutterSecureStorage`, with migration off a legacy plaintext Hive box.
- Download filenames sanitized (`sanitizePathComponent`), stream URLs validated (`isAcceptableStreamUrl`), downloaded bytes sniffed for audio signatures before promotion, temp-file + atomic rename, path-guard on delete.
- Release logging disabled (`Logger.root.level = OFF` outside debug) so queries/URLs don't leak to logcat; crash reporting is on-device first.
- `SECURITY.md` with coordinated-disclosure policy; CI pins action SHAs.

**❌ Bad**
- `android/app/debug.keystore` is committed to the repo. If it's ever used for a release build, that's a signing-key compromise. (Verify it's debug-only and rotate if it ever signed anything else.)
- Hive boxes (likes, history, downloads metadata, settings) are **unencrypted at rest** despite README/PRIVACY claims of an "encrypted on-device database". Hive has no built-in encryption; the claim overstates reality.
- `DownloadService` writes to public `/storage/emulated/0/Download/PrismMusic/Audio` as a fallback — other apps can read those files (no `MANAGE_EXTERNAL_STORAGE` gating on that path, and no MediaStore API usage).
- Spotify/Apple Music datasources exist but Spotify auth (`SpotifyAuthService`) + client-credentials flow means tokens live in memory/Hive — audit token storage before enabling those paths by default.

**➕ Needs adding**
- Encrypted Hive (AES via `hive_ce` + key in secure storage) or at minimum correct the privacy docs to match reality.
- MediaStore API for downloads on Android 10+ instead of raw public-path writes.
- `android:allowBackup` review + backup rules so Hive data isn't silently included in cloud backups.

**📌 TODO**
- Confirm `debug.keystore` is debug-only; add a CI check that fails if a non-debug keystore appears.
- Dependency audit: 100+ upgradable deps and one overridden `permission_handler_android` — schedule a `pub upgrade` + full test pass.

**🔮 Future**
- Certificate pinning for provider hosts; reproducible-build verification for releases; SBOM published with each APK.

---

### 2.5 📄 Pages (23 pages)

| Page | Lines | Verdict |
|---|---|---|
| `home_page` / `home_tab` | 426 / 1208 | Strong: tab caching, adaptive layout, mood filter, pinned rails. Missing error state. |
| `search_page` | 1055 | Strong: debounced, ranked, per-filter routing, offline results merged. |
| `player_page` | 432 | Good: 3 layouts, lyrics sheet, queue sheet, video mode. Loading-stage UX missing (§2.3). |
| `settings_page` | 1536 | Comprehensive (8 section cards) but the largest page file — split by section. |
| `stats_page` | 977 | Rich listening stats + export. |
| `library_tab` | 622 | Playlists/artists/smart playlists/import. Missing error state. |
| `artist_page` | 531 | Full artist view. |
| `playlist_detail_page` | 604 | Full CRUD + share QR + export. |
| `downloads_page` | 362 | Works, but playback from here is broken offline (§1A) — highest-priority page fix. |
| `podcasts_page` / `podcast_detail_page` | 361 / 294 | Present; no error/empty states. |
| `album_page`, `chart_page`, `charts_hub_page`, `genre_*`, `curated_playlist_page`, `remote_playlist_page`, `smart_playlist_page`, `liked_songs_page`, `recently_played_page`, `onboarding_page` | 200–370 each | Solid coverage; several lack error/empty states. |

**Cross-cutting:** every page uses `PrismPersistentMiniPlayer`; navigation is `IndexedStack` tab caching (good for state retention, costs memory on low-end devices — consider `Offstage` + lazy build for the 4th tab).

---

### 2.6 🏗️ Architecture & state management

**✅ Good**
- Clean layering (domain / data / presentation), repository pattern with `Either<Failure, T>`, BLoC with event transformers (debounce on search), generation counters against async races — above-average discipline for an indie app.
- DI is centralized and testable; 145 test files including bloc tests, golden tests, datasource tests, and security tests.

**❌ Bad**
- **Dead weight:** `PlaybackBloc` (403 lines) and `QueueBloc` (487 lines) are registered in DI and injected into `PlayerBloc`, but `PlayerBloc` never delegates to them (one stray `_queueBloc?.add(event)` at line 2307). ~890 lines of parallel state machine that can drift from `PlayerBloc` — delete or finish the split.
- `PlayerBloc` is 2,506 lines — the god-object of the app. Playback, queue, recommendations, sleep timer, scrobbling, video mode, and persistence all live in one class. Hard to test in isolation (the test suite works around it with fakes).
- `SettingsService.instance` singleton accessed directly inside `PlayerBloc`/`DownloadService` alongside injected deps — inconsistent DI, hurts testability.
- `MusicRepositoryImpl.getStreamUrl` + `StreamLoaderService` + `MediaResolverService` + `YouTubeMusicDataSource.getStreamUrl` = **four overlapping stream-resolution paths**. Only the `PlayerBloc` path is live; the repository path is legacy.

**➕ Needs adding**
- Split `PlayerBloc` into `PlaybackBloc`/`QueueBloc` for real (the files already exist) or remove them.
- Remove the dead repository stream path; one resolution pipeline only.

**📌 TODO**
- Replace direct `SettingsService.instance` reads with injected settings in `PlayerBloc`/`DownloadService`.

**🔮 Future**
- Event-sourced queue (replayable queue history for undo); remote queue sync (backend hooks exist in `BACKEND_INTEGRATION.md`).

---

### 2.7 💾 Storage, downloads & offline

**✅ Good**
- Download pipeline is careful: quota checks, Wi-Fi-only mode, priority queue (max 3 concurrent), cancel tokens, temp-file validation (size + magic bytes + content-type), atomic promotion, Hive reconciliation on launch, offline artwork caching.
- Queue persistence + session restore (paused, no autoplay) + local backup/restore that survives uninstall.

**❌ Bad**
- The offline playback bug (§1A) makes the whole feature appear broken — downloads succeed but don't play in queue mode.
- `isDownloaded` keyed by `playableId` is fragile across provider contexts (§1A secondary).
- No download integrity beyond magic bytes (no checksum vs provider metadata); no resume of partial downloads (`.tmp` files are deleted, not resumed).
- `getAllDownloadedSongs()` does sync `File.existsSync()` per record on the UI thread (called from `DownloadsPage._loadDownloads`) — jank with many downloads.

**➕ Needs adding**
- Resume support (HTTP Range on the temp file); checksum verification; async file-existence checks.
- A stable download key (e.g. ISRC or provider track id) independent of `playableId` derivation.

**📌 TODO**
- Move download listing off the UI thread.

**🔮 Future**
- Smart downloads (auto-download liked/top-played on Wi-Fi); storage-pressure auto-evict (LRU by play count).

---

### 2.8 📱 Platform (Android / iOS / desktop)

**✅ Good**
- Android: notification channel v2, media session coordinator, home-screen widget (`PrismAppWidgetProvider`), Wear OS bridge, automotive descriptor, audio-focus handling.
- Desktop: window service (title sync), shortcuts service, platform audio load config.
- iOS/macOS/Windows/Linux runners present; orientation policy adapts to tablets.

**❌ Bad**
- `PrismAudioHandler` has **zero try/catch** (grep: 0) — a handler exception can kill background playback silently.
- Desktop audio support is thin vs Android (no equivalent of the session/effects binding); Windows/macOS playback quality unverified in CI (CI builds Android only).
- Widget artwork sync fetches via `DefaultCacheManager` on every song change — wasteful if the image is already cached.

**➕ Needs adding**
- CI builds for at least one desktop target; background-playback smoke test on Android emulator.
- Defensive try/catch + logging in `PrismAudioHandler` callbacks.

**📌 TODO**
- Verify `androidStopForegroundOnPause: false` + `androidNotificationOngoing: false` combo on Android 14+ (foreground-service type requirements).

**🔮 Future**
- Android Auto / CarPlay full browsing (descriptor exists, browsing tree likely minimal); Cast (service exists) needs UX polish.

---

### 2.9 🧪 Testing & CI

**✅ Good**
- 145 test files: bloc tests, golden tests (12 goldens), datasource tests (incl. geo-restriction, backoff), service tests (download concurrency, gapless, queue persistence, offline mode), widget tests per page, integration test (`app_flow_test.dart`).
- CI: analyze + test + debug APK on every PR; pinned action SHAs; bot-commit filtering; release workflows for alpha + Windows + Pages.

**❌ Bad**
- No test covers the reported bugs: no test plays a **downloaded queue offline**, no test asserts next-track auto-advance latency, no test for bloc/native queue sync after recommendations. The exact failure modes you hit are untested.
- Golden tests exist but tolerance comparator (`tolerant_golden_comparator.dart`) suggests flaky goldens were papered over rather than fixed.
- `flutter`/`dart` aren't available in this sandbox, so I could not re-run the suite — treat prior "699 passed / 4 failed" numbers as unverified until CI confirms.

**➕ Needs adding**
- Regression tests: (1) offline queue of downloaded songs plays end-to-end; (2) `_onAddRecommendations` keeps native queue in sync; (3) `loadQueue` with local paths builds `AudioSource.uri`, not `YouTubeAudioSource`.
- A playback-latency benchmark test (the repo has `playback_benchmark_matrix.dart` — wire it into CI).

**📌 TODO**
- Fix the 4 midnight-boundary `date_grouping` failures noted in the prior audit.

**🔮 Future**
- On-device playback E2E (emulator) in CI; provider-mock contract tests so resolver changes can't silently break playback.

---

## 3. Prioritized fix list

| # | Fix | Files | Effort | Impact |
|---|---|---|---|---|
| 1 | Detect local paths before YouTube classification in `loadQueue`/`addToQueue`/`appendToQueue`; use `Uri.file()` | `audio_player_service.dart` | S | 🔴 Fixes offline downloads |
| 2 | Resolve local paths for **all** queue entries in `_loadAudioQueueSafe`, not just current | `player_bloc.dart:2158` | S | 🔴 Fixes offline queue |
| 3 | Sync native queue when recommendations append (`appendToQueue` call) | `player_bloc.dart:2009` | S | 🔴 Fixes "back to first song" desync |
| 4 | Pre-resolve next 2–3 tracks and inject URLs into queued sources (or pre-warm manifests) | `player_bloc.dart`, `media_resolver_service.dart` | M | 🔴 Fixes slow next-track |
| 5 | Race resolvers in parallel (`Future.any`) instead of sequential fallback | `stream_loader_service.dart:192` | M | 🟠 Fixes slow first play |
| 6 | Watchdog for stuck native queue tracks (index changed, never `playing` → skip/re-resolve) | `player_bloc.dart` (`_onIndexChanged`) | M | 🟠 Fixes "next song never comes" |
| 7 | Surface playback errors to the user (snackbar + "skipped" notice) | `player_bloc.dart`, UI | S | 🟠 UX |
| 8 | Delete or finish `PlaybackBloc`/`QueueBloc` split; remove dead repo stream path | `player_bloc/`, `music_repository_impl.dart` | M | 🟡 Maintainability |
| 9 | Fix `isDownloaded(song.id)` → `playableId` inconsistencies; stable download key | `player_bloc.dart:835,843`, `download_service.dart` | S | 🟡 Correctness |
| 10 | Regression tests for bugs 1–3 | `test/` | M | 🟡 Prevents recurrence |
| 11 | Encrypt Hive or correct privacy docs; MediaStore for downloads | storage layer | L | 🟡 Security honesty |
| 12 | Error states on 10 pages; semantics labels; split `settings_page.dart` | presentation | M | 🟢 Polish |

---

## 3b. Implementation status of fixes 1–6

Fixes 1–6 were implemented after this audit, one commit each (identified here by subject, since hashes change when a branch is rebased or merged):

| # | Status | Commit | What was done / how it differs from the table above |
|---|---|---|---|
| 1 | ✅ Done | `fix(player): detect local file paths before YouTube classification in queue loading` | Shared `_isLocalPath` / `_uriForUrl` helpers; local files are checked **before** the YouTube branch in `addToQueue`, `loadQueue` and `appendToQueue` and built with `Uri.file`. |
| 2 | ✅ Done | `fix(player): resolve downloaded file paths for every queue entry` | `_loadAudioQueueSafe` looks up every entry in the download store, not just the current song. |
| 3 | ✅ Done | `fix(player): sync native queue when recommendations are appended` | `_onAddRecommendations` appends to the native queue (when one is active) so the two queues stay in lock-step. |
| 4 | ✅ Done (manifest pre-warm variant) | `fix(player): pre-warm stream manifests for upcoming queue tracks` | Uses the "or pre-warm manifests" alternative via the previously unused `YouTubeAudioSource.prewarmCache`. The warm window slides with every index change, starts only after the current track is ready, honours the *prefetch lookahead* setting, and skips local files, entries that already carry a URL, non-YouTube ids and offline mode. **Limit:** it only helps YouTube-id tracks. A queued track with a non-YouTube id and no URL is not helped here; fix 6 recovers it. |
| 5 | ✅ Done (hedged race, not bare `Future.any`) | `fix(streaming): race stream resolvers with a staggered hedge` | A bare `Future.any` would drop JioSaavn's priority and distort the per-source circuit breakers. Instead the best resolver runs alone for 2 s; a slow one is joined by the next, a failing one is replaced immediately, and the first stream wins. An explicit `preferredResolverName` keeps strict ordering. Losers' outcomes still feed the circuit breakers. **Trade-off:** if JioSaavn takes longer than ~2 s, YouTube can win the race, so that track may be served from YouTube instead of JioSaavn. |
| 6 | ✅ Done | `fix(player): add a watchdog for queue tracks that never start playing` | 15 s one-shot timer armed in `_onIndexChanged`; a stall is routed through the existing `_handlePlaybackError` policy (fresh re-resolve, bounded retries, then skip under the existing cap). |

**How these were verified.** The sandbox has no Flutter/Dart SDK and no pub.dev access, so `flutter analyze` / `flutter test` could not be run locally. Every edited Dart file was parsed with a tree-sitter Dart grammar and compared with its pre-change version (no new syntax errors), the type-level details were checked by hand against the surrounding code and the shared test fakes, and regression tests were added for fixes 5 and 6. **CI is the authoritative check.** Fixes 1–4 have no automated tests yet; that remains item 10 in the table above.

---

## 4. Bottom line

Prism Music is a **well-architected, genuinely ambitious app** — the fallback chain, circuit breaker, generation guards, and download validation show real engineering care, and the test suite is far above typical indie-app coverage. The three bugs you hit are not random flakiness; they are **structural consequences of two design decisions**: (1) queue-mode tracks are never pre-resolved, so every transition pays a full lazy manifest fetch; and (2) local files and YouTube tracks share one `videoId`-based classifier that misroutes downloads. Fix #1–#4 above and the app's core promise — "search, stream, go offline, keep playing" — will actually hold end to end.

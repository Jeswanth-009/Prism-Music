# Prism Music — Comprehensive Application & Codebase Audit Report

**Date of Audit:** November 15, 2026  
**App Version:** `0.2.90+126`  
**Flutter SDK Target:** Flutter 3.38+ / Dart 3.9+  
**Target Operating Systems:** Android (API 24–36), iOS, macOS, Windows  
**Audit Scope:** 100% of codebase covering Core Services, Data Sources & Remote APIs, Domain Layer, BLoC State Management, Presentation UI/UX (23 Pages & 40+ Widgets), Security & Privacy Boundary, Platform Manifests/Configurations, and Automated Test Suites.

---

## Table of Contents

1. [Executive Summary & System Health](#1-executive-summary--system-health)
2. [Categorized Code & Architectural Breakdown](#2-categorized-code--architectural-breakdown)
   - 2.1 [Core Audio & Playback Engine](#21-core-audio--playback-engine)
   - 2.2 [Data Sources & Remote APIs](#22-data-sources--remote-apis)
   - 2.3 [BLoC State Management & Lifecycle](#23-bloc-state-management--lifecycle)
   - 2.4 [UI, UX, Pages & Design System](#24-ui-ux-pages--design-system)
   - 2.5 [Storage, Backup & Offline Pipeline](#25-storage-backup--offline-pipeline)
   - 2.6 [Platform Integrations & Manifests](#26-platform-integrations--manifests)
   - 2.7 [Automated Test Suite & Quality Assurance](#27-automated-test-suite--quality-assurance)
3. [Fixes Needed to be Done (Prioritized)](#3-fixes-needed-to-be-done)
   - 3.1 [High Priority Fixes](#31-high-priority-fixes)
   - 3.2 [Medium Priority Fixes](#32-medium-priority-fixes)
   - 3.3 [Low Priority Fixes](#33-low-priority-fixes)
4. [Security & Privacy Vulnerabilities (Prioritized)](#4-security--privacy-vulnerabilities)
   - 4.1 [High Priority Security Fixes](#41-high-priority-security-fixes)
   - 4.2 [Medium Priority Security Fixes](#42-medium-priority-security-fixes)
   - 4.3 [Low Priority Security Fixes](#43-low-priority-security-fixes)
5. [Incomplete Features & TODO Backlog (Prioritized)](#5-incomplete-features--todo-backlog)
   - 5.1 [High Priority Incomplete Features](#51-high-priority-incomplete-features)
   - 5.2 [Medium Priority Incomplete Features](#52-medium-priority-incomplete-features)
   - 5.3 [Low Priority Incomplete Features](#53-low-priority-incomplete-features)
6. [Future Features & Strategic Roadmap (Prioritized)](#6-future-features--strategic-roadmap)
   - 6.1 [High Strategic Value](#61-high-strategic-value)
   - 6.2 [Medium Strategic Value](#62-medium-strategic-value)
   - 6.3 [Low Strategic Value](#63-low-strategic-value)
7. [Prioritized Remediation Roadmap](#7-prioritized-remediation-roadmap)

---

## 1. Executive Summary & System Health

Prism Music is an advanced, privacy-focused, zero-login music streaming application built using Flutter with Clean Architecture and BLoC. It is designed around resilient multi-provider streaming (YouTube Explode, YouTube Music API, JioSaavn, Piped, Invidious), synchronized lyrics (LRCLIB), audio normalization, smart recommendations, local offline storage, and peer-to-peer playlist collaboration.

### Verification Baseline
- **Static Analysis:** `flutter analyze` reports `0 issues found`.
- **Automated Test Results:** `699 tests passed`, `4 tests failed` (all 4 failures isolated to midnight timestamp boundaries in `date_grouping.dart`).
- **Dependencies:** 1 discontinued package (`palette_generator: 0.3.3+7`), 1 overridden package (`permission_handler_android: 13.0.1`), 102 upgradable dependencies.
- **Architecture Integrity:** Clean separation across domain, data, and presentation layers; however, remnants of incomplete refactorings (e.g. `PlaybackBloc` and `QueueBloc` coexisting unused alongside `PlayerBloc`) exist in presentation.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        PRISM MUSIC SYSTEM MAP                          │
├────────────────────────────────────────────────────────────────────────┤
│ Presentation:  23 Pages, 42 Widgets, 4 BLoCs (Player, Library, Search) │
│ Core Services: 32 Services (Audio, DLNA Cast, WearOS, Video, Sync)    │
│ Data Layer:    7 Remote Datasources (YT, Jio, Spotify, Apple, Lyrics)  │
│ Storage:       Hive Key-Value (Profiles, History, Downloads, Metadata) │
│ Platforms:     Android (API 36), iOS, macOS, Windows                   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Categorized Code & Architectural Breakdown

### 2.1 Core Audio & Playback Engine
- **Implementation:** `AudioPlayerService` wrapping `just_audio` and `audio_service` (`PrismAudioHandler`).
- **Strengths:** 
  - Bulletproof local streaming via `YouTubeAudioSource` (`StreamAudioSource`), eliminating proxy ports and Range request drops.
  - Multi-client YouTube resolution fallback chain (`androidSdkless` -> `android` -> `ios` -> `mweb`).
  - Native equalizer, bass boost, and reverb integration via platform channel `com.prismmusic/audio_effects`.
  - Sleep timer with bedtime fading volume curves.
- **Weaknesses:**
  - `MusicVideoPlayer` operates independently from `AudioPlayerService`, resulting in double audio when video mode is active.
  - Native audio effects state is dropped whenever Android recreates the audio session ID.
  - Audio normalization relies on static hardcoded LUFS estimates per provider rather than real EBU R128 or ReplayGain metadata.

### 2.2 Data Sources & Remote APIs
- **Implementation:** `YouTubeMusicDataSource`, `YtMusicApiService`, `JioSaavnDataSource`, `SpotifyDataSource`, `AppleMusicDataSource`, `LyricsDataSource`.
- **Strengths:**
  - Robust 3DES decryption for JioSaavn encrypted media URLs.
  - Intelligent match confidence scoring (`MatchConfidenceEngine`) preventing wrong recording substitutions.
  - Resilient LRCLIB synchronized lyrics with local caching and `lyrics.ovh` fallback.
- **Weaknesses:**
  - JioSaavn metadata relies on an unmonitored third-party free Vercel deployment (`jiosaavn-api-privatecvc2.vercel.app`).
  - Apple Music playlist songs are tagged with `MusicSource.spotify` because `MusicSource.appleMusic` does not exist in domain entities.
  - `ChartService` does not fetch authentic charts; it executes search queries and fabricates rank numbers.

### 2.3 BLoC State Management & Lifecycle
- **Implementation:** `PlayerBloc`, `LibraryBloc`, `SearchBloc`, `ThemeBloc`.
- **Strengths:**
  - Droppable pagination transformers and debouncing (`_droppablePagination`, `_restartableDebounce`) in `SearchBloc`.
  - Generation guards (`_searchGeneration`, `_recommendationGeneration`) preventing stale async race conditions.
- **Weaknesses:**
  - `PlayerBloc` is an oversized god-class (2,428 lines).
  - `PlaybackBloc` (13KB) and `QueueBloc` (15KB) are instantiated in DI and forwarded events, but no UI widget listens to them.

### 2.4 UI, UX, Pages & Design System
- **Implementation:** 23 Pages, glassmorphism theme (`PrismTheme`), responsive layouts (`AdaptiveLayout`).
- **Strengths:**
  - Responsive layout adapts cleanly from mobile portrait to landscape and tablet navigation rails.
  - Three distinct player layouts: Default Modern, Classic, and Vinyl Turntable.
  - Smooth 60fps animations with `ReducedMotion` accessibility awareness.
- **Weaknesses:**
  - Several collection headers lack direct search/filter fields within playlists.
  - High dependency on discontinued `palette_generator` for album art dominant color extraction.

### 2.5 Storage, Backup & Offline Pipeline
- **Implementation:** Hive boxes with user profile isolation (`UserProfileService`), `LocalBackupService`, `DownloadService`.
- **Strengths:**
  - Restored backup paths are strictly canonicalized via `DownloadPathGuard` and `resolveSymbolicLinksSync` (mitigating S01).
  - Schema boundaries: 50MB file size, 10-level depth, and 10,000 array item caps.
  - Automatic on-device backups surviving uninstall.
- **Weaknesses:**
  - `LocalDataSourceImpl._getSettingsBox()` returns the temporary song cache box, risking settings erasure on cache clear.
  - P2P QR/URL playlist deserialization lacks decompression length bounds (potential gzip bomb).

### 2.6 Platform Integrations & Manifests
- **Android:** Manifest properly declared with foreground media playback, Android Auto descriptor, Home screen widget provider. However, exported broadcast receivers lack permissions.
- **iOS:** Missing `CFBundleURLTypes` for custom `prism://` scheme; missing `NSLocalNetworkUsageDescription` required for local SSDP DLNA casting on iOS 14+.
- **macOS:** Entitlements properly include `network.client`.

### 2.7 Automated Test Suite & Quality Assurance
- **Coverage:** 194+ test files containing 703 total test cases.
- **Status:** 699 passed, 4 failed.
- **Analysis of Failures:** The 4 failures in `test/widgets/history_grouping_test.dart` are all caused by a calendar-crossing edge case in `date_grouping.dart` when tests execute within 2 hours of midnight.

---

## 3. Fixes Needed to be Done

### 3.1 High Priority Fixes

#### FIX-01: Midnight-Crossing Timestamp Misclassification & Test Failures
- **Location:** `lib/core/utils/date_grouping.dart:11-55`
- **Root Cause:** `DateGrouping.getPeriodLabel` and `formatRelativeTime` rely on `dateTime.day == now.day` and `Duration(days: 1)`. When the current time is between 00:00 and 02:00, any song played 20 minutes earlier (at 23:45 the previous calendar day) has `dateTime.day != now.day`, causing it to be labeled as `"Yesterday, 11:45 PM"` or `"This week"` instead of `"20m ago"` or `"Today"`.
- **Impact:** Fails 4 automated tests in `test/widgets/history_grouping_test.dart` and produces confusing chronological sections on `RecentlyPlayedPage`.
- **Remediation:**
  ```dart
  // In lib/core/utils/date_grouping.dart
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.isNegative || diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago'; // Check elapsed hours before calendar day!
    
    final yesterdayDate = DateTime(now.year, now.month, now.day - 1);
    if (dateTime.year == yesterdayDate.year &&
        dateTime.month == yesterdayDate.month &&
        dateTime.day == yesterdayDate.day) {
      return 'Yesterday, ${DateFormat('h:mm a').format(dateTime)}';
    }
    // ...
  }
  ```

#### FIX-02: DLNA / UPnP Casting Hardcoded Control URLs Fail on Real Speakers
- **Location:** `lib/core/services/cast_service.dart:201-209, 260-264`
- **Root Cause:** `CastService` hardcodes `/upnp/control/AVTransport` and `/upnp/control/RenderingControl`. Standard UPnP devices (Samsung Smart TVs, LG webOS, Sonos, Bose, Yamaha) specify dynamic control paths in their XML device descriptors (e.g. `/AVTransport/control`, `/upnp/control/rendctrl1`).
- **Impact:** Casting audio to home wireless speakers fails with HTTP 404 or connection rejection.
- **Remediation:** On receiving an SSDP discovery packet with a `Location` header, send an HTTP GET to the device description XML, parse `<serviceType>urn:schemas-upnp-org:service:AVTransport:1</serviceType>`, and dynamically extract the `<controlURL>`.

#### FIX-03: Android Network Security Policy Blocks All DLNA Local Casting
- **Location:** `android/app/src/main/res/xml/network_security_config.xml:6-8`
- **Root Cause:** The config enforces `<base-config cleartextTrafficPermitted="false" />`. DLNA / UPnP home audio devices communicate solely over local cleartext HTTP. Android OS blocks every outgoing SOAP request to `http://192.168.x.x`.
- **Impact:** DLNA wireless speaker casting is completely broken on Android.
- **Remediation:**
  ```xml
  <network-security-config>
      <base-config cleartextTrafficPermitted="false" />
      <!-- Permit local LAN cleartext traffic for DLNA speaker casting & local party server -->
      <domain-config cleartextTrafficPermitted="true">
          <domain includeSubdomains="true">127.0.0.1</domain>
          <domain includeSubdomains="true">localhost</domain>
          <domain includeSubdomains="true">10.0.2.2</domain>
      </domain-config>
      <base-config>
          <trust-anchors>
              <certificates src="system" />
          </trust-anchors>
      </base-config>
  </network-security-config>
  ```

#### FIX-04: Fabricated Chart Rankings Disguised as Official Billboard Top 50
- **Location:** `lib/core/services/chart_service.dart:123-189`
- **Root Cause:** Scrapers for Billboard and Spotify charts are hard-disabled. All charts fall back to executing YouTube search queries (e.g. `'billboard hot 100 top songs 2026'`), taking the first 25 search results, and displaying them in `ChartPage` with artificial ordinal ranks `#1..#25`.
- **Impact:** Deceives users into believing YouTube search results represent official Billboard/Spotify chart rankings.
- **Remediation:** Either integrate verified public chart feeds (such as daily Spotify Charts CSV or verified Billboard RSS) or re-label the section from "Official Charts" to "Trending Discovery Mixes" and eliminate the misleading `#1..#25` ranking badges.

#### FIX-05: Double-Audio Playback Echo in Music Video Player
- **Location:** `lib/presentation/widgets/player/music_video_player.dart:66-85`
- **Root Cause:** `MusicVideoPlayer` initializes a `VideoPlayerController` streaming muxed audio/video. The underlying `AudioPlayerService` continues playing the audio track simultaneously through `just_audio`.
- **Impact:** Severe out-of-sync audio echo when streaming music videos.
- **Remediation:** When video mode is activated, pause `AudioPlayerService` (or set its volume to `0.0`) and seek the video to the audio player's current position. On exiting video mode, seek the audio player to the video position and resume.

---

### 3.2 Medium Priority Fixes

#### FIX-06: Redundant Parallel BLoC Architectures Running Concurrently
- **Location:** `lib/presentation/blocs/player/playback_bloc.dart`, `queue_bloc.dart`, `player_bloc.dart`
- **Issue:** `PlaybackBloc` and `QueueBloc` were introduced during a refactoring attempt to split `PlayerBloc`. However, all pages and widgets still listen directly to `PlayerBloc`. `PlaybackBloc` and `QueueBloc` are registered in GetIt, initialized, and forward events, but their states are completely ignored.
- **Remediation:** Complete the refactoring by delegating UI consumption to the modular BLoCs, or delete the dead BLoCs and consolidate logic within `PlayerBloc`.

#### FIX-07: Missing `MusicSource.appleMusic` Domain Entity Enum
- **Location:** `lib/domain/entities/song.dart:4-11`, `lib/data/datasources/remote/apple_music/apple_music_datasource.dart:247, 343, 387`
- **Issue:** Songs imported from Apple Music playlists are tagged with `MusicSource.spotify` because `MusicSource.appleMusic` does not exist in domain entities.
- **Remediation:** Add `appleMusic` to `MusicSource` enum in `song.dart` and update mappers.

#### FIX-08: RSS Podcast Feed `pubDate` Parsing Failure
- **Location:** `lib/core/services/podcast_service.dart:118`
- **Issue:** RSS 2.0 feeds use RFC 2822 dates (`"Tue, 14 Nov 2026 12:00:00 +0000"`). `DateTime.tryParse` only accepts ISO 8601, returning `null` for all podcast episodes.
- **Remediation:** Use `DateFormat('EEE, dd MMM yyyy HH:mm:ss Z', 'en_US')` from package `intl` to correctly parse publication dates.

#### FIX-09: Android Native Audio Effects Dropped on Audio Session Change
- **Location:** `android/app/src/main/kotlin/.../MainActivity.kt:45-54`, `lib/core/services/equalizer_service.dart`
- **Issue:** When the Android audio engine changes sessions, `MainActivity.kt` releases existing effects but never re-applies the user's active bass boost, treble, and reverb levels to the new session.
- **Remediation:** Cache active levels in `MainActivity` and automatically re-apply them whenever `initialize` receives a new session ID.

#### FIX-10: Local Settings Box Collision with Song Cache Box
- **Location:** `lib/data/datasources/local/local_datasource.dart:959-962`
- **Issue:** In `LocalDataSourceImpl`, `_getSettingsBox()` returns `_getCacheBox()`. Calling `clearCache()` wipes out settings stored through `LocalDataSource`.
- **Remediation:** Allocate a distinct Hive box `'local_settings'` for settings persistence.

#### FIX-11: JioSaavn Metadata Depends on Single Free Public Endpoint
- **Location:** `lib/data/datasources/remote/jiosaavn/jiosaavn_datasource.dart:49`
- **Issue:** Metadata lookups point to `https://jiosaavn-api-privatecvc2.vercel.app`, an unmonitored community deployment subject to downtime and rate limiting.
- **Remediation:** Add direct fallback parsing against JioSaavn's public JSON API (`www.jiosaavn.com/api.php`).

#### FIX-12: Missing Request Headers on Direct Podcast Streams
- **Location:** `lib/core/services/media_resolver_service.dart:67-74`
- **Issue:** `ResolvedMediaSource` passes `headers: null` for direct podcast URLs. Podcast CDNs (NPR, Libsyn, BBC) return 403 Forbidden when requests lack a valid `User-Agent`.
- **Remediation:** Supply `'User-Agent': 'PrismMusic/1.0'` by default on all direct media requests.

---

### 3.3 Low Priority Fixes

#### FIX-13: Discontinued `palette_generator` Dependency
- **Location:** `pubspec.yaml:70`, `lib/presentation/pages/player_page.dart:5`
- **Issue:** Package `palette_generator 0.3.3+7` is discontinued by Flutter.
- **Remediation:** Replace with `color_thief_flutter` or implement a lightweight native platform color extractor.

#### FIX-14: Hardcoded App Version in Crash Reporting Service
- **Location:** `lib/core/services/crash_reporting_service.dart:25, 46`
- **Issue:** `CrashReport` defaults `appVersion` to `'0.2.83'` instead of dynamic `PackageInfo`.
- **Remediation:** Obtain version from `PackageInfo.fromPlatform()`.

#### FIX-15: Missing iOS Deep Link URL Schemes
- **Location:** `ios/Runner/Info.plist`
- **Issue:** `prism://playlist` deep links work on Android but fail on iOS due to missing `CFBundleURLTypes`.
- **Remediation:** Add `<key>CFBundleURLTypes</key>` declaring `prism` in `ios/Runner/Info.plist`.

#### FIX-16: Desktop Window Title Stale on Pause
- **Location:** `lib/main.dart:252-260`
- **Issue:** When playback is paused on desktop, window title continues displaying playing status.
- **Remediation:** Format window title as `'Prism Music (Paused)'`.

---

## 4. Security & Privacy Vulnerabilities

### 4.1 High Priority Security Fixes

#### SEC-01: Exported Wear OS BroadcastReceiver Lacks Permission Checks (Local IPC Hijacking)
- **File:** `android/app/src/main/kotlin/com/prismmusic/prism_music/wear/WearOsBridge.kt:73-77`
- **Vulnerability:** The receiver is registered with `Context.RECEIVER_EXPORTED` with no custom permissions or caller verification.
- **Threat Model:** Any rogue app installed on the user's Android phone can broadcast actions (`com.prismmusic.wear.ACTION_SET_VOLUME`, `ACTION_SEEK`, `ACTION_PAUSE`, `ACTION_PLAY`) to manipulate playback or crank volume to maximum without permission.
- **Remediation:**
  ```kotlin
  // In AndroidManifest.xml
  <permission
      android:name="com.prismmusic.app.permission.WEAR_CONTROL"
      android:protectionLevel="signature" />
  
  // In WearOsBridge.kt
  if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
      context.registerReceiver(
          receiver,
          filter,
          "com.prismmusic.app.permission.WEAR_CONTROL",
          null,
          Context.RECEIVER_EXPORTED
      )
  }
  ```

#### SEC-02: Stored Cross-Site Scripting (XSS) in Party Mode Web Client
- **File:** `lib/core/services/collaborative_queue_service.dart:429-430`
- **Vulnerability:** In the embedded HTTP web template, search results are rendered into the DOM using `item.innerHTML = ... \${s.title} ...`.
- **Threat Model:** A track with a crafted title (e.g., from YouTube or JioSaavn) containing `<img src=x onerror=...>` will execute arbitrary JavaScript on the browsers of all guests connected to the local party mode.
- **Remediation:** Use `textContent` instead of `innerHTML`, or HTML-entity escape all song metadata prior to DOM insertion:
  ```javascript
  const titleDiv = document.createElement('div');
  titleDiv.textContent = s.title; // Safe against XSS
  ```

---

### 4.2 Medium Priority Security Fixes

#### SEC-03: Party Mode PIN Leaked via Unauthenticated Endpoint
- **File:** `lib/core/services/collaborative_queue_service.dart:149, 408-410`
- **Vulnerability:** Visiting `/api/session` returns the host's party PIN in plaintext JSON (`'pin': _pin`), which the web client autofills.
- **Threat Model:** Anyone on the local network can bypass the PIN barrier and spam the host's queue.
- **Remediation:** Remove `'pin'` from the `/api/session` payload. Require guests to enter the 4-character PIN visually displayed on the host's phone screen.

#### SEC-04: Unbounded Memory Decompression in P2P Playlist Sharing (Gzip Bomb)
- **File:** `lib/core/services/playlist_collaboration_service.dart:84-98`
- **Vulnerability:** `decodePlaylistPayload` accepts raw base64 data and decompresses gzip without size bounds.
- **Threat Model:** A crafted compressed payload can unpack into hundreds of megabytes in memory, triggering an `OutOfMemoryError` crash.
- **Remediation:** Limit input string length to 256 KB and wrap decompression in a bounded byte stream enforcing a 5 MB maximum decompressed limit and 1,000 track limit.

#### SEC-05: Unauthenticated GitHub API Rate Limiting on Update Checks
- **File:** `lib/core/services/app_update_service.dart:45-46, 96-102`
- **Vulnerability:** Direct unauthenticated requests to GitHub API (`/repos/Jeswanth-009/Prism-Music/releases`).
- **Threat Model:** Users behind shared NAT IP addresses (universities, corporate offices) will trigger GitHub's 60 req/hr rate limit, causing update checks to fail.
- **Remediation:** Point update checks to a static JSON manifest hosted on GitHub Pages or Cloudflare Workers.

---

### 4.3 Low Priority Security Fixes

#### SEC-06: Missing iOS Local Network Permission Declaration
- **File:** `ios/Runner/Info.plist`
- **Vulnerability:** Lacks `NSLocalNetworkUsageDescription`.
- **Threat Model:** On iOS 14+, SSDP multicast scanning (`239.255.255.250`) and hosting the local party server will trigger OS-level permission denials.
- **Remediation:** Add `NSLocalNetworkUsageDescription` with an explanatory message to `Info.plist`.

---

## 5. Incomplete Features & TODO Backlog

### 5.1 High Priority Incomplete Features
1. **Chromecast V2 Protocol Implementation (`lib/core/services/cast_service.dart:303-307`):**
   - Currently a stub setting `CastState.connected` without opening a TLS socket on port 8009 or communicating with the Cast Default Media Receiver.
2. **Remote Playlist Pagination (`lib/presentation/pages/remote_playlist_page.dart`):**
   - Playlists with more than 100 tracks do not load continuation tokens when scrolling to the bottom.
3. **Canonical Artist Discography & Follow Action (`lib/presentation/pages/artist_page.dart:326`):**
   - The heart follow button has an empty callback, and albums are derived from search instead of the artist's official discography browse channel.

### 5.2 Medium Priority Incomplete Features
1. **Podcast Episode Playback Progress Sync (`lib/core/services/podcast_service.dart:207-215`):**
   - Playback position is saved to Hive in utility methods, but `PlayerBloc` does not automatically update podcast progress during playback.
2. **Download Queue Pause and Resume (`lib/core/services/download_service.dart`):**
   - `DownloadStatus.paused` exists in the enum, but no pause/resume methods exist in `DownloadService`.
3. **Lyrics Tap-to-Seek & Manual Offset Adjustment (`lib/presentation/widgets/player/player_lyrics_sheet.dart`):**
   - Tapping a lyric line does not seek the audio player; missing `+/- 500ms` sync adjustment slider.
4. **Equalizer Custom Presets Export (`lib/presentation/widgets/equalizer/equalizer_bottom_sheet.dart`):**
   - Custom user EQ presets are stored locally in Hive but omitted from portable JSON backups.

### 5.3 Low Priority Incomplete Features
1. **Sleep Timer Non-Linear Fade Curves (`lib/presentation/blocs/player/mixins/sleep_timer_mixin.dart`):**
   - Volume fades strictly linearly; needs logarithmic/exponential easing option.
2. **In-Playlist Search & Sorting (`lib/presentation/pages/playlist_detail_page.dart`):**
   - Missing search query filter and alphabetical/chronological sorting within user playlists.

---

## 6. Future Features & Strategic Roadmap

### 6.1 High Strategic Value

#### FEAT-01: Local Device Audio Library Indexer (Full Device Scan)
- **Concept:** Index audio files stored on the device's physical storage and SD card (MP3, FLAC, AAC, WAV) via Android `MediaStore` and iOS/Desktop file pickers.
- **Strategic Impact:** Transforms Prism Music into a complete hybrid player, seamlessly uniting a user's offline file collection with cloud streaming in a single unified library.

#### FEAT-02: Predictive Offline Intelligent Cache-Ahead
- **Concept:** Automatically cache the user's Top 25 most played tracks and active playlist favorites in the background when connected to Wi-Fi and charging.
- **Strategic Impact:** Eliminates playback drops when commuting, entering subways, or losing mobile connectivity.

#### FEAT-03: Real ITU-R BS.1770 / EBU R128 Loudness Normalization
- **Concept:** Replace the heuristic provider-based LUFS table with actual peak/RMS analysis or parse embedded ReplayGain ID3 tags.
- **Strategic Impact:** Audiophile-grade volume consistency across vintage dynamic recordings and modern loud pop masters.

---

### 6.2 Medium Strategic Value

#### FEAT-04: Looping Synced Video Canvas Backgrounds
- **Concept:** Stream lightweight looping canvas visuals (similar to Spotify Canvas) behind player controls when available.
- **Strategic Impact:** Modern visual engagement matching premium commercial streaming platforms.

#### FEAT-05: Desktop Mini-Player & System Tray Daemon
- **Concept:** Enable closing to the system tray on Windows, macOS, and Linux with a floating mini-player controller.
- **Strategic Impact:** Essential workflow tool for desktop power users.

#### FEAT-06: Android Auto MediaBrowserService Hierarchy
- **Concept:** Implement full structured browsable trees for Playlists, Liked Songs, and Downloaded Tracks on Android Auto dashboards.
- **Strategic Impact:** Safe, native vehicular media browsing.

---

### 6.3 Low Strategic Value

#### FEAT-07: Year-in-Review & Listening Habit Analytics ("Prism Wrapped")
- **Concept:** Generate shareable visual cards showing top genres, artists, and listening hour distribution based on the 90-day history database.
#### FEAT-08: Customizable OpenGL / Skia Shader Visualizers
- **Concept:** Offer selectable visualizer styles (Retro Wave, Neon Bars, Audio Oscilloscope) on the player screen.

---

## 7. Prioritized Remediation Roadmap

```
PHASE 1: Immediate Critical Fixes & Security Hardening
├── [SEC-01] Add signature permission to WearOsBridge BroadcastReceiver
├── [SEC-02] Sanitize HTML inputs in Party Mode web template to stop XSS
├── [FIX-03] Declare cleartext exceptions in network_security_config.xml for DLNA
├── [FIX-05] Mute/pause main audio player when MusicVideoPlayer is active
└── [FIX-01] Fix midnight rolling hour logic in DateGrouping utility

PHASE 2: Content Trust & Incomplete Capabilities
├── [FIX-04] Relabel ChartService to "Discovery Mixes" or integrate real chart APIs
├── [FIX-02] Fetch UPnP device description XML in CastService for valid control URLs
├── [FIX-07] Add MusicSource.appleMusic enum and update mappers
└── [FIX-08] Fix RFC 2822 date parsing in PodcastService

PHASE 3: Architectural Cleanup & Platform Alignment
├── [FIX-06] Consolidate or fully wire PlaybackBloc / QueueBloc
├── [FIX-09] Re-apply native audio effects on Android session recreation
├── [SEC-04] Enforce 5MB/1000-track limit on P2P playlist decompression
└── [FIX-15] Add iOS URL schemes in Info.plist
```


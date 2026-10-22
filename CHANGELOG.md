# Changelog

All notable changes to Prism Music are documented here, one entry per automated alpha release.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versions are `MAJOR.MINOR.PATCH` with the Flutter build number recorded per release. Every release below links to its GitHub prerelease page, which carries the signed APK, AAB and SHA-256 checksums.

## [Unreleased]

_Nothing yet._

## [0.2.49] - 2026-10-22

### Changed

- Add modular provider architecture guide, isolation tests and issue templates

## [0.2.48] - 2026-10-22

### Added

- Streamline first-use search and playback with honest permission disclosures

## [0.2.47] - 2026-10-22

### Added

- Add portable backup export/import with merge reconciliation and restored identity

## [0.2.46] - 2026-10-22

### Added

- Add explainable reasons, language preferences, not-interested feedback and queue autoplay toggle

## [0.2.45] - 2026-10-22

### Added

- Add release playback benchmark matrix and diagnostics runner

## [0.2.44] - 2026-10-22

### Added

- Add comprehensive build diagnostics, source links, licenses, and support details
- Bundle Inter typography locally and unify media fallback artwork
- Enhance tap-to-seek, fine-grained manual offset controls, and auto-follow toggle
- Implement temporal grouping and per-query deletion for search and listening history
- Add rename, song reordering, search filtering, and m3u/json export UI

### Changed

- Set cross-platform font rasterization tolerance to 5% for Linux CI
- Update reference snapshots for bundled Inter typography and unified artwork

## [0.2.43] - 2026-10-22

### Added

- Expand backup management with import, export, status, and deletion controls
- Provide accurate cache accounting and granular storage cleanup
- Add interactive unmatched-track reconciliation and visible import cancellation dialog
- Support full remote playlist pagination and infinite scroll loading
- Implement download retry, cancellation notifications, and storage state reconciliation
- Add user-configurable secure credentials, validation tests, and disabled states
- Accurately represent audio transition with smooth fade curves and settings alignment
- Implement selectable Classic and Modern player layouts in PlayerPage
- Persist favorite artists in local storage with reactive library synchronization
- Implement search pagination and incremental result loading in SearchBloc

### Fixed

- Preserve active Hive database and lock files during cache cleanup
- Resolve static analysis warnings and unused declarations
- Improve accessibility with touch targets, text scaling, and theme contrast
- Align listening session metrics and enforce consistent history retention
- Enforce persistent mini-player across all collection and detail routes
- Enforce true end-of-track sleep timer stopping and update timer UI indicators
- Bind native equalizer and audio session on playback initiation and persist presets
- Persist layout mode in SettingsService and unify settings ownership

### Changed

- Update search mock signature and refresh golden baselines for mini-player

## [0.2.42] - 2026-10-21

### Added

- Safe backup restore controls, structured verification and trustworthy persistence feedback (M21, M22, M25)
- Durable imported playlists, source refresh identity and matching summary (F07, M16)
- Honestly relabel search-based charts as curated discovery mixes with authentic provenance (F05)
- Complete all-filter search navigation, unified queueing and robust album playback (F09, F10)

### Fixed

- Prevent grid card horizontal layout overflow on small devices
- Enforce reliable play/pause/stop concurrency and visible error recovery (F01, F02, F03)
- Respect requested audio quality and resolve genuine match confidence

### Changed

- Stage tag publication after build verification and enforce APK integrity regression gates (M31, M32)

## [0.2.41] - 2026-10-14

### Added

- Implement uncapped playlist import, ISRC resolution, review sheet & cancellation (M16)

## [0.2.40] - 2026-10-14

### Added

- Add glassmorphic audio provenance badge, diagnostics sheet & manual source switcher
- Support manual stream source override and prioritized resolver execution

### Fixed

- Eliminate fake lossless badges and permanent fast-start quality degradation (M08)

## [0.2.39] - 2026-10-14

### Added

- Unify stream caching with StreamCacheService to resolve dual-cache desync (M06)

## [0.2.38] - 2026-10-14

### Added

- Implement pluggable stream resolvers and mid-playback 403 stream expiry auto-recovery
- Eliminate nested fallback loops and introduce dynamic instance health engine
- Implement match confidence engine, audio provenance & negative lyrics caching

## [0.2.37] - 2026-10-14

### Added

- Introduce centralized locale-aware formatters for dates, counts, and sizes (L04)
- Redesign showcase into dual-pane stage with feature cards and full-screen lightbox
- Elevate landing page with live interactive audio demo, bento grid, and showcase

### Fixed

- Enhance a11y, keyboard screenshot navigation, release tag parsing, and reduced motion (L11)
- Dispose dialog text controllers and guard async setState calls (L05)
- Eliminate duplicate queue-source append in AudioPlayerService (L02)
- Resolve mobile layout breakdown, prevent horizontal overflow, and polish responsive drawer
- Resolve comparison table layout, restore release notes banner and changelog feed

### Changed

- Decouple HomePage tabs with tabBuilders and resolve test timeout
- Lazily construct IndexedStack tabs and eliminate redundant full-screen blur shader (L12)
- Output reviewable image diffs on failure and tighten golden tolerance (L10)
- Align security versions, stream timeouts, and background playback docs with implementation (L09)
- Remove obsolete proxy startup scripts and cleanup find-ip instructions (L08)
- Consolidate collection headers and standardize song rows with overflow actions (L06, L07)
- Improve Album and Playlist equality semantics and copyWith sentinel clearing (L03)
- Remove unused AudioDownloaderService and CobaltDataSource (L01)
- Hide background prism beam illustration behind phone on mobile screens
- Modernize README with feature matrix, architecture diagram, and badges

## [0.2.36] - 2026-10-11

### Fixed

- Seed queue with single song so recommendation service appends new tracks

## [0.2.35] - 2026-10-11

### Added

- Add history retention notices, stats semantics, and transparent onboarding disclosures
- Add error recovery banner, stream format badge, and persistent controls in lyrics mode
- Expose song metadata and album artwork in download transfer queue
- Enhance charts, library import flow, and playlist detail robustness
- Preserve full playback queue and add pagination progress indicator
- Compact editorial hero and deduplicate continue-listening recommendations
- Dock bottom navigation bar and add reliable bottom insets
- Add PrismCollectionHeader and enhance PrismSongTile with overflow actions
- Add spacing tokens, pill radius, reduced motion, and safe sheet scrolling

### Fixed

- Remove unused constants in home_page and unused import in test

## [0.2.34] - 2026-10-11

### Added

- Add tap-to-seek, sync correction, and manual scroll toggle for lyrics
- Preserve regional scripts, strengthen artist confidence, and enhance cache identity

## [0.2.33] - 2026-10-10

### Added

- Refine stats, settings, and onboarding pages with theme-aware contrast and retention disclosures
- Enhance search taxonomy, charts hub text resilience, and remote playlist saving
- Overhaul liked songs, playlists, recently played, and downloads with persistent mini-player and actions
- Upgrade navigation bar with opaque background, accessibility semantics, and focus contract

### Fixed

- Resolve single-track repeat socket EOF and queue loop-around (RepeatMode.one & all)

## [0.2.32] - 2026-10-09

### Fixed

- Add startup recovery, macos entitlements, monotonic versioning, and release gates (M27-M32)
- Version hive schema, serialize writes, accurate stats, backup sync, and cache clean (M21-M26)
- Reuse resolved streams, atomic files, live download queue, and offline UX (M17-M20)
- Refine search state, typed ytmusic parser, artist browse identity, new releases, and spotify import (M11-M16)
- Add autoplay setting, fix sleep timer track completion, seek dragging, and theme palette (M07, M09, M10, M33)
- Enforce resolution budget, circuit breakers, cache policy, and quality labels (M05, M06, M08)
- Bind native equalizer session, correct treble units, fix crossfade and audio focus (M01-M04)

### Changed

- Update README with audio engine, offline resilience, and architectural enhancements

## [0.2.31] - 2026-10-08

### Fixed

- Resolve playback lifecycle, command concurrency, native errors, and queue coherence (F01, F02, F03, F08)
- Route album browse IDs to native album API instead of playlist endpoint (F10)
- Score and validate stream candidates to prevent mismatch (F04)
- Relabel search fallbacks as discovery mixes and prevent fake ranks (F05)
- Resolve partial load failures and durably persist imported playlists (F06, F07)
- Prevent filter state race condition on query submission (F09)
- Preserve regional Unicode scripts during text normalization (F11)

## [0.2.30] - 2026-10-08

### Changed

- Run OSV scanner via standalone binary in security scan job

## [0.2.29] - 2026-10-08

### Fixed

- Fail closed on unsigned release builds and skip publish (S02)

### Changed

- Fix workflow action commit SHAs with verified commit hashes
- Add PRIVACY.md and qualify privacy claims in README and website (S13)
- Pin actions and Flutter version, scope permissions, add SBOM, provenance and OSV scans (S12)

## [0.2.28] - 2026-10-07

### Added

- Secure session storage and dart-define credential gating (S10)
- Private-by-default storage with opt-in shared copy (S03)

### Fixed

- Request notification, storage and battery permissions just-in-time (S11)
- Strip queries and disable verbose logging in release builds (S05)
- Exact-host validation for links and redirects (S09)
- Enforce HTTPS-only traffic via network security config (S04)
- Validate schema, size and count limits on restore and imports (S06)
- Sanitize download filenames and validate stream URLs (S07)
- Restrict deletions to app-owned roots (S01)

### Changed

- Remove unused StreamProxyService (S08)

## [0.2.27] - 2026-10-01

### Added

- Brand spectrum, real screenshots, gallery, live GitHub data and copy fixes

### Changed

- Generate release notes and update CHANGELOG automatically
- Rebuild CHANGELOG from release history
- Redesign README with banner and framed screenshots

## [0.2.26] - 2026-10-01

### Changed

- Tolerate cross-platform font rasterization diffs

## [0.2.25] - 2026-10-01

### Changed

- Move waitFor into shared helpers, temp-dir Hive for remaining suites
- Testing guide with device matrix and manual release checklist
- Search → play → background → next-track flow
- Dark/light golden coverage at common phone sizes
- Cover player, library, search, charts, home and lyrics
- Shared fakes plus library, search, theme and services coverage

## [0.2.24] - 2026-10-01

### Added

- Stale-safe lyrics sheet with retry, refresh and attribution
- Robust LRCLIB matching with normalization and local cache
- Import music playlists, mixes and bare playlist IDs

## [0.2.23] - 2026-09-30

### Fixed

- Write library backup to public storage so it survives uninstall

## [0.2.22] - 2026-09-30

### Fixed

- Sign releases with a stable keystore so updates install

## [0.2.21] - 2026-09-30

### Fixed

- Make the Auto Shuffle setting actually shuffle
- Correct labels, restore dialog state, drop dead dialogs

## [0.2.20] - 2026-09-30

### Added

- Richer charts hub and chart page
- Show playlist cover art and richer playlist pages

### Fixed

- Fetch playlist tracks via Invidious when youtube_explode comes up empty
- Refresh imported playlists instead of duplicating them
- Harden playlist storage ids, removals and persistence

## [0.2.18] - 2026-09-30

### Fixed

- Persist imported playlists and await import completion
- Match imported Spotify tracks in parallel and keep metadata
- Parse playlists from public embed pages so import works

### Changed

- Clean up analyzer warnings in yt music service and tests

## [0.2.17] - 2026-09-20

### Fixed

- Preserve media notification in release builds

## [0.2.16] - 2026-09-19

### Fixed

- Skip blocked streams without duplicate fallback

## [0.2.15] - 2026-09-19

### Fixed

- Prevent device crash and restore media notification

## [0.2.14] - 2026-09-19

### Fixed

- Media cards overflowed rails by 19px at playback

## [0.2.13] - 2026-09-19

### Fixed

- Adaptive compact action indices prevents play crash

## [0.2.12] - 2026-09-19

### Changed

- Drop invalid administration permission and self-enablement
- Self-enable GitHub Pages on first deploy

## [0.2.11] - 2026-09-19

### Added

- Marketing landing page + GitHub Pages deploy

### Fixed

- Remove merge conflict markers left in pubspec.yaml
- Reliable skip/retry on failing songs + working media notification

### Changed

- Prepare version 0.2.11+47

## [0.2.10] - 2026-09-16

### Fixed

- Resolve search failure and fix recommendation flow from search

## [0.2.9] - 2026-09-16

### Fixed

- Serve fresh recommendations instead of stale search results

### Changed

- Pass commit message to release script via env, not interpolation

## [0.2.8] - 2026-09-15

### Added

- Personalise the albums rail from listening rotation

## [0.2.7] - 2026-09-15

### Added

- Experience depth — stats page, dynamic accent, onboarding

## [0.2.6] - 2026-09-15

### Added

- P2 playback polish — sleep timer, real treble, quality + crossfade + cache

### Changed

- Rewrite README to match current app and pipeline

## [0.2.5] - 2026-09-15

### Added

- P1 gaps — song actions, playlist import, theme persistence, remote playlists

## [0.2.4] - 2026-09-15

### Added

- Personalised rails, album releases, hero shuffle

### Changed

- Merge branch 'main' of https://github.com/Jeswanth-009/Prism-Music

## [0.2.3] - 2026-09-15

### Added

- Full Material 3 UI revamp — clean artwork-first design

### Changed

- Fix release failing on already-existing version tag
- Merge branch 'main' of https://github.com/Jeswanth-009/Prism-Music

## [0.2.2] - 2026-09-13

### Added

- Add Charts hub, Aurora theme backdrops, and refine navigation

## [0.2.1] - 2026-09-13

### Changed

- Redesign UI with artwork-led Prism shell and immersive experiences

## [0.2.0] - 2026-09-13

### Added

- Redesign Prism Music navigation, visual system, library, search, and player

## [0.1.43] - 2026-09-13

### Fixed

- Prevent recommendation starvation and auto-advance playback on failure

## [0.1.42] - 2026-09-02

### Added

- Overhaul Similar and Discover recommendation systems

## [0.1.41] - 2026-08-26

### Added

- Modernize queue UI and fix workflow loop guard

### Changed

- Simplify workflow bot filter
- Fix workflow loop guard logic

## [0.1.40] - 2026-08-26

### Fixed

- Prevent stream loader from hanging on JioSaavn api timeouts

## [0.1.39] - 2026-08-24

### Changed

- Completely modernize and restructure the settings page

## [0.1.38] - 2026-08-24

### Fixed

- Correctly parse numeric durations from YouTube Music API

## [0.1.37] - 2026-08-24

### Fixed

- Address critical and high priority UI audit findings

## [0.1.36] - 2026-08-23

### Fixed

- Resolve 403 download error and UI glitches

## [0.1.35] - 2026-08-23

### Fixed

- Use getByName for debug signing config

## [0.1.34] - 2026-08-23

### Added

- App-wide glassmorphic UI overhaul and stable alpha signing

## [0.1.33] - 2026-08-23

### Added

- Implement dynamic CDN fallback rotation

## [0.1.32] - 2026-08-23

### Added

- Integrate JioSaavn as primary streaming backend

## [0.1.31] - 2026-08-22

### Fixed

- Prioritize unthrottled ratebypass streams for uninterrupted playback without 403

## [0.1.30] - 2026-08-22

### Fixed

- Bypass web watch page rate limits by setting requireWatchPage: false

## [0.1.29] - 2026-08-22

### Fixed

- Restore pure high-bitrate audio streaming and throttle prefetching

## [0.1.28] - 2026-08-22

### Fixed

- Select unthrottled ratebypass streams to fix ExoPlayer 403 playback error

## [0.1.27] - 2026-08-22

### Fixed

- Invalidate cache on playback 403 and enable audio fallback resolution
- Add missing import for PipedDataSource
- Switch to androidSdkless client and add Piped fallback to restore audio playback

## [0.1.26] - 2026-08-22

### Fixed

- Remove undefined 'web' YoutubeApiClient to resolve compilation error
- Update YouTube clients to bypass bot detection

## [0.1.25] - 2026-08-22

### Fixed

- Restore correct Android namespace to prevent ClassNotFoundException on startup

## [0.1.24] - 2026-08-22

### Fixed

- Set compileSdk to 36 for backward compatibility with older Flutter plugins

## [0.1.23] - 2026-08-22

### Fixed

- Pin permission_handler_android below v14 to maintain AGP 8.x compatibility

## [0.1.22] - 2026-08-22

### Fixed

- Revert to AGP 8.9.1 and Gradle 8.12.1 to fix Flutter SDK NullPointerException

## [0.1.21] - 2026-08-22

### Fixed

- Remove kotlin-android plugin because AGP 9.0+ uses built-in Kotlin

## [0.1.20] - 2026-08-22

### Fixed

- Entirely disable Android Lint globally to prevent third-party plugin crashes

## [0.1.19] - 2026-08-22

### Fixed

- Disable Android Lint on CI to prevent JVM compatibility crash

## [0.1.18] - 2026-08-22

### Fixed

- Resolve compileSdk, NDK version, and IconData final class errors

## [0.1.17] - 2026-08-22

### Fixed

- Upgrade to AGP 9.3.0 and Gradle 9.5.0

## [0.1.16] - 2026-08-22

### Fixed

- Revert AGP and Kotlin to stable versions (8.9.1 and 2.1.0)

## [0.1.15] - 2026-08-22

### Fixed

- Restore working gradle version and skip CI dependency checks

## [0.1.14] - 2026-08-22

### Fixed

- Resolve remaining CI warnings and ambiguous imports

## [0.1.13] - 2026-08-22

### Fixed

- Permanently resolve all CI analyze failures + AGP version

## [0.1.12] - 2026-08-22

### Fixed

- Resolve all CI analyze errors and Gradle version requirement

## [0.1.11] - 2026-08-22

### Fixed

- Resolve CI failures — dependency conflicts and deprecated action versions

## [0.1.10] - 2026-08-22

### Added

- Auto-versioning + song info dialog + local data fixes
- Add library stats, recently played, backups, and release versioning
- Auto-publish alpha release with guaranteed APK asset

### Fixed

- Auto-version workflow defaults to patch bump
- Add ignore battery optimizations permission for background audio
- Background audio playback stops when screen off / app backgrounded

### Changed

- Overhaul CI/CD pipeline — auto-version, conflict-free APK builds, audio service migration
- Bump pubspec version metadata to fix Android build-number parsing in CI
- Update app version and refine YouTube Music service, repository, and player page integration
- Audio and YouTube Music integration; improve player, settings, and repository layers
- Add vulnerability reporting policy

## [0.1.0] - 2026-04-06

_Initial public alpha. ([release](https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.0-build6))_

### Added
- GitHub Actions CI workflow for analyze, test, and debug APK artifact generation.
- GitHub Actions alpha release workflow for tagged prereleases with APK/AAB + checksum artifacts.
- MIT License and contribution guide for open-source readiness.
- Optional Android signed release support through GitHub Secrets.
- GitHub issue templates and pull request template for collaboration quality.
- README media placeholders, badges, feature comparison table, and roadmap table.

### Changed
- Set app version baseline to 0.1.0+6 for the next alpha build.
- Updated release workflow to auto-publish alpha prereleases on main pushes with APK always attached.

[Unreleased]: https://github.com/Jeswanth-009/Prism-Music/compare/alpha-v0.2.26-build62...HEAD
[0.1.0]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.0-build6
[0.1.10]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.10-build2
[0.1.11]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.11-build3
[0.1.12]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.12-build4
[0.1.13]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.13-build5
[0.1.14]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.14-build6
[0.1.15]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.15-build7
[0.1.16]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.16-build8
[0.1.17]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.17-build9
[0.1.18]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.18-build10
[0.1.19]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.19-build11
[0.1.20]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.20-build12
[0.1.21]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.21-build13
[0.1.22]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.22-build14
[0.1.23]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.23-build15
[0.1.24]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.24-build16
[0.1.25]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.25-build17
[0.1.26]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.26-build18
[0.1.27]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.27-build19
[0.1.28]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.28-build20
[0.1.29]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.29-build21
[0.1.30]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.30-build22
[0.1.31]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.31-build23
[0.1.32]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.32-build24
[0.1.33]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.33-build25
[0.1.34]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.34-build26
[0.1.35]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.35-build27
[0.1.36]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.36-build28
[0.1.37]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.37-build29
[0.1.38]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.38-build30
[0.1.39]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.39-build31
[0.1.40]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.40-build32
[0.1.41]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.41-build33
[0.1.42]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.42-build34
[0.1.43]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.1.43-build35
[0.2.0]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.0-build36
[0.2.1]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.1-build37
[0.2.2]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.2-build38
[0.2.3]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.3-build39
[0.2.4]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.4-build40
[0.2.5]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.5-build41
[0.2.6]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.6-build42
[0.2.7]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.7-build43
[0.2.8]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.8-build44
[0.2.9]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.9-build45
[0.2.10]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.10-build46
[0.2.11]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.11-build47
[0.2.12]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.12-build48
[0.2.13]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.13-build49
[0.2.14]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.14-build50
[0.2.15]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.15-build51
[0.2.16]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.16-build52
[0.2.17]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.17-build53
[0.2.18]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.18-build54
[0.2.20]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.20-build56
[0.2.21]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.21-build57
[0.2.22]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.22-build58
[0.2.23]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.23-build59
[0.2.24]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.24-build60
[0.2.25]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.25-build61
[0.2.26]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.26-build62
[0.2.27]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.27-build63
[0.2.28]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.28-build64
[0.2.29]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.29-build65
[0.2.30]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.30-build66
[0.2.31]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.31-build67
[0.2.32]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.32-build68
[0.2.33]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.33-build69
[0.2.34]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.34-build70
[0.2.35]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.35-build71
[0.2.36]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.36-build72
[0.2.37]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.37-build73
[0.2.38]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.38-build74
[0.2.39]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.39-build75
[0.2.40]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.40-build76
[0.2.41]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.41-build77
[0.2.42]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.42-build78
[0.2.43]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.43-build79
[0.2.44]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.44-build80
[0.2.45]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.45-build81
[0.2.46]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.46-build82
[0.2.47]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.47-build83
[0.2.48]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.48-build84
[0.2.49]: https://github.com/Jeswanth-009/Prism-Music/releases/tag/alpha-v0.2.49-build85

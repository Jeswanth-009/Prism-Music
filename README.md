# Prism Music

[![CI](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/ci.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/ci.yml)
[![Alpha Release](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/release-alpha.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/release-alpha.yml)
[![Auto Version](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/auto-version.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/auto-version.yml)
[![Latest Alpha](https://img.shields.io/github/v/release/Jeswanth-009/Prism-Music?include_prereleases&label=latest%20alpha&color=purple)](https://github.com/Jeswanth-009/Prism-Music/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)

Open-source, privacy-first music streaming app built with Flutter.

Prism Music streams from YouTube Music (with Spotify/JioSaavn bridges), needs
no account, keeps your library on-device, and ships as an automated alpha
release on every push to `main`.

## Alpha Status

- Stage: Early alpha — breaking changes can happen between builds
- Primary target: Android (APK/AAB from every release run)
- Current version: see the [latest release](https://github.com/Jeswanth-009/Prism-Music/releases) or `pubspec.yaml`

## Screenshots

Placeholder frames while real screenshots are collected from alpha devices:

| Home | Player | Search |
| --- | --- | --- |
| ![Home](docs/media/home-placeholder.svg) | ![Player](docs/media/player-placeholder.svg) | ![Search](docs/media/search-placeholder.svg) |

## Why Prism Music Is Different

Most mainstream music apps are optimized around account lock-in and
platform-owned funnels. Prism Music is intentionally engineered with a
different set of priorities:

- **No login for the core flow** — search, play, like, download, all local
- **Local-first backup** — your library and history survive reinstall without any cloud account
- **Fallback-first reliability** — search, recommendations, and playback have multi-path safety nets
- **Performance-first playback** — stream caching and prefetch (lookahead) built into the resolve path
- **Open pipeline** — CI, release automation, and architecture docs are public from alpha

## Features

- **Material 3 interface** — artwork-first design with a single accent, Inter
  typography, light/dark themes (persisted across restarts), skeleton
  loaders, and unified empty/error states
- **Home** — continue-listening hero with shuffle, jump back in, personalized
  *Recommended for you* rail (similar-artists or discover mode), new albums,
  trending, charts, and curated mood mixes
- **Search** — songs, artists, albums, and playlists, with real album detail
  pages and remote playlist detail pages
- **Player** — dominant-color ambient background, tap-through to a synced
  lyrics view with auto-scroll, editable queue (reorder / remove / clear /
  play next), shuffle and repeat
- **Song actions everywhere** — long-press any song for play next, queue,
  add to playlist, like, download, and share
- **Library** — liked songs, recently played, downloads, playlists with
  create/delete, and a listening-stats overview
- **Playlist import** — bring Spotify or YouTube playlist links into Prism
- **Offline** — download songs and play them without a connection
- **Equalizer** — presets, bass boost, and reverb, applied through the
  native audio effects channel
- **Last.fm scrobbling** — optional account link (see [LASTFM_SETUP.md](LASTFM_SETUP.md))

## What Has Been Done So Far

| Area | Completed Work | Current Outcome |
| --- | --- | --- |
| Architecture | Layered core/data/domain/presentation design with DI and BLoC | Clean separation and testability |
| UI | Full Material 3 revamp: token-based theme (`PrismSpec`), Inter type, shared prism widget library, single song-actions sheet | Calm, artwork-led interface; shadcn_ui removed entirely |
| Lyrics | Synced lyrics via LRCLIB with line highlight and auto-scroll (`scrollable_positioned_list`) | Built-in lyrics without third-party UI |
| Albums & playlists | Album detail pages, remote playlist pages, create/delete playlist, add-to-playlist, Spotify/YouTube import | Full browse-and-collect loop |
| Search | YT Music service and mapper pipeline with fallback handling | Resilient on parser edge cases |
| Recommendations | Mode-aware service (similar / discover) with taste profile and fallbacks | Personalized rails on Home |
| Playback | Stream loader, cache strategy, prefetch lookahead, reliability hardening (retry + circuit breaker) | Fast repeat play and stable streaming |
| Streaming backend | Custom JioSaavn bridge with 3DES decryption and CDN fallback | Reliable high-bitrate streams, downloads without bot-blocking |
| Library & data | On-device likes, playlists, history, stats, and uninstall-surviving backup | Private, durable library |
| Open source | CI/CD, changelog, license, contributing docs | Public, reproducible alpha delivery |

## Known Limitations (Alpha)

- Crossfade duration and audio-quality selection dialogs are not yet wired to
  the audio engine
- "Clear cache" does not yet delete cached streams
- Treble control in the equalizer is a placeholder
- Android-first; iOS/desktop are untested

## Roadmap

| Milestone | Status | Scope |
| --- | --- | --- |
| Material 3 UI revamp | Done | Design system, home, search, library, player, lyrics |
| P1 feature gaps | Done | Song actions, playlist import, theme persistence, remote playlists |
| Playback polish | Next | Real crossfade, audio-quality selection, sleep timer, treble, cache management |
| Experience depth | Planned | Full stats page, app-wide dynamic accent color, onboarding |
| Beta readiness | Planned | Regression pass, quality gates, iOS evaluation |

## Architecture Overview

Prism Music follows a layered structure:

- **Presentation**: pages, widgets, BLoCs
- **Domain**: entities and repository contracts
- **Data**: repository implementations and data sources
- **Core**: DI, services, mappers, utilities

High-level pipelines:

- Search: UI → SearchBloc → MusicRepository → YT Music service → mappers → UI
- Playback: PlayerBloc → media resolver → stream loader/cache → audio engine
- Recommendations: PlayerBloc (recordPlay) → RecommendationService → repository fallbacks → Home rails

## Tech Stack

- Flutter + Dart (Material 3)
- State: flutter_bloc, bloc, equatable, rxdart
- DI: get_it, injectable
- Audio: just_audio, audio_service, audio_session, just_audio_background
- Sources: dart_ytmusic_api, youtube_explode_dart, darttubefix, dio
- Persistence: hive_flutter
- UI utilities: cached_network_image, google_fonts (Inter), palette_generator, scrollable_positioned_list

## Project Structure

```text
lib/
  core/            # DI, services (audio, downloads, lyrics, recs), mappers, utils
  data/            # repository impls + remote/local data sources
  domain/          # entities (Song, Album, Artist, Playlist, Lyrics, ...)
  presentation/
    blocs/         # player, search, library, theme
    pages/         # home, search, library, player, albums, playlists, settings...
    theme/         # design tokens (PrismColors, PrismSpec, radius, motion)
    widgets/       # shared prism/ component library + feature widgets
```

## Getting Started

### Prerequisites

- Flutter stable SDK (recommended: 3.38.4+)
- Android SDK with an emulator or device
- Android Studio or VS Code

### Install & run

```bash
flutter pub get
flutter run
```

### Build

```bash
flutter build apk --debug
flutter build apk --release
```

## CI/CD and Release Automation

### CI — `.github/workflows/ci.yml`

Runs on push and pull requests: `pub get`, `analyze`, `test`, debug APK build,
artifact upload.

### Auto Version + Release — `.github/workflows/auto-version.yml`

Runs on every push to `main` (skips doc-only changes and its own bot commits):

1. Reads the version from `pubspec.yaml`
2. If that version's tag already exists, bumps the version
   (`patch` by default; `[minor]` / `[major]` in the commit message force
   bigger bumps)
3. Commits the bump, tags `alpha-v<version>-build<build>`, pushes the tag
4. Builds release APK and AAB with matching `versionName`/`versionCode`
5. Publishes a GitHub prerelease with APK, AAB, and SHA-256 checksums

### Manual / tag re-builds — `.github/workflows/release-alpha.yml`

Re-builds and re-publishes when you push an `alpha-v*` tag, or run it manually
from the Actions tab (adds a `-run<N>` suffix so tags never collide).

### Release signing (optional)

Signing is enabled automatically when these repository secrets are set:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_PASSWORD`

Without secrets, builds fall back to debug signing.

## Versioning Strategy

Prism Music uses the Flutter version format:

```text
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

The Android `versionCode` is **generated automatically** from the number of
git commits (`git rev-list --count HEAD`) in `android/app/build.gradle.kts`,
with the `pubspec.yaml` build number kept as a safety floor. Consequences:

- You do **not** need to manually bump build numbers — every push produces a
  higher `versionCode`, so updates install in-place without uninstalling.
- Automatic releases use the tag format `alpha-v<version>-build<build>`,
  where both parts come from `pubspec.yaml`.
- Keep `MAJOR` at 0 during the unstable phase; bump the visible version name
  only when you want a new release label (or let the bot do it — see above).

### Publishing a release

Just push to `main`. The bot handles the bump, tag, build, and prerelease.
To force a bigger version, include `[minor]` or `[major]` in your commit
message.

## Collaboration

- Bug report template: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Feature request template: `.github/ISSUE_TEMPLATE/feature_request.yml`
- PR template: `.github/pull_request_template.md`
- Security policy: [SECURITY.md](SECURITY.md)

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution expectations.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [STREAM_ARCHITECTURE.md](STREAM_ARCHITECTURE.md)
- [BACKEND_INTEGRATION.md](BACKEND_INTEGRATION.md)
- [LASTFM_SETUP.md](LASTFM_SETUP.md)
- [CHANGELOG.md](CHANGELOG.md)
- [PRISM_MUSIC_DOCUMENTATION.md](PRISM_MUSIC_DOCUMENTATION.md)
- [MUSIC_APPS_DOCUMENTATION.md](MUSIC_APPS_DOCUMENTATION.md)
- [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)

## License

MIT License. See [LICENSE](LICENSE).

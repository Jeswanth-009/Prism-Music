# Prism Music

[![CI](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/ci.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/ci.yml)
[![Alpha Release](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/release-alpha.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/release-alpha.yml)
[![Auto Version](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/auto-version.yml/badge.svg)](https://github.com/Jeswanth-009/Prism-Music/actions/workflows/auto-version.yml)
[![Latest Alpha](https://img.shields.io/github/v/release/Jeswanth-009/Prism-Music?include_prereleases&label=latest%20alpha&color=purple)](https://github.com/Jeswanth-009/Prism-Music/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-brightgreen.svg)](LICENSE)
[![Version](https://img.shields.io/github/v/release/Jeswanth-009/Prism-Music?include_prereleases&label=version)](https://github.com/Jeswanth-009/Prism-Music/releases)

Open-source, privacy-first music streaming app built with Flutter.

Prism Music is in a very early alpha stage. Current work is focused on building a strong engineering base: reliable search, resilient playback, and recommendation quality, with transparent open-source development.

## Alpha Status

- Stage: Early alpha
- Current version: 0.1.1+7
- Primary target: Android
- Stability: Experimental, breaking changes may happen between alpha builds

## Screenshots and Demo

### Current placeholders

These placeholders keep README layout ready while real screenshots are collected from alpha devices.

| Home | Player | Search |
| --- | --- | --- |
| ![Home](docs/media/home-placeholder.svg) | ![Player](docs/media/player-placeholder.svg) | ![Search](docs/media/search-placeholder.svg) |

### GIF walkthrough

- Planned for next alpha documentation pass
- Target file path: docs/media/prism-alpha-demo.gif

## Why Prism Music Is Different

Most mainstream music apps are optimized around account lock-in and platform-owned funnels.
Prism Music is intentionally engineered with a different set of priorities.

### Core differentiators

- Privacy-first usage model with no mandatory login for core flow
- Local-first data backup: your library and history are backed up on-device and survive reinstall without any cloud account
- Fallback-first reliability for search, recommendations, and playback
- Performance-first playback path with cache and pre-resolve strategies
- Open architecture and public release automation from early alpha stage

## Feature Comparison

| Capability | Prism Music (Alpha) | Typical Music Apps |
| --- | --- | --- |
| Core usage without mandatory login | Yes | Usually no |
| Open-source code visibility | Yes | Usually no |
| Search fallback behavior | Typed parse plus raw fallback | Mostly single-path or opaque |
| Recommendation fallback behavior | Multi-path with safety net | Service-specific and closed |
| Stream startup optimization | Cache-first and pre-resolve aware | Varies by platform |
| Public release pipeline visibility | Yes, GitHub Actions | Often internal only |

## What Has Been Done So Far

| Area | Completed Work | Current Outcome |
| --- | --- | --- |
| Architecture | Layered core/data/domain/presentation design with DI and BLoC | Cleaner separation and maintainability |
| Search | YT Music focused service and mapper pipeline with fallback handling | Better resilience on parser edge cases |
| Recommendations | Multi-path recommendation flow with fallback logic | Reduced empty-state queue failures |
| Playback | Stream loader plus cache strategy and reliability hardening | Faster repeat play and improved stability |
| Library & data | On-device library (likes, playlists, history), listening stats, and a local backup that survives uninstall without cloud sync | Private, durable library across updates and reinstalls |
| Open source | CI/CD workflows, changelog, license, contributing docs | Public, reproducible alpha delivery |

## Public Roadmap

| Milestone | Target Date | Status | Scope |
| --- | --- | --- | --- |
| Alpha hardening wave 1 | 2026-04-20 | In progress | Analyzer cleanup, failure handling, test additions |
| Alpha hardening wave 2 | 2026-05-15 | Planned | Playback polish, diagnostics, recommendation refinements |
| Rich alpha baseline | 2026-06-30 | Planned | Library and playlist UX improvements |
| Beta readiness review | 2026-08-15 | Planned | Regression checks, quality gates, stabilization |
| v1.0 planning checkpoint | 2026-10-01 | Planned | Scope lock, privacy posture, release readiness |

Dates are target estimates and may move based on quality and contributor velocity.

## Architecture Overview

Prism Music follows a layered structure:

- Presentation: pages, widgets, BLoCs
- Domain: entities and contracts
- Data: repository implementations and data sources
- Core: DI, services, mappers, utilities

High-level pipelines:

- Search: UI -> SearchBloc -> MusicRepository -> YT Music service -> mapper -> UI
- Playback: PlayerBloc -> stream loader/cache -> audio engine
- Recommendations: PlayerBloc -> recommendation service -> repository fallback -> queue update

Deep architecture docs are listed later in this README.

## Tech Stack

- Flutter + Dart
- BLoC: flutter_bloc, bloc
- Dependency injection: get_it, injectable
- Audio stack: just_audio, audio_service, just_audio_background
- Networking/data: dart_ytmusic_api, youtube_explode_dart, dio
- Local persistence: hive

## Project Structure

```text
lib/
  core/
    di/
    mappers/
    services/
  data/
    datasources/
    repositories/
  domain/
    entities/
    repositories/
  presentation/
    blocs/
    pages/
    widgets/
```

## Getting Started

### Prerequisites

- Flutter stable SDK
- Recommended Flutter version: 3.38.4
- Android Studio or VS Code
- Android SDK and emulator/device

### Install

```bash
flutter pub get
```

### Run

```bash
flutter run
```

### Build

```bash
flutter build apk --debug
flutter build apk --release
```

## CI/CD and Release Automation

### CI workflow

File: .github/workflows/ci.yml

Runs on push and pull request:

- flutter pub get
- flutter analyze --no-fatal-infos --no-fatal-warnings
- flutter test
- flutter build apk --debug
- Upload debug APK artifact

### Alpha release workflow

File: .github/workflows/release-alpha.yml

Runs automatically on every push to main (and also supports manual tag pushes matching alpha-v*):

- Builds release APK and AAB
- Generates SHA-256 checksum files
- Fails the workflow if APK output is missing
- Uploads APK and AAB as workflow artifacts
- Publishes GitHub prerelease artifacts with APK attached every run
- Uses contents write permissions for release publishing

### Signed release support via GitHub Secrets

Release signing is automatically enabled when these repository secrets are set:

- ANDROID_KEYSTORE_BASE64
- ANDROID_KEY_ALIAS
- ANDROID_KEYSTORE_PASSWORD
- ANDROID_KEY_PASSWORD

When secrets are missing, workflow still builds using debug signing fallback.

## Versioning Strategy

Prism Music uses the Flutter version format:

```text
version: MAJOR.MINOR.PATCH+BUILD_NUMBER
```

The `BUILD_NUMBER` (Android `versionCode`) is **generated automatically** from the
number of git commits (`git rev-list --count HEAD`) in `android/app/build.gradle.kts`.
It is monotonic for both local `flutter run` and CI builds, which means:

- You do **not** need to manually bump the build number.
- Every push to `main` produces a new, higher `versionCode`, so updates install
  in-place instead of forcing an uninstall.
- The `+BUILD_NUMBER` in `pubspec.yaml` is only kept as a safety floor and is
  otherwise ignored for the Android build number.

Alpha guidance:

- Keep `MAJOR` at 0 during the unstable phase.
- Bump `MAJOR.MINOR.PATCH` (the visible version name) only when you want a new
  release label.
- Automated releases use the tag format:
  `alpha-v<version>-build<git-commit-count>-run<workflow-run>`.

## Publish Next Alpha

1. (Optional) Bump the `MAJOR.MINOR.PATCH` version name in `pubspec.yaml` if you
   want a new visible release label. Do **not** edit the `+BUILD_NUMBER` part —
   it is derived from git history automatically.
2. Commit and push to `main`.
3. The release-alpha workflow runs automatically and publishes a GitHub
   prerelease with APK and AAB assets. The build number increments on its own.

Optional manual trigger via tag (the build number is still auto-derived from git):

```bash
git tag alpha-v0.1.1
git push origin alpha-v0.1.1
```

4. Wait for the release-alpha workflow to publish the prerelease artifacts.

## Collaboration Workflow

- Bug report template: .github/ISSUE_TEMPLATE/bug_report.yml
- Feature request template: .github/ISSUE_TEMPLATE/feature_request.yml
- PR template: .github/pull_request_template.md
- Security policy: SECURITY.md

See CONTRIBUTING.md for contribution expectations.

## Documentation

- ARCHITECTURE.md
- STREAM_ARCHITECTURE.md
- BACKEND_INTEGRATION.md
- IMPLEMENTATION_SUMMARY.md
- PRISM_MUSIC_DOCUMENTATION.md
- MUSIC_APPS_DOCUMENTATION.md

## License

MIT License. See LICENSE.

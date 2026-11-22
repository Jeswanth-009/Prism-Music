# Backend Integration Guide

This project now uses a backend-agnostic playback path:

1. Map backend payloads to Song objects.
2. Dispatch PlaySongEvent(song: ...).
3. PlayerBloc asks MediaResolverService to resolve local/offline/online source.
4. AudioPlayerService plays with retry, focus policy, and optional crossfade handoff.

## Fast Start

Use this mapper for any provider payload:

- File: lib/core/mappers/backend_song_mapper.dart
- API: BackendSongMapper.fromMap(raw, source: MusicSource.youtubeMusic)

Example:

```dart
final song = BackendSongMapper.fromMap(
  rawPayload,
  source: MusicSource.youtubeMusic,
);

context.read<PlayerBloc>().add(
  PlaySongEvent(song: song),
);
```

## Required Song Fields

Populate these fields from your backend whenever possible:

- id
- title
- artist
- duration
- source
- youtubeId for YouTube-family sources
- jioSaavnId for JioSaavn sources
- streamUrl when backend already gives a valid playable URL

## Source-specific Playback

MediaResolverService contains source-aware branches:

- Local downloaded file preferred first.
- Direct streamUrl used when backend provides one.
- StreamLoader fallback for YouTube stream resolution + cache.
- Pre-resolve for next tracks is supported via preResolveSong/takePreResolved.

## Adding a New Provider

1. Build provider client/datasource.
2. Map payload to Song with MusicSource enum.
3. If provider supports direct stream URLs, set streamUrl in Song.
4. Optionally add a dedicated branch in MediaResolverService.resolveForPlayback.
5. Dispatch PlaySongEvent with mapped Song.

## Reliability Behavior

PlayerBloc now includes:

- Circuit breaker after repeated failures.
- Exponential backoff retries for online failures.
- Offline decode failure cleanup for corrupt local files.
- Audio focus and interruption handling in a single orchestration service.

## Make sure backend songs play

Checklist:

- Song.playableId must not be empty.
- Song.duration should be set.
- Song.source must be correct.
- youtubeId/jioSaavnId/streamUrl should be populated for your provider.
- If using local files, ensure the file exists and is valid audio.

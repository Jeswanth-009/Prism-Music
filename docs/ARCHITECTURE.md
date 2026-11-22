# Prism Music Architecture

## Overview

Prism Music follows a layered Flutter architecture:

- Presentation layer: pages, widgets, and BLoCs
- Domain layer: entities and repository contracts
- Data layer: repository implementations and data sources
- Core layer: DI, services, mappers, utilities, and cross-cutting concerns

The app is designed around resilient fallbacks:

- Search uses YT Music API with raw-response fallback parsing
- Recommendations use multiple strategies with graceful fallback
- Playback uses stream caching and retry/fallback paths for reliability

## Layered Design

## Presentation Layer

Responsibilities:

- Handle user input and UI state
- Dispatch events through BLoCs
- Render search results, playback controls, queue, and library

Key components:

- Search flow: SearchPage -> SearchBloc
- Player flow: PlayerPage/MiniPlayer -> PlayerBloc
- Library flow: LibraryPage -> LibraryBloc

## Domain Layer

Responsibilities:

- Define business entities and contracts
- Remain independent of API/provider details

Key contracts:

- MusicRepository
- LibraryRepository

Key entities:

- Song, Artist, Album, Playlist
- StreamInfo, Lyrics, Chart

## Data Layer

Responsibilities:

- Implement repository contracts
- Orchestrate remote and local data sources
- Convert external data to domain models

Primary implementation:

- MusicRepositoryImpl

Data sources:

- YouTubeMusicDataSource (youtube_explode_dart based)
- YtMusicApiService (dart_ytmusic_api wrapper)
- LocalDataSource (Hive)
- Optional providers (Spotify/JioSaavn/Lyrics)

## Dependency Injection

DI is configured with GetIt in the core DI module.

Wiring includes:

- Data sources and services
- Repositories
- BLoCs

This keeps constructors explicit and makes it straightforward to swap implementations.

## Runtime Pipelines

## Search Pipeline

1. User submits query in SearchPage.
2. SearchBloc calls MusicRepository.searchSongs/searchAll.
3. MusicRepositoryImpl delegates to YtMusicApiService.
4. YtMusicApiService attempts typed parser output first.
5. If empty/failing, service falls back to raw request parsing.
6. Mapper layer converts result maps to domain entities.
7. BLoC emits results to UI.

## Recommendation Pipeline

Two recommendation paths are active:

- Behavioral path (RecommendationService in player flow)
- Repository path (MusicRepository recommendations and related songs)

Behavioral path:

1. Player requests recommendations for current song.
2. RecommendationService builds context from listening history and taste profile.
3. Discovery/similar strategies generate multiple search queries in parallel.
4. Results are filtered, scored, and deduplicated.
5. If discovery yields empty output, fallback switches to similar mode.

Repository path:

1. getRelatedSongs first tries YT Music Up Next via YtMusicApiService.
2. If Up Next is empty, fallback uses YouTubeMusicDataSource.getRelatedSongs.
3. getRecommendations uses recent history seeds and merges related results.
4. If no useful related results exist, fallback returns trending songs.

Player safety net:

- If RecommendationService returns zero songs, PlayerBloc requests repository recommendations before giving up.

## Playback Pipeline

1. PlayerBloc receives a song to play.
2. StreamLoaderService resolves stream using cache-first strategy.
3. If needed, YouTubeMusicDataSource fetches manifest and selects best audio stream by quality.
4. Stream URL and metadata are cached.
5. AudioPlayerService/just_audio starts playback.
6. History and profile signals are updated for future recommendations.

## Caching Strategy

## Search Cache

- Query-level in-memory cache in YouTubeMusicDataSource
- Short TTL to reduce duplicate calls while preserving freshness

## Stream Cache

Two complementary caches are used:

- StreamLoaderService cache for quick replay and prefetch reuse
- YouTubeMusicDataSource stream cache keyed by videoId + quality

Stream cache validity checks include:

- TTL window
- URL expiry timestamp extracted from YouTube stream URL
- Safety buffer before expiry to avoid stale playback URLs

## Local Persistence

Hive-backed local storage is used for:

- Listening history
- Liked songs
- Search history
- Settings/profile snapshots

Listening history is central to personalization and recommendation quality.

## Fallback and Resilience Model

Search resilience:

- Typed parser -> raw parser fallback

Recommendation resilience:

- Discovery -> similar fallback
- Up Next -> related songs fallback
- Personalized -> trending fallback
- Player-level repository fallback if recommendation service returns empty

Playback resilience:

- Cache-first stream loading
- Retry behavior in stream resolution path
- Backup source attempts where available

## Key Design Decisions

- Keep domain clean and provider-agnostic
- Isolate external API shape changes inside service + mapper boundaries
- Prefer layered fallback over single-source failure
- Favor fast perceived playback through aggressive but safe stream caching
- Use BLoC and DI to keep logic testable and replaceable

## Core Files

- lib/core/di/injection.dart
- lib/core/services/ytmusic_api_service.dart
- lib/core/mappers/ytmusic_api_mappers.dart
- lib/core/services/recommendation_service.dart
- lib/core/services/stream_loader_service.dart
- lib/data/repositories/music_repository_impl.dart
- lib/data/datasources/remote/youtube/youtube_music_datasource.dart
- lib/data/datasources/local/local_datasource.dart
- lib/presentation/blocs/player/player_bloc.dart
- lib/presentation/blocs/search/search_bloc.dart

## Notes

- STREAM_ARCHITECTURE.md focuses deeply on streaming internals.
- This document is the system-level architecture view across search, recommendations, playback, and persistence.

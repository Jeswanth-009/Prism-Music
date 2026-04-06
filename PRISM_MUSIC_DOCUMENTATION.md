# Comprehensive Documentation: Prism Music

## Music Player Application - Complete Technical Analysis

---

# Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Technology Stack](#technology-stack)
4. [Music Sources & APIs](#music-sources--apis)
5. [Search Functionality](#search-functionality)
6. [Audio Playback System](#audio-playback-system)
7. [Stream Loading Architecture](#stream-loading-architecture)
8. [Playlist & Library Management](#playlist--library-management)
9. [Download & Offline Functionality](#download--offline-functionality)
10. [Recommendations System](#recommendations-system)
11. [Lyrics Integration](#lyrics-integration)
12. [Charts & Trending](#charts--trending)
13. [History & Recently Played](#history--recently-played)
14. [Settings & Preferences](#settings--preferences)
15. [Last.fm Integration](#lastfm-integration)
16. [Audio Effects & Equalizer](#audio-effects--equalizer)
17. [Dynamic Theming](#dynamic-theming)
18. [Data Storage & Persistence](#data-storage--persistence)
19. [Platform Support](#platform-support)
20. [UI/UX Architecture](#uiux-architecture)
21. [Dependency Injection](#dependency-injection)
22. [Error Handling & Resilience](#error-handling--resilience)
23. [Feature Summary Matrix](#feature-summary-matrix)

---

# Executive Summary

## Prism Music (v1.0.0)
**Description:** A privacy-first, high-fidelity music streaming application built with Flutter, offering seamless YouTube Music streaming with no login required.

**Tagline:** "A privacy-first, high-fidelity music streaming app with no login required."

**Key Highlights:**
- **No Login Required** - Stream music instantly without account creation
- **Privacy-First** - No tracking, no data collection, no ads
- **High-Fidelity Audio** - Support for lossless quality up to 320kbps (Opus)
- **Clean Architecture** - BLoC pattern with proper domain separation
- **Multi-Source Streaming** - YouTube Explode with Invidious fallback
- **Smart Prefetching** - Parallel stream loading with 5-hour cache
- **Last.fm Scrobbling** - Full integration for listening history tracking
- **Dynamic Theming** - Album art color extraction for immersive UI
- **Audio Equalizer** - Bass boost, reverb, and preset support
- **Cross-Platform** - Android, iOS, Windows, Linux, macOS support
- **Offline Mode** - Download songs for offline playback
- **Synced Lyrics** - LRC format support via LRCLIB

---

# Architecture Overview

## Clean Architecture Implementation

Prism Music follows **Clean Architecture** principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Flutter App                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                         Presentation Layer                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
│  │    Pages     │  │   Widgets    │  │    BLoCs     │  │   States     │    │
│  │  (5 screens) │  │              │  │ (5 blocs)    │  │   Events     │    │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘    │
├─────────────────────────────────────────────────────────────────────────────┤
│                           Domain Layer                                       │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────┐  │
│  │     Entities     │  │   Repositories   │  │       Use Cases          │  │
│  │ Song, Artist,    │  │   (Abstract)     │  │ Search, Player, Library  │  │
│  │ Album, Playlist  │  │                  │  │ Charts, Recommendations  │  │
│  └──────────────────┘  └──────────────────┘  └──────────────────────────┘  │
├─────────────────────────────────────────────────────────────────────────────┤
│                            Data Layer                                        │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                         Repositories (Impl)                           │  │
│  │  MusicRepositoryImpl            │    LibraryRepositoryImpl            │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────┐  ┌───────────────────────────────────┐  │
│  │      Remote Data Sources      │  │       Local Data Sources          │  │
│  │ ┌──────────────────────────┐ │  │ ┌─────────────────────────────┐   │  │
│  │ │ YouTubeMusicDataSource   │ │  │ │   LocalDataSourceImpl       │   │  │
│  │ │ InvidiousDataSource      │ │  │ │   (Hive Database)           │   │  │
│  │ │ SpotifyDataSource        │ │  │ └─────────────────────────────┘   │  │
│  │ │ LyricsDataSource         │ │  │                                    │  │
│  │ └──────────────────────────┘ │  └───────────────────────────────────┘  │
│  └───────────────────────────────┘                                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                           Core Services                                      │
│  ┌────────────────┐ ┌────────────────┐ ┌────────────────┐ ┌──────────────┐ │
│  │AudioPlayerSvc  │ │StreamLoaderSvc │ │StreamCacheSvc  │ │ChartService  │ │
│  │EqualizerSvc    │ │DownloadSvc     │ │RecommendSvc    │ │SettingsSvc   │ │
│  │LastFmService   │ │YouTubeStreamSvc│ │PermissionSvc   │ │             │ │
│  └────────────────┘ └────────────────┘ └────────────────┘ └──────────────┘ │
├─────────────────────────────────────────────────────────────────────────────┤
│                        Dependency Injection (GetIt)                          │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │  Global Service Locator - Lazy Singleton & Factory Registration       │  │
│  └──────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
lib/
├── main.dart                    # App entry point with initialization
├── core/                        # Core utilities and services
│   ├── constants/               # App-wide constants
│   ├── di/                      # Dependency injection setup
│   │   └── injection.dart       # GetIt service locator config
│   ├── error/                   # Failure classes for error handling
│   ├── models/                  # Core data models
│   │   └── reverb_preset.dart   # Audio effect presets
│   ├── network/                 # Network configuration
│   ├── services/                # Core application services
│   │   ├── audio_player_service.dart
│   │   ├── audio_effects_channel.dart
│   │   ├── chart_service.dart
│   │   ├── download_service.dart
│   │   ├── equalizer_service.dart
│   │   ├── lastfm_service.dart
│   │   ├── permission_service.dart
│   │   ├── recommendation_service.dart
│   │   ├── settings_service.dart
│   │   ├── stream_cache_service.dart
│   │   ├── stream_loader_service.dart
│   │   ├── stream_proxy_service.dart
│   │   ├── youtube_audio_source.dart
│   │   └── youtube_stream_service.dart
│   ├── theme/                   # Theme configuration
│   └── utils/                   # Utility functions & logger
├── data/                        # Data layer
│   ├── datasources/
│   │   ├── local/
│   │   │   └── local_datasource.dart
│   │   └── remote/
│   │       ├── lyrics/
│   │       │   └── lyrics_datasource.dart
│   │       ├── spotify/
│   │       │   └── spotify_datasource.dart
│   │       └── youtube/
│   │           ├── cobalt_datasource.dart
│   │           ├── invidious_datasource.dart
│   │           ├── piped_datasource.dart
│   │           └── youtube_music_datasource.dart
│   ├── models/                  # Data transfer objects
│   └── repositories/            # Repository implementations
│       ├── music_repository_impl.dart
│       └── library_repository_impl.dart
├── domain/                      # Domain layer (business logic)
│   ├── entities/                # Business entities
│   │   ├── album.dart
│   │   ├── artist.dart
│   │   ├── entities.dart
│   │   ├── playlist.dart
│   │   ├── song.dart
│   │   └── stream_info.dart
│   ├── repositories/            # Abstract repository contracts
│   │   ├── library_repository.dart
│   │   ├── music_repository.dart
│   │   └── repositories.dart
│   └── usecases/                # Business use cases
│       ├── charts/
│       ├── library/
│       ├── player/
│       └── search/
└── presentation/                # Presentation layer
    ├── blocs/                   # BLoC state management
    │   ├── charts/
    │   ├── library/
    │   │   ├── library_bloc.dart
    │   │   ├── library_event.dart
    │   │   └── library_state.dart
    │   ├── player/
    │   │   ├── player_bloc.dart
    │   │   ├── player_event.dart
    │   │   └── player_state.dart
    │   ├── search/
    │   │   ├── search_bloc.dart
    │   │   ├── search_event.dart
    │   │   └── search_state.dart
    │   └── theme/
    │       ├── theme_bloc.dart
    │       ├── theme_event.dart
    │       └── theme_state.dart
    ├── pages/                   # Screen pages
    │   ├── artist_page.dart
    │   ├── home_page.dart
    │   ├── player_page.dart
    │   ├── search_page.dart
    │   └── settings_page.dart
    └── widgets/                 # Reusable UI components
        ├── cards/
        ├── common/
        ├── download_button.dart
        ├── equalizer/
        │   └── equalizer_bottom_sheet.dart
        ├── lastfm_login_dialog.dart
        └── player/
            └── mini_player.dart
```

---

# Technology Stack

## Core Dependencies

| Category | Package | Version | Purpose |
|----------|---------|---------|---------|
| **State Management** | `flutter_bloc` | ^9.0.0 | BLoC pattern implementation |
| **State Management** | `bloc` | ^9.0.0 | Core BLoC library |
| **State Management** | `equatable` | ^2.0.5 | Value equality for states |
| **Audio Player** | `just_audio` | ^0.10.5 | Cross-platform audio playback |
| **Background Audio** | `audio_service` | ^0.18.18 | Background audio service |
| **Background Audio** | `just_audio_background` | ^0.0.1-beta.17 | Background playback integration |
| **Media Processing** | `media_kit` | ^1.2.2 | Media toolkit for desktop |
| **Media Processing** | `media_kit_libs_audio` | ^1.0.7 | Audio codec support |
| **YouTube API** | `youtube_explode_dart` | ^2.2.3 | YouTube video/audio extraction |
| **HTTP Client** | `dio` | ^5.7.0 | Advanced HTTP client |
| **HTTP Client** | `http` | ^1.2.2 | Basic HTTP client |
| **Networking** | `connectivity_plus` | ^6.0.5 | Network connectivity detection |
| **Database** | `hive_flutter` | ^1.1.0 | Lightweight key-value database |
| **Database** | `hive` | ^2.2.3 | Hive core library |
| **Dependency Injection** | `get_it` | ^8.0.2 | Service locator pattern |
| **Dependency Injection** | `injectable` | ^2.4.4 | DI code generation |
| **Functional** | `dartz` | ^0.10.1 | Functional programming (Either) |
| **Last.fm** | `lastfm` | ^0.0.6 | Last.fm API integration |
| **Color Extraction** | `palette_generator` | ^0.3.3+4 | Extract colors from images |
| **Image Caching** | `cached_network_image` | ^3.3.1 | Cached network images |
| **Fonts** | `google_fonts` | ^6.2.1 | Google Fonts integration |
| **Shimmer** | `shimmer` | ^3.0.0 | Loading shimmer effects |
| **SVG** | `flutter_svg` | ^2.0.10+1 | SVG rendering |
| **Animations** | `flutter_animate` | ^4.5.0 | Declarative animations |
| **Animations** | `lottie` | ^3.2.0 | Lottie animations |
| **Audio Waveforms** | `audio_waveforms` | ^1.1.2 | Audio visualization |
| **Lyrics** | `scrollable_positioned_list` | ^0.3.8 | Synced lyrics scrolling |
| **Permissions** | `permission_handler` | ^11.3.1 | Runtime permissions |
| **Storage** | `path_provider` | ^2.1.4 | File system paths |
| **Storage** | `path` | ^1.9.0 | Path manipulation |
| **Sharing** | `share_plus` | ^10.0.3 | Share content |
| **URL Launcher** | `url_launcher` | ^6.3.1 | Open URLs |
| **Package Info** | `package_info_plus` | ^8.0.3 | App version info |
| **Device Info** | `device_info_plus` | ^11.1.1 | Device information |
| **Crypto** | `crypto` | ^3.0.5 | Cryptographic functions |
| **HTML Parsing** | `html` | ^0.15.4 | HTML parsing |
| **JSON** | `json_annotation` | ^4.9.0 | JSON serialization |
| **Freezed** | `freezed_annotation` | ^2.4.4 | Immutable classes |

## Dev Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `build_runner` | ^2.4.13 | Code generation |
| `json_serializable` | ^6.8.0 | JSON code generation |
| `freezed` | ^2.5.7 | Immutable class generation |
| `injectable_generator` | ^2.6.2 | DI code generation |
| `bloc_test` | ^10.0.0 | BLoC testing utilities |
| `mocktail` | ^1.0.4 | Mocking library |
| `flutter_launcher_icons` | ^0.14.4 | App icon generation |

---

# Music Sources & APIs

## Primary Source: YouTube Music via YouTube Explode

**File:** `lib/data/datasources/remote/youtube/youtube_music_datasource.dart`

### Abstract Interface

```dart
abstract class YouTubeMusicDataSource {
  Future<List<Song>> searchSongs(String query, {int limit = 20});
  Future<List<Artist>> searchArtists(String query, {int limit = 20});
  Future<List<Album>> searchAlbums(String query, {int limit = 20});
  Future<List<Playlist>> searchPlaylists(String query, {int limit = 20});
  Future<StreamInfo> getStreamUrl(String videoId, {AudioQuality preferredQuality});
  Future<List<StreamInfo>> getAvailableStreams(String videoId);
  Future<List<Song>> getRelatedSongs(String videoId, {int limit = 20});
  Future<Song> getSongDetails(String videoId);
  Future<Playlist> getPlaylistDetails(String playlistId);
  Future<List<Song>> getCharts({String region = 'US', int limit = 50});
}
```

### Key Features

1. **Enhanced Search Strategy:**
   ```dart
   // Primary: Official music videos
   '$query official music'
   // Backup: Audio versions
   '$query audio'
   ```

2. **Intelligent Result Ranking:**
   - Exact title/artist match: +10/+8 points
   - Contains full query: +5/+4 points
   - Official content: +3 points
   - Penalize covers/remixes: -1 to -3 points
   - Heavily penalize playlists/compilations: -10 to -20 points
   - Duration validation (2-8 minutes for songs)

3. **Audio Stream Selection:**
   ```dart
   // Quality hierarchy
   AudioQuality.lossless (320kbps) → Prefer WebM/Opus
   AudioQuality.high (256kbps)     → Prefer highest bitrate
   AudioQuality.medium (128kbps)   → Target 128-160kbps
   AudioQuality.low (64kbps)       → Lowest bitrate
   ```

4. **Rate Limiting & Caching:**
   - 200ms minimum request interval
   - 5-minute in-memory search cache
   - Exponential backoff on failures

---

## Fallback Source: Invidious API

**File:** `lib/data/datasources/remote/youtube/invidious_datasource.dart`

### Instance Rotation

```dart
class InvidiousInstances {
  static const List<String> instances = [
    'https://invidious.io',
    'https://iv.ggtyler.dev',
    'https://invidious.projectsegfau.lt',
    'https://inv.riverside.rocks',
    'https://y.com.sb',
    'https://inv.nadeko.net',
    'https://invidious.snopyta.org',
  ];
}
```

### Features

- **Automatic instance rotation** on failure
- **Proxied streams** using `local=true` parameter
- **Fallback to direct proxy endpoint**: `/latest_version?id={videoId}&itag=140`
- Supports AAC and Opus codecs

---

## Metadata Source: Spotify (Embed API)

**File:** `lib/data/datasources/remote/spotify/spotify_datasource.dart`

### Interface

```dart
abstract class SpotifyDataSource {
  Future<List<Song>> searchSongs(String query, {int limit = 20});
  Future<List<Song>> getTopChart({String region = 'global'});
  Future<List<Artist>> getSimilarArtists(String artistId, {int limit = 10});
  Future<List<Song>> getPlaylistTracks(String playlistUrl);
  Future<Artist> getArtistDetails(String artistId);
}
```

### Implementation

- Uses Spotify embed endpoint (no auth required)
- Global Top 50 playlist ID: `37i9dQZEVXbMDoHDwVN2tF`
- Parses HTML response for track data

---

## Lyrics Source: LRCLIB

**File:** `lib/data/datasources/remote/lyrics/lyrics_datasource.dart`

### Features

- **Free API** with no authentication required
- **Synced lyrics support** (LRC format)
- **Plain text lyrics** fallback

```dart
static const String _lrclibBaseUrl = 'https://lrclib.net/api';

Future<Lyrics?> getSyncedLyrics(
  String title,
  String artist, {
  Duration? duration,
});
```

### LRC Parsing

```dart
// Format: [MM:SS.mmm]Text
final regex = RegExp(r'\[(\d{2}):(\d{2})\.(\d{2,3})\](.*)');
```

---

# Search Functionality

## SearchBloc Architecture

**File:** `lib/presentation/blocs/search/search_bloc.dart`

### Events

```dart
class SearchQueryEvent extends SearchEvent {
  final String query;
  final SearchFilter filter;
}
class ClearSearchEvent extends SearchEvent {}
class LoadMoreResultsEvent extends SearchEvent {}
class UpdateFilterEvent extends SearchEvent {
  final SearchFilter filter;
}
class AddToHistoryEvent extends SearchEvent {
  final String query;
}
class ClearHistoryEvent extends SearchEvent {}
```

### States

```dart
enum SearchStatus { initial, loading, success, loadingMore, error }

enum SearchFilter { songs, albums, artists, playlists }

class SearchState {
  final SearchStatus status;
  final String query;
  final SearchFilter filter;
  final SearchResults results;
  final List<String> history;
  final bool hasMore;
  final String? errorMessage;
}
```

### Search Flow

```
User Types Query
       ↓
SearchQueryEvent dispatched
       ↓
_musicRepository.searchAll(query)
       ↓
   ┌─────────────────────────────────┐
   │  Parallel search operations:    │
   │  - Songs                        │
   │  - Artists                      │
   │  - Albums                       │
   │  - Playlists                    │
   └─────────────────────────────────┘
       ↓
Results ranked and filtered
       ↓
Add to search history
       ↓
Emit success state
```

### Search Features

- **Debounced input** (fires after 2+ characters)
- **Tabbed results** (Songs, Albums, Artists, Playlists)
- **Search history** with recent queries (max 10)
- **Quick query chips** for recent searches
- **Filter-based searching** per tab

---

# Audio Playback System

## AudioPlayerService

**File:** `lib/core/services/audio_player_service.dart`

### Core Architecture

```dart
class AudioPlayerService {
  late AudioPlayer _player;
  late EqualizerService _equalizerService;
  final List<AudioSource> _queueSources = [];
  
  // Stream controllers for reactive updates
  final _positionController = StreamController<Duration>.broadcast();
  final _bufferedPositionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _playingController = StreamController<bool>.broadcast();
  final _bufferingController = StreamController<bool>.broadcast();
  final _completedController = StreamController<bool>.broadcast();
  final _errorController = StreamController<String>.broadcast();
}
```

### Key Methods

```dart
// Set and prepare audio source
Future<Duration?> setUrl(
  String url, {
  Map<String, String>? headers,
  String? videoId,
  String quality = 'high',
  String? title,
  String? artist,
  String? album,
  String? artworkUrl,
});

// Playback controls
Future<void> play();
Future<void> pause();
Future<void> stop();
Future<void> seek(Duration position);
Future<void> setVolume(double volume);
Future<void> setSpeed(double speed);

// Queue management
Future<Duration?> loadQueue(List<Map<String, dynamic>> songs, {int initialIndex = 0});
Future<void> addToQueue(String url, {Map<String, String>? headers, String? videoId, String quality = 'high'});
Future<void> skipToNext();
Future<void> skipToPrevious();
```

### Audio Source Priority

```dart
// 1. Try pre-resolved URL (faster startup)
if (url.isNotEmpty) {
  AudioSource.uri(Uri.parse(url), headers: sanitizedHeaders);
}

// 2. Fallback to YouTubeAudioSource (live resolution)
if (videoId != null && videoId.isNotEmpty) {
  YouTubeAudioSource(videoId: videoId, quality: quality);
}
```

### Error Handling

```dart
String _mapPlayerExceptionToMessage(String? errorMessage) {
  if (errorMessage.contains('Unable to connect')) 
    return 'Network connection error';
  if (errorMessage.contains('timeout')) 
    return 'Connection timeout';
  if (errorMessage.contains('format')) 
    return 'Unsupported audio format';
  if (errorMessage.contains('codec')) 
    return 'Audio codec not supported';
}
```

---

## PlayerBloc

**File:** `lib/presentation/blocs/player/player_bloc.dart`

### Events

```dart
PlaySongEvent       // Play a song with optional queue
DownloadSongEvent   // Download song for offline
ResumeEvent         // Resume playback
PauseEvent          // Pause playback
TogglePlayPauseEvent
NextEvent           // Skip to next
PreviousEvent       // Skip to previous
SeekEvent           // Seek to position
SetVolumeEvent
ToggleMuteEvent
SetShuffleEvent
ToggleShuffleEvent
SetRepeatModeEvent
CycleRepeatModeEvent
AddToQueueEvent
RemoveFromQueueEvent
ReorderQueueEvent
ClearQueueEvent
SetPlaybackSpeedEvent
SetAudioQualityEvent
StopEvent
```

### State

```dart
enum PlayerStatus { initial, loading, playing, paused, buffering, error }
enum RepeatMode { off, one, all }

class PlayerState {
  final PlayerStatus status;
  final Song? currentSong;
  final Duration position;
  final Duration duration;
  final Duration bufferedPosition;
  final double volume;
  final bool isMuted;
  final bool isShuffleEnabled;
  final RepeatMode repeatMode;
  final List<Song> queue;
  final List<Song> originalQueue;
  final int queueIndex;
  final double playbackSpeed;
  final AudioQuality audioQuality;
  final String? errorMessage;
}
```

### Playback Flow

```
PlaySongEvent received
       ↓
Emit loading state (immediate UI feedback)
       ↓
StreamLoaderService.loadStream(song)
    ├─ Cache hit? → Instant return
    └─ Cache miss? → Fetch stream
       ↓
AudioPlayerService.setUrl(streamInfo.url)
       ↓
AudioPlayerService.play()
       ↓
Prefetch next 3 songs in queue
       ↓
Async: Fetch recommendations if no queue provided
       ↓
Add to listening history
       ↓
Last.fm updateNowPlaying()
       ↓
Emit playing state
```

### Repeat Modes

```dart
enum RepeatMode {
  off,  // Stop after queue ends
  one,  // Repeat current song
  all,  // Loop entire queue
}
```

---

# Stream Loading Architecture

## StreamLoaderService

**File:** `lib/core/services/stream_loader_service.dart`

### Production-Ready Features

1. **Parallel Source Fetching**
2. **Stream URL Caching** (5-hour TTL)
3. **Smart Prefetching** (next 3 songs)
4. **Analytics Tracking**

### Stream Sources

```dart
enum StreamSource {
  youtubeExplode,   // Primary - Direct YouTube API
  invidious,        // Fallback - Proxied streams
  alternative,      // Emergency fallback
}
```

### Load Flow

```dart
Future<StreamInfo> loadStream(Song song, {bool useCache = true}) async {
  // 1. Check cache first (instant return)
  if (useCache) {
    final cached = _cache.getCached(videoId);
    if (cached != null) return cached;
  }
  
  // 2. Check if already prefetching
  final existingPrefetch = _prefetchQueue[videoId];
  if (existingPrefetch != null) {
    return await existingPrefetch;
  }
  
  // 3. Optimized fetch (primary source first)
  return await _fetchOptimized(videoId);
}
```

### Parallel Fetch Strategy

```dart
Future<StreamInfo> _fetchParallel(String videoId) async {
  final futures = [
    _fetchFromSource(videoId, StreamSource.youtubeExplode),
    _fetchFromSource(videoId, StreamSource.invidious),
    _fetchFromSource(videoId, StreamSource.alternative),
  ];
  
  // First success wins
  final result = await Future.any(futures);
  return result;
}
```

### Prefetching

```dart
void prefetch(Song song) {
  // Skip if already cached or in queue
  if (_cache.isCached(videoId) || _prefetchQueue.containsKey(videoId)) {
    return;
  }
  
  // Non-blocking background fetch
  _prefetchQueue[videoId] = _fetchOptimized(videoId).then((streamInfo) {
    _cache.cache(videoId, streamInfo);
    return streamInfo;
  });
}
```

### Performance Metrics

| Scenario | Before (Sequential) | After (Parallel + Cache) |
|----------|---------------------|--------------------------|
| First playback | 2-11 seconds | 2-5 seconds |
| Cached playback | N/A | <10ms |
| Next song (prefetched) | 2-5 seconds | <100ms |

---

## StreamCacheService

**File:** `lib/core/services/stream_cache_service.dart`

### Configuration

- **TTL:** 5 hours (YouTube streams expire in ~6 hours)
- **Key:** videoId → StreamInfo
- **Auto-cleanup:** Expired entries removed on access

---

# Playlist & Library Management

## LibraryBloc

**File:** `lib/presentation/blocs/library/library_bloc.dart`

### Events

```dart
LoadLibraryEvent
ToggleLikeSongEvent(Song song)
CreatePlaylistEvent(String name, String? description)
DeletePlaylistEvent(String playlistId)
AddToPlaylistEvent(String playlistId, Song song)
RemoveFromPlaylistEvent(String playlistId, String songId)
ImportSpotifyPlaylistEvent(String playlistUrl)
ImportYouTubePlaylistEvent(String playlistUrl)
LoadHistoryEvent
ClearHistoryEvent
DownloadSongEvent(Song song)
DeleteDownloadEvent(String songId)
```

### State

```dart
enum LibraryStatus { initial, loading, success, importing, error }

class LibraryState {
  final LibraryStatus status;
  final List<Song> likedSongs;
  final Set<String> likedSongIds;
  final List<Playlist> playlists;
  final List<Song> history;
  final List<Song> recentlyPlayed;
  final List<Song> downloads;
  final Set<String> downloadedSongIds;
  final double? importProgress;
  final String? errorMessage;
}
```

### Library Features

- **Liked Songs** - Quick access to favorites
- **Custom Playlists** - Create, edit, delete
- **Playlist Import** - Spotify and YouTube URLs
- **Listening History** - Full playback history
- **Recently Played** - Quick access to recent tracks
- **Downloads** - Offline songs management

---

## LibraryRepository

**File:** `lib/domain/repositories/library_repository.dart`

### Abstract Contract

```dart
abstract class LibraryRepository {
  // Liked Songs
  Future<Either<Failure, List<Song>>> getLikedSongs();
  Future<Either<Failure, void>> likeSong(Song song);
  Future<Either<Failure, void>> unlikeSong(String songId);
  Future<bool> isSongLiked(String songId);
  
  // Playlists
  Future<Either<Failure, List<Playlist>>> getUserPlaylists();
  Future<Either<Failure, Playlist>> createPlaylist(String name, {String? description});
  Future<Either<Failure, void>> deletePlaylist(String playlistId);
  Future<Either<Failure, void>> addSongToPlaylist(String playlistId, Song song);
  Future<Either<Failure, void>> removeSongFromPlaylist(String playlistId, String songId);
  Future<Either<Failure, void>> reorderPlaylistSongs(String playlistId, int oldIndex, int newIndex);
  
  // History
  Future<Either<Failure, List<Song>>> getListeningHistory({int limit = 50});
  Future<Either<Failure, void>> addToHistory(Song song);
  Future<Either<Failure, void>> clearHistory();
  Future<Either<Failure, List<Song>>> getRecentlyPlayed({int limit = 20});
  
  // Downloads
  Future<Either<Failure, List<Song>>> getDownloadedSongs();
  Future<Either<Failure, String>> downloadSong(Song song, String streamUrl);
  Future<Either<Failure, void>> deleteDownload(String songId);
  Future<bool> isSongDownloaded(String songId);
}
```

---

# Download & Offline Functionality

## DownloadService

**File:** `lib/core/services/download_service.dart`

### Download States

```dart
enum DownloadStatus {
  notDownloaded,
  downloading,
  completed,
  failed,
}

class DownloadInfo {
  final String songId;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? error;
}
```

### Download Flow

```dart
Future<bool> downloadSong(Song song) async {
  // 1. Check if already downloaded
  if (isDownloaded(song.playableId)) return true;
  
  // 2. Check if already downloading
  if (_downloadProgress.containsKey(song.playableId)) return false;
  
  // 3. Get stream URL
  final streamResult = await _musicRepository.getStreamUrl(song.playableId);
  
  // 4. Create safe filename
  final safeTitle = song.title.replaceAll(RegExp(r'[^\w\s-]'), '');
  final fileName = '${song.playableId}_$safeTitle.m4a';
  
  // 5. Download with progress tracking
  await _dio.download(
    streamUrl,
    filePath,
    onReceiveProgress: (received, total) {
      final progress = received / total;
      _notifyListeners(progressInfo);
    },
  );
  
  // 6. Save to database
  await _downloadBox.put(songId, {'localPath': filePath, ...});
  
  return true;
}
```

### Storage Location

```dart
Future<Directory> _getDownloadDirectory() async {
  final appDir = await getApplicationDocumentsDirectory();
  return Directory('${appDir.path}/downloads');
}
```

---

# Recommendations System

## RecommendationService

**File:** `lib/core/services/recommendation_service.dart`

### Recommendation Modes

```dart
enum RecommendationMode {
  similar,   // Similar songs to currently playing
  discover,  // Discover new songs user might like
}
```

### Recommendation Strategies

1. **Similar Songs Mode:**
   ```dart
   Future<List<Song>> _getSimilarSongs(Song song, int limit) async {
     // Strategy 0: YouTube related videos (tightest continuity)
     final relatedResult = await _musicRepository.getRelatedSongs(song.youtubeId!);
     
     // Strategy 1: Artist's official content
     final artistQuery = '${song.artist} official audio';
     
     // Strategy 2: Topic channel
     final topicQuery = '${song.artist} - Topic';
     
     // Strategy 3: Similar songs search
     final similarQuery = '${song.title} ${song.artist} similar songs';
     
     // Rank and deduplicate
     return _rankSongs(allResults, song);
   }
   ```

2. **Song Ranking (Spotube-inspired):**
   ```dart
   List<Song> _rankSongs(List<Song> songs, Song currentSong) {
     // Score based on:
     // - Same artist: +1 (keep some)
     // - Different artist: +2 (favor variety)
     // - Title contains artist: +2
     // - Title contains current title: +3
     // - Official flag: +1
     // - Random boost: 0-2 (avoid repetition)
   }
   ```

### Auto-Queue Integration

When no queue is provided, recommendations are fetched asynchronously:

```dart
recommendationService
    .getRecommendations(currentSong: song, limit: 10)
    .then((recommendations) {
      // Add unique recommendations to queue
      // Prefetch first recommendation
    });
```

---

# Lyrics Integration

## Lyrics Data Model

```dart
class Lyrics extends Equatable {
  final String songId;
  final String? plainLyrics;
  final List<LyricLine>? syncedLyrics;
  final String source;
  
  bool get isSynced => syncedLyrics?.isNotEmpty ?? false;
}

class LyricLine extends Equatable {
  final int startTimeMs;
  final int? endTimeMs;
  final String text;
}
```

## Lyrics Fetching

```dart
Future<Lyrics?> getSyncedLyrics(
  String title,
  String artist, {
  Duration? duration,
}) async {
  final response = await _dio.get(
    '$_lrclibBaseUrl/get',
    queryParameters: {
      'track_name': title,
      'artist_name': artist,
      if (duration != null) 'duration': duration.inSeconds,
    },
  );
  
  // Parse both synced and plain lyrics
  final syncedLyrics = data['syncedLyrics'];
  final plainLyrics = data['plainLyrics'];
  
  return Lyrics(
    syncedLyrics: _parseLrcLyrics(syncedLyrics),
    plainLyrics: plainLyrics,
    source: 'LRCLIB',
  );
}
```

---

# Charts & Trending

## ChartService

**File:** `lib/core/services/chart_service.dart`

### Chart Definitions

```dart
static List<ChartDefinition> getAvailableCharts(String countryCode, String countryName) {
  return [
    ChartDefinition(
      id: 'billboard_hot100',
      name: 'Billboard Hot 100',
      source: ChartSource.billboard,
    ),
    ChartDefinition(
      id: 'billboard_global200',
      name: 'Billboard Global 200',
      source: ChartSource.billboard,
    ),
    ChartDefinition(
      id: 'youtube_trending_$countryCode',
      name: 'YouTube Trending',
      source: ChartSource.youtube,
    ),
    ChartDefinition(
      id: 'youtube_top_music_$countryCode',
      name: 'YouTube Top Music',
      source: ChartSource.youtube,
    ),
    ChartDefinition(
      id: 'billboard_tiktok',
      name: 'TikTok Billboard Top 50',
      source: ChartSource.billboard,
    ),
    ChartDefinition(
      id: 'youtube_new_releases',
      name: 'New Releases',
      source: ChartSource.youtube,
    ),
  ];
}
```

### Caching

```dart
// Chart data cached for 2 hours
static const _cacheDuration = Duration(hours: 2);

class _CachedChart {
  final List<Song> songs;
  final DateTime fetchedAt;
  
  bool get isExpired => 
    DateTime.now().difference(fetchedAt) > _cacheDuration;
}
```

---

# History & Recently Played

## Listening History

Tracked automatically during playback:

```dart
// In PlayerBloc._onPlaySong
await _libraryRepository.addToHistory(event.song);
```

## History Operations

```dart
// Get listening history
Future<Either<Failure, List<Song>>> getListeningHistory({
  int limit = 50,
  DateTime? since,
});

// Get recently played (last 20)
Future<Either<Failure, List<Song>>> getRecentlyPlayed({
  int limit = 20,
});

// Clear all history
Future<Either<Failure, void>> clearHistory();
```

---

# Settings & Preferences

## SettingsService

**File:** `lib/core/services/settings_service.dart`

### Available Settings

| Setting | Key | Default | Description |
|---------|-----|---------|-------------|
| Country Code | `country_code` | US | Music region selection |
| Audio Quality | `audio_quality` | high | low/medium/high |
| Crossfade Duration | `crossfade_duration` | 0.0 | Seconds of crossfade |
| Auto Shuffle | `auto_shuffle` | false | Auto-shuffle on play |
| Bass Boost | `bass_boost` | false | Enable bass boost |
| Player UI Style | `player_ui_style` | classic | classic/modern |

### Supported Countries (40+)

```dart
const List<CountryInfo> supportedCountries = [
  CountryInfo(code: 'US', name: 'United States', flag: '🇺🇸'),
  CountryInfo(code: 'GB', name: 'United Kingdom', flag: '🇬🇧'),
  CountryInfo(code: 'IN', name: 'India', flag: '🇮🇳'),
  // ... 37 more countries
];
```

### Player UI Styles

```dart
enum PlayerUiStyle { classic, modern }
```

---

# Last.fm Integration

## LastFmService

**File:** `lib/core/services/lastfm_service.dart`

### Features

1. **Authentication:**
   ```dart
   Future<bool> authenticate(String username, String password);
   Future<void> logout();
   bool get isAuthenticated;
   String? get username;
   ```

2. **Scrobbling:**
   ```dart
   Future<bool> scrobble({
     required String track,
     required String artist,
     required String album,
     DateTime? timestamp,
   });
   ```

3. **Now Playing:**
   ```dart
   Future<bool> updateNowPlaying({
     required String track,
     required String artist,
     required String album,
   });
   ```

4. **User Data:**
   ```dart
   Future<List<Map<String, dynamic>>> getTopTracks({int limit = 20, String period = '7day'});
   Future<List<Map<String, dynamic>>> getRecentTracks({int limit = 20});
   Future<List<Map<String, dynamic>>> getRecommendedTracks({int limit = 20});
   ```

5. **Track Actions:**
   ```dart
   Future<bool> loveTrack({required String track, required String artist});
   Future<bool> unloveTrack({required String track, required String artist});
   ```

### Scrobble Rules

Scrobble is sent when:
- Played for **more than 4 minutes**, OR
- Played for **more than 50%** of track duration

```dart
final shouldScrobble = position.inSeconds > 240 || 
                      (duration.inSeconds > 0 && 
                       position.inSeconds > duration.inSeconds * 0.5);
```

### API Methods Used

| Method | Purpose |
|--------|---------|
| `auth.getMobileSession` | Username/password authentication |
| `track.updateNowPlaying` | Update current playing track |
| `track.scrobble` | Submit listening history |
| `user.getTopTracks` | Get user's top tracks |
| `user.getRecentTracks` | Get recently played |
| `track.love` | Love a track |
| `track.unlove` | Unlove a track |

---

# Audio Effects & Equalizer

## EqualizerService

**File:** `lib/core/services/equalizer_service.dart`

### Presets

```dart
static const Map<String, EqualizerPreset> presets = {
  'Normal': EqualizerPreset(bassBoost: 0.0, treble: 0.5, reverb: ReverbPreset.none),
  'Bass Boost': EqualizerPreset(bassBoost: 0.8, treble: 0.4, reverb: ReverbPreset.none),
  'Treble Boost': EqualizerPreset(bassBoost: 0.2, treble: 0.9, reverb: ReverbPreset.none),
  'Rock': EqualizerPreset(bassBoost: 0.65, treble: 0.7, reverb: ReverbPreset.largeRoom),
  'Pop': EqualizerPreset(bassBoost: 0.55, treble: 0.65, reverb: ReverbPreset.mediumRoom),
  'Classical': EqualizerPreset(bassBoost: 0.3, treble: 0.6, reverb: ReverbPreset.largeHall),
  'Jazz': EqualizerPreset(bassBoost: 0.5, treble: 0.55, reverb: ReverbPreset.smallRoom),
  'Electronic': EqualizerPreset(bassBoost: 0.75, treble: 0.8, reverb: ReverbPreset.plate),
};
```

### Available Effects

1. **Bass Boost** (0.0 - 1.0)
2. **Treble Adjustment** (0.0 - 1.0)
3. **Reverb Presets:**
   - none
   - smallRoom
   - mediumRoom
   - largeRoom
   - largeHall
   - plate

### Platform Integration

Uses native Android audio effects via `AudioEffectsChannel`:

```dart
await AudioEffectsChannel.setBassBoost(_bassBoostLevel, _bassBoostEnabled);
await AudioEffectsChannel.setReverb(_reverbPreset.value);
```

---

# Dynamic Theming

## ThemeBloc

**File:** `lib/presentation/blocs/theme/theme_bloc.dart`

### Events

```dart
SetThemeModeEvent(ThemeMode mode)     // Light/Dark/System
UpdateDynamicColorEvent(Color? primaryColor, String? imageUrl)
ToggleDynamicColorEvent()             // Enable/disable
SetLayoutModeEvent(LayoutMode mode)
ResetThemeEvent()
```

### State

```dart
class ThemeState {
  final ThemeMode themeMode;
  final Color primaryColor;
  final Color defaultPrimaryColor;
  final bool isDynamicColorEnabled;
  final bool isExtractingColor;
  final LayoutMode layoutMode;
  
  ThemeData get lightTheme;
  ThemeData get darkTheme;
}
```

### Color Extraction

```dart
Future<void> _onUpdateDynamicColor(...) async {
  final paletteGenerator = await PaletteGenerator.fromImageProvider(
    NetworkImage(imageUrl),
    maximumColorCount: 20,
  );
  
  Color? extractedColor = 
    paletteGenerator.dominantColor?.color ??
    paletteGenerator.vibrantColor?.color ??
    paletteGenerator.mutedColor?.color;
  
  // Ensure minimum saturation
  final hsl = HSLColor.fromColor(extractedColor);
  if (hsl.saturation < 0.3) {
    extractedColor = hsl.withSaturation(0.5).toColor();
  }
}
```

---

# Data Storage & Persistence

## Hive Database

### Box Organization

```dart
// Session data
Hive.box('lastfm_session')
  - session_key: String
  - username: String

// Recommendation settings
Hive.box('recommendation_settings')
  - recommendation_mode: String

// App settings
Hive.box('app_settings')
  - country_code: String
  - audio_quality: String
  - crossfade_duration: double
  - auto_shuffle: bool
  - bass_boost: bool
  - player_ui_style: String

// Downloads
Hive.box('downloads')
  - {songId}: {localPath: String, ...}
```

### Initialization

```dart
// In main.dart
await Hive.initFlutter();
await initializeDependencies();
```

---

# Platform Support

| Platform | Status | Audio Backend | Notes |
|----------|--------|---------------|-------|
| **Android** | ✅ Full | just_audio (native) | Primary platform |
| **iOS** | ✅ Full | just_audio (native) | Supported |
| **Windows** | ✅ Full | media_kit | Desktop support |
| **Linux** | ✅ Full | media_kit | Desktop support |
| **macOS** | ✅ Full | media_kit | Desktop support |
| **Web** | ⚠️ Limited | just_audio (web) | Some features limited |

### Android Configuration

```yaml
# Flutter Launcher Icons
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/dark.png"
  adaptive_icon_background: "#000000"
  adaptive_icon_foreground: "assets/icon/dark.png"
```

---

# UI/UX Architecture

## Screens (5 main pages)

```
pages/
├── home_page.dart       # Main home with tabs
│   ├── _DiscoverTab     # Charts & recommendations
│   ├── _HomeTab         # Trending & top songs
│   └── _LibraryTab      # User library
├── search_page.dart     # Full search with tabs
├── player_page.dart     # Full-screen player
│   ├── Classic mode     # Traditional layout
│   └── Modern mode      # Immersive dial UI
├── artist_page.dart     # Artist details
└── settings_page.dart   # App settings
```

## Navigation

- **Bottom Navigation Bar** with 4 destinations:
  - Discover
  - Home
  - Library
  - Settings

- **Mini Player** - Floating above nav bar when song playing
- **Full-Screen Player** - Slide up from mini player

## Player Page Layouts

### Classic Mode
- Traditional album art centered
- Progress bar with time labels
- Standard playback controls
- Extra controls row (shuffle, repeat, queue)

### Modern Mode
- Circular album art with progress dial
- Gradient background from dominant color
- Minimalist controls
- Immersive full-screen experience

## Widget Organization

```
widgets/
├── cards/               # Song, album, artist cards
├── common/              # Shared components
├── download_button.dart # Download indicator
├── equalizer/           # EQ bottom sheet
├── lastfm_login_dialog.dart
└── player/
    └── mini_player.dart # Floating mini player
```

---

# Dependency Injection

## GetIt Configuration

**File:** `lib/core/di/injection.dart`

### Registration Pattern

```dart
Future<void> initializeDependencies() async {
  // Core services (Lazy Singleton)
  getIt.registerLazySingleton<Dio>(() => Dio(...));
  getIt.registerLazySingleton<AudioPlayerService>(() => AudioPlayerService());
  getIt.registerLazySingleton<StreamCacheService>(() => StreamCacheService());
  
  // Data Sources (Lazy Singleton)
  getIt.registerLazySingleton<YouTubeMusicDataSource>(() => YouTubeMusicDataSourceImpl());
  getIt.registerLazySingleton<SpotifyDataSource>(() => SpotifyDataSourceImpl(dio: getIt()));
  getIt.registerLazySingleton<LyricsDataSource>(() => LyricsDataSourceImpl(dio: getIt()));
  getIt.registerLazySingleton<LocalDataSource>(() => LocalDataSourceImpl());
  
  // Stream Loader (depends on datasource + cache)
  getIt.registerLazySingleton<StreamLoaderService>(
    () => StreamLoaderService(getIt(), getIt()),
  );
  
  // Repositories (Lazy Singleton)
  getIt.registerLazySingleton<MusicRepository>(() => MusicRepositoryImpl(...));
  getIt.registerLazySingleton<LibraryRepository>(() => LibraryRepositoryImpl(...));
  
  // BLoCs (Factory - new instance each time)
  getIt.registerFactory<PlayerBloc>(() => PlayerBloc(...));
  getIt.registerFactory<SearchBloc>(() => SearchBloc(...));
  getIt.registerFactory<LibraryBloc>(() => LibraryBloc(...));
  getIt.registerFactory<ThemeBloc>(() => ThemeBloc());
}
```

---

# Error Handling & Resilience

## Failure Types

```dart
abstract class Failure {
  final String message;
}

class ServerFailure extends Failure {}
class NetworkFailure extends Failure {}
class CacheFailure extends Failure {}
class NotFoundFailure extends Failure {}
```

## Either Pattern

```dart
// All repository methods return Either<Failure, T>
Future<Either<Failure, List<Song>>> searchSongs(String query);

// Usage
result.fold(
  (failure) => handleError(failure.message),
  (songs) => displayResults(songs),
);
```

## Stream Source Resilience

1. **Primary:** YouTube Explode
2. **Fallback 1:** Invidious (rotating instances)
3. **Fallback 2:** Alternative sources
4. **Parallel fetching:** First success wins

## Error Recovery

- **Automatic retry** with exponential backoff
- **Instance rotation** for Invidious
- **Graceful degradation** to lower quality
- **User-friendly error messages**

---

# Feature Summary Matrix

| Feature | Status | Description |
|---------|--------|-------------|
| **Music Sources** | ✅ | YouTube Music (primary), Invidious (fallback), Spotify (metadata) |
| **No Login Required** | ✅ | Stream instantly without account |
| **Audio Quality** | ✅ | Low (64kbps) / Medium (128kbps) / High (256kbps) / Lossless (320kbps) |
| **State Management** | ✅ | BLoC/Cubit pattern |
| **Database** | ✅ | Hive (key-value storage) |
| **Stream Caching** | ✅ | 5-hour TTL with parallel fetching |
| **Smart Prefetching** | ✅ | Next 3 songs prefetched |
| **Lyrics** | ✅ | Synced (LRC) + Plain via LRCLIB |
| **Last.fm Scrobbling** | ✅ | Full integration (Now Playing, Scrobble, Love) |
| **Recommendations** | ✅ | Similar songs + Discovery mode |
| **Charts** | ✅ | Billboard, YouTube Trending, TikTok Top 50 |
| **Offline Mode** | ✅ | Download songs for offline playback |
| **Equalizer** | ✅ | Bass boost, reverb, 8 presets |
| **Dynamic Theming** | ✅ | Album art color extraction |
| **Player UI Modes** | ✅ | Classic + Modern layouts |
| **Search** | ✅ | Songs, Artists, Albums, Playlists with history |
| **Queue Management** | ✅ | Add, remove, reorder, shuffle |
| **Repeat Modes** | ✅ | Off, One, All |
| **Playback Speed** | ✅ | 0.25x - 2.0x |
| **Volume Control** | ✅ | With mute toggle |
| **Playlist Import** | ✅ | Spotify & YouTube URLs |
| **40+ Countries** | ✅ | Region-based charts and recommendations |
| **Android** | ✅ | Full support |
| **iOS** | ✅ | Full support |
| **Windows** | ✅ | Full support |
| **Linux** | ✅ | Full support |
| **macOS** | ✅ | Full support |

---

# Summary

## Prism Music Strengths

1. **Privacy-First Approach** - No login, no tracking, no ads
2. **Clean Architecture** - Proper separation with domain-driven design
3. **High-Fidelity Audio** - Up to 320kbps Opus streaming
4. **Smart Streaming** - Parallel fetching + 5-hour cache + prefetching
5. **Resilient Playback** - Multiple fallback sources with auto-recovery
6. **Last.fm Integration** - Full scrobbling and recommendations
7. **Audio Effects** - Real equalizer with bass boost and reverb
8. **Dynamic Theming** - Album art color extraction
9. **Cross-Platform** - Android, iOS, Windows, Linux, macOS
10. **Offline Support** - Download songs for offline playback
11. **Synced Lyrics** - LRC format with scrolling
12. **Modern UI** - Material 3 with classic/modern player modes

## Recommended Use Cases

**Choose Prism Music if you want:**
- A privacy-respecting music app with no account required
- High-quality audio streaming without ads
- Last.fm scrobbling for listening history
- Cross-platform support including desktop
- Clean, modern UI with dynamic theming
- Offline download capability
- Audio equalizer with presets
- Synced lyrics support

---

*Documentation generated on January 4, 2026*
*Based on Prism Music v1.0.0*

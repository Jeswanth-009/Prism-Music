# Comprehensive Documentation: BloomeeTunes vs Musify

## Music Player Applications - Complete Technical Analysis

---

# Table of Contents

1. [Executive Summary](#executive-summary)
2. [Architecture Overview](#architecture-overview)
3. [Technology Stack](#technology-stack)
4. [Music Sources & APIs](#music-sources--apis)
5. [Search Functionality](#search-functionality)
6. [Audio Playback System](#audio-playback-system)
7. [Playlist Management](#playlist-management)
8. [Download & Offline Functionality](#download--offline-functionality)
9. [Recommendations System](#recommendations-system)
10. [Lyrics Integration](#lyrics-integration)
11. [History & Recently Played](#history--recently-played)
12. [Settings & Preferences](#settings--preferences)
13. [Data Storage & Persistence](#data-storage--persistence)
14. [Platform Support](#platform-support)
15. [External Integrations](#external-integrations)
16. [UI/UX Architecture](#uiux-architecture)
17. [Feature Comparison Matrix](#feature-comparison-matrix)

---

# Executive Summary

## BloomeeTunes (v2.13.3)
**Description:** An open-source free music player built with Flutter, offering multi-source music streaming with support for YouTube Music, YouTube Videos, and JioSaavn (Indian music service).

**Key Highlights:**
- Multi-source music aggregation (YouTube, YouTube Music, JioSaavn, Spotify import)
- BLoC state management pattern
- Isar database for local storage
- Last.fm scrobbling integration
- Discord Rich Presence support
- Cross-platform support (Android, iOS, Windows, Linux, macOS, Web)

## Musify (v9.7.4)
**Description:** A music streaming application focused on simplicity and YouTube-based music playback with extensive localization support.

**Key Highlights:**
- YouTube-focused music streaming
- Hive database for storage
- 22+ language support
- SponsorBlock integration
- Proxy support for restricted regions
- Clean, Material Design 3 interface

---

# Architecture Overview

## BloomeeTunes Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                              │
├─────────────────────────────────────────────────────────────────┤
│                    Presentation Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Screens    │  │   Widgets    │  │   Routes     │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
├─────────────────────────────────────────────────────────────────┤
│                    State Management (BLoC/Cubit)                 │
│  ┌────────────┐ ┌──────────────┐ ┌───────────┐ ┌─────────────┐ │
│  │ PlayerCubit│ │ SearchCubit  │ │LibraryCubit│ │DownloadCubit│ │
│  │ LyricsCubit│ │ ExploreCubit │ │SettingsCubit│ │ TimerCubit │ │
│  │ HistoryCubit│ │ Last.fm Cubit│ │ConnectCubit │ │           │ │
│  └────────────┘ └──────────────┘ └───────────┘ └─────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│                    Repository Layer                              │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │  YouTube    │ │  Saavn API  │ │ Spotify API │ │ Last.FM   │ │
│  │  Services   │ │             │ │   (Import)  │ │    API    │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │ YT Music API│ │  Lyrics API │ │  Mixed API  │               │
│  └─────────────┘ └─────────────┘ └─────────────┘               │
├─────────────────────────────────────────────────────────────────┤
│                    Services Layer                                │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────────┐  │
│  │ BloomeeMusicPlayer│ │DiscordService  │ │Import/Export Svc │  │
│  │ (Audio Handler)  │ │                │ │                  │  │
│  └─────────────────┘ └─────────────────┘ └──────────────────┘  │
│  ┌─────────────────┐ ┌─────────────────┐ ┌──────────────────┐  │
│  │ Keyboard Shortcuts│ │ DB Service    │ │  YTBG Service    │  │
│  └─────────────────┘ └─────────────────┘ └──────────────────┘  │
├─────────────────────────────────────────────────────────────────┤
│                    Data Layer (Isar Database)                    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ MediaPlaylist│ │ MediaItems   │ │ Settings     │            │
│  │ RecentPlayed │ │ ChartsCache  │ │ YTLinkCache  │            │
│  │ Notifications│ │ Downloads    │ │ Lyrics       │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
└─────────────────────────────────────────────────────────────────┘
```

### BloomeeTunes Directory Structure

```
lib/
├── main.dart                    # App entry point
├── blocs/                       # BLoC state management
│   ├── add_to_playlist/        # Add to playlist functionality
│   ├── album_view/             # Album viewing logic
│   ├── artist_view/            # Artist page logic
│   ├── downloader/             # Download management
│   ├── explore/                # Home/Explore page
│   ├── global_events/          # App-wide events
│   ├── history/                # Play history
│   ├── internet_connectivity/  # Network state
│   ├── lastdotfm/              # Last.fm integration
│   ├── library/                # Library management
│   ├── lyrics/                 # Lyrics fetching
│   ├── mediaPlayer/            # Main player logic
│   ├── mini_player/            # Mini player state
│   ├── notification/           # Notifications
│   ├── player_overlay/         # Player overlay UI
│   ├── playlist_view/          # Playlist viewing
│   ├── search/                 # Search functionality
│   ├── search_suggestions/     # Search autocomplete
│   ├── settings_cubit/         # App settings
│   └── timer/                  # Sleep timer
├── model/                       # Data models
├── plugins/                     # External plugins
├── repository/                  # API integrations
│   ├── LastFM/                 # Last.fm API
│   ├── Lyrics/                 # Lyrics services
│   ├── MixedAPI/               # Multi-source API
│   ├── Saavn/                  # JioSaavn API
│   ├── Spotify/                # Spotify API
│   └── Youtube/                # YouTube & YT Music
├── routes_and_consts/          # Navigation & constants
├── screens/                    # UI screens
├── services/                   # Core services
│   ├── db/                     # Database services
│   ├── player/                 # Player components
│   └── ...                     # Other services
├── theme_data/                 # Theme configuration
└── utils/                      # Utility functions
```

---

## Musify Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Flutter App                              │
├─────────────────────────────────────────────────────────────────┤
│                    Presentation Layer                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │   Screens    │  │   Widgets    │  │  Router Svc  │          │
│  │  (10 pages)  │  │              │  │  (go_router) │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
├─────────────────────────────────────────────────────────────────┤
│                    State Management (ValueNotifier)              │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │ Global ValueNotifiers for reactive state                    ││
│  │ - userPlaylists, userLikedSongs, userRecentlyPlayed        ││
│  │ - shuffleNotifier, repeatNotifier, lyrics                  ││
│  │ - settings (theme, language, audio quality)                 ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    API Layer                                     │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                    musify.dart (Main API)                    ││
│  │  - YouTube Explode integration                               ││
│  │  - Playlist management                                       ││
│  │  - Song fetching & caching                                   ││
│  │  - Recommendations                                           ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    Services Layer                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │AudioService │ │DataManager  │ │SettingsManager│ │IO Service │ │
│  │(Audio Handler)│ │ (Caching)  │ │              │ │           │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌───────────┐ │
│  │LyricsManager│ │ProxyManager │ │UpdateManager│ │RouterService│ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └───────────┘ │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │           PlaylistDownloadService (Offline)                  ││
│  └─────────────────────────────────────────────────────────────┘│
├─────────────────────────────────────────────────────────────────┤
│                    Data Layer (Hive Database)                    │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐            │
│  │ user Box     │ │ settings Box │ │ cache Box    │            │
│  │ userNoBackup │ │              │ │              │            │
│  └──────────────┘ └──────────────┘ └──────────────┘            │
├─────────────────────────────────────────────────────────────────┤
│                    Database Layer                                │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │  playlists.db.dart  |  albums.db.dart (Predefined lists)    ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Musify Directory Structure

```
lib/
├── main.dart              # App entry point
├── main_fdroid.dart       # F-Droid variant entry point
├── API/
│   ├── clients.dart       # YouTube client configurations
│   ├── musify.dart        # Main API (1400+ lines)
│   └── version.dart       # Version information
├── DB/
│   ├── albums.db.dart     # Predefined albums
│   └── playlists.db.dart  # Predefined playlists
├── extensions/
│   └── l10n.dart          # Localization extensions
├── localization/          # 22+ language files
├── models/
│   ├── full_player_state.dart
│   ├── position_data.dart
│   └── proxy_model.dart
├── screens/               # 10 main screens
│   ├── about_page.dart
│   ├── bottom_navigation_page.dart
│   ├── home_page.dart
│   ├── library_page.dart
│   ├── now_playing_page.dart
│   ├── playlist_folder_page.dart
│   ├── playlist_page.dart
│   ├── search_page.dart
│   ├── settings_page.dart
│   └── user_songs_page.dart
├── services/
│   ├── audio_service.dart    # Audio handler (1500+ lines)
│   ├── data_manager.dart     # Caching system
│   ├── io_service.dart       # File operations
│   ├── logger_service.dart   # Logging
│   ├── lyrics_manager.dart   # Lyrics fetching
│   ├── playlist_download_service.dart
│   ├── playlist_sharing.dart
│   ├── proxy_manager.dart    # Proxy support
│   ├── router_service.dart   # Navigation
│   ├── settings_manager.dart # Settings
│   └── update_manager.dart   # App updates
├── style/
│   ├── app_colors.dart
│   ├── app_themes.dart
│   └── dynamic_color_temp_fix.dart
├── utilities/
│   ├── artwork_provider.dart
│   ├── common_variables.dart
│   ├── flutter_bottom_sheet.dart
│   ├── flutter_toast.dart
│   ├── formatter.dart
│   ├── mediaitem.dart
│   ├── playlist_image_picker.dart
│   ├── sort_utils.dart
│   ├── url_launcher.dart
│   └── utils.dart
└── widgets/               # Reusable UI components
```

---

# Technology Stack

## BloomeeTunes Dependencies

| Category | Package | Purpose |
|----------|---------|---------|
| **State Management** | `flutter_bloc` (v9.1.1) | BLoC/Cubit pattern |
| **Database** | `isar_community` (v3.3.0-dev.3) | NoSQL local database |
| **Audio** | `just_audio` (v0.10.5) | Audio playback |
| **Audio Service** | `audio_service` (v0.18.18) | Background audio |
| **YouTube** | `youtube_explode_dart` (forked) | YouTube API |
| **Networking** | `http` (v1.5.0) | HTTP requests |
| **Reactive** | `rxdart` (v0.28.0) | Reactive extensions |
| **Navigation** | `go_router` (v16.2.4) | Declarative routing |
| **Caching** | `cached_network_image` (v3.4.1) | Image caching |
| **Responsive** | `responsive_framework` (v1.5.1) | Responsive UI |
| **Metadata** | `metadata_god` (v1.0.0) | Audio metadata |
| **Discord** | `dart_discord_rpc` (v0.0.2) | Discord RPC |
| **Platform Audio** | `just_audio_media_kit` (v2.1.0) | Desktop audio |
| **Permissions** | `permission_handler` (v12.0.1) | Permission handling |
| **Sharing** | `share_plus` (v12.0.0) | Content sharing |
| **File Picker** | `file_picker` (v10.3.3) | File selection |

## Musify Dependencies

| Category | Package | Purpose |
|----------|---------|---------|
| **State Management** | `ValueNotifier` (built-in) | Simple reactive state |
| **Database** | `hive_flutter` (v1.1.0) | Key-value database |
| **Audio** | `just_audio` (v0.10.5) | Audio playback |
| **Audio Service** | `audio_service` (v0.18.18) | Background audio |
| **YouTube** | `youtube_explode_dart` (v3.0.4) | YouTube API |
| **Networking** | `http` (v1.6.0) | HTTP requests |
| **Reactive** | `rxdart` (v0.28.0) | Reactive extensions |
| **Navigation** | `go_router` (v17.0.1) | Declarative routing |
| **Caching** | `cached_network_image` (v3.4.1) | Image caching |
| **Theming** | `dynamic_color` (v1.8.1) | Material You colors |
| **Localization** | `flutter_localizations` | Multi-language |
| **Icons** | `fluentui_system_icons` (v1.1.273) | Fluent icons |
| **Pagination** | `infinite_scroll_pagination` (v5.1.1) | Infinite lists |
| **Deep Links** | `app_links` (v7.0.0) | URL handling |

---

# Music Sources & APIs

## BloomeeTunes Music Sources

### 1. YouTube Music (Primary Source)
**File:** `lib/repository/Youtube/ytm/ytmusic.dart`

```dart
// Search types supported
Future<Map?> searchYtm(String query, {String type = "songs"}) async {
  // Types: "songs", "playlists", "albums", "artists"
}
```

**Features:**
- Full YouTube Music catalog access
- Song/Album/Playlist/Artist search
- Music home page data fetching
- Trending videos
- Charts integration

### 2. YouTube Videos
**File:** `lib/repository/Youtube/youtube_api.dart`

```dart
class YouTubeServices {
  final YoutubeExplode yt = YoutubeExplode();
  
  // Key methods:
  Future<List<Video>> getPlaylistSongs(String id)
  Future<Video?> getVideoFromId(String id)
  Future<Map?> refreshLink(String id, {String quality = 'Low'})
  Future<Playlist> getPlaylistDetails(String id)
  Future<Map<String, List>> getMusicHome()
}
```

**Features:**
- Video search and playback
- Playlist fetching
- Stream URL resolution
- Quality selection (Low/High)

### 3. JioSaavn (Indian Music)
**File:** `lib/repository/Saavn/saavn_api.dart`

```dart
class SaavnAPI {
  String baseUrl = 'www.jiosaavn.com';
  
  // Endpoints supported:
  'homeData', 'topSearches', 'fromToken', 'songDetails',
  'playlistDetails', 'albumDetails', 'getResults',
  'albumResults', 'artistResults', 'playlistResults',
  'getReco', 'getAlbumReco'
}
```

**Features:**
- Indian music catalog
- Song/Album/Playlist search
- Related songs recommendations
- Regional content support

### 4. Spotify (Import Only)
**File:** `lib/repository/Spotify/spotify_api.dart`

```dart
class SpotifyApi {
  // OAuth client credentials flow
  final String clientID = '4ede44382bf14ac3ba1d97ad753b233f';
  
  Future<List> getUserPlaylists(String accessToken)
  Future<Map<String, Object>> getAllTracksOfPlaylist(accessToken, playlistId)
}
```

**Features:**
- Playlist import from Spotify
- OAuth authentication
- Track metadata extraction
- Converts to playable format via YouTube

---

## Musify Music Source

### YouTube (Single Source)
**File:** `lib/API/musify.dart`

```dart
// Global YouTube Explode instance with proxy support
YoutubeExplode get _yt => ProxyManager().getClientSync();

// Core functions (1400+ lines):
Future<List> fetchSongsList(String searchQuery)
Future<List> getRecommendedSongs()
Future<List> getSongsFromPlaylist(playlistId)
Future<String?> getSong(String songId, bool isLive)
Future<AudioOnlyStreamInfo?> getSongManifest(String? songId)
```

**Features:**
- YouTube search integration
- Video to audio extraction
- Stream URL caching (3 hours)
- Audio quality selection (low/medium/high)
- Proxy support for restricted regions
- SponsorBlock segment skipping

### Client Configuration
```dart
final _clients = [customAndroidVr, customAndroidSdkless];
```

---

# Search Functionality

## BloomeeTunes Search System

### Multi-Source Search Architecture
**File:** `lib/blocs/search/fetch_search_results.dart`

```dart
enum SourceEngine {
  eng_YTM,  // YouTube Music
  eng_YTV,  // YouTube Videos
  eng_JIS   // JioSaavn
}

enum ResultTypes {
  songs, playlists, albums, artists
}

class FetchSearchResultsCubit extends Cubit<FetchSearchResultsState> {
  // Maintains separate search states for each source
  LastSearch last_YTM_search;
  LastSearch last_YTV_search;
  LastSearch last_JIS_search;
  
  Future<void> search(String query, {SourceEngine? sourceEngine, ResultTypes? resultType})
  Future<void> searchYTMTracks(String query, {ResultTypes resultType})
  Future<void> searchYTVTracks(String query, {ResultTypes resultType})
  Future<void> searchJISTracks(String query, {bool loadMore, ResultTypes resultType})
}
```

### Search Flow:
1. User enters query in search bar
2. Source engine selected (YTM/YTV/JIS)
3. Result type selected (Songs/Playlists/Albums/Artists)
4. API called based on selections
5. Results converted to unified `MediaItemModel`
6. Pagination support for JioSaavn

### Search Suggestions
**File:** `lib/blocs/search_suggestions/search_suggestion_bloc.dart`
- Debounced suggestions
- Multiple source suggestion aggregation

---

## Musify Search System

### Single-Source Search
**File:** `lib/screens/search_page.dart`

```dart
class _SearchPageState extends State<SearchPage> {
  Future<void> search() async {
    final query = _searchBar.text;
    
    // Parallel searches
    _songsSearchResult = await fetchSongsList(query);
    _albumsSearchResult = await getPlaylists(query: query, type: 'album');
    _playlistsSearchResult = await getPlaylists(query: query, type: 'playlist');
  }
}
```

### Search Features:
- Songs, Albums, and Playlists in single search
- Search history with persistence
- Debounced suggestions (300ms delay)
- History management (delete individual/all)

### Search Suggestions
```dart
Future<List<String>> getSearchSuggestions(String query) async {
  final suggestions = await _yt.search.getQuerySuggestions(query);
  return suggestions;
}
```

---

# Audio Playback System

## BloomeeTunes Player

### Main Player Class
**File:** `lib/services/bloomeePlayer.dart`

```dart
class BloomeeMusicPlayer extends BaseAudioHandler with SeekHandler, QueueHandler {
  late AudioPlayer audioPlayer;
  
  // Modular components
  late AudioSourceManager _audioSourceManager;
  late PlayerErrorHandler _errorHandler;
  late QueueManager _queueManager;
  late RelatedSongsManager _relatedSongsManager;
  late RecentlyPlayedTracker _recentlyPlayedTracker;
  
  // State streams
  BehaviorSubject<bool> fromPlaylist;
  BehaviorSubject<bool> isOffline;
  BehaviorSubject<LoopMode> loopMode;
}
```

### Key Features:

1. **Modular Architecture:**
   - `AudioSourceManager`: Handles audio source resolution
   - `PlayerErrorHandler`: Error categorization and recovery
   - `QueueManager`: Queue manipulation and shuffling
   - `RelatedSongsManager`: Auto-queue related songs
   - `RecentlyPlayedTracker`: Tracks play history

2. **Playback Controls:**
```dart
Future<void> play()
Future<void> pause()
Future<void> seek(Duration position)
Future<void> seekNSecForward(Duration n)
Future<void> seekNSecBackward(Duration n)
Future<void> skipToNext()
Future<void> skipToPrevious()
```

3. **Queue Management:**
```dart
Future<void> loadPlaylist(MediaPlaylist mediaList, {int idx, bool doPlay, bool shuffling})
Future<void> updateQueue(List<MediaItemModel> songs, {doPlay, idx})
Future<void> addQueueItem(MediaItem mediaItem)
Future<void> addQueueItems(List<MediaItem> mediaItems, {bool atLast})
Future<void> removeQueueItemAt(int index)
```

4. **Loop Modes:**
   - `LoopMode.off`: No repeat
   - `LoopMode.one`: Repeat current song
   - `LoopMode.all`: Repeat queue

5. **Recently Played Tracking:**
```dart
// Configurable thresholds
void setRecentlyPlayedThresholdSeconds(int seconds)  // Default: 15s
void setRecentlyPlayedPercentThreshold(double percent)  // Default: 40%
```

6. **Error Recovery:**
   - Automatic retry on playback errors
   - Skip to next on persistent failures
   - Error categorization (network, source, playback, buffering, permission)

---

## Musify Player

### Audio Handler
**File:** `lib/services/audio_service.dart`

```dart
class MusifyAudioHandler extends BaseAudioHandler {
  final AudioPlayer audioPlayer = AudioPlayer(
    audioLoadConfiguration: AudioLoadConfiguration(
      androidLoadControl: AndroidLoadControl(
        maxBufferDuration: Duration(seconds: 60),
        bufferForPlaybackDuration: Duration(milliseconds: 500),
        bufferForPlaybackAfterRebufferDuration: Duration(seconds: 3),
      ),
    ),
  );
  
  // Queue management
  final List<Map> _queueList = [];
  final List<Map> _originalQueueList = [];
  final List<Map> _historyList = [];
  
  // Error handling
  static const int _maxConsecutiveErrors = 3;
  static const Duration _errorRetryDelay = Duration(seconds: 2);
  
  // Preloading
  static const int _queueLookahead = 3;
  static const int _maxConcurrentPreloads = 2;
}
```

### Key Features:

1. **Smart Preloading:**
```dart
// Preloads next 3 songs for seamless playback
static const int _queueLookahead = 3;
static const int _maxConcurrentPreloads = 2;
```

2. **Audio Quality Selection:**
```dart
AudioStreamInfo selectAudioQuality(List<AudioStreamInfo> availableSources) {
  final qualitySetting = audioQualitySetting.value;
  if (qualitySetting == 'low') return availableSources.last;
  if (qualitySetting == 'medium') return availableSources[length ~/ 2];
  return availableSources.withHighestBitrate();  // high
}
```

3. **Stream URL Caching:**
```dart
// 3-hour cache with validation
const _cacheDuration = Duration(hours: 3);
// HEAD request validation for URLs older than 1 hour
```

4. **SponsorBlock Integration:**
```dart
Future<List<Map<String, int>>> getSkipSegments(String id) async {
  // Categories: sponsor, selfpromo, interaction, intro, outro, music_offtopic
}
```

5. **Sleep Timer:**
```dart
Timer? _sleepTimer;
bool sleepTimerExpired = false;
```

6. **Repeat Modes:**
```dart
enum AudioServiceRepeatMode { none, one, all }
```

---

# Playlist Management

## BloomeeTunes Playlists

### Data Models
**File:** `lib/model/MediaPlaylistModel.dart`

```dart
class MediaPlaylist {
  String playlistName;
  List<MediaItemModel> mediaItems;
  String? artURL;
  String? description;
  String? permaURL;
  String? source;
  String? artists;
}
```

### Database Operations
**File:** `lib/services/db/bloomee_db_service.dart`

```dart
// Standard playlists
static const downloadPlaylist = '_DOWNLOADS';
static const recentlyPlayedPlaylist = 'recently_played';
static const likedPlaylist = 'Liked';

// Playlist operations
static Future<void> addPlaylist(MediaPlaylist mediaPlaylist)
static Future<MediaPlaylist?> getPlaylist(String playlistName)
static Future<List<MediaPlaylist>> getAllPlaylists()
static Future<void> removePlaylist(String playlistName)
static Future<void> addToPlaylist(String playlistName, MediaItemModel mediaItem)
static Future<void> removeFromPlaylist(String playlistName, MediaItemModel mediaItem)
static Future<void> reorderPlaylist(String playlistName, int oldIndex, int newIndex)
```

### Playlist Features:
- Create custom playlists
- Import from Spotify
- Import from YouTube
- Export/Import as JSON backup
- Reordering support
- Duplicate detection

### BLoC Management
**File:** `lib/blocs/library/cubit/library_items_cubit.dart`

---

## Musify Playlists

### Data Structures
**File:** `lib/API/musify.dart`

```dart
// Global playlist state
final userPlaylists = ValueNotifier<List>([]);        // YouTube playlist IDs
final userCustomPlaylists = ValueNotifier<List>([]);  // User-created playlists
final userPlaylistFolders = ValueNotifier<List>([]);  // Folder organization
List userLikedSongsList = [];
List userRecentlyPlayed = [];
List userOfflineSongs = [];
```

### Playlist Operations

```dart
// User YouTube Playlists
Future<List<dynamic>> getUserPlaylists()
Future<String> addUserPlaylist(String input, BuildContext context)
void removeUserPlaylist(String playlistId)

// Custom Playlists
String createCustomPlaylist(String name, String? image, BuildContext context)
String addSongInCustomPlaylist(context, playlistName, Map song, {int? indexToInsert})
bool removeSongFromPlaylist(Map playlist, Map songToRemove, {int? removeOneAtIndex})

// Playlist Folders
String createPlaylistFolder(String folderName, [BuildContext? context])
String movePlaylistToFolder(Map playlist, String? folderId, BuildContext context)
String deletePlaylistFolder(String folderId, [BuildContext? context])
List<Map> getPlaylistsInFolder(String folderId)
List<Map> getPlaylistsNotInFolders()
```

### Playlist Features:
- Import YouTube playlists by URL/ID
- Create custom playlists with images
- Folder organization for playlists
- Song reordering within playlists
- Song renaming in playlists
- Playlist update/refresh

---

# Download & Offline Functionality

## BloomeeTunes Download System

### Download Cubit
**File:** `lib/blocs/downloader/cubit/downloader_cubit.dart`

```dart
class DownloaderCubit extends Cubit<DownloaderState> {
  final DownloadEngine _downloadEngine = DownloadEngine();
  final List<DownloadProgress> _activeDownloads = [];
  final YoutubeExplode _yt = YoutubeExplode();
  
  Future<void> downloadSong(MediaItemModel song, {bool showSnackbar = true})
}
```

### Download Flow:
1. Check internet connectivity
2. Check if already downloaded (DB + file exists)
3. Check if already in queue
4. Resolve stream URL from source
5. Download audio file
6. Apply metadata (using `metadata_god`)
7. Save to database
8. Update library

### Download Features:
- Queue management
- Progress tracking
- Metadata embedding
- Duplicate detection
- Stale record cleanup
- Configurable download directory

### Download States:
```dart
enum DownloadState { queued, downloading, completed, failed }

class DownloadProgress {
  final DownloadTask task;
  final DownloadStatus status;
}
```

---

## Musify Offline System

### Offline Playlist Service
**File:** `lib/services/playlist_download_service.dart`

```dart
class OfflinePlaylistService {
  // Progress tracking per playlist
  final Map<String, ValueNotifier<DownloadProgress>> downloadProgressNotifiers = {};
  final List<String> activeDownloads = [];
  final offlinePlaylists = ValueNotifier<List<dynamic>>([]);
  
  Future<void> downloadPlaylist(BuildContext context, Map playlist)
  bool isPlaylistDownloaded(String playlistId)
  bool isPlaylistDownloading(String playlistId)
}
```

### Single Song Offline
**File:** `lib/API/musify.dart`

```dart
Future<bool> makeSongOffline(dynamic song, {bool fromPlaylist = false}) async {
  // Download audio stream
  // Save artwork
  // Update song metadata
  // Add to offline songs list
}

bool isSongAlreadyOffline(songIdToCheck)
```

### Download Features:
- Parallel downloads (max 3 concurrent)
- Playlist-level progress tracking
- Individual song progress
- Cancellation support
- Resume capability
- Timeout handling (2 min per song)
- File path management with custom FilePaths class

---

# Recommendations System

## BloomeeTunes Recommendations

### Related Songs Manager
**File:** `lib/services/player/related_songs_manager.dart`

```dart
class RelatedSongsManager {
  BehaviorSubject<List<MediaItem>> relatedSongs;
  
  Future<void> checkForRelatedSongs({
    required MediaItem currentMedia,
    required List<MediaItem> queue,
    required int currentPlayingIdx,
    required LoopMode loopMode,
  })
}
```

### Features:
- Auto-loads related songs when queue is about to end
- Uses YouTube's related videos API
- JioSaavn recommendations (`getReco` endpoint)
- Throttled checks (every 5 seconds)

### Explore/Charts
**File:** `lib/blocs/explore/cubit/explore_cubits.dart`

```dart
class TrendingCubit extends Cubit<TrendingCubitState> {
  void getTrendingVideos()  // Fetches trending music videos
}

class ChartCubit extends Cubit<ChartState> {
  // Supports multiple chart sources
}
```

---

## Musify Recommendations

### Recommendation Engine
**File:** `lib/API/musify.dart`

```dart
Future<List> getRecommendedSongs() async {
  if (externalRecommendations.value && userRecentlyPlayed.isNotEmpty) {
    return await _getRecommendationsFromRecentlyPlayed();
  } else {
    return await _getRecommendationsFromMixedSources();
  }
}
```

### External Recommendations (Based on history):
```dart
Future<List> _getRecommendationsFromRecentlyPlayed() async {
  final recent = userRecentlyPlayed.take(3).toList();
  // Get related videos for each recent song
  // Combine and shuffle
  // Return max 15 songs
}
```

### Mixed Source Recommendations:
```dart
Future<List> _getRecommendationsFromMixedSources() async {
  // Combine: liked songs + recently played + global playlist + custom playlists
  // Deduplicate and shuffle
  // Return max 15 songs
}
```

### Similar Song Feature:
```dart
Future<void> getSimilarSong(String songYtId) async {
  // Gets next recommended song for auto-play
}
```

---

# Lyrics Integration

## BloomeeTunes Lyrics

### Lyrics Repository
**File:** `lib/repository/Lyrics/lyrics.dart`

```dart
class LyricsRepository {
  static Future<Lyrics> getLyrics(
    String title,
    String artist, {
    String? album,
    Duration? duration,
    LyricsProvider provider = LyricsProvider.none,
  })
  
  static Future<List<Lyrics>> searchLyrics(...)
}
```

### LRC.net API Integration
**File:** `lib/repository/Lyrics/lrcnet_api.dart`
- Synced lyrics support (LRC format)
- Multiple search results
- Album/duration matching

### Lyrics Cubit
**File:** `lib/blocs/lyrics/lyrics_cubit.dart`
- Automatic lyrics fetching on song change
- Caching in database
- Manual lyrics search

### Lyrics Model:
```dart
class Lyrics {
  String? plainLyrics;
  String? syncedLyrics;  // LRC format with timestamps
  LyricsProvider provider;
}
```

---

## Musify Lyrics

### Lyrics Manager
**File:** `lib/services/lyrics_manager.dart`

```dart
class LyricsManager {
  Future<String?> fetchLyrics(String artistName, String title) async {
    // Try Google search first
    final lyricsFromGoogle = await _fetchLyricsFromGoogle(artistName, title);
    if (lyricsFromGoogle != null) return lyricsFromGoogle;
    
    // Fallback to paroles.net
    final lyricsFromParolesNet = await _fetchLyricsFromParolesNet(...);
    if (lyricsFromParolesNet != null) return lyricsFromParolesNet;
    
    // Final fallback to lyricsmania
    return await _fetchLyricsFromLyricsMania1(...);
  }
}
```

### Lyrics Sources (in priority order):
1. **Google Search** - Parses lyrics from search results
2. **Paroles.net** - French lyrics database
3. **LyricsMania** - General lyrics database

### Lyrics State:
```dart
final lyrics = ValueNotifier<String?>(null);
String? lastFetchedLyrics;  // Cache check
```

---

# History & Recently Played

## BloomeeTunes History

### Recently Played Tracker
**File:** `lib/services/player/recently_played_tracker.dart`

```dart
class RecentlyPlayedTracker {
  int _thresholdSeconds = 15;
  double _percentThreshold = 0.4;  // 40%
  
  // Tracks continuous playback time
  // Adds to history only after threshold met
}
```

### Database Operations:
```dart
static Future<void> addToRecentlyPlayed(MediaItemModel mediaItem)
static Future<MediaPlaylist> getRecentlyPlayed({int limit = 50})
static Future<void> refreshRecentlyPlayed()  // Removes invalid entries
```

### Recently Cubit:
```dart
class RecentlyCubit extends Cubit<RecentlyCubitState> {
  void getRecentlyPlayed()
  Future<void> watchRecentlyPlayed()  // Real-time updates
}
```

---

## Musify History

### History Management
**File:** `lib/API/musify.dart`

```dart
List userRecentlyPlayed = Hive.box('user').get('recentlyPlayedSongs', defaultValue: []);
final currentRecentlyPlayedLength = ValueNotifier<int>(userRecentlyPlayed.length);

Future<void> updateRecentlyPlayed(String visId) async {
  // Adds song to history
  // Limits to max 100 entries
  // Removes duplicates
}
```

### Features:
- Max 100 entries
- Duplicate prevention
- Persistent storage in Hive
- Length notifier for UI updates

---

# Settings & Preferences

## BloomeeTunes Settings

### Settings Cubit
**File:** `lib/blocs/settings_cubit/cubit/settings_cubit.dart`

### Available Settings:
| Setting | Storage Key | Description |
|---------|-------------|-------------|
| Download Path | `downPathSetting` | Custom download directory |
| YouTube Quality | `ytQuality` | Audio quality (Low/High) |
| Backup Path | `backupPath` | Backup file location |
| Last.fm Keys | `lFMUsername`, `lFMApiKey`, `lFMSecret`, `lFMSession` | Scrobbling auth |

### Database Settings Types:
```dart
// Boolean settings
class AppSettingsBoolDB {
  String settingName;
  bool settingValue;
}

// String settings
class AppSettingsStrDB {
  String settingName;
  String settingValue;
}
```

---

## Musify Settings

### Settings Manager
**File:** `lib/services/settings_manager.dart`

```dart
// Preference ValueNotifiers
final shouldWeCheckUpdates = ValueNotifier<bool?>(null);
final playNextSongAutomatically = ValueNotifier<bool>(false);
final useSystemColor = ValueNotifier<bool>(true);
final usePureBlackColor = ValueNotifier<bool>(false);
final offlineMode = ValueNotifier<bool>(false);
final predictiveBack = ValueNotifier<bool>(false);
final sponsorBlockSupport = ValueNotifier<bool>(false);
final externalRecommendations = ValueNotifier<bool>(false);
final useProxy = ValueNotifier<bool>(false);
final audioQualitySetting = ValueNotifier<String>('high');
final shuffleNotifier = ValueNotifier<bool>(false);
final repeatNotifier = ValueNotifier<AudioServiceRepeatMode>(...);
```

### Settings Categories:
1. **Playback:**
   - Auto-play next song
   - Audio quality (low/medium/high)
   - Shuffle/Repeat persistence

2. **Appearance:**
   - Theme mode (light/dark/system)
   - System color (Material You)
   - Pure black mode
   - Accent color

3. **Localization:**
   - 22+ languages supported

4. **Privacy/Network:**
   - Proxy support
   - Offline mode

5. **Features:**
   - SponsorBlock
   - External recommendations
   - Update checks

---

# Data Storage & Persistence

## BloomeeTunes - Isar Database

### Database Schema
**File:** `lib/services/db/GlobalDB.dart`

```dart
@Collection()
class MediaPlaylistDB {
  Id? isarId;
  String playlistName;
  List<MediaItemDB> mediaItems;
}

@Collection()
class MediaItemDB {
  String title;
  String artist;
  String album;
  String artURL;
  String id;
  String source;
  Map<String, dynamic>? extras;
}

@Collection()
class RecentlyPlayedDB { ... }

@Collection()
class ChartsCacheDB { ... }

@Collection()
class YtLinkCacheDB { ... }

@Collection()
class NotificationDB { ... }

@Collection()
class DownloadDB { ... }

@Collection()
class PlaylistsInfoDB { ... }

@Collection()
class SavedCollectionsDB { ... }

@Collection()
class LyricsDB { ... }

@Collection()
class SearchHistoryDB { ... }
```

### Backup System:
```dart
static Future<String?> createBackUp()
static Future<Map<String, dynamic>> restoreDB(String? path, {...})
static Future<bool> backupExists()
```

### Backup Format (JSON):
```json
{
  "_meta": {
    "generated_by": "Bloomee",
    "version": "...",
    "created_at": "ISO8601"
  },
  "b_settings": [...],
  "s_settings": [...],
  "playlists": [...],
  "search_history": [...],
  "saved_collections": [...],
  "media_items": [...]
}
```

---

## Musify - Hive Database

### Box Organization:
```dart
// User data
Hive.box('user')
  - playlists: List<String>        // YouTube playlist IDs
  - customPlaylists: List<Map>     // User-created playlists
  - playlistFolders: List<Map>     // Folder structure
  - likedSongs: List<Map>          // Liked songs
  - recentlyPlayedSongs: List<Map> // History
  - searchHistory: List<String>    // Search queries
  - likedPlaylists: List<Map>      // Liked playlists

// User data (no backup)
Hive.box('userNoBackup')
  - offlineSongs: List<Map>        // Downloaded songs
  - offlinePlaylists: List<Map>    // Downloaded playlists

// Settings
Hive.box('settings')
  - All preference values

// Cache
Hive.box('cache')
  - Song URLs with timestamps
  - Playlist songs
```

### Data Manager Caching:
```dart
// Cache durations
const Duration songCacheDuration = Duration(hours: 1, minutes: 30);
const Duration playlistCacheDuration = Duration(hours: 5);
const Duration searchCacheDuration = Duration(days: 4);
const Duration defaultCacheDuration = Duration(days: 7);

// In-memory cache
final _memoryCache = <String, _CacheEntry>{};
const int _maxMemoryCacheSize = 500;
```

---

# Platform Support

## BloomeeTunes Platforms

| Platform | Status | Audio Backend |
|----------|--------|---------------|
| Android | ✅ Full | just_audio (native) |
| iOS | ✅ Full | just_audio (native) |
| Windows | ✅ Full | just_audio_media_kit |
| Linux | ✅ Full | just_audio_media_kit + MPRIS |
| macOS | ✅ Full | just_audio_media_kit |
| Web | ✅ Full | just_audio (web) |

### Platform-Specific:
- **Windows:** `audio_service_win` for system integration
- **Linux:** `audio_service_mpris` for media controls
- **Desktop:** `media_kit_libs_*` for audio codec support

---

## Musify Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Android | ✅ Full | Primary platform |
| iOS | ✅ Full | Supported |
| Windows | ⚠️ Partial | Basic support |
| Linux | ⚠️ Partial | Basic support |
| macOS | ⚠️ Partial | Basic support |
| Web | ❌ No | Not supported |

### F-Droid Build:
**File:** `lib/main_fdroid.dart`
- Separate entry point for F-Droid
- `isFdroidBuild = true` flag

---

# External Integrations

## BloomeeTunes Integrations

### 1. Last.fm Scrobbling
**File:** `lib/blocs/lastdotfm/lastdotfm_cubit.dart`

```dart
class LastdotfmCubit extends Cubit<LastdotfmState> {
  // Scrobbling requirements:
  // - 30 seconds played OR 50% of track
  
  Future<bool> scrobble(MediaItemModel mediaItem)
  Future<void> fetchSessionkey({token, secret, apiKey})
  Future<bool> updateNowPlaying(MediaItemModel mediaItem)
}
```

### 2. Discord Rich Presence
**File:** `lib/services/discord_service.dart`

```dart
class DiscordService {
  static void updatePresence({MediaItem? mediaItem, bool isPlaying})
}
```

### 3. External URL Handling
**File:** `lib/main.dart`

```dart
void processIncomingIntent(SharedMedia sharedMedia) {
  // Handles shared URLs:
  // - Spotify tracks/playlists/albums
  // - YouTube videos/playlists
  // - Import files
}
```

---

## Musify Integrations

### 1. SponsorBlock
**File:** `lib/API/musify.dart`

```dart
Future<List<Map<String, int>>> getSkipSegments(String id) async {
  // Categories skipped:
  // - sponsor, selfpromo, interaction
  // - intro, outro, music_offtopic
}
```

### 2. Proxy Support
**File:** `lib/services/proxy_manager.dart`

```dart
class ProxyManager {
  YoutubeExplode getClientSync()
  Future<YoutubeExplode?> getYoutubeExplodeClient()
  Future<StreamManifest?> getSongManifest(String songId)
}
```

### 3. Deep Links
**File:** `lib/main.dart`

```dart
final appLinks = AppLinks();
// Handles incoming URLs for playlist/song sharing
```

### 4. Playlist Sharing
**File:** `lib/services/playlist_sharing.dart`
- Export/Import playlists
- Share playlist links

---

# UI/UX Architecture

## BloomeeTunes UI Structure

### Screens:
```
screens/
├── screen/
│   ├── explore_screen.dart      # Home/Discover
│   ├── search_screen.dart       # Search
│   ├── library_screen.dart      # Library
│   ├── player_screen.dart       # Now Playing
│   ├── offline_screen.dart      # Downloads
│   ├── test_screen.dart         # Debug
│   ├── chart/                   # Charts views
│   ├── common_views/            # Shared views
│   ├── home_views/              # Home sections
│   ├── library_views/           # Library sections
│   ├── offline_views/           # Offline sections
│   ├── player_views/            # Player components
│   └── search_views/            # Search results
└── widgets/                     # Reusable widgets
```

### Navigation:
- `go_router` for declarative routing
- Bottom navigation bar
- Sliding up panel for mini player
- Full-screen player overlay

### Responsive Design:
- `responsive_framework` integration
- Adaptive layouts for tablets
- Desktop window management

---

## Musify UI Structure

### Screens (10 main pages):
```
screens/
├── about_page.dart              # App info
├── bottom_navigation_page.dart  # Main container
├── home_page.dart               # Home/Recommendations
├── library_page.dart            # Library
├── now_playing_page.dart        # Now Playing
├── playlist_folder_page.dart    # Folder contents
├── playlist_page.dart           # Playlist view
├── search_page.dart             # Search
├── settings_page.dart           # Settings
└── user_songs_page.dart         # Liked/Offline songs
```

### Theming:
**File:** `lib/style/app_themes.dart`
- Material Design 3
- Dynamic color (Material You)
- Pure black mode option
- Custom accent colors

### Navigation:
- `go_router` for routing
- Bottom navigation (4 tabs: Home, Search, Library, Settings)
- Full-screen now playing page

---

# Feature Comparison Matrix

| Feature | BloomeeTunes | Musify |
|---------|--------------|--------|
| **Music Sources** | YouTube, YT Music, JioSaavn | YouTube only |
| **Spotify Import** | ✅ OAuth + Playlist import | ❌ |
| **State Management** | BLoC/Cubit | ValueNotifier |
| **Database** | Isar (NoSQL) | Hive (Key-Value) |
| **Localization** | Limited | 22+ languages |
| **Lyrics** | Synced (LRC) + Plain | Plain only |
| **Last.fm** | ✅ Full scrobbling | ❌ |
| **Discord RPC** | ✅ | ❌ |
| **SponsorBlock** | ❌ | ✅ |
| **Proxy Support** | ❌ | ✅ |
| **Offline Mode** | ✅ | ✅ |
| **Playlist Folders** | ❌ | ✅ |
| **Sleep Timer** | ✅ | ✅ |
| **Audio Quality** | Low/High | Low/Medium/High |
| **Material You** | ❌ | ✅ |
| **Web Support** | ✅ | ❌ |
| **Desktop Support** | ✅ Full | ⚠️ Partial |
| **Keyboard Shortcuts** | ✅ | ❌ |
| **Backup/Restore** | ✅ JSON | ⚠️ Limited |
| **Charts/Trending** | ✅ Multiple sources | ❌ |
| **Related Songs Auto-queue** | ✅ | ✅ |
| **F-Droid Build** | ❌ | ✅ |

---

# Summary

## BloomeeTunes Strengths:
1. Multi-source music aggregation
2. Robust BLoC architecture
3. Full cross-platform support
4. Last.fm & Discord integrations
5. Synced lyrics support
6. Comprehensive backup system
7. Charts from multiple sources
8. Keyboard shortcuts for desktop

## Musify Strengths:
1. Clean, simple architecture
2. Extensive localization (22+ languages)
3. SponsorBlock integration
4. Proxy support for restricted regions
5. Playlist folder organization
6. Material You theming
7. Audio quality options
8. F-Droid availability

## Recommended Use Cases:

**Choose BloomeeTunes if:**
- You need access to Indian music (JioSaavn)
- You want Spotify playlist import
- You use Last.fm for scrobbling
- You need Discord presence
- You primarily use desktop
- You want synced lyrics

**Choose Musify if:**
- You prefer a simpler YouTube-only experience
- You need extensive language support
- You're in a region requiring proxy
- You want SponsorBlock ad-skipping
- You want Material You theming
- You prefer F-Droid installation

---

*Documentation generated on January 4, 2026*
*Based on BloomeeTunes v2.13.3 and Musify v9.7.4*

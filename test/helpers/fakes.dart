import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prism_music/core/di/injection.dart';
import 'package:prism_music/core/error/failures.dart';
import 'package:prism_music/core/services/audio_focus_orchestrator_service.dart';
import 'package:prism_music/core/services/audio_player_service.dart';
import 'package:prism_music/core/services/download_service.dart';
import 'package:prism_music/core/services/media_resolver_service.dart';
import 'package:prism_music/core/services/playback_reliability_service.dart';
import 'package:prism_music/core/services/recommendation_service.dart';
import 'package:prism_music/core/services/stream_loader_service.dart';
import 'package:prism_music/data/datasources/local/local_datasource.dart';
import 'package:prism_music/domain/entities/entities.dart';
import 'package:prism_music/domain/repositories/repositories.dart';
import 'package:prism_music/presentation/blocs/library/library_bloc.dart';
import 'package:prism_music/presentation/blocs/player/player_bloc.dart';
import 'package:prism_music/presentation/blocs/search/search_bloc.dart';
import 'package:prism_music/presentation/blocs/theme/theme_state.dart';

/// Canonical fakes shared across test files.
///
/// The codebase previously duplicated near-identical fakes per test file;
/// these are the single versions. Fakes extend behavior through public
/// fields — set them per test — and fall through to `noSuchMethod` so
/// untouched interface methods throw rather than silently pass.
///
/// All fakes are offline; nothing here touches the network.

// ---------------------------------------------------------------------------
// Builders
// ---------------------------------------------------------------------------

Song song(
  String id,
  String title, {
  String artist = 'Test Artist',
  Duration duration = const Duration(seconds: 200),
  MusicSource source = MusicSource.youtube,
  String? youtubeId,
}) =>
    Song(
      id: id,
      title: title,
      artist: artist,
      duration: duration,
      thumbnails: const Thumbnails(),
      source: source,
      youtubeId: youtubeId ?? id,
    );

Playlist playlist(
  String id,
  String name, {
  List<Song>? songs,
  bool isUserCreated = true,
  String? spotifyPlaylistId,
  String? youtubePlaylistId,
  String? description,
  Thumbnails? thumbnails,
}) =>
    Playlist(
      id: id,
      name: name,
      description: description,
      songs: songs ?? const [],
      trackCount: songs?.length ?? 0,
      isUserCreated: isUserCreated,
      spotifyPlaylistId: spotifyPlaylistId,
      youtubePlaylistId: youtubePlaylistId,
      thumbnails: thumbnails,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

StreamInfo streamInfo([String url = 'https://stream.example.com/audio']) =>
    StreamInfo(
      url: url,
      codec: 'aac',
      bitrate: 128,
      container: 'm4a',
      quality: AudioQuality.medium,
    );

// ---------------------------------------------------------------------------
// Repository fakes
// ---------------------------------------------------------------------------

/// [MusicRepository] fake with configurable search/import/lyrics/stream
/// behavior. Every call is recorded for assertions.
class FakeMusicRepository implements MusicRepository {
  // searchSongs
  int searchSongsCallCount = 0;
  String? lastSearchQuery;
  Either<Failure, List<Song>> searchResult = const Right([]);
  Either<Failure, List<Artist>> artistsResult = const Right([]);
  Either<Failure, List<Album>> albumsResult = const Right([]);
  Either<Failure, List<Playlist>> playlistsResult = const Right([]);
  Either<Failure, SearchResults> searchAllResult = const Right(SearchResults());

  // importSpotifyPlaylist / importYouTubePlaylist
  String? lastImportUrl;
  final List<double> importProgressValues = [];
  Either<Failure, Playlist> importResult =
      const Left(ParsingFailure(message: 'not configured'));

  // getLyrics
  int getLyricsCallCount = 0;
  int? lastLyricsDurationSeconds;
  bool lastLyricsForceRefresh = false;
  Either<Failure, Lyrics> lyricsResult =
      const Left(SearchFailure(message: 'Lyrics not found'));
  Duration lyricsDelay = Duration.zero;

  // getStreamUrl
  Either<Failure, StreamInfo> streamUrlResult =
      Right(streamInfo('https://stream.example.com/fallback'));

  int getStreamUrlCallCount = 0;
  String? lastStreamUrlSongId;

  // getTrending / getNewReleases (HomeTab loaders)
  Either<Failure, List<Song>> trendingResult = const Right([]);
  int trendingCallCount = 0;
  bool throwOnTrending = false;
  Either<Failure, List<Album>> newReleasesResult = const Right([]);

  bool throwOnSearch = false;

  @override
  Future<Either<Failure, List<Song>>> searchSongs(
    String query, {
    int limit = 20,
    String? filter,
  }) async {
    if (throwOnSearch) throw Exception('network down');
    searchSongsCallCount++;
    lastSearchQuery = query;
    return searchResult;
  }

  @override
  Future<Either<Failure, List<Artist>>> searchArtists(
    String query, {
    int limit = 20,
  }) async {
    searchSongsCallCount++;
    lastSearchQuery = query;
    return artistsResult;
  }

  @override
  Future<Either<Failure, List<Album>>> searchAlbums(
    String query, {
    int limit = 20,
  }) async {
    searchSongsCallCount++;
    lastSearchQuery = query;
    return albumsResult;
  }

  @override
  Future<Either<Failure, List<Playlist>>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    searchSongsCallCount++;
    lastSearchQuery = query;
    return playlistsResult;
  }

  @override
  Future<Either<Failure, SearchResults>> searchAll(
    String query, {
    int limit = 10,
  }) async {
    searchSongsCallCount++;
    lastSearchQuery = query;
    return searchAllResult;
  }

  @override
  Future<Either<Failure, Playlist>> importSpotifyPlaylist(
    String playlistUrl, {
    void Function(double progress)? onProgress,
  }) async {
    return _import(playlistUrl, onProgress);
  }

  @override
  Future<Either<Failure, Playlist>> importYouTubePlaylist(
    String playlistUrl,
  ) async {
    return _import(playlistUrl, null);
  }

  Either<Failure, Playlist> _import(
    String playlistUrl,
    void Function(double progress)? onProgress,
  ) {
    lastImportUrl = playlistUrl;
    importProgressValues.addAll([0.0, 0.5, 1.0]);
    onProgress?.call(0.0);
    onProgress?.call(0.5);
    onProgress?.call(1.0);
    return importResult;
  }

  @override
  Future<Either<Failure, Lyrics>> getLyrics(
    String songTitle,
    String artistName, {
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    getLyricsCallCount++;
    lastLyricsDurationSeconds = duration?.inSeconds;
    lastLyricsForceRefresh = forceRefresh;
    if (lyricsDelay > Duration.zero) {
      await Future<void>.delayed(lyricsDelay);
    }
    return lyricsResult;
  }

  @override
  Future<Either<Failure, StreamInfo>> getStreamUrl(
    String songId, {
    bool forceRefresh = false,
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    getStreamUrlCallCount++;
    lastStreamUrlSongId = songId;
    return streamUrlResult;
  }

  @override
  Future<Either<Failure, List<Song>>> getTrending({
    String region = 'US',
    int limit = 50,
  }) async {
    trendingCallCount++;
    if (throwOnTrending) throw Exception('trending down');
    return trendingResult;
  }

  @override
  Future<Either<Failure, List<Album>>> getNewReleases({int limit = 20}) async {
    return newReleasesResult;
  }

  Either<Failure, Album> albumResult = const Right(
    Album(
      id: 'album-1',
      title: 'Test Album',
      artist: 'Test Artist',
      thumbnails: Thumbnails(),
    ),
  );
  String? lastAlbumIdRequested;

  @override
  Future<Either<Failure, Album>> getAlbumDetails(String albumId) async {
    lastAlbumIdRequested = albumId;
    return albumResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [LibraryRepository] fake with canned library contents and recorded
/// mutations.
class FakeLibraryRepository implements LibraryRepository {
  List<Song> likedSongs = const [];
  List<Playlist> playlists = const [];
  List<Song> history = const [];
  List<Song> recentlyPlayed = const [];
  List<Song> downloads = const [];
  ListeningStats? stats;

  bool failLoad = false;
  bool failLikedSongs = false;
  bool failPlaylists = false;
  bool failHistory = false;
  bool failRecentlyPlayed = false;
  bool failDownloads = false;
  bool failStats = false;
  Either<Failure, Playlist> createPlaylistResult = Left(
    const UnknownFailure(message: 'not configured'),
  );

  // Recorded mutations
  final List<String> createdPlaylistNames = [];
  final Map<String, List<Song>> songsAddedByPlaylist = {};
  final Map<String, List<Song>> playlistSongsUpdated = {};
  final List<String> deletedPlaylistIds = [];
  final List<String> removedSongKeys = [];
  final List<Song> likedSaved = [];
  final List<String> unlikedIds = [];
  final List<Song> historyAdded = [];
  final Map<String, String> downloadsSaved = {};

  @override
  Future<Either<Failure, List<Song>>> getLikedSongs() async {
    if (failLoad || failLikedSongs) return const Left(UnknownFailure(message: 'liked load failed'));
    return Right(likedSongs);
  }

  @override
  Future<Either<Failure, List<Playlist>>> getUserPlaylists() async {
    if (failLoad || failPlaylists) return const Left(UnknownFailure(message: 'playlists load failed'));
    return Right(playlists);
  }

  @override
  Future<Either<Failure, List<Song>>> getListeningHistory({
    int limit = 50,
    DateTime? since,
  }) async {
    if (failLoad || failHistory) return const Left(UnknownFailure(message: 'history load failed'));
    return Right(history);
  }

  @override
  Future<Either<Failure, List<Song>>> getRecentlyPlayed({
    int limit = 20,
  }) async {
    if (failLoad || failRecentlyPlayed) return const Left(UnknownFailure(message: 'recent load failed'));
    return Right(recentlyPlayed);
  }

  @override
  Future<Either<Failure, List<Song>>> getDownloadedSongs() async {
    if (failLoad || failDownloads) return const Left(UnknownFailure(message: 'downloads load failed'));
    return Right(downloads);
  }

  @override
  Future<Either<Failure, ListeningStats>> getListeningStats() async {
    if (failLoad || failStats) return const Left(UnknownFailure(message: 'stats load failed'));
    return Right(stats ?? const ListeningStats(totalPlays: 0, uniqueSongs: 0));
  }

  @override
  Future<Either<Failure, Playlist>> createPlaylist(
    String name, {
    String? description,
  }) async {
    createdPlaylistNames.add(name);
    return createPlaylistResult;
  }

  Either<Failure, Playlist>? saveImportedPlaylistResult;
  final List<Playlist> savedImportedPlaylists = [];

  @override
  Future<Either<Failure, Playlist>> saveImportedPlaylist(Playlist playlist) async {
    savedImportedPlaylists.add(playlist);
    if (saveImportedPlaylistResult != null) {
      return saveImportedPlaylistResult!;
    }
    final isExisting = playlists.any((p) => p.id == playlist.id);
    if (isExisting) {
      final songs = (playlist.songs ?? const []).toList();
      playlistSongsUpdated[playlist.id] = songs;
      return Right(playlist);
    } else {
      createdPlaylistNames.add(playlist.name);
      final id = createPlaylistResult.fold(
        (_) => playlist.id.isNotEmpty ? playlist.id : 'local_${savedImportedPlaylists.length}',
        (c) => c.id,
      );
      final songs = (playlist.songs ?? const []).toList();
      songsAddedByPlaylist[id] = songs;
      playlistSongsUpdated[id] = songs;
      return Right(playlist.copyWith(id: id));
    }
  }

  @override
  Future<Either<Failure, void>> addSongToPlaylist(
    String playlistId,
    Song song,
  ) async {
    (songsAddedByPlaylist[playlistId] ??= []).add(song);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updatePlaylistSongs(
    String playlistId,
    List<Song> songs,
  ) async {
    playlistSongsUpdated[playlistId] = songs;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deletePlaylist(String playlistId) async {
    deletedPlaylistIds.add(playlistId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> removeSongFromPlaylist(
    String playlistId,
    String songId,
  ) async {
    removedSongKeys.add('$playlistId/$songId');
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> likeSong(Song song) async {
    likedSaved.add(song);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> unlikeSong(String songId) async {
    unlikedIds.add(songId);
    return const Right(null);
  }

  @override
  Future<bool> isSongLiked(String songId) => Future.value(false);

  @override
  Future<Either<Failure, void>> addToHistory(Song song) async {
    historyAdded.add(song);
    return const Right(null);
  }

  @override
  Future<Either<Failure, String>> downloadSong(
    Song song,
    String streamUrl, {
    void Function(double progress)? onProgress,
  }) async {
    downloadsSaved[song.id] = streamUrl;
    return Right('/tmp/downloads/${song.id}.m4a');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// [LocalDataSource] fake covering the search-history surface SearchBloc
/// uses. Entry shape matches the real Hive implementation
/// (`id`/`query`/`timestamp`).
class FakeLocalDataSource implements LocalDataSource {
  final Map<String, String> historyRows = {
    'h1': 'older query',
    'h2': 'newer query',
  };

  @override
  Future<void> addSearchHistory(String query) async {
    historyRows['h${historyRows.length + 1}'] = query;
  }

  @override
  Future<List<Map<String, String>>> getSearchHistory({int limit = 20}) async {
    // Real implementation sorts keys descending (newest first).
    final keys = historyRows.keys.toList()
      ..sort((a, b) => b.compareTo(a));
    return [
      for (final key in keys.take(limit))
        {'id': key, 'query': historyRows[key]!, 'timestamp': '2026-01-01'},
    ];
  }

  @override
  Future<List<Map<String, String>>> getSimilarSearches(
    String query, {
    int limit = 5,
  }) async {
    final lower = query.toLowerCase();
    return [
      for (final entry in historyRows.entries)
        if (entry.value.toLowerCase().contains(lower))
          {'id': entry.key, 'query': entry.value, 'timestamp': '2026-01-01'},
    ].take(limit).toList();
  }

  @override
  Future<void> clearSearchHistory() async {
    historyRows.clear();
  }

  @override
  Future<void> removeSearchHistory(String id) async {
    historyRows.remove(id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ---------------------------------------------------------------------------
// Audio-stack fakes (for constructing a real PlayerBloc offline)
// ---------------------------------------------------------------------------

class FakeAudioPlayerService implements AudioPlayerService {
  final _posCtrl = StreamController<Duration>.broadcast();
  final _bufCtrl = StreamController<Duration>.broadcast();
  final _durCtrl = StreamController<Duration?>.broadcast();
  final _playCtrl = StreamController<bool>.broadcast();
  final _bufferingCtrl = StreamController<bool>.broadcast();
  final _compCtrl = StreamController<bool>.broadcast();
  final _errCtrl = StreamController<String>.broadcast();
  final _idxCtrl = StreamController<int?>.broadcast();

  int playCalls = 0;
  int stopCalls = 0;
  final List<String> setUrls = [];
  bool isPlayingFlag = false;

  @override
  Stream<Duration> get positionStream => _posCtrl.stream;
  @override
  Stream<Duration> get bufferedPositionStream => _bufCtrl.stream;
  @override
  Stream<Duration?> get durationStream => _durCtrl.stream;
  @override
  Stream<bool> get playingStream => _playCtrl.stream;
  @override
  Stream<bool> get bufferingStream => _bufferingCtrl.stream;
  @override
  Stream<bool> get completedStream => _compCtrl.stream;
  @override
  Stream<String> get errorStream => _errCtrl.stream;
  @override
  Stream<int?> get currentIndexStream => _idxCtrl.stream;

  @override
  bool get playing => isPlayingFlag;
  @override
  bool get isQueueMode => false;

  @override
  Future<Duration?> setUrl(
    String url, {
    Map<String, String>? headers,
    String? videoId,
    String quality = 'high',
    String? title,
    String? artist,
    String? album,
    String? artworkUrl,
    Duration? mediaDuration,
    bool allowYouTubeFallbackOnDirectFailure = false,
  }) async {
    setUrls.add(url);
    if (url.contains('unplayable')) {
      _errCtrl.add('HTTP 403 Forbidden');
      return null;
    }
    return const Duration(seconds: 180);
  }

  @override
  Future<void> play() async {
    playCalls++;
    isPlayingFlag = true;
  }

  @override
  Future<void> stop() async {
    stopCalls++;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAudioFocusOrchestrator implements AudioFocusOrchestratorService {
  @override
  Future<void> initialize() async {}

  @override
  Future<bool> activateForPlayback() async => true;

  @override
  Future<void> keepAlive() async {}

  @override
  Future<void> deactivate() async {}

  @override
  void notifyUserPaused(bool paused) {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeMediaResolver implements MediaResolverService {
  @override
  Future<ResolvedMediaSource> resolveForPlayback(
    Song song, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    return ResolvedMediaSource(
      uri: 'https://stream.example.com/${song.id}',
      isOffline: false,
      videoId: song.id,
    );
  }

  @override
  ResolvedMediaSource? takePreResolved(String songId) => null;

  @override
  void preResolveSong(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}

  @override
  void invalidate(String songId) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeStreamLoader implements StreamLoaderService {
  @override
  void prefetch(Song song, {AudioQuality preferredQuality = AudioQuality.high}) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDownloadService implements DownloadService {
  @override
  bool isDownloaded(String songId) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Assemble a real [PlayerBloc] wired to offline fakes — the same recipe
/// the player bloc tests use, shared so widget tests can pump a real bloc
/// with fabricated states.
PlayerBloc buildTestPlayerBloc({
  FakeMusicRepository? musicRepository,
  FakeLibraryRepository? libraryRepository,
  FakeAudioPlayerService? audioPlayerService,
  FakeMediaResolver? mediaResolver,
  RecommendationService? recommendationService,
}) {
  ensureWidgetTestHive();
  return PlayerBloc(
      musicRepository: musicRepository ?? FakeMusicRepository(),
      libraryRepository: libraryRepository ?? FakeLibraryRepository(),
      audioPlayerService: audioPlayerService ?? FakeAudioPlayerService(),
      audioFocus: FakeAudioFocusOrchestrator(),
      mediaResolver: mediaResolver ?? FakeMediaResolver(),
      reliability: PlaybackReliabilityService(),
      streamLoader: FakeStreamLoader(),
      downloadService: FakeDownloadService(),
      recommendationService: recommendationService,
    );
}

// ---------------------------------------------------------------------------
// getIt registration for widget tests
// ---------------------------------------------------------------------------

/// Registers offline fakes into getIt for widget tests that read singletons
/// directly (HomeTab, PlayerLyricsView, ChartService, DownloadsPage).
///
/// `getIt` is empty inside tests (the real app registers everything in
/// main()), so tests may register freely; call `getIt.reset()` in tearDown.
void registerTestGetIt({
  FakeMusicRepository? musicRepository,
  FakeRecommendationService? recommendationService,
  FakeDownloadService? downloadService,
}) {
  musicRepository ??= FakeMusicRepository();
  recommendationService ??= FakeRecommendationService();
  downloadService ??= FakeDownloadService();

  getIt.registerSingleton<MusicRepository>(musicRepository);
  getIt.registerSingleton<RecommendationService>(recommendationService);
  getIt.registerSingleton<DownloadService>(downloadService);
}

/// A [RecommendationService] fake for HomeTab.
class FakeRecommendationService implements RecommendationService {
  int getRecommendationsCount = 0;
  bool throwOnGet = false;
  Song? lastCurrentSong;

  @override
  RecommendationMode get mode => RecommendationMode.similar;

  @override
  Future<List<Song>> getRecommendations({
    Song? currentSong,
    int limit = 10,
  }) async {
    getRecommendationsCount++;
    lastCurrentSong = currentSong;
    if (throwOnGet) throw Exception('recommendations down');
    return [
      song('rec_1', 'Recommended Song 1'),
      song('rec_2', 'Recommended Song 2'),
    ];
  }

  @override
  Future<void> recordPlay(Song song) async {}

  @override
  Future<void> dispose() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Hive bootstrap for tests: a unique temp dir per process, so parallel
/// or re-run test processes never contend on Windows Hive lock files.
void initTestHive(String suiteName) {
  final temp = Directory.systemTemp.createTempSync('prism_${suiteName}_hive');
  Hive.init(temp.path);
}

/// Poll until [condition] is true — bloc event chains complete
/// asynchronously (e.g. add-to-playlist triggers a full library reload).
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('waitFor condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

bool _widgetHiveReady = false;

/// Hive bootstrap for the widget-test harness (PlayerBloc's constructor
/// opens the settings box, so Hive must be initialized before building).
void ensureWidgetTestHive() {
  if (_widgetHiveReady) return;
  final temp = Directory.systemTemp.createTempSync('prism_widget_hive');
  Hive.init(temp.path);
  _widgetHiveReady = true;
}

// ---------------------------------------------------------------------------
// Widget-test harness
// ---------------------------------------------------------------------------

/// Wraps [child] in the app theme + bloc providers so pages pump without
/// the real audio stack or network.
///
/// Blocs passed in are owned by the caller (close them in tearDown);
/// unspecified ones are created on the fly with offline fakes.
Widget wrapForTests(
  Widget child, {
  Brightness brightness = Brightness.light,
  LibraryBloc? libraryBloc,
  PlayerBloc? playerBloc,
  SearchBloc? searchBloc,
}) {
  final themeState = const ThemeState();
  return MultiBlocProvider(
    providers: [
      BlocProvider<LibraryBloc>.value(
        value: libraryBloc ??
            LibraryBloc(
              libraryRepository: FakeLibraryRepository(),
              musicRepository: FakeMusicRepository(),
            ),
      ),
      BlocProvider<PlayerBloc>.value(value: playerBloc ?? buildTestPlayerBloc()),
      if (searchBloc != null) BlocProvider<SearchBloc>.value(value: searchBloc),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme:
          brightness == Brightness.light
              ? themeState.lightTheme
              : themeState.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

/// Pumps [child] at a fixed phone-sized surface so slivers build the same
/// way they would on a device (and off-screen slivers can be forced by
/// passing a taller [size]).
Future<void> pumpTestWidget(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  Size size = const Size(400, 900),
  LibraryBloc? libraryBloc,
  PlayerBloc? playerBloc,
  SearchBloc? searchBloc,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.reset();
  });
  await tester.pumpWidget(wrapForTests(
    child,
    brightness: brightness,
    libraryBloc: libraryBloc,
    playerBloc: playerBloc,
    searchBloc: searchBloc,
  ));
}

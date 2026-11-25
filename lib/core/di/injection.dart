import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/spotify/spotify_datasource.dart';
import '../../data/datasources/remote/apple_music/apple_music_datasource.dart';
import '../../data/datasources/remote/lyrics/lyrics_datasource.dart';
import '../../data/datasources/remote/lyrics/fallback_lyrics_provider.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../../data/datasources/local/local_datasource.dart';
import '../../presentation/blocs/player/player.dart';
import '../../presentation/blocs/search/search_bloc.dart';
import '../../presentation/blocs/library/library_bloc.dart';
import '../../presentation/blocs/theme/theme_bloc.dart';
import '../providers/innertube/innertube_stream_resolver.dart';
import '../providers/stream_resolvers.dart';
import '../services/audio_player_service.dart';
import '../services/youtube_audio_source.dart';
import '../services/audio_focus_orchestrator_service.dart';
import '../services/settings_service.dart';
import '../services/stream_cache_service.dart';
import '../services/stream_loader_service.dart';
import '../services/media_resolver_service.dart';
import '../services/playback_reliability_service.dart';
import '../services/download_service.dart';
import '../services/offline_mode_service.dart';
import '../services/ytmusic_api_service.dart';
import '../services/recommendation_service.dart';
import '../services/instance_health_service.dart';
import '../services/spotify_auth_service.dart';
import '../services/storage_service.dart';
import '../services/smart_playlist_service.dart';
import '../services/app_update_service.dart';
import '../services/audio_recognition_service.dart';
import '../services/deep_link_service.dart';
import '../services/dj_sequencer_service.dart';
import '../services/kids_mode_service.dart';
import '../services/music_video_service.dart';

/// Global service locator instance
final GetIt getIt = GetIt.instance;

/// Initialize all dependencies
Future<void> initializeDependencies() async {
  // ============ CORE ============
  
  // Dio HTTP Client
  getIt.registerLazySingleton<Dio>(() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      },
    ));
    
    // Add interceptors for logging and error handling (debug mode only)
    if (kDebugMode) {
      dio.interceptors.add(LogInterceptor(
        requestBody: false,
        responseBody: false,
        error: true,
      ));
    }
    
    return dio;
  });
  
  // Audio Player Service
  getIt.registerLazySingleton<AudioPlayerService>(
    () => AudioPlayerService(),
  );

  // Playback reliability policy (retry + circuit breaker)
  getIt.registerLazySingleton<PlaybackReliabilityService>(
    () => PlaybackReliabilityService(),
  );
  
  // Stream Cache Service - singleton for shared cache
  getIt.registerLazySingleton<StreamCacheService>(
    () => StreamCacheService(),
  );

  // Instance Health Service - tracks public Piped/Invidious instance latency and health
  getIt.registerLazySingleton<InstanceHealthService>(
    () => InstanceHealthService(),
  );

  // Storage Service - accurate storage metrics and cache management
  getIt.registerLazySingleton<StorageService>(
    () => StorageService(
      streamCacheService: getIt<StreamCacheService>(),
    ),
  );

  // ============ DATA SOURCES ============
  
  // Remote Data Sources
  getIt.registerLazySingleton<YouTubeMusicDataSource>(
    () => YouTubeMusicDataSourceImpl(
      cache: getIt<StreamCacheService>(),
    ),
  );

  getIt.registerLazySingleton<SpotifyAuthService>(
    () => SpotifyAuthService(
      dio: getIt<Dio>(),
      settingsService: SettingsService.instance,
    ),
  );

  getIt.registerLazySingleton<SpotifyDataSource>(
    () => SpotifyDataSourceImpl(
      dio: getIt<Dio>(),
      authService: getIt<SpotifyAuthService>(),
    ),
  );

  getIt.registerLazySingleton<AppleMusicDataSource>(
    () => AppleMusicDataSourceImpl(
      dio: getIt<Dio>(),
    ),
  );

  getIt.registerLazySingleton<LyricsDataSource>(
    () => LyricsDataSourceImpl(
      dio: getIt<Dio>(),
      fallbackProvider: LyricsOvhFallbackProvider(dio: getIt<Dio>()),
    ),
  );

  getIt.registerLazySingleton<JioSaavnDataSource>(
    () => JioSaavnDataSourceImpl(),
  );

  getIt.registerLazySingleton<YtMusicApiService>(
    () => YtMusicApiService(),
  );

  getIt.registerLazySingleton<MusicVideoService>(
    () => MusicVideoService(),
  );
  
  // Local Data Source
  getIt.registerLazySingleton<LocalDataSource>(
    () => LocalDataSourceImpl(),
  );
  
  // Stream Loader Service - depends on datasources, cache, and reliability policy
  getIt.registerLazySingleton<StreamLoaderService>(
    () => StreamLoaderService(
      getIt<YouTubeMusicDataSource>(),
      getIt<StreamCacheService>(),
      jioSaavn: getIt<JioSaavnDataSource>(),
      resolvers: [
        JioSaavnAudioStreamResolver(
          dataSource: getIt<JioSaavnDataSource>(),
        ),
        YouTubeExplodeAudioStreamResolver(
          dataSource: getIt<YouTubeMusicDataSource>(),
        ),
        InnerTubeStreamResolver(),
        PipedAudioStreamResolver(
          healthService: getIt<InstanceHealthService>(),
        ),
        InvidiousAudioStreamResolver(
          healthService: getIt<InstanceHealthService>(),
        ),
      ],
      reliability: getIt<PlaybackReliabilityService>(),
    ),
  );

  // ============ REPOSITORIES ============
  
  getIt.registerLazySingleton<MusicRepository>(
    () => MusicRepositoryImpl(
      youtubeMusicDataSource: getIt<YouTubeMusicDataSource>(),
      spotifyDataSource: getIt<SpotifyDataSource>(),
      appleMusicDataSource: getIt<AppleMusicDataSource>(),
      lyricsDataSource: getIt<LyricsDataSource>(),
      localDataSource: getIt<LocalDataSource>(),
      jioSaavnDataSource: getIt<JioSaavnDataSource>(),
      ytMusicApiService: getIt<YtMusicApiService>(),
    ),
  );

// Audio focus orchestration for interruptions/noisy events
   getIt.registerLazySingleton<AudioFocusOrchestratorService>(
     () => AudioFocusOrchestratorService(
       audioPlayer: getIt<AudioPlayerService>(),
       pausePlayback: () => getIt<AudioPlayerService>().pause(),
     ),
   );

getIt.registerLazySingleton<LibraryRepository>(
      () => LibraryRepositoryImpl(
        localDataSource: getIt<LocalDataSource>(),
        downloadService: getIt<DownloadService>(),
      ),
    );

   // Download Service (singleton) depends on MusicRepository
   {
     final downloadService = DownloadService(
       getIt<StreamLoaderService>(),
       settingsService: SettingsService.instance,
       lyricsDataSource: getIt<LyricsDataSource>(),
     );
     await downloadService.initialize();
     getIt.registerSingleton<DownloadService>(downloadService);
   }

   // Offline Mode Service (singleton)
   {
     final offlineModeService = OfflineModeService.instance;
     await offlineModeService.initialize();
     getIt.registerSingleton<OfflineModeService>(offlineModeService);
   }

// Recommendation Service (singleton) depends on MusicRepository and LibraryRepository
    {
      final recommendationService = RecommendationService(
        getIt<MusicRepository>(),
        getIt<LibraryRepository>(),
      );
      await recommendationService.initialize();
      getIt.registerSingleton<RecommendationService>(recommendationService);
    }

    // Media Resolver Service - central playback resolver (offline/local/online)
    final mediaResolverService = MediaResolverService(
      streamLoader: getIt<StreamLoaderService>(),
      downloadService: getIt<DownloadService>(),
    );
    getIt.registerSingleton<MediaResolverService>(mediaResolverService);

    AudioQuality mapQuality(String q) {
      switch (q.toLowerCase()) {
        case 'low':
          return AudioQuality.low;
        case 'medium':
          return AudioQuality.medium;
        case 'lossless':
          return AudioQuality.lossless;
        case 'high':
        default:
          return AudioQuality.high;
      }
    }

    getIt<AudioPlayerService>().configureQueueResolvers(
      streamCache: getIt<StreamCacheService>(),
      deferredResolver: (songId, title, artist, quality) async {
        final pre = mediaResolverService.takePreResolved(songId);
        if (pre != null) return pre;
        final placeholder = Song(
          id: songId,
          title: title,
          artist: artist,
          duration: Duration.zero,
          thumbnails: const Thumbnails(),
          youtubeId: RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(songId) ? songId : null,
        );
        return mediaResolverService.resolveForPlayback(
          placeholder,
          preferredQuality: quality,
        );
      },
    );

    YouTubeAudioSource.streamFallbackResolver = (videoId, quality) async {
      final placeholder = Song(
        id: videoId,
        title: videoId,
        artist: '',
        duration: Duration.zero,
        thumbnails: const Thumbnails(),
        source: MusicSource.youtube,
        youtubeId: videoId,
      );
      try {
        final streamInfo = await getIt<StreamLoaderService>().loadStream(
          placeholder,
          useCache: false,
          preferredQuality: mapQuality(quality),
        );
        return ResolvedExternalAudioStream(
          url: streamInfo.url,
          contentLength: streamInfo.contentLength,
          contentType: 'audio/${streamInfo.container}',
          headers: streamInfo.headers,
        );
      } catch (_) {
        return null;
      }
    };

    // Smart Playlist Service
    getIt.registerLazySingleton<SmartPlaylistService>(
      () => SmartPlaylistService(
        localDataSource: getIt<LocalDataSource>(),
        libraryRepository: getIt<LibraryRepository>(),
      ),
    );

    // App Update Service
    getIt.registerLazySingleton<AppUpdateService>(
      () => AppUpdateService.instance,
    );

    // Kids Mode Service
    getIt.registerLazySingleton<KidsModeService>(
      () => KidsModeService.instance,
    );

    // DJ Sequencer Service
    getIt.registerLazySingleton<DjSequencerService>(
      () => DjSequencerService(),
    );

    // Audio Recognition Service
    getIt.registerLazySingleton<AudioRecognitionService>(
      () => AudioRecognitionService.instance,
    );

    // ============ BLOCS ============
  
  getIt.registerLazySingleton<PlayerBloc>(
    () => PlayerBloc(
      musicRepository: getIt<MusicRepository>(),
      libraryRepository: getIt<LibraryRepository>(),
      audioPlayerService: getIt<AudioPlayerService>(),
      audioFocus: getIt<AudioFocusOrchestratorService>(),
      mediaResolver: getIt<MediaResolverService>(),
      reliability: getIt<PlaybackReliabilityService>(),
      streamLoader: getIt<StreamLoaderService>(),
      downloadService: getIt<DownloadService>(),
      recommendationService: getIt<RecommendationService>(),
      settingsService: SettingsService.instance,
    ),
  );

  // Deep Link Service
  getIt.registerLazySingleton<DeepLinkService>(
    () => DeepLinkService(
      playerBloc: getIt<PlayerBloc>(),
      dataSource: getIt<YouTubeMusicDataSource>(),
    ),
  );
  
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(
      musicRepository: getIt<MusicRepository>(),
      localDataSource: getIt<LocalDataSource>(),
      downloadService: getIt<DownloadService>(),
      offlineModeService: getIt<OfflineModeService>(),
    ),
  );
  
  getIt.registerFactory<LibraryBloc>(
    () => LibraryBloc(
      libraryRepository: getIt<LibraryRepository>(),
      musicRepository: getIt<MusicRepository>(),
    ),
  );
  
  getIt.registerFactory<ThemeBloc>(
    () => ThemeBloc(
      initialThemeMode: SettingsService.instance.themeMode,
    ),
  );
}

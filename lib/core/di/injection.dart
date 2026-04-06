import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../../domain/repositories/music_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../../data/repositories/music_repository_impl.dart';
import '../../data/repositories/library_repository_impl.dart';
import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../data/datasources/remote/spotify/spotify_datasource.dart';
import '../../data/datasources/remote/lyrics/lyrics_datasource.dart';
import '../../data/datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../../data/datasources/local/local_datasource.dart';
import '../../presentation/blocs/player/player_bloc.dart';
import '../../presentation/blocs/search/search_bloc.dart';
import '../../presentation/blocs/library/library_bloc.dart';
import '../../presentation/blocs/theme/theme_bloc.dart';
import '../services/audio_player_service.dart';
import '../services/audio_focus_orchestrator_service.dart';
import '../services/stream_cache_service.dart';
import '../services/stream_loader_service.dart';
import '../services/media_resolver_service.dart';
import '../services/playback_reliability_service.dart';
import '../services/download_service.dart';
import '../services/ytmusic_api_service.dart';

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
    
    // Add interceptors for logging and error handling
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      error: true,
    ));
    
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

  // ============ DATA SOURCES ============
  
  // Remote Data Sources
  getIt.registerLazySingleton<YouTubeMusicDataSource>(
    () => YouTubeMusicDataSourceImpl(),
  );

  getIt.registerLazySingleton<SpotifyDataSource>(
    () => SpotifyDataSourceImpl(dio: getIt<Dio>()),
  );

  getIt.registerLazySingleton<LyricsDataSource>(
    () => LyricsDataSourceImpl(dio: getIt<Dio>()),
  );

  getIt.registerLazySingleton<JioSaavnDataSource>(
    () => JioSaavnDataSourceImpl(),
  );

  getIt.registerLazySingleton<YtMusicApiService>(
    () => YtMusicApiService(),
  );
  
  // Local Data Source
  getIt.registerLazySingleton<LocalDataSource>(
    () => LocalDataSourceImpl(),
  );
  
  // Stream Loader Service - depends on datasource and cache
  getIt.registerLazySingleton<StreamLoaderService>(
    () => StreamLoaderService(
      getIt<YouTubeMusicDataSource>(),
      getIt<StreamCacheService>(),
    ),
  );

  // ============ REPOSITORIES ============
  
  getIt.registerLazySingleton<MusicRepository>(
    () => MusicRepositoryImpl(
      youtubeMusicDataSource: getIt<YouTubeMusicDataSource>(),
      spotifyDataSource: getIt<SpotifyDataSource>(),
      lyricsDataSource: getIt<LyricsDataSource>(),
      localDataSource: getIt<LocalDataSource>(),
      jioSaavnDataSource: getIt<JioSaavnDataSource>(),
      ytMusicApiService: getIt<YtMusicApiService>(),
    ),
  );

  // Download Service (singleton) depends on MusicRepository
  {
    final downloadService = DownloadService(getIt<MusicRepository>());
    await downloadService.initialize();
    getIt.registerSingleton<DownloadService>(downloadService);
  }

  // Media Resolver Service - central playback resolver (offline/local/online)
  getIt.registerLazySingleton<MediaResolverService>(
    () => MediaResolverService(
      streamLoader: getIt<StreamLoaderService>(),
      downloadService: getIt<DownloadService>(),
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
    ),
  );

  // ============ BLOCS ============
  
  getIt.registerFactory<PlayerBloc>(
    () => PlayerBloc(
      musicRepository: getIt<MusicRepository>(),
      libraryRepository: getIt<LibraryRepository>(),
      audioPlayerService: getIt<AudioPlayerService>(),
      audioFocus: getIt<AudioFocusOrchestratorService>(),
      mediaResolver: getIt<MediaResolverService>(),
      reliability: getIt<PlaybackReliabilityService>(),
      streamLoader: getIt<StreamLoaderService>(),
      downloadService: getIt<DownloadService>(),
    ),
  );
  
  getIt.registerFactory<SearchBloc>(
    () => SearchBloc(
      musicRepository: getIt<MusicRepository>(),
      localDataSource: getIt<LocalDataSource>(),
    ),
  );
  
  getIt.registerFactory<LibraryBloc>(
    () => LibraryBloc(
      libraryRepository: getIt<LibraryRepository>(),
      musicRepository: getIt<MusicRepository>(),
    ),
  );
  
  getIt.registerFactory<ThemeBloc>(
    () => ThemeBloc(),
  );
}

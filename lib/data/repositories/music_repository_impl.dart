import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import '../../core/error/error.dart';
import '../../core/mappers/ytmusic_api_mappers.dart';
import '../../core/services/ytmusic_api_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';
import '../datasources/remote/youtube/youtube_music_datasource.dart';
import '../datasources/remote/spotify/spotify_datasource.dart';
import '../datasources/remote/lyrics/lyrics_datasource.dart';
import '../datasources/remote/jiosaavn/jiosaavn_datasource.dart';
import '../datasources/local/local_datasource.dart';

/// Implementation of MusicRepository using mixed data sources
class MusicRepositoryImpl implements MusicRepository {
  final YouTubeMusicDataSource _youtubeMusicDataSource;
  final SpotifyDataSource _spotifyDataSource;
  final LyricsDataSource _lyricsDataSource;
  final LocalDataSource _localDataSource;
  final JioSaavnDataSource _jioSaavnDataSource;
  final YtMusicApiService _ytMusicApiService;

  MusicRepositoryImpl({
    required YouTubeMusicDataSource youtubeMusicDataSource,
    required SpotifyDataSource spotifyDataSource,
    required LyricsDataSource lyricsDataSource,
    required LocalDataSource localDataSource,
    required JioSaavnDataSource jioSaavnDataSource,
    required YtMusicApiService ytMusicApiService,
  })  : _youtubeMusicDataSource = youtubeMusicDataSource,
        _spotifyDataSource = spotifyDataSource,
        _lyricsDataSource = lyricsDataSource,
        _localDataSource = localDataSource,
        _jioSaavnDataSource = jioSaavnDataSource,
        _ytMusicApiService = ytMusicApiService;

  @override
  Future<Either<Failure, List<Song>>> searchSongs(
    String query, {
    int limit = 20,
    String? filter,
  }) async {
    try {
      final items = await _ytMusicApiService.searchSongs(query);
      Logger.root.info(
        'MusicRepository.searchSongs("$query"): raw items = ${items.length}',
      );
      final songs = items
          .map((item) => songFromYtMusicApi(item))
          .where((song) => song.playableId.isNotEmpty)
          .take(limit)
          .toList();
      Logger.root.info(
        'MusicRepository.searchSongs("$query"): mapped songs = ${songs.length}',
      );
      return Right(songs);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Artist>>> searchArtists(
    String query, {
    int limit = 20,
  }) async {
    try {
      final items = await _ytMusicApiService.searchArtists(query);
      final artists = items
          .map((item) => artistFromYtMusicApi(item))
          .where((artist) => artist.id.isNotEmpty)
          .take(limit)
          .toList();
      return Right(artists);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Album>>> searchAlbums(
    String query, {
    int limit = 20,
  }) async {
    try {
      final items = await _ytMusicApiService.searchAlbums(query);
      final albums = items
          .map((item) => albumFromYtMusicApi(item))
          .where((album) => album.id.isNotEmpty)
          .take(limit)
          .toList();
      return Right(albums);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Playlist>>> searchPlaylists(
    String query, {
    int limit = 20,
  }) async {
    try {
      final items = await _ytMusicApiService.searchPlaylists(query);
      final playlists = items
          .map((item) => playlistFromYtMusicApi(item))
          .where((playlist) => playlist.id.isNotEmpty)
          .take(limit)
          .toList();
      return Right(playlists);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, SearchResults>> searchAll(
    String query, {
    int limit = 10,
  }) async {
    try {
      final items = await _ytMusicApiService.search(query);
      final songs = <Song>[];
      final artists = <Artist>[];
      final albums = <Album>[];
      final playlists = <Playlist>[];

      for (final item in items) {
        final rawType = (item['type'] ?? item['resultType'] ?? item['category'])
            ?.toString()
            .toLowerCase();
        switch (rawType) {
          case 'song':
          case 'video':
            songs.add(songFromYtMusicApi(item));
            break;
          case 'artist':
            artists.add(artistFromYtMusicApi(item));
            break;
          case 'album':
          case 'single':
          case 'ep':
            albums.add(albumFromYtMusicApi(item));
            break;
          case 'playlist':
            playlists.add(playlistFromYtMusicApi(item));
            break;
          default:
            // Heuristic fallback when type metadata is missing.
            if (item.containsKey('videoId') || item.containsKey('duration')) {
              songs.add(songFromYtMusicApi(item));
            }
            break;
        }
      }

      final primaryResults = SearchResults(
        songs: songs.take(limit).toList(),
        artists: artists.take(limit).toList(),
        albums: albums.take(limit).toList(),
        playlists: playlists.take(limit).toList(),
      );
      return Right(primaryResults);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, StreamInfo>> getStreamUrl(
    String videoId, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    try {
      final streamInfo = await _youtubeMusicDataSource.getStreamUrl(
        videoId,
        preferredQuality: preferredQuality,
      );
      return Right(streamInfo);
    } on StreamNotFoundException {
      return const Left(StreamNotFoundFailure());
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      return Left(AudioFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<StreamInfo>>> getAvailableStreams(String videoId) async {
    try {
      final streams = await _youtubeMusicDataSource.getAvailableStreams(videoId);
      return Right(streams);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Song>> getSongDetails(String songId) async {
    try {
      // First check cache
      final cached = await _localDataSource.getCachedSong(songId);
      if (cached != null) return Right(cached);

      // Fetch from YouTube
      final song = await _youtubeMusicDataSource.getSongDetails(songId);
      
      // Cache the result
      await _localDataSource.cacheSong(song);
      
      return Right(song);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, ArtistDetails>> getArtistDetails(String artistId) async {
    try {
      // First, try to get the channel info to resolve the real name
      String artistName = artistId;
      String? thumbnailUrl;

      // Search via YT Music API to resolve name + thumbnail.
      final channelItems = await _ytMusicApiService.searchArtists(artistId);
      final channelSearch = channelItems
          .map((item) => artistFromYtMusicApi(item))
          .where((artist) => artist.id.isNotEmpty)
          .take(1)
          .toList();
      if (channelSearch.isNotEmpty) {
        artistName = channelSearch.first.name;
        thumbnailUrl = channelSearch.first.thumbnailUrl;
      }

      // Now search for the artist's top songs using the resolved name.
      final topSongItems = await _ytMusicApiService.searchSongs('$artistName songs');
      final topSongs = topSongItems
          .map((item) => songFromYtMusicApi(item))
          .where((song) => song.playableId.isNotEmpty)
          .take(20)
          .toList();

      // Search for albums.
      final albumItems = await _ytMusicApiService.searchAlbums(artistName);
      final albums = albumItems
          .map((item) => albumFromYtMusicApi(item))
          .where((album) => album.id.isNotEmpty)
          .take(6)
          .toList();

      return Right(ArtistDetails(
        artist: Artist(
          id: artistId,
          name: artistName,
          thumbnails: thumbnailUrl != null ? Thumbnails.fromUrl(thumbnailUrl) : null,
          youtubeChannelId: artistId,
        ),
        topSongs: topSongs,
        albums: albums,
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Album>> getAlbumDetails(String albumId) async {
    try {
      final playlist = await _youtubeMusicDataSource.getPlaylistDetails(albumId);
      
      return Right(Album(
        id: playlist.id,
        title: playlist.name,
        artist: playlist.author ?? 'Unknown Artist',
        thumbnails: playlist.thumbnails ?? const Thumbnails(),
        trackCount: playlist.trackCount,
        songs: playlist.songs,
        youtubePlaylistId: playlist.youtubePlaylistId,
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> getPlaylistDetails(String playlistId) async {
    try {
      final playlist = await _youtubeMusicDataSource.getPlaylistDetails(playlistId);
      return Right(playlist);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Song>>> getRelatedSongs(
    String songId, {
    int limit = 20,
  }) async {
    try {
      final upNextItems = await _ytMusicApiService.getUpNexts(songId, limit: limit);
      final upNextSongs = upNextItems
          .map((item) => songFromYtMusicApi(item))
          .where((song) => song.playableId.isNotEmpty)
          .take(limit)
          .toList();

      Logger.root.info(
        'MusicRepository.getRelatedSongs("$songId"): upNext = ${upNextSongs.length}',
      );

      if (upNextSongs.isNotEmpty) {
        return Right(upNextSongs);
      }

      final songs = await _youtubeMusicDataSource.getRelatedSongs(songId, limit: limit);
      Logger.root.info(
        'MusicRepository.getRelatedSongs("$songId"): youtube fallback = ${songs.length}',
      );
      return Right(songs);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Song>>> getJioSaavnSuggestions(
    String songId, {
    int limit = 10,
  }) async {
    try {
      final songs = await _jioSaavnDataSource.getSongSuggestions(songId, limit: limit);
      return Right(songs);
    } catch (e) {
      debugPrint('JioSaavn suggestions failed: $e');
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Song>>> getRecommendations({
    int limit = 20,
  }) async {
    try {
      // Get listening history to base recommendations on
      final history = await _localDataSource.getListeningHistory(limit: 10);
      Logger.root.info('MusicRepository.getRecommendations: history length = ${history.length}');
      
      if (history.isEmpty) {
        // If no history, return trending
        Logger.root.info('MusicRepository.getRecommendations: history empty, using trending fallback');
        return getTrending(limit: limit);
      }

      final historyIds = history.map((s) => s.playableId).toSet();
      final seedIds = history
          .map((s) => s.playableId)
          .where((id) => id.isNotEmpty)
          .take(3)
          .toList();

      if (seedIds.isEmpty) {
        Logger.root.info('MusicRepository.getRecommendations: no valid history playableIds, using trending fallback');
        return getTrending(limit: limit);
      }

      final recommendationPool = <Song>[];
      final seen = <String>{};

      final perSeedLimit = (limit / seedIds.length).ceil().clamp(6, limit);
      for (final seedId in seedIds) {
        final relatedResult = await getRelatedSongs(seedId, limit: perSeedLimit);
        relatedResult.fold(
          (_) {},
          (songs) {
            for (final song in songs) {
              final playableId = song.playableId;
              if (playableId.isEmpty || historyIds.contains(playableId) || !seen.add(playableId)) {
                continue;
              }
              recommendationPool.add(song);
              if (recommendationPool.length >= limit) {
                break;
              }
            }
          },
        );
        if (recommendationPool.length >= limit) {
          break;
        }
      }

      Logger.root.info(
        'MusicRepository.getRecommendations: candidate related songs = ${recommendationPool.length}',
      );

      if (recommendationPool.isNotEmpty) {
        return Right(recommendationPool.take(limit).toList());
      }

      Logger.root.info('MusicRepository.getRecommendations: related empty, using trending fallback');
      return getTrending(limit: limit);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Artist>>> getSimilarArtists(
    String artistId, {
    int limit = 10,
  }) async {
    try {
      final artists = await _spotifyDataSource.getSimilarArtists(artistId, limit: limit);
      return Right(artists);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chart>> getSpotifyTopChart({String region = 'global'}) async {
    try {
      final songs = await _spotifyDataSource.getTopChart(region: region);
      
      return Right(Chart(
        id: 'spotify_top_$region',
        name: 'Spotify Top 50 ${region.toUpperCase()}',
        type: ChartType.topSongs,
        source: MusicSource.spotify,
        region: region,
        songs: songs,
        updatedAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Chart>> getYouTubeMusicChart({String region = 'global'}) async {
    try {
      final songs = await _youtubeMusicDataSource.getCharts(region: region);
      
      return Right(Chart(
        id: 'youtube_top_$region',
        name: 'YouTube Music Top 100',
        type: ChartType.topSongs,
        source: MusicSource.youtubeMusic,
        region: region,
        songs: songs,
        updatedAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Song>>> getTrending({
    String region = 'US',
    int limit = 50,
  }) async {
    try {
      final songs = await _youtubeMusicDataSource.getCharts(region: region, limit: limit);
      return Right(songs);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Album>>> getNewReleases({int limit = 20}) async {
    try {
      final items = await _ytMusicApiService.searchAlbums('new music');
      final albums = items
          .map((item) => albumFromYtMusicApi(item))
          .where((album) => album.id.isNotEmpty)
          .take(limit)
          .toList();
      return Right(albums);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> importSpotifyPlaylist(String playlistUrl) async {
    try {
      // Get tracks from Spotify playlist
      final spotifyTracks = await _spotifyDataSource.getPlaylistTracks(playlistUrl);
      
      if (spotifyTracks.isEmpty) {
        return const Left(ParsingFailure(message: 'Could not parse Spotify playlist'));
      }

      // Convert Spotify tracks to YouTube video IDs
      final convertedSongs = <Song>[];
      
      for (final track in spotifyTracks) {
        final youtubeIdResult = await spotifyToYouTubeId(track.title, track.artist);
        
        await youtubeIdResult.fold(
          (failure) async {
            // Skip failed conversions
          },
          (youtubeId) async {
            convertedSongs.add(track.copyWith(youtubeId: youtubeId));
          },
        );
      }

      // Create local playlist
      final playlist = Playlist(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: 'Imported Spotify Playlist',
        trackCount: convertedSongs.length,
        songs: convertedSongs,
        isUserCreated: true,
        spotifyPlaylistId: playlistUrl,
        createdAt: DateTime.now(),
      );

      return Right(playlist);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> importYouTubePlaylist(String playlistUrl) async {
    try {
      // Extract playlist ID from URL
      final regex = RegExp(r'[?&]list=([^&]+)');
      final match = regex.firstMatch(playlistUrl);
      
      if (match == null) {
        return const Left(ParsingFailure(message: 'Invalid YouTube playlist URL'));
      }

      final playlistId = match.group(1)!;
      final playlist = await _youtubeMusicDataSource.getPlaylistDetails(playlistId);
      
      return Right(playlist.copyWith(isUserCreated: true));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Lyrics>> getLyrics(
    String songTitle,
    String artistName, {
    Duration? duration,
  }) async {
    try {
      final lyrics = await _lyricsDataSource.getSyncedLyrics(
        songTitle,
        artistName,
        duration: duration,
      );
      
      if (lyrics == null) {
        return const Left(SearchFailure(message: 'Lyrics not found'));
      }
      
      return Right(lyrics);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> spotifyToYouTubeId(
    String trackTitle,
    String artistName,
  ) async {
    try {
      // Search YT Music for the song.
      final query = '$artistName $trackTitle';
      final items = await _ytMusicApiService.searchSongs(query);
      final results = items
          .map((item) => songFromYtMusicApi(item))
          .where((song) => song.playableId.isNotEmpty)
          .take(1)
          .toList();
      
      if (results.isEmpty) {
        return const Left(SearchFailure(message: 'No matching YouTube video found'));
      }
      
      return Right(results.first.youtubeId ?? results.first.id);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }
}

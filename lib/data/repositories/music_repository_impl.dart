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

/// Hard cap on tracks imported from an external provider playlist, so a
/// hostile or pathological collection cannot exhaust memory.
const int _maxImportedPlaylistTracks = 1000;

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
      if (songs.isNotEmpty) {
        return Right(songs);
      }
      Logger.root.warning(
        'MusicRepository.searchSongs("$query"): 0 songs from ytMusicApi, falling back to YouTubeExplode',
      );
      final fallbackSongs = await _youtubeMusicDataSource.searchSongs(query, limit: limit);
      return Right(fallbackSongs);
    } on NetworkException {
      return const Left(NetworkFailure());
    } catch (e) {
      Logger.root.warning(
        'MusicRepository.searchSongs("$query") failed ($e), falling back to YouTubeExplode',
      );
      try {
        final fallbackSongs = await _youtubeMusicDataSource.searchSongs(query, limit: limit);
        if (fallbackSongs.isNotEmpty) {
          return Right(fallbackSongs);
        }
      } catch (_) {}
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

      if (songs.isEmpty) {
        try {
          final fallbackSongs = await _youtubeMusicDataSource.searchSongs(query, limit: limit);
          songs.addAll(fallbackSongs);
        } catch (_) {}
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
    bool forceRefresh = false,
  }) async {
    try {
      final streamInfo = await _youtubeMusicDataSource.getStreamUrl(
        videoId,
        preferredQuality: preferredQuality,
        forceRefresh: forceRefresh,
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
      // 1. If artistId is a canonical YouTube channel/browse ID (starts with UC),
      // query the native getArtist endpoint directly to get verified discography.
      if (artistId.startsWith('UC')) {
        try {
          final artistData = await _ytMusicApiService.getArtist(artistId);
          if (artistData.isNotEmpty) {
            final artist = artistFromYtMusicApi(artistData);
            final rawSongs = artistData['topSongs'] ?? artistData['songs'];
            final topSongs = rawSongs is List
                ? rawSongs
                    .map((item) => songFromYtMusicApi(item as Map<String, dynamic>))
                    .where((s) => s.playableId.isNotEmpty)
                    .toList()
                : <Song>[];
            final rawAlbums = artistData['topAlbums'] ?? artistData['albums'];
            final albums = rawAlbums is List
                ? rawAlbums
                    .map((item) => albumFromYtMusicApi(item as Map<String, dynamic>))
                    .where((a) => a.id.isNotEmpty)
                    .toList()
                : <Album>[];

            return Right(ArtistDetails(
              artist: artist.copyWith(youtubeChannelId: artistId),
              topSongs: topSongs,
              albums: albums,
            ));
          }
        } catch (e) {
          debugPrint('MusicRepositoryImpl: Native getArtist failed for $artistId: $e');
        }
      }

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
      // 1. If it's a YouTube Music album browse ID (starts with MPREb_), or not a standard playlist ID (PL/OLAK/RD/VL),
      // fetch via native YtMusicApiService.getAlbum
      if (albumId.startsWith('MPREb_') || (!albumId.startsWith('PL') && !albumId.startsWith('OLAK') && !albumId.startsWith('RD') && !albumId.startsWith('VL'))) {
        try {
          final albumData = await _ytMusicApiService.getAlbum(albumId);
          if (albumData.isNotEmpty) {
            final album = albumFromYtMusicApi(albumData);
            if (album.songs != null && album.songs!.isNotEmpty) {
              return Right(album);
            }
          }
        } catch (e) {
          debugPrint('MusicRepositoryImpl: Native getAlbum failed for $albumId: $e');
        }
      }

      // 2. Fallback to playlist details using playlist endpoint
      final playlist = await _youtubeMusicDataSource.getPlaylistDetails(albumId);
      
      return Right(Album(
        id: albumId,
        title: playlist.name,
        artist: playlist.author ?? 'Unknown Artist',
        thumbnails: playlist.thumbnails ?? const Thumbnails(),
        trackCount: playlist.trackCount,
        songs: playlist.songs,
        youtubePlaylistId: playlist.youtubePlaylistId ?? playlist.id,
      ));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

      @override
  Future<Either<Failure, Playlist>> getPlaylistDetails(String playlistId) async {
    try {
      Map<String, dynamic> playlistData = {};

      // 1. Primary Native YT Music API Routing
      if (playlistId.startsWith('RD')) {
        // Radio Mixes MUST use the custom /next queue endpoint
        playlistData = await _ytMusicApiService.getRadioPlaylist(playlistId);
      } else {
        // Standard Playlists (PL, OLAK) use the standard /browse endpoint natively
        try {
          playlistData = await _ytMusicApiService.getPlaylist(playlistId);
        } catch (e) {
          debugPrint('YT Music API standard fetch failed for $playlistId: $e');
        }
        
        // THE MAGIC TRICK:
        // If standard browse fails or returns 0 tracks (extremely common for 
        // auto-generated Global Charts like PL4f...), we instantly fallback 
        // and force it through the custom /next queue endpoint!
        if (playlistData.isEmpty || 
            playlistData['tracks'] == null || 
            (playlistData['tracks'] as List).isEmpty) {
          debugPrint('Standard fetch empty, forcing queue endpoint for $playlistId');
          playlistData = await _ytMusicApiService.getRadioPlaylist(playlistId);
        }
      }

      // 2. Map the data if successful
      if (playlistData.isNotEmpty && playlistData['tracks'] != null) {
        final playlist = playlistFromYtMusicApi(playlistData);
        if (playlist.songs != null && playlist.songs!.isNotEmpty) {
           return Right(playlist);
        }
      }

      // 3. Last Resort: Explode Fallback (Only fires if API servers are entirely down)
      final cleanedId = playlistId.startsWith('RDCLAK') ? playlistId.substring(2) : playlistId;
      final fallbackPlaylist = await _youtubeMusicDataSource.getPlaylistDetails(cleanedId);
      
      if (fallbackPlaylist.songs != null && fallbackPlaylist.songs!.isNotEmpty) {
        return Right(fallbackPlaylist);
      }

      return const Left(SearchFailure(message: 'Playlist not found or empty'));
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
      final combinedSongs = <Song>[];
      final seenIds = <String>{songId};

      void addSongs(List<Song> songs) {
        for (final s in songs) {
          final pid = s.playableId;
          if (pid.isNotEmpty && seenIds.add(pid)) {
            combinedSongs.add(s);
            if (combinedSongs.length >= limit) break;
          }
        }
      }

      // 1. Try YouTube Music UpNext
      try {
        final upNextItems = await _ytMusicApiService.getUpNexts(songId, limit: limit);
        final upNextSongs = upNextItems
            .map((item) => songFromYtMusicApi(item))
            .where((song) => song.playableId.isNotEmpty)
            .toList();

        Logger.root.info(
          'MusicRepository.getRelatedSongs("$songId"): upNext = ${upNextSongs.length}',
        );
        addSongs(upNextSongs);
      } catch (e) {
        Logger.root.warning('MusicRepository.getRelatedSongs("$songId"): upNext error: $e');
      }

      // 2. If we still need more songs, query YouTube Music Radio Mix (RDAMVM)
      if (combinedSongs.length < limit) {
        try {
          final radioData = await _ytMusicApiService.getRadioPlaylist('RDAMVM$songId');
          if (radioData.isNotEmpty &&
              radioData['tracks'] is List &&
              (radioData['tracks'] as List).isNotEmpty) {
            final radioPlaylist = playlistFromYtMusicApi(radioData);
            if (radioPlaylist.songs != null && radioPlaylist.songs!.isNotEmpty) {
              final validSongs = radioPlaylist.songs!
                  .where((s) => s.playableId.isNotEmpty && s.playableId != songId)
                  .toList();
              Logger.root.info(
                'MusicRepository.getRelatedSongs("$songId"): radio mix = ${validSongs.length}',
              );
              addSongs(validSongs);
            }
          }
        } catch (e) {
          Logger.root.warning('MusicRepository.getRelatedSongs("$songId"): radio mix error: $e');
        }
      }

      // 3. If still under limit, use YouTube Mix (RDMM) / search fallback
      if (combinedSongs.length < limit) {
        try {
          final songs = await _youtubeMusicDataSource.getRelatedSongs(songId, limit: limit);
          Logger.root.info(
            'MusicRepository.getRelatedSongs("$songId"): youtube fallback = ${songs.length}',
          );
          addSongs(songs);
        } catch (e) {
          Logger.root.warning('MusicRepository.getRelatedSongs("$songId"): youtube fallback error: $e');
        }
      }

      if (combinedSongs.isNotEmpty) {
        return Right(combinedSongs.take(limit).toList());
      }

      Logger.root.info('MusicRepository.getRelatedSongs("$songId"): no songs found from any source');
      return const Right([]);
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
        return await getTrending(limit: limit);
      }

      final historyIds = history.map((s) => s.playableId).toSet();
      final seedIds = history
          .map((s) => s.playableId)
          .where((id) => id.isNotEmpty)
          .take(3)
          .toList();

      if (seedIds.isEmpty) {
        Logger.root.info('MusicRepository.getRecommendations: no valid history playableIds, using trending fallback');
        return await getTrending(limit: limit);
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

      // If we still haven't reached the requested limit, supplement with trending
      if (recommendationPool.length < limit) {
        Logger.root.info(
          'MusicRepository.getRecommendations: supplementing ${limit - recommendationPool.length} tracks from trending',
        );
        final trendingResult = await getTrending(limit: limit);
        trendingResult.fold(
          (_) {},
          (songs) {
            for (final song in songs) {
              final playableId = song.playableId;
              if (playableId.isNotEmpty && !historyIds.contains(playableId) && seen.add(playableId)) {
                recommendationPool.add(song);
                if (recommendationPool.length >= limit) break;
              }
            }
          },
        );
      }

      if (recommendationPool.isNotEmpty) {
        return Right(recommendationPool.take(limit).toList());
      }

      Logger.root.info('MusicRepository.getRecommendations: related empty, using trending fallback');
      return await getTrending(limit: limit);
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
      // 1. Exclusively use YT Music API.
      // We are completely bypassing _youtubeMusicDataSource.getCharts() 
      // because it has a known bug parsing "Streamed" durations and gets stuck in redirect loops.
      
      final currentYear = DateTime.now().year;
      final query = region.toLowerCase() == 'in' || region.toLowerCase() == 'india'
          ? 'trending music india $currentYear'
          : 'top hits $region $currentYear';

      final items = await _ytMusicApiService.searchSongs(query);
      
      final songs = items
          .map((item) => songFromYtMusicApi(item))
          // Filter out invalid IDs and weird 0-second live streams
          .where((song) => song.playableId.isNotEmpty && song.duration.inSeconds > 30)
          .take(limit)
          .toList();
          
      if (songs.isNotEmpty) {
        return Right(songs);
      }

      return const Left(SearchFailure(message: 'No trending songs found.'));
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Album>>> getNewReleases({int limit = 20}) async {
    try {
      // Personalise the rail: dig up albums from artists already in the
      // listener's rotation instead of a static "new music" query.
      final seeds = <String>[];
      final banned = RegExp(r'various|playlist|topic|compilation');
      try {
        final history = await _localDataSource.getListeningHistory(limit: 20);
        for (final song in history) {
          final artist = song.artist.trim();
          if (artist.isEmpty || banned.hasMatch(artist.toLowerCase())) {
            continue;
          }
          if (seeds.any((s) => s.toLowerCase() == artist.toLowerCase())) {
            continue;
          }
          seeds.add(artist);
          if (seeds.length >= 4) break;
        }
      } catch (_) {
        // History is optional — without it there is nothing to personalise.
      }

      // No rotation yet: no rail rather than a generic one.
      if (seeds.isEmpty) return const Right([]);

      final perArtist = await Future.wait(
        seeds.map((seed) async {
          final result = await searchAlbums('$seed album', limit: 6);
          return result.fold((_) => <Album>[], (items) => items);
        }),
      );

      // Round-robin across artists so the rail mixes them up.
      final albums = <Album>[];
      final seenIds = <String>{};
      final seenKeys = <String>{};
      var index = 0;
      while (albums.length < limit) {
        var progressed = false;
        for (final items in perArtist) {
          if (index >= items.length) continue;
          progressed = true;
          final album = items[index];
          if (album.id.isNotEmpty &&
              seenIds.add(album.id) &&
              seenKeys.add(
                '${album.title.toLowerCase()}|${album.artist.toLowerCase()}',
              )) {
            albums.add(album);
          }
        }
        if (!progressed) break;
        index++;
      }

      final currentYear = DateTime.now().year;
      final recentAlbums = albums.where((a) {
        if (a.year == null) return true;
        return a.year! >= currentYear - 1;
      }).toList();

      return Right(recentAlbums.take(limit).toList());
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Playlist>> importSpotifyPlaylist(
    String playlistUrl, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final details = await _spotifyDataSource.getPlaylistDetails(playlistUrl);
      if (details == null) {
        return const Left(
          ParsingFailure(
            message:
                'Could not read that Spotify playlist. Make sure it is public and the link is correct.',
          ),
        );
      }

      // Match each track on YouTube in parallel (small worker pool) so a
      // 100-track playlist takes seconds instead of minutes. Oversized
      // playlists are truncated at [_maxImportedPlaylistTracks].
      final tracks = details.tracks.length > _maxImportedPlaylistTracks
          ? details.tracks.sublist(0, _maxImportedPlaylistTracks)
          : details.tracks;
      final matched = List<Song?>.filled(tracks.length, null);
      var nextIndex = 0;
      var converted = 0;

      Future<void> worker() async {
        while (nextIndex < tracks.length) {
          final index = nextIndex++;
          final track = tracks[index];
          final match = await _searchYoutubeMatch(track.title, track.artist);
          if (match != null) {
            matched[index] = track.copyWith(
              youtubeId: match.youtubeId ?? match.id,
              // Spotify embed tracks carry no artwork — fall back to the
              // YouTube match's thumbnail.
              thumbnails: track.thumbnails.smallest == null
                  ? match.thumbnails
                  : track.thumbnails,
            );
          }
          converted++;
          onProgress?.call(converted / tracks.length);
        }
      }

      await Future.wait([
        for (var i = 0; i < 5 && i < tracks.length; i++) worker(),
      ]);

      final convertedSongs = matched.whereType<Song>().toList();
      if (convertedSongs.isEmpty) {
        return const Left(
          ParsingFailure(
            message:
                'Tracks were read from Spotify but none could be matched on YouTube. Try again later.',
          ),
        );
      }

      final unmatchedCount = tracks.length - convertedSongs.length;
      if (unmatchedCount > 0) {
        Logger.root.info(
          'Spotify import: $unmatchedCount of ${tracks.length} tracks could not be matched with high confidence.',
        );
      }

      final playlist = Playlist(
        id: 'spotify_${details.id}',
        name: details.name,
        description: details.owner == null
            ? 'Imported from Spotify • ${convertedSongs.length}/${tracks.length} tracks matched'
            : 'Imported from Spotify • ${details.owner} (${convertedSongs.length}/${tracks.length} tracks matched)',
        thumbnails: details.coverUrl == null
            ? null
            : Thumbnails.fromUrl(details.coverUrl!),
        author: details.owner,
        trackCount: convertedSongs.length,
        songs: convertedSongs,
        isUserCreated: true,
        spotifyPlaylistId: details.id,
        createdAt: DateTime.now(),
      );

      return Right(playlist);
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Search YT Music for the closest match to a Spotify track with token scoring.
  Future<Song?> _searchYoutubeMatch(String trackTitle, String artistName) async {
    try {
      final items = await _ytMusicApiService.searchSongs(
        '$artistName $trackTitle',
      );
      final results = items
          .map((item) => songFromYtMusicApi(item))
          .where((song) => song.playableId.isNotEmpty)
          .toList();
      if (results.isEmpty) return null;
      return _bestYoutubeMatch(trackTitle, artistName, results);
    } catch (_) {
      return null;
    }
  }

  Song? _bestYoutubeMatch(String trackTitle, String artistName, List<Song> candidates) {
    if (candidates.isEmpty) return null;
    final titleNorm = trackTitle.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final artistNorm = artistName.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
    final titleTokens = titleNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
    final artistTokens = artistNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

    Song? best;
    double highestScore = -1.0;

    for (final candidate in candidates) {
      final candTitleNorm = candidate.title.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      final candArtistNorm = candidate.artist.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
      final candTitleTokens = candTitleNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();
      final candArtistTokens = candArtistNorm.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toSet();

      final matchingTitle = titleTokens.intersection(candTitleTokens).length;
      final titleScore = titleTokens.isEmpty ? 0.0 : matchingTitle / titleTokens.length;

      final matchingArtist = artistTokens.intersection(candArtistTokens).length;
      final artistScore = artistTokens.isEmpty ? 0.0 : matchingArtist / artistTokens.length;

      final totalScore = (titleScore * 0.6) + (artistScore * 0.4);

      if (totalScore > highestScore) {
        highestScore = totalScore;
        best = candidate;
      }
    }

    if (highestScore >= 0.35) {
      return best;
    }
    return candidates.first;
  }

  @override
  Future<Either<Failure, Playlist>> importYouTubePlaylist(String playlistUrl) async {
    final playlistId = _extractYouTubePlaylistId(playlistUrl.trim());

    if (playlistId == null) {
      return const Left(ParsingFailure(message: 'Invalid YouTube playlist URL'));
    }

    try {
      final playlist = await _youtubeMusicDataSource.getPlaylistDetails(playlistId);

      if (playlist.songs == null || playlist.songs!.isEmpty) {
        return const Left(
          ParsingFailure(
            message:
                'Could not fetch that playlist\u2019s tracks. Make sure it is public and the link is correct.',
          ),
        );
      }

      final songs = playlist.songs!;
      final capped = songs.length > _maxImportedPlaylistTracks
          ? songs.sublist(0, _maxImportedPlaylistTracks)
          : songs;

      return Right(
        playlist.copyWith(
          isUserCreated: true,
          songs: capped,
          trackCount: capped.length,
        ),
      );
    } catch (e) {
      return Left(UnknownFailure(message: e.toString()));
    }
  }

  /// Extract a YouTube playlist ID from any of the share formats:
  /// `youtube.com/playlist?list=ID`, `music.youtube.com/playlist?list=ID`,
  /// `youtube.com/playlist/ID`, or a bare playlist ID (including `RD*`
  /// mixes and radio playlists).
  String? _extractYouTubePlaylistId(String url) {
    final listParam = RegExp(r'[?&]list=([^&]+)').firstMatch(url);
    if (listParam != null) return listParam.group(1);

    final pathSegment = RegExp(r'/playlist/([A-Za-z0-9_-]+)').firstMatch(url);
    if (pathSegment != null) return pathSegment.group(1);

    // Bare ID pasted directly — playlist IDs run 13–42 chars (PL…, RD…,
    // OLAK5uy…, UU…). The prefix rules of real IDs keep this from
    // matching free text.
    final trimmed = url.trim();
    if (RegExp(r'^[A-Za-z0-9_-]{13,42}$').hasMatch(trimmed)) {
      return trimmed;
    }
    return null;
  }

  @override
  Future<Either<Failure, Lyrics>> getLyrics(
    String songTitle,
    String artistName, {
    Duration? duration,
    bool forceRefresh = false,
  }) async {
    try {
      final lyrics = await _lyricsDataSource.getSyncedLyrics(
        songTitle,
        artistName,
        duration: duration,
        forceRefresh: forceRefresh,
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
    final match = await _searchYoutubeMatch(trackTitle, artistName);
    if (match == null) {
      return const Left(
        SearchFailure(message: 'No matching YouTube video found'),
      );
    }
    return Right(match.youtubeId ?? match.id);
  }
}

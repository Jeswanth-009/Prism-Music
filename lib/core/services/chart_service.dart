import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../data/datasources/remote/spotify/spotify_datasource.dart';
import '../../domain/entities/entities.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../di/injection.dart';

/// Service for fetching music charts from Apple Music, Spotify, YouTube Music, and Billboard.
class ChartService {
  static final ChartService _instance = ChartService._internal();
  static ChartService get instance => _instance;

  ChartService._internal();

  // Cache for chart data
  final Map<String, _CachedChart> _chartCache = {};
  static const _cacheDuration = Duration(hours: 2);

  /// Available chart definitions across Apple Music, Spotify, YouTube Music, and Billboard.
  static List<ChartDefinition> getAvailableCharts(String countryCode, String countryName) {
    final region = countryCode.toUpperCase();
    return [
      ChartDefinition(
        id: 'apple_top50_$region',
        name: 'Apple Music Top 50 ($countryName)',
        source: ChartSource.appleMusic,
        description: 'The most popular songs in $countryName on Apple Music',
        iconType: ChartIconType.top,
        region: region,
        isDiscoveryMix: true,
        provenance: 'Direct Apple Music Top 50 RSS feed',
      ),
      ChartDefinition(
        id: 'spotify_top50_global',
        name: 'Spotify Global Top 50',
        source: ChartSource.spotify,
        description: 'The most streamed tracks globally on Spotify',
        iconType: ChartIconType.global,
        region: 'global',
        isDiscoveryMix: true,
        provenance: 'Spotify Official Global Chart',
      ),
      ChartDefinition(
        id: 'spotify_top50_$region',
        name: 'Spotify Top 50 ($countryName)',
        source: ChartSource.spotify,
        description: 'Trending tracks across Spotify in $countryName',
        iconType: ChartIconType.top,
        region: region,
        isDiscoveryMix: true,
        provenance: 'Spotify Regional Top 50',
      ),
      ChartDefinition(
        id: 'youtube_trending_$region',
        name: 'YouTube Music Trending',
        source: ChartSource.youtube,
        description: 'Trending tracks and official music in $countryName',
        iconType: ChartIconType.trending,
        region: region,
        isDiscoveryMix: true,
        provenance: 'Curated via YouTube search for trending songs in $region',
      ),
      ChartDefinition(
        id: 'billboard_hot100',
        name: 'Billboard Hot 100',
        source: ChartSource.billboard,
        description: 'The week\'s top songs across sales and streaming in the US',
        iconType: ChartIconType.chart,
        isDiscoveryMix: true,
        provenance: 'Billboard Hot 100 Weekly Chart',
      ),
      ChartDefinition(
        id: 'billboard_global200',
        name: 'Billboard Global 200',
        source: ChartSource.billboard,
        description: 'Top songs worldwide based on streams and digital sales',
        iconType: ChartIconType.global,
        isDiscoveryMix: true,
        provenance: 'Billboard Global 200 Weekly Chart',
      ),
      ChartDefinition(
        id: 'billboard_tiktok',
        name: 'TikTok Viral 50',
        source: ChartSource.billboard,
        description: 'Top songs and trending audio sounds on TikTok',
        iconType: ChartIconType.viral,
        isDiscoveryMix: true,
        provenance: 'TikTok Viral Weekly Chart',
      ),
      ChartDefinition(
        id: 'youtube_new_releases_$region',
        name: 'New Releases & Premieres',
        source: ChartSource.youtube,
        description: 'Latest official music drops and fresh music videos',
        iconType: ChartIconType.newRelease,
        region: region,
        isDiscoveryMix: true,
        provenance: 'YouTube Music New Releases',
      ),
    ];
  }

  /// Fetch songs for a specific chart
  Future<List<Song>> getChartSongs(ChartDefinition chart) async {
    // Check cache first
    final cached = _chartCache[chart.id];
    if (cached != null && !cached.isExpired) {
      debugPrint('ChartService: Using cached data for ${chart.id}');
      return cached.songs;
    }

    debugPrint('ChartService: Fetching chart ${chart.id} (${chart.source.name})');

    try {
      List<Song> songs;

      switch (chart.source) {
        case ChartSource.appleMusic:
          songs = await _fetchAppleMusicChart(chart);
          break;
        case ChartSource.spotify:
          songs = await _fetchSpotifyChart(chart);
          break;
        case ChartSource.billboard:
          songs = await _fetchBillboardChart(chart);
          break;
        case ChartSource.youtube:
          songs = await _fetchYouTubeChart(chart);
          break;
      }

      // Cache the results
      if (songs.isNotEmpty) {
        _chartCache[chart.id] = _CachedChart(songs: songs, fetchedAt: DateTime.now());
      }

      return songs;
    } catch (e) {
      debugPrint('ChartService: Error fetching chart ${chart.id}: $e');
      if (cached != null) {
        return cached.songs;
      }
      rethrow;
    }
  }

  /// Fetch Apple Music Top Songs via public RSS feed
  Future<List<Song>> _fetchAppleMusicChart(ChartDefinition chart) async {
    try {
      final dio = getIt.isRegistered<Dio>() ? getIt<Dio>() : Dio();
      final region = chart.region?.toLowerCase() ?? 'us';
      final res = await dio.get(
        'https://itunes.apple.com/$region/rss/topsongs/limit=50/json',
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      if (res.statusCode == 200) {
        final data = res.data is Map ? res.data as Map : null;
        final feed = data?['feed'] as Map?;
        final entries = feed?['entry'] as List?;
        if (entries != null && entries.isNotEmpty) {
          final songs = <Song>[];
          for (final entry in entries) {
            if (entry is! Map) continue;
            final title = (entry['im:name'] as Map?)?['label'] as String? ?? '';
            final artist = (entry['im:artist'] as Map?)?['label'] as String? ?? '';
            final images = entry['im:image'] as List?;
            final thumbUrl = images != null && images.isNotEmpty
                ? (images.last as Map)['label'] as String?
                : null;
            final appleId = (entry['id'] as Map?)?['attributes']?['im:id']?.toString() ?? '';

            if (title.isNotEmpty && artist.isNotEmpty) {
              songs.add(
                Song(
                  id: 'apple_$appleId',
                  title: title,
                  artist: artist,
                  duration: const Duration(minutes: 3, seconds: 20),
                  thumbnails: thumbUrl != null
                      ? Thumbnails.fromUrl(thumbUrl)
                      : Thumbnails.empty(),
                ),
              );
            }
          }
          if (songs.isNotEmpty) return songs;
        }
      }
    } catch (e) {
      debugPrint('ChartService: Apple Music RSS failed: $e');
    }

    return _fetchChartViaSearch(chart);
  }

  /// Fetch Spotify Top Chart
  Future<List<Song>> _fetchSpotifyChart(ChartDefinition chart) async {
    try {
      if (getIt.isRegistered<SpotifyDataSource>()) {
        final spotify = getIt<SpotifyDataSource>();
        final region = chart.region ?? 'global';
        final tracks = await spotify.getTopChart(region: region);
        if (tracks.isNotEmpty) {
          return tracks.where(_isValidSong).toList();
        }
      }
    } catch (e) {
      debugPrint('ChartService: Spotify fetch failed: $e');
    }

    return _fetchChartViaSearch(chart);
  }

  /// Fetch Billboard chart with live JSON mirror fallback
  Future<List<Song>> _fetchBillboardChart(ChartDefinition chart) async {
    try {
      if (chart.id.contains('hot100')) {
        final dio = getIt.isRegistered<Dio>() ? getIt<Dio>() : Dio();
        final res = await dio.get(
          'https://raw.githubusercontent.com/mhollingshead/billboard-hot-100/main/recent.json',
          options: Options(receiveTimeout: const Duration(seconds: 8)),
        );

        if (res.statusCode == 200 && res.data is Map) {
          final list = res.data['data'] as List?;
          if (list != null && list.isNotEmpty) {
            final songs = <Song>[];
            for (final item in list.take(50)) {
              if (item is Map) {
                final songTitle = item['song'] as String? ?? '';
                final songArtist = item['artist'] as String? ?? '';
                final rank = item['this_week']?.toString() ?? '';
                if (songTitle.isNotEmpty && songArtist.isNotEmpty) {
                  songs.add(
                    Song(
                      id: 'billboard_$rank',
                      title: songTitle,
                      artist: songArtist,
                      duration: const Duration(minutes: 3, seconds: 30),
                      thumbnails: Thumbnails.empty(),
                    ),
                  );
                }
              }
            }
            if (songs.isNotEmpty) return songs;
          }
        }
      }
    } catch (e) {
      debugPrint('ChartService: Billboard JSON fetch error: $e');
    }

    return _fetchChartViaSearch(chart);
  }

  /// Fetch YouTube Music charts
  Future<List<Song>> _fetchYouTubeChart(ChartDefinition chart) async {
    if (chart.id.contains('new_releases')) {
      return _fetchYouTubeNewReleases(chart.region ?? 'US');
    }
    return _fetchChartViaSearch(chart);
  }

  /// Fetch new releases from YouTube
  Future<List<Song>> _fetchYouTubeNewReleases(String region) async {
    final regionName = _getRegionName(region);
    final results = await _searchMultipleSongs(
      'new music releases $regionName ${DateTime.now().year}',
      limit: 25,
    );
    return results.where(_isValidSong).toList();
  }

  /// Fallback: Fetch chart songs via search queries
  Future<List<Song>> _fetchChartViaSearch(ChartDefinition chart) async {
    debugPrint('ChartService: Using search fallback for ${chart.id}');

    String query;
    final currentYear = DateTime.now().year;

    if (chart.source == ChartSource.appleMusic) {
      final region = _getRegionName(chart.region ?? 'US');
      query = 'apple music top hits $region $currentYear';
    } else if (chart.id.contains('hot100')) {
      query = 'billboard hot 100 top songs $currentYear';
    } else if (chart.id.contains('global')) {
      query = 'top songs worldwide $currentYear';
    } else if (chart.id.contains('tiktok')) {
      query = 'tiktok viral songs trending $currentYear';
    } else if (chart.id.contains('trending')) {
      final region = chart.region ?? 'global';
      final regionName = _getRegionName(region);
      query = 'trending songs $regionName $currentYear';
    } else {
      query = 'top songs $currentYear';
    }

    final songs = <Song>[];
    final results = await _searchMultipleSongs(query, limit: 25);
    for (final song in results) {
      if (_isValidSong(song)) {
        songs.add(song);
      }
    }

    return songs;
  }

  /// Search for multiple songs on YouTube
  Future<List<Song>> _searchMultipleSongs(String query, {int limit = 10}) async {
    final musicRepository = getIt<MusicRepository>();
    final result = await musicRepository.searchSongs(query, limit: limit);
    return result.fold(
      (failure) {
        debugPrint('ChartService: Search failed for "$query": ${failure.message}');
        throw Exception('Failed to load chart songs: ${failure.message}');
      },
      (songs) => songs.where(_isValidSong).toList(),
    );
  }

  /// Check if a song is valid
  bool _isValidSong(Song song) {
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();

    if (titleLower.contains('playlist')) return false;
    if (titleLower.contains('mix 20')) return false;
    if (titleLower.contains('top 50')) return false;
    if (titleLower.contains('top 100')) return false;
    if (titleLower.contains('compilation')) return false;
    if (titleLower.contains('megamix')) return false;
    if (titleLower.contains('nonstop')) return false;
    if (titleLower.contains('hours')) return false;
    if (RegExp(r'\d+ hour').hasMatch(titleLower)) return false;
    if (artistLower.contains('various')) return false;
    if (artistLower.contains('playlist')) return false;

    final seconds = song.duration.inSeconds;
    if (seconds > 0 && (seconds < 60 || seconds > 600)) return false;

    return true;
  }

  /// Get region display name
  String _getRegionName(String code) {
    final regions = {
      'US': 'USA',
      'GB': 'UK',
      'UK': 'UK',
      'IN': 'India',
      'KR': 'Korea',
      'JP': 'Japan',
      'DE': 'Germany',
      'FR': 'France',
      'BR': 'Brazil',
      'MX': 'Mexico',
      'CA': 'Canada',
      'AU': 'Australia',
    };
    return regions[code.toUpperCase()] ?? code;
  }

  /// Clear chart cache
  void clearCache() {
    _chartCache.clear();
  }
}

/// Cached chart data
class _CachedChart {
  final List<Song> songs;
  final DateTime fetchedAt;

  _CachedChart({required this.songs, required this.fetchedAt});

  bool get isExpired => DateTime.now().difference(fetchedAt) > ChartService._cacheDuration;
}

/// Chart definition
class ChartDefinition {
  final String id;
  final String name;
  final ChartSource source;
  final String description;
  final ChartIconType iconType;
  final String? region;
  final bool isDiscoveryMix;
  final String? provenance;
  final DateTime? chartDate;

  const ChartDefinition({
    required this.id,
    required this.name,
    required this.source,
    required this.description,
    required this.iconType,
    this.region,
    this.isDiscoveryMix = true,
    this.provenance,
    this.chartDate,
  });
}

/// Chart sources
enum ChartSource {
  spotify,
  youtube,
  billboard,
  appleMusic,
}

/// Chart icon types for styling
enum ChartIconType {
  global,
  viral,
  trending,
  top,
  chart,
  newRelease,
}

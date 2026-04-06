import 'package:flutter/foundation.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/entities.dart';
import '../../domain/repositories/music_repository.dart';
import '../di/injection.dart';

/// Service for fetching music charts from various sources
class ChartService {
  static final ChartService _instance = ChartService._internal();
  static ChartService get instance => _instance;
  
  ChartService._internal();

  // Cache for chart data
  final Map<String, _CachedChart> _chartCache = {};
  static const _cacheDuration = Duration(hours: 2);

  /// Available chart definitions
  static List<ChartDefinition> getAvailableCharts(String countryCode, String countryName) {
    return [
      ChartDefinition(
        id: 'billboard_hot100',
        name: 'Billboard Hot 100',
        source: ChartSource.billboard,
        description: 'The week\'s most popular songs in the US',
        iconType: ChartIconType.chart,
      ),
      ChartDefinition(
        id: 'billboard_global200',
        name: 'Billboard Global 200',
        source: ChartSource.billboard,
        description: 'Top 200 songs worldwide',
        iconType: ChartIconType.global,
      ),
      ChartDefinition(
        id: 'youtube_trending_$countryCode',
        name: 'YouTube Trending',
        source: ChartSource.youtube,
        description: 'Trending music on YouTube',
        iconType: ChartIconType.trending,
        region: countryCode,
      ),
      ChartDefinition(
        id: 'youtube_top_music_$countryCode',
        name: 'YouTube Top Music',
        source: ChartSource.youtube,
        description: 'Top music videos on YouTube',
        iconType: ChartIconType.top,
        region: countryCode,
      ),
      ChartDefinition(
        id: 'billboard_tiktok',
        name: 'TikTok Billboard Top 50',
        source: ChartSource.billboard,
        description: 'Top songs on TikTok',
        iconType: ChartIconType.viral,
      ),
      ChartDefinition(
        id: 'youtube_new_releases',
        name: 'New Releases',
        source: ChartSource.youtube,
        description: 'Latest music releases',
        iconType: ChartIconType.newRelease,
        region: countryCode,
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

    debugPrint('ChartService: Fetching chart ${chart.id}');

    try {
      List<Song> songs;
      
      switch (chart.source) {
        case ChartSource.billboard:
          songs = await _fetchBillboardChart(chart);
          break;
        case ChartSource.youtube:
          songs = await _fetchYouTubeChart(chart);
          break;
        case ChartSource.spotify:
          songs = await _fetchYouTubeChart(chart); // Fallback to YouTube
          break;
      }

      // Cache the results
      if (songs.isNotEmpty) {
        _chartCache[chart.id] = _CachedChart(songs: songs, fetchedAt: DateTime.now());
      }
      
      return songs;
    } catch (e) {
      debugPrint('ChartService: Error fetching chart ${chart.id}: $e');
      // Return cached data even if expired, as fallback
      if (cached != null) {
        return cached.songs;
      }
      rethrow;
    }
  }

  /// Fetch Billboard chart by scraping their website
  Future<List<Song>> _fetchBillboardChart(ChartDefinition chart) async {
    debugPrint('ChartService: Billboard scraping disabled - using search fallback for ${chart.id}');
    
    // Skip unreliable scraping, go directly to search
    return _fetchChartViaSearch(chart);
  }

  /// Fetch YouTube Music charts
  Future<List<Song>> _fetchYouTubeChart(ChartDefinition chart) async {
    debugPrint('ChartService: YouTube Charts scraping disabled - using search fallback for ${chart.id}');
    
    if (chart.id.contains('new_releases')) {
      return _fetchYouTubeNewReleases(chart.region ?? 'US');
    }
    
    // Skip unreliable scraping, go directly to search
    return _fetchChartViaSearch(chart);
  }

  /// Fetch new releases from YouTube
  Future<List<Song>> _fetchYouTubeNewReleases(String region) async {
    // Single search for new releases
    try {
      final results = await _searchMultipleSongs('new music releases 2024', limit: 25);
      return results.where(_isValidSong).toList();
    } catch (e) {
      debugPrint('ChartService: Error fetching new releases: $e');
      return [];
    }
  }

  /// Fallback: Fetch chart songs via search queries
  Future<List<Song>> _fetchChartViaSearch(ChartDefinition chart) async {
    debugPrint('ChartService: Using search fallback for ${chart.id}');
    
    String query;
    
    if (chart.id.contains('hot100')) {
      query = 'billboard hot 100 top songs 2024';
    } else if (chart.id.contains('global')) {
      query = 'billboard global 200 top songs 2024';
    } else if (chart.id.contains('tiktok')) {
      query = 'tiktok viral songs trending 2024';
    } else if (chart.id.contains('trending')) {
      final region = chart.region ?? 'global';
      final regionName = _getRegionName(region);
      query = 'trending songs $regionName 2024';
    } else if (chart.id.contains('top_music')) {
      final region = chart.region ?? 'global';
      final regionName = _getRegionName(region);
      query = 'top music $regionName 2024';
    } else {
      query = 'top songs 2024';
    }
    
    final songs = <Song>[];
    
    try {
      // Single search to avoid rate limiting
      final results = await _searchMultipleSongs(query, limit: 25);
      for (final song in results) {
        if (_isValidSong(song)) {
          songs.add(song);
        }
      }
    } catch (e) {
      debugPrint('ChartService: Search error for "$query": $e');
    }
    
    return songs;
  }

  /// Search for multiple songs on YouTube
  Future<List<Song>> _searchMultipleSongs(String query, {int limit = 10}) async {
    try {
      final musicRepository = getIt<MusicRepository>();
      final result = await musicRepository.searchSongs(query, limit: limit);
      
      return result.fold(
        (failure) => <Song>[],
        (songs) => songs.where(_isValidSong).toList(),
      );
    } catch (e) {
      debugPrint('ChartService: Search error: $e');
      return [];
    }
  }

  /// Check if a song is valid (not a playlist, reasonable duration)
  bool _isValidSong(Song song) {
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();
    
    // Filter out playlists and compilations
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
    
    // Check duration (2-8 minutes)
    final seconds = song.duration.inSeconds;
    if (seconds > 0 && (seconds < 90 || seconds > 480)) return false;
    
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

  const ChartDefinition({
    required this.id,
    required this.name,
    required this.source,
    required this.description,
    required this.iconType,
    this.region,
  });
}

/// Chart sources
enum ChartSource {
  spotify,
  youtube,
  billboard,
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

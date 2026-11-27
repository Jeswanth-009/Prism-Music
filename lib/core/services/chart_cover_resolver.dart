import 'package:dio/dio.dart';

import '../di/injection.dart';
import 'chart_service.dart';

/// Resolves real cover artwork for charts.
///
/// Spotify playlists resolve through the public oEmbed endpoint — the same
/// cover the Spotify charts site shows. Every other provider falls back to
/// the artwork of the chart's current #1 track (what Apple Music's chart
/// pages use as their hero), fetched through [ChartService] so the call
/// doubles as a prefetch of the countdown itself.
///
/// Network work starts behind [deferred] and everything is best-effort:
/// failures resolve to null and callers keep their quiet fallback chip.
class ChartCoverResolver {
  ChartCoverResolver._();

  static final _memory = <String, String?>{};
  static final _inFlight = <String, Future<String?>>{};

  /// Synchronous peek: only returns what is already known without network —
  /// a previously resolved cover, or artwork from a cached chart fetch.
  static String? peek(ChartDefinition chart) {
    final known = _memory[chart.id];
    if (known != null) return known;
    return ChartService.instance.peekCachedTopArtwork(chart);
  }

  /// Resolves a cover for [chart], deferring network work by [deferred] so
  /// test harnesses and golden runs never hit the network.
  static Future<String?> resolve(
    ChartDefinition chart, {
    Duration deferred = const Duration(milliseconds: 650),
  }) {
    final known = peek(chart);
    if (known != null) return Future.value(known);
    return _inFlight.putIfAbsent(chart.id, () async {
      await Future<void>.delayed(deferred);
      try {
        final url = await _resolveNow(chart);
        _memory[chart.id] = url;
        return url;
      } catch (_) {
        _memory[chart.id] = null;
        return null;
      } finally {
        _inFlight.remove(chart.id);
      }
    });
  }

  static Future<String?> _resolveNow(ChartDefinition chart) async {
    // Spotify: the playlist cover, via the public oEmbed endpoint.
    final playlistId = chart.playlistId;
    if (chart.source == ChartSource.spotify && playlistId != null) {
      final oembed = await _spotifyOEmbedCover(playlistId);
      if (oembed != null) return oembed;
    }
    // Everyone else: the current #1 track's artwork, prefetched through
    // the certified chart fetch.
    final songs = await ChartService.instance.getChartSongs(chart);
    if (songs.isEmpty) return null;
    return songs.first.thumbnails.max ??
        songs.first.thumbnails.high ??
        songs.first.thumbnailUrl;
  }

  static Future<String?> _spotifyOEmbedCover(String playlistId) async {
    final dio = getIt.isRegistered<Dio>() ? getIt<Dio>() : Dio();
    final response = await dio.get<Map<String, dynamic>>(
      'https://open.spotify.com/oembed',
      queryParameters: {
        'url': 'https://open.spotify.com/playlist/$playlistId',
      },
      options: Options(
        responseType: ResponseType.json,
        sendTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (response.statusCode != 200 || response.data == null) return null;
    final url = (response.data!['thumbnail_url'] ?? '').toString();
    return url.isEmpty ? null : url;
  }

  /// Test hook: clear memoised covers.
  static void reset() => _memory.clear();
}

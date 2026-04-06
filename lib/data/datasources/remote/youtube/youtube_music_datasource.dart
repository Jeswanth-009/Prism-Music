import 'package:flutter/foundation.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../../../../domain/entities/song.dart';
import '../../../../domain/entities/playlist.dart';
import '../../../../domain/entities/stream_info.dart' as domain;
import 'invidious_datasource.dart';

/// Data source for YouTube Music API operations
abstract class YouTubeMusicDataSource {
  /// Get stream URL for a video
  Future<domain.StreamInfo> getStreamUrl(
    String videoId, {
    AudioQuality preferredQuality = AudioQuality.high,
  });

  /// Get all available streams for a video
  Future<List<domain.StreamInfo>> getAvailableStreams(String videoId);

  /// Get related/recommended songs
  Future<List<Song>> getRelatedSongs(String videoId, {int limit = 20});

  /// Get video/song details
  Future<Song> getSongDetails(String videoId);

  /// Get playlist details and tracks
  Future<Playlist> getPlaylistDetails(String playlistId);

  /// Get YouTube Music charts
  Future<List<Song>> getCharts({String region = 'US', int limit = 50});
}

/// Implementation using youtube_explode_dart
class YouTubeMusicDataSourceImpl implements YouTubeMusicDataSource {
  final yt.YoutubeExplode _youtube = yt.YoutubeExplode();
  final InvidiousDataSource _invidious = InvidiousDataSource();

  // Lightweight rate limiting + caching to keep fetches snappy without hitting limits
  DateTime? _lastRequestTime;
  static const _minRequestInterval = Duration(
    milliseconds: 200,
  ); // more responsive than 1s

  // Stream URL cache to avoid repeated manifest fetches for recently played tracks
  final Map<String, _StreamCacheEntry> _streamCache = {};
  static const _streamCacheTtl = Duration(minutes: 25);

  /// Wait before making request to avoid rate limiting
  Future<void> _waitForRateLimit() async {
    if (_lastRequestTime != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastRequestTime!);
      if (timeSinceLastRequest < _minRequestInterval) {
        final waitTime = _minRequestInterval - timeSinceLastRequest;
        debugPrint(
          'YouTubeDataSource: Rate limiting - waiting ${waitTime.inMilliseconds}ms',
        );
        await Future.delayed(waitTime);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  /// Retry a search operation with exponential backoff
  Future<T> _retrySearch<T>(
    Future<T> Function() operation, {
    int maxRetries = 2,
    Duration initialDelay = const Duration(seconds: 2),
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        await _waitForRateLimit();
        return await operation();
      } catch (e) {
        attempt++;
        if (attempt > maxRetries ||
            !e.toString().contains('Redirect limit exceeded')) {
          rethrow;
        }

        debugPrint(
          'YouTubeDataSource: Retry attempt $attempt after ${delay.inSeconds}s due to rate limit',
        );
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }

  @override
  Future<domain.StreamInfo> getStreamUrl(
    String videoId, {
    AudioQuality preferredQuality = AudioQuality.high,
  }) async {
    final totalStopwatch = Stopwatch()..start();
    debugPrint('YouTubeDataSource: Getting stream URL for $videoId');

    final cacheKey = _streamCacheKey(videoId, preferredQuality);
    final cached = _streamCache[cacheKey];
    if (cached != null && _isStreamCacheEntryValid(cached)) {
      totalStopwatch.stop();
      debugPrint(
        'YouTubeDataSource: Stream cache HIT for $videoId ($preferredQuality) '
        'in ${totalStopwatch.elapsedMilliseconds}ms',
      );
      return cached.streamInfo;
    }

    // Primary approach: YouTube Explode (direct streams - most reliable)
    // Strict audio-only path: fetch manifest once, select audio stream only.
    try {
      debugPrint(
        'YouTubeDataSource: Trying YouTube Explode (audio-only manifest)...',
      );
      final manifestStopwatch = Stopwatch()..start();
      final manifest = await _youtube.videos.streams.getManifest(
        videoId,
        requireWatchPage: true,
        ytClients: [yt.YoutubeApiClient.androidVr],
      );
      manifestStopwatch.stop();

      final selectStopwatch = Stopwatch()..start();
      final audioStreams = manifest.audioOnly.toList()
        ..sort(
          (a, b) => b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
        );

      if (audioStreams.isNotEmpty) {
        yt.AudioOnlyStreamInfo selectedStream;

        debugPrint(
          'YouTubeDataSource: Found ${audioStreams.length} audio streams',
        );

        switch (preferredQuality) {
          case AudioQuality.lossless:
          case AudioQuality.high:
            selectedStream = _selectBestAudioStream(
              audioStreams,
              preferWebM: true,
            );
            break;
          case AudioQuality.medium:
            selectedStream = _selectMediumQualityStream(audioStreams);
            break;
          case AudioQuality.low:
            selectedStream = _selectLowQualityStream(audioStreams);
            break;
        }
        selectStopwatch.stop();

        final directUrl = selectedStream.url.toString();
        totalStopwatch.stop();

        debugPrint('YouTubeDataSource: ✓ YouTube Explode SUCCESS');
        debugPrint(
          '  - ${selectedStream.container.name} ${selectedStream.codec.subtype} '
          '${selectedStream.bitrate.kiloBitsPerSecond}kbps',
        );
        debugPrint(
          '  - manifest: ${manifestStopwatch.elapsedMilliseconds}ms, '
          'selection: ${selectStopwatch.elapsedMilliseconds}ms, '
          'total: ${totalStopwatch.elapsedMilliseconds}ms',
        );

        final streamHeaders = {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Referer': 'https://www.youtube.com/',
          'Origin': 'https://www.youtube.com',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Range': 'bytes=0-',
        };

        final streamInfo = domain.StreamInfo(
          url: directUrl,
          codec: selectedStream.codec.subtype,
          bitrate: selectedStream.bitrate.kiloBitsPerSecond.toInt(),
          container: selectedStream.container.name,
          quality: _bitrateToQuality(
            selectedStream.bitrate.kiloBitsPerSecond.toInt(),
          ),
          // Avoid extra probe calls here; size is optional for playback startup.
          contentLength: null,
          expiresAt: _extractExpiryFromUrl(directUrl),
          isAudioOnly: true,
          headers: streamHeaders,
        );

        _cacheStream(cacheKey, streamInfo);
        return streamInfo;
      }

      throw Exception('No audio-only streams available for video $videoId');
    } catch (e) {
      debugPrint('YouTubeDataSource: ✗ YouTube Explode failed: $e');
      final errorText = e.toString();

      if (_isVideoStream403Error(errorText)) {
        debugPrint(
          'YouTubeDataSource: Skipping retries for video-stream 403 '
          '(not needed for audio playback)',
        );
      }

      // On rate limiting, single retry after short delay
      if (_isRateLimitError(errorText) && !_isVideoStream403Error(errorText)) {
        debugPrint(
          'YouTubeDataSource: Rate limited, retrying in 1.5 seconds...',
        );
        await Future.delayed(const Duration(milliseconds: 1500));

        try {
          final manifest = await _youtube.videos.streams.getManifest(
            videoId,
            requireWatchPage: true,
            ytClients: [yt.YoutubeApiClient.androidVr],
          );
          final audioStreams = manifest.audioOnly.toList()
            ..sort(
              (a, b) =>
                  b.bitrate.bitsPerSecond.compareTo(a.bitrate.bitsPerSecond),
            );

          if (audioStreams.isNotEmpty) {
            final selectedStream = _selectBestAudioStream(
              audioStreams,
              preferWebM: true,
            );

            debugPrint('YouTubeDataSource: ✓ YouTube Explode RETRY SUCCESS');

            final streamInfo = domain.StreamInfo(
              url: selectedStream.url.toString(),
              codec: selectedStream.codec.subtype,
              bitrate: selectedStream.bitrate.kiloBitsPerSecond.toInt(),
              container: selectedStream.container.name,
              quality: _bitrateToQuality(
                selectedStream.bitrate.kiloBitsPerSecond.toInt(),
              ),
              contentLength: null,
              expiresAt: _extractExpiryFromUrl(selectedStream.url.toString()),
              isAudioOnly: true,
              headers: {
                'User-Agent':
                    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                'Referer': 'https://www.youtube.com/',
              },
            );

            _cacheStream(cacheKey, streamInfo);
            return streamInfo;
          }
        } catch (retryE) {
          debugPrint('YouTubeDataSource: ✗ Retry also failed: $retryE');
        }
      }
    }

    // Fallback: Try Invidious as backup option
    try {
      final fallbackStopwatch = Stopwatch()..start();
      debugPrint('YouTubeDataSource: Trying Invidious...');
      final invidiousStream = await _invidious.getStreamUrl(videoId);
      fallbackStopwatch.stop();
      if (invidiousStream != null) {
        totalStopwatch.stop();
        debugPrint(
          'YouTubeDataSource: ✓ Invidious SUCCESS '
          '(fallback ${fallbackStopwatch.elapsedMilliseconds}ms, '
          'total ${totalStopwatch.elapsedMilliseconds}ms)',
        );
        _cacheStream(cacheKey, invidiousStream);
        return invidiousStream;
      }
      debugPrint('YouTubeDataSource: ✗ Invidious returned null');
    } catch (e) {
      debugPrint('YouTubeDataSource: ✗ Invidious failed: $e');
    }

    throw Exception('All stream sources failed for video $videoId');
  }

  bool _isRateLimitError(String errorText) {
    final lower = errorText.toLowerCase();
    return lower.contains('429') || lower.contains('rate limit');
  }

  bool _isVideoStream403Error(String errorText) {
    final lower = errorText.toLowerCase();
    if (!lower.contains('403')) return false;

    final streamMatch = RegExp(r'stream:\s*(\d+)').firstMatch(lower);
    if (streamMatch == null) return false;

    final streamId = streamMatch.group(1);
    const audioItags = {'139', '140', '141', '171', '172', '249', '250', '251'};
    return streamId != null && !audioItags.contains(streamId);
  }

  @override
  Future<List<domain.StreamInfo>> getAvailableStreams(String videoId) async {
    final manifest = await _youtube.videos.streamsClient.getManifest(videoId);

    return manifest.audioOnly
        .map(
          (s) => domain.StreamInfo(
            url: s.url.toString(),
            codec: s.codec.subtype,
            bitrate: s.bitrate.kiloBitsPerSecond.toInt(),
            container: s.container.name,
            quality: _bitrateToQuality(s.bitrate.kiloBitsPerSecond.toInt()),
            contentLength: s.size.totalBytes,
            isAudioOnly: true,
          ),
        )
        .toList();
  }

  @override
  Future<List<Song>> getRelatedSongs(String videoId, {int limit = 20}) async {
    try {
      // Try YouTube's Mix/Radio playlist for the video — better related content
      final mixPlaylistId = 'RDMM$videoId';
      try {
        final videos = await _youtube.playlists
            .getVideos(mixPlaylistId)
            .take(limit + 10)
            .toList();
        if (videos.length > 1) {
          debugPrint(
            'YouTubeDataSource: Got ${videos.length} from Mix playlist',
          );
          // Skip the first entry (usually the source song itself)
          return videos
              .skip(1)
              .map((v) => _videoToSong(v))
              .where(
                (s) =>
                    s.duration.inSeconds >= 60 &&
                    s.duration.inSeconds <= 600 &&
                    !_isLikelyNonMusic(s),
              )
              .take(limit)
              .toList();
        }
      } catch (_) {
        debugPrint(
          'YouTubeDataSource: Mix playlist fetch failed, falling back to search',
        );
      }

      // Fallback: search by author + title
      final video = await _youtube.videos.get(videoId);
      final query = '${video.author} ${video.title.split('-').first.trim()}';
      return _searchSongsByQuery(query, limit: limit);
    } catch (e) {
      debugPrint('YouTubeDataSource: getRelatedSongs error: $e');
      return [];
    }
  }

  Future<List<Song>> _searchSongsByQuery(String query, {int limit = 20}) async {
    try {
      final results = await _retrySearch(() => _youtube.search.search(query));
      final songs = <Song>[];
      final seen = <String>{};

      for (final result in results) {
        if (songs.length >= limit) break;
        if (result is! yt.SearchVideo) continue;

        final song = _videoToSong(result);
        final trackKey =
            '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
        if (!seen.add(trackKey)) continue;

        if (song.duration.inSeconds < 45 || song.duration.inSeconds > 720) {
          continue;
        }
        if (_isLikelyNonMusic(song)) continue;

        songs.add(song);
      }

      return songs;
    } catch (e) {
      debugPrint(
        'YouTubeDataSource: _searchSongsByQuery failed for "$query": $e',
      );
      return [];
    }
  }

  @override
  Future<Song> getSongDetails(String videoId) async {
    final video = await _youtube.videos.get(videoId);
    return _videoToSong(video);
  }

  @override
  Future<Playlist> getPlaylistDetails(String playlistId) async {
    final playlist = await _youtube.playlists.get(playlistId);
    final videos = await _youtube.playlists.getVideos(playlistId).toList();

    final songs = videos.map((v) => _videoToSong(v)).toList();
    String? thumbnailUrl;
    try {
      thumbnailUrl = playlist.thumbnails.maxResUrl;
    } catch (e) {
      thumbnailUrl = null;
    }

    // Calculate total duration
    Duration totalDuration = Duration.zero;
    for (final song in songs) {
      totalDuration = totalDuration + song.duration;
    }

    return Playlist(
      id: playlist.id.value,
      name: playlist.title,
      description: playlist.description,
      thumbnails: thumbnailUrl != null
          ? Thumbnails.fromUrl(thumbnailUrl)
          : Thumbnails.empty(),
      author: playlist.author,
      trackCount: videos.length,
      totalDuration: totalDuration,
      songs: songs,
      youtubePlaylistId: playlist.id.value,
    );
  }

  @override
  Future<List<Song>> getCharts({String region = 'US', int limit = 50}) async {
    // Search for trending music with region-specific query
    // YouTube's search naturally adapts to regional content
    final regionQuery = region.toUpperCase();
    debugPrint('YouTubeDataSource: Fetching charts for region: $regionQuery');

    final currentYear = DateTime.now().year;
    // Region-specific search strategies
    final searchQueries = [
      'top hits $regionQuery $currentYear',
      'trending music $regionQuery $currentYear',
      'popular songs $regionQuery',
    ];

    final allSongs = <Song>[];
    final seen = <String>{};

    for (final query in searchQueries) {
      if (allSongs.length >= limit) break;

      try {
        final searchResults = await _retrySearch(
          () => _youtube.search.search(query),
        );

        for (final result in searchResults) {
          if (allSongs.length >= limit) break;
          if (result is! yt.SearchVideo) continue;

          final song = _videoToSong(result);
          final trackKey =
              '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';

          // Skip duplicates and invalid durations
          if (seen.contains(trackKey)) continue;
          if (song.duration.inSeconds < 90 || song.duration.inSeconds > 420) {
            continue;
          }

          seen.add(trackKey);
          allSongs.add(song);
        }
      } catch (e) {
        debugPrint('YouTubeDataSource: Chart query "$query" failed: $e');
      }
    }

    debugPrint(
      'YouTubeDataSource: Returning ${allSongs.length} chart songs for $regionQuery',
    );
    return allSongs.take(limit).toList();
  }

  /// Parse a duration string like "3:45" or "1:02:30" into a [Duration].
  Duration? _parseDuration(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parts = raw.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    if (parts.length == 3) {
      return Duration(hours: parts[0], minutes: parts[1], seconds: parts[2]);
    } else if (parts.length == 2) {
      return Duration(minutes: parts[0], seconds: parts[1]);
    }
    return null;
  }

  // Helper methods
  Song _videoToSong(dynamic video) {
    // Extract video ID
    String videoId;
    String title;
    String channelName;
    String? thumbnailUrl;
    Duration? duration;

    if (video is yt.Video) {
      videoId = video.id.value;
      title = video.title;
      channelName = video.author;
      try {
        thumbnailUrl = video.thumbnails.maxResUrl;
      } catch (e) {
        thumbnailUrl = null;
      }
      duration = video.duration;
    } else if (video is yt.SearchVideo) {
      videoId = video.id.value;
      title = video.title;
      channelName = video.author;
      try {
        thumbnailUrl = video.thumbnails.isNotEmpty
            ? video.thumbnails.first.url.toString()
            : null;
      } catch (e) {
        thumbnailUrl = null;
      }
      // SearchVideo has duration as a String – parse it
      duration = _parseDuration(video.duration);
    } else {
      throw Exception('Unsupported video type: ${video.runtimeType}');
    }

    // ── Clean title ──
    // Only strip noise tags like [Official Video], (Official Audio), [Lyrics],
    // [HD], [HQ], (Audio), (Music Video), etc.
    // KEEP meaningful info like (feat. …), (from …), (Deluxe), (Remix).
    String cleanTitle = title
        .replaceAll(
          RegExp(
            r'[\[\(]\s*(?:official\s*(?:music\s*)?(?:video|audio|lyric(?:s)?\s*(?:video)?|visuali[sz]er|mv)|'
            r'lyric(?:s)?\s*(?:video)?|music\s*video|audio|(?:full\s*)?hd|hq|4k|360°?|'
            r'explicit|clean\s*version|remastered|remaster|official)\s*[\]\)]',
            caseSensitive: false,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    // Extract artist and song name from "Artist - Song" pattern
    // Use the FIRST " - " only (some songs have dashes in the title)
    String artist = channelName;
    String songName = cleanTitle;

    final dashIdx = cleanTitle.indexOf(' - ');
    if (dashIdx > 0) {
      final before = cleanTitle.substring(0, dashIdx).trim();
      final after = cleanTitle.substring(dashIdx + 3).trim();
      if (before.isNotEmpty && after.isNotEmpty) {
        artist = before;
        songName = after;
      }
    }

    // Strip " - Topic" from auto-generated YouTube Music channels
    artist = artist
        .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
        .trim();
    // Strip "VEVO" suffix from channel names
    artist = artist
        .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
        .trim();

    return Song(
      id: videoId,
      title: songName,
      artist: artist,
      duration: duration ?? const Duration(minutes: 3),
      thumbnails: thumbnailUrl != null
          ? Thumbnails.fromUrl(thumbnailUrl)
          : Thumbnails.empty(),
    );
  }

  /// Select the best audio stream (highest quality) similar to yt-dlp's 'bestaudio'
  yt.AudioOnlyStreamInfo _selectBestAudioStream(
    List<yt.AudioOnlyStreamInfo> streams, {
    bool preferWebM = true,
  }) {
    if (streams.isEmpty) throw Exception('No audio streams available');

    // First, try to find the highest bitrate WebM/Opus stream (modern, efficient codec)
    if (preferWebM) {
      final webmStreams = streams
          .where(
            (s) =>
                s.container.name.toLowerCase() == 'webm' &&
                s.codec.subtype.toLowerCase().contains('opus'),
          )
          .toList();

      if (webmStreams.isNotEmpty) {
        final bestWebm = webmStreams.first; // Already sorted by bitrate
        debugPrint(
          'YouTubeDataSource: Selected best WebM/Opus: ${bestWebm.bitrate.kiloBitsPerSecond}kbps',
        );
        return bestWebm;
      }

      // If no Opus, try any WebM
      final anyWebm = streams
          .where((s) => s.container.name.toLowerCase() == 'webm')
          .toList();
      if (anyWebm.isNotEmpty) {
        debugPrint(
          'YouTubeDataSource: Selected best WebM: ${anyWebm.first.bitrate.kiloBitsPerSecond}kbps',
        );
        return anyWebm.first;
      }
    }

    // Fall back to highest bitrate stream regardless of container
    final best = streams.first;
    debugPrint(
      'YouTubeDataSource: Selected highest bitrate stream: ${best.container.name} ${best.bitrate.kiloBitsPerSecond}kbps',
    );
    return best;
  }

  /// Select medium quality stream (around 128-160 kbps)
  yt.AudioOnlyStreamInfo _selectMediumQualityStream(
    List<yt.AudioOnlyStreamInfo> streams,
  ) {
    // Look for streams in the 128-160 kbps range
    final mediumQualityStreams = streams
        .where(
          (s) =>
              s.bitrate.kiloBitsPerSecond >= 128 &&
              s.bitrate.kiloBitsPerSecond <= 160,
        )
        .toList();

    if (mediumQualityStreams.isNotEmpty) {
      // Prefer WebM in this range
      final webmMedium = mediumQualityStreams
          .where((s) => s.container.name.toLowerCase() == 'webm')
          .toList();
      if (webmMedium.isNotEmpty) {
        return webmMedium.first;
      }
      return mediumQualityStreams.first;
    }

    // If no medium quality, pick middle stream
    final middleIndex = streams.length ~/ 2;
    return streams[middleIndex];
  }

  /// Select low quality stream (lowest bitrate but still prefer WebM)
  yt.AudioOnlyStreamInfo _selectLowQualityStream(
    List<yt.AudioOnlyStreamInfo> streams,
  ) {
    // Try to find the lowest bitrate WebM stream first
    final webmStreams = streams
        .where((s) => s.container.name.toLowerCase() == 'webm')
        .toList();
    if (webmStreams.isNotEmpty) {
      return webmStreams.last; // Last element has lowest bitrate
    }

    // Fall back to overall lowest bitrate
    return streams.last;
  }

  AudioQuality _bitrateToQuality(int bitrateKbps) {
    if (bitrateKbps >= 256) return AudioQuality.lossless;
    if (bitrateKbps >= 160) return AudioQuality.high;
    if (bitrateKbps >= 96) return AudioQuality.medium;
    return AudioQuality.low;
  }

  /// Non-music channel names — interviews, reactions, podcasts, news.
  /// Uses word-boundary matching to avoid false positives (e.g. "Radiohead").
  static final _nonMusicChannels = RegExp(
    r'(?:^|\W)(?:entertainment tonight|billboard news|access hollywood|'
    r'the tonight show|jimmy kimmel|jimmy fallon|late night with|good morning america|'
    r'the breakfast club|hot 97|siriusxm|complex news|xxl mag|the fader|'
    r'pitchfork|nardwuar|fine brothers|teens react|'
    r'first we feast|hot ones)(?:$|\W)',
    caseSensitive: false,
  );

  /// Non-music title patterns — not actual songs.
  /// More precise patterns to avoid blocking legitimate music.
  static final _nonMusicTitles = RegExp(
    r'(?:^|\W)(?:interview|reacts? to|talks? about|talks? upcoming|responds to|'
    r'reveals|breaks down|explains|podcast|behind the scenes|making of|documentary|'
    r'unboxing|haul|\bvlog\b|Q&A|\bAMA\b|livestream|live stream|'
    r'cipher|tier list|ranking .* songs|'
    r'commentary|roast|exposed|'
    r'\btutorial\b|\bhow to\b|\blesson\b|\bguide\b|\btips\b)(?:$|\W)',
    caseSensitive: false,
  );

  /// Check if a song result is likely NOT music (interview, reaction, podcast, etc.)
  bool _isLikelyNonMusic(Song song) {
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();

    // Check non-music channels
    if (_nonMusicChannels.hasMatch(artist)) return true;

    // Check non-music title patterns (match against the FULL original title)
    if (_nonMusicTitles.hasMatch(title)) return true;

    return false;
  }

  String _streamCacheKey(String videoId, AudioQuality quality) =>
      '${videoId}_${quality.name}';

  bool _isStreamCacheEntryValid(_StreamCacheEntry entry) {
    if (DateTime.now().difference(entry.cachedAt) > _streamCacheTtl) {
      return false;
    }

    final expiresAt = entry.streamInfo.expiresAt;
    if (expiresAt == null) {
      return true;
    }

    // Add a safety buffer so we don't return a near-expired URL.
    return DateTime.now().isBefore(
      expiresAt.subtract(const Duration(minutes: 1)),
    );
  }

  void _cacheStream(String key, domain.StreamInfo streamInfo) {
    _streamCache[key] = _StreamCacheEntry(
      streamInfo: streamInfo,
      cachedAt: DateTime.now(),
    );

    if (_streamCache.length > 200) {
      final oldestKey = _streamCache.entries
          .reduce((a, b) => a.value.cachedAt.isBefore(b.value.cachedAt) ? a : b)
          .key;
      _streamCache.remove(oldestKey);
    }
  }

  DateTime? _extractExpiryFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final expires = uri.queryParameters['expire'];
      if (expires == null) return null;
      final epochSeconds = int.tryParse(expires);
      if (epochSeconds == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(epochSeconds * 1000);
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _youtube.close();
  }
}

class _StreamCacheEntry {
  final domain.StreamInfo streamInfo;
  final DateTime cachedAt;

  _StreamCacheEntry({required this.streamInfo, required this.cachedAt});
}

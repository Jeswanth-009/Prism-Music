import 'dart:async';
import 'package:dio/dio.dart';
import '../../../../domain/entities/entities.dart';
import 'custom_lyrics_storage.dart';
import 'fallback_lyrics_provider.dart';
import 'lyrics_local_cache.dart';
import 'providers/better_lyrics_provider.dart';
import 'providers/bini_lyrics_provider.dart';
import 'providers/genius_lyrics_provider.dart';
import 'providers/jiosaavn_lyrics_provider.dart';
import 'providers/kugou_lyrics_provider.dart';
import 'providers/lrclib_provider.dart';
import 'providers/lyrics_plus_provider.dart';
import 'providers/lyrics_provider.dart';
import 'providers/netease_lyrics_provider.dart';
import 'providers/qq_music_provider.dart';
import 'providers/unison_lyrics_provider.dart';
import 'providers/youtube_transcript_provider.dart';

/// Abstract contract for multi-source lyrics data operations.
abstract class LyricsDataSource {
  /// Get synced or plain lyrics for a song.
  /// When [preferredProviderId] is provided, that specific provider is used.
  /// Otherwise, the 3-tier intelligent auto-switcher selects the highest quality source.
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
    bool forceRefresh = false,
    String? preferredProviderId,
    String? songId,
  });

  /// Get plain text lyrics for a song.
  Future<String?> getPlainLyrics(String title, String artist);

  /// Inspect and list all available lyrics sources and their status for a song.
  Future<List<LyricsSourceDescriptor>> getAvailableSources(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  });
}

/// Thrown when the lyrics service is unreachable or encounters an outage.
class LyricsOutageException implements Exception {
  final String message;
  const LyricsOutageException(this.message);

  @override
  String toString() => 'LyricsOutageException: $message';
}

/// Multi-source orchestrator with 3-tier quality cascade and provider selection.
class LyricsDataSourceImpl implements LyricsDataSource {
  final Dio _dio;
  final LyricsLocalCache _cache;
  final FallbackLyricsProvider? _fallbackProvider;

  // Registered providers
  late final BetterLyricsProvider _betterLyrics;
  late final LyricsPlusProvider _lyricsPlus;
  late final QqMusicLyricsProvider _qqMusic;
  late final BiniLyricsProvider _bini;
  late final UnisonLyricsProvider _unison;
  late final LrclibLyricsProvider _lrclib;
  late final NetEaseLyricsProvider _netEase;
  late final KuGouLyricsProvider _kuGou;
  late final YouTubeTranscriptProvider _ytTranscript;
  late final JioSaavnLyricsProvider _jioSaavn;
  late final GeniusLyricsProvider _genius;

  LyricsDataSourceImpl({
    required Dio dio,
    LyricsLocalCache? cache,
    FallbackLyricsProvider? fallbackProvider,
  })  : _dio = dio,
        _cache = cache ?? LyricsLocalCache(),
        _fallbackProvider = fallbackProvider {
    _betterLyrics = BetterLyricsProvider(dio: _dio);
    _lyricsPlus = LyricsPlusProvider(dio: _dio);
    _qqMusic = QqMusicLyricsProvider(dio: _dio);
    _bini = BiniLyricsProvider(dio: _dio);
    _unison = UnisonLyricsProvider(dio: _dio);
    _lrclib = LrclibLyricsProvider(dio: _dio);
    _netEase = NetEaseLyricsProvider(dio: _dio);
    _kuGou = KuGouLyricsProvider(dio: _dio);
    _ytTranscript = YouTubeTranscriptProvider();
    _jioSaavn = JioSaavnLyricsProvider(dio: _dio);
    _genius = GeniusLyricsProvider(dio: _dio);
  }

  List<LyricsProvider> get _allProviders => [
        _kuGou,
        _qqMusic,
        _betterLyrics,
        _lyricsPlus,
        _bini,
        _netEase,
        _lrclib,
        _unison,
        _genius,
        _ytTranscript,
        _jioSaavn,
      ];

  LyricsProvider? _getProviderById(String id) {
    try {
      return _allProviders.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Lyrics?> getSyncedLyrics(
    String title,
    String artist, {
    Duration? duration,
    bool forceRefresh = false,
    String? preferredProviderId,
    String? songId,
  }) async {
    final effectiveSongId = songId ?? '${artist}_$title';

    // 0. Always check user-edited / custom lyrics first unless explicitly requesting another source
    if (preferredProviderId == null || preferredProviderId == 'prism_custom') {
      final customLyrics = await CustomLyricsStorage.instance.getCustomLyrics(
        title,
        artist,
        effectiveSongId,
      );
      if (customLyrics != null) return customLyrics;
      if (preferredProviderId == 'prism_custom') return null;
    }

    // 1. Direct provider selection override
    if (preferredProviderId != null) {
      final targetProvider = _getProviderById(preferredProviderId);
      if (targetProvider != null) {
        final result = await targetProvider.fetchLyrics(
          title,
          artist,
          duration: duration,
          songId: effectiveSongId,
        );
        if (result != null) {
          await _cacheSuccess(title, artist, result, duration: duration);
          return result;
        }
        return null;
      }
    }

    // 2. Cache lookup across all 12 providers (bypass on forceRefresh)
    if (!forceRefresh) {
      final candidateProviderIds = <String>[
        ?preferredProviderId,
        _betterLyrics.id,
        _lyricsPlus.id,
        _qqMusic.id,
        _bini.id,
        _unison.id,
        _lrclib.id,
        'LRCLIB',
        _netEase.id,
        _kuGou.id,
        _ytTranscript.id,
        _jioSaavn.id,
        _genius.id,
        'lyrics.ovh',
      ];
      for (final pid in candidateProviderIds.toSet()) {
        final cached = await _cache.get(
          title,
          artist,
          effectiveSongId,
          duration: duration,
          provider: pid,
        );
        if (cached != null) return cached;
      }

      final isKnownNotFound = await _cache.isMarkedNotFound(
        title,
        artist,
        duration: duration,
      );
      if (isKnownNotFound) return null;
    }

    // 3. Intelligent 3-Tier Auto-Switcher Cascade
    // Tier 1: Word-by-Word Karaoke (Better Lyrics, LyricsPlus, QQ Music, Bini, Unison)
    final tier1Providers = [
      _betterLyrics,
      _lyricsPlus,
      _qqMusic,
      _bini,
      _unison,
    ];

    Lyrics? tier1SyncedFallback;
    for (final provider in tier1Providers) {
      try {
        final result = await provider.fetchLyrics(
          title,
          artist,
          duration: duration,
          songId: effectiveSongId,
        );
        if (result != null && result.isWordSynced) {
          await _cacheSuccess(title, artist, result, duration: duration);
          return result;
        }
        if (result != null && result.isSynced && tier1SyncedFallback == null) {
          tier1SyncedFallback = result;
        }
      } catch (_) {
        // Individual provider timeout / error falls through
      }
    }

    // Tier 2: Time-synced lines (LRCLIB, NetEase, KuGou, JioSaavn, YouTube Transcripts)
    final tier2Providers = [
      _lrclib,
      _netEase,
      _kuGou,
      _ytTranscript,
      _jioSaavn,
    ];

    for (final provider in tier2Providers) {
      try {
        final result = await provider.fetchLyrics(
          title,
          artist,
          duration: duration,
          songId: effectiveSongId,
        );
        if (result != null && result.isSynced) {
          await _cacheSuccess(title, artist, result, duration: duration);
          return result;
        }
      } catch (_) {
        // Fall through
      }
    }

    if (tier1SyncedFallback != null) {
      await _cacheSuccess(title, artist, tier1SyncedFallback, duration: duration);
      return tier1SyncedFallback;
    }

    // Tier 3: Plain text fallbacks (Genius, Lyrics.ovh)
    try {
      final geniusResult = await _genius.fetchLyrics(
        title,
        artist,
        duration: duration,
        songId: effectiveSongId,
      );
      if (geniusResult != null && (geniusResult.plainLyrics?.isNotEmpty ?? false)) {
        await _cacheSuccess(title, artist, geniusResult, duration: duration);
        return geniusResult;
      }
    } catch (_) {}

    if (_fallbackProvider != null) {
      try {
        final fallbackPlain = await _fallbackProvider.fetchLyrics(title, artist);
        if (fallbackPlain != null && fallbackPlain.trim().isNotEmpty) {
          final fallbackLyrics = Lyrics(
            songId: effectiveSongId,
            plainLyrics: fallbackPlain.trim(),
            syncedLyrics: null,
            source: 'lyrics.ovh',
            syncType: LyricsSyncType.plain,
            providerId: 'lyrics.ovh',
          );
          await _cacheSuccess(title, artist, fallbackLyrics, duration: duration);
          return fallbackLyrics;
        }
      } catch (_) {}
    }

    // Mark not found in cache so subsequent lookups are fast
    await _cache.markNotFound(title, artist, duration: duration);
    return null;
  }

  @override
  Future<String?> getPlainLyrics(String title, String artist) async {
    final lyrics = await getSyncedLyrics(title, artist);
    return lyrics?.plainLyrics;
  }

  @override
  Future<List<LyricsSourceDescriptor>> getAvailableSources(
    String title,
    String artist, {
    Duration? duration,
    String? songId,
  }) async {
    final effectiveSongId = songId ?? '${artist}_$title';
    final results = <LyricsSourceDescriptor>[];

    // Check custom lyrics first
    final customLyrics = await CustomLyricsStorage.instance.getCustomLyrics(
      title,
      artist,
      effectiveSongId,
    );

    // Query each provider concurrently with a 2.5-second cap
    final providerChecks = _allProviders.map((provider) async {
      try {
        final lyrics = await provider
            .fetchLyrics(
              title,
              artist,
              duration: duration,
              songId: effectiveSongId,
            )
            .timeout(const Duration(milliseconds: 2500));

        final available = lyrics != null;
        final syncType = lyrics?.syncType ?? provider.syncType;
        return LyricsSourceDescriptor.fromAvailability(
          id: provider.id,
          displayName: provider.displayName,
          type: syncType,
          available: available,
        );
      } catch (_) {
        return LyricsSourceDescriptor.fromAvailability(
          id: provider.id,
          displayName: provider.displayName,
          type: provider.syncType,
          available: false,
        );
      }
    }).toList();

    final descriptors = await Future.wait(providerChecks);

    // Map ordered descriptors matching Screenshot 2:
    // KuGou, QQ Music, Better Lyrics, LyricsPlus, Bini, Prism Music, NetEase, LRCLIB, Unison, Genius
    final orderedIds = [
      'kugou',
      'qq_music',
      'better_lyrics',
      'lyrics_plus',
      'bini',
      'netease',
      'lrclib',
      'unison',
      'genius',
      'youtube_transcript',
      'jiosaavn',
    ];

    final descMap = {for (final d in descriptors) d.id: d};

    for (final id in orderedIds) {
      if (id == 'netease') {
        // Insert Prism Music descriptor right before NetEase
        results.add(LyricsSourceDescriptor.fromAvailability(
          id: 'prism_custom',
          displayName: 'Prism Music',
          type: LyricsSyncType.lineSynced,
          available: customLyrics != null,
        ));
      }
      if (descMap.containsKey(id)) {
        results.add(descMap[id]!);
      }
    }

    return results;
  }

  Future<void> _cacheSuccess(
    String title,
    String artist,
    Lyrics lyrics, {
    Duration? duration,
  }) async {
    await _cache.put(
      title,
      artist,
      duration: duration,
      provider: lyrics.source,
      providerId: lyrics.providerId,
      syncType: lyrics.syncType,
      plainLyrics: lyrics.plainLyrics,
      syncedLrc: _encodeLrc(lyrics.syncedLyrics),
      syncedLyrics: lyrics.syncedLyrics,
    );
  }

  String? _encodeLrc(List<LyricLine>? lines) {
    if (lines == null || lines.isEmpty) return null;
    return lines.map((line) {
      final ms = line.startTimeMs;
      final minutes = (ms ~/ 60000).toString().padLeft(2, '0');
      final seconds = ((ms % 60000) ~/ 1000).toString().padLeft(2, '0');
      final hundredths = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
      return '[$minutes:$seconds.$hundredths]${line.text}';
    }).join('\n');
  }
}

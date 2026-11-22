import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/datasources/remote/lyrics/lyrics_datasource.dart';
import '../../domain/entities/song.dart';
import '../../domain/entities/stream_info.dart';
import '../di/injection.dart';

import 'stream_loader_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/logger.dart';
import '../utils/path_safety.dart';
import '../utils/formatters.dart';
import '../utils/unicode_search_matcher.dart';
import 'settings_service.dart';

/// Builds a filesystem-safe file name for a downloaded song.
///
/// Both inputs come from provider data (ids may contain colons, titles may
/// contain separators), so each component is strictly allowlisted.
String downloadFileName(String playableId, String title) =>
    '${sanitizePathComponent(playableId, maxLength: 64)}-${sanitizePathComponent(title)}.m4a';

enum DownloadStatus {
  notDownloaded,
  queued,
  downloading,
  paused,
  completed,
  failed,
}

/// Download priority levels for queue ordering
enum DownloadPriority {
  low(0),
  normal(1),
  high(2);

  final int value;
  const DownloadPriority(this.value);
}

/// An entry in the download queue tracking metadata, status, and priority
class QueuedDownload {
  final Song song;
  final StreamInfo? resolvedStream;
  final AudioQuality? quality;
  final Completer<bool> completer;
  DownloadPriority priority;
  final DateTime enqueuedAt;

  QueuedDownload({
    required this.song,
    this.resolvedStream,
    this.quality,
    required this.completer,
    this.priority = DownloadPriority.normal,
    DateTime? enqueuedAt,
  }) : enqueuedAt = enqueuedAt ?? DateTime.now();
}

class DownloadInfo {
  final String songId;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? error;
  final String? songTitle;
  final String? artist;
  final String? thumbnailUrl;

  DownloadInfo({
    required this.songId,
    required this.status,
    this.progress = 0.0,
    this.localPath,
    this.error,
    this.songTitle,
    this.artist,
    this.thumbnailUrl,
  });

  DownloadInfo copyWith({
    String? songId,
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? error,
    String? songTitle,
    String? artist,
    String? thumbnailUrl,
  }) {
    return DownloadInfo(
      songId: songId ?? this.songId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
      songTitle: songTitle ?? this.songTitle,
      artist: artist ?? this.artist,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
    );
  }
}

class DownloadService {
  static const String _downloadBoxName = 'downloads';
  static const int _minValidAudioBytes = 16 * 1024;
  static const int _maxConcurrentDownloads = 3;
  final StreamLoaderService _streamLoaderService;
  final Dio _dio;
  final SettingsService _settingsService;
  final LyricsDataSource? _lyricsDataSource;
  final Map<String, CancelToken> _cancelTokens = {};

  final List<QueuedDownload> _downloadQueue = [];
  final Set<String> _activeDownloadIds = {};

  Box? _downloadBox;
  final Map<String, String> _secondaryKeyIndex = {};
  final Map<String, DownloadInfo> _downloadProgress = {};
  final List<Function(DownloadInfo)> _listeners = [];

  DownloadService(
    this._streamLoaderService, {
    Dio? dio,
    SettingsService? settingsService,
    LyricsDataSource? lyricsDataSource,
  })  : _dio = dio ?? Dio(),
        _settingsService = settingsService ?? SettingsService.instance,
        _lyricsDataSource = lyricsDataSource;

  /// Sort queue by priority descending (high > normal > low), then FIFO
  void _sortQueue() {
    _downloadQueue.sort((a, b) {
      final pComp = b.priority.value.compareTo(a.priority.value);
      if (pComp != 0) return pComp;
      return a.enqueuedAt.compareTo(b.enqueuedAt);
    });
  }

  /// Bump priority of a queued song (e.g. user taps "Download Now" on a queued song)
  bool bumpPriority(String songId, [DownloadPriority priority = DownloadPriority.high]) {
    final idx = _downloadQueue.indexWhere((q) => q.song.playableId == songId);
    if (idx != -1) {
      _downloadQueue[idx].priority = priority;
      _sortQueue();
      return true;
    }
    return false;
  }

  /// Unmodifiable view of current download queue
  List<QueuedDownload> get queuedDownloads => List.unmodifiable(_downloadQueue);

  /// Check whether total downloaded storage + estimated download size fits in quota
  Future<bool> checkStorageQuotaAllowed({int estimatedBytes = 8 * 1024 * 1024}) async {
    final quotaMB = _settingsService.downloadStorageQuotaMB;
    if (quotaMB <= 0) return true; // 0 = unlimited

    final currentTotalBytes = await getTotalDownloadSize();
    final quotaBytes = quotaMB * 1024 * 1024;
    return (currentTotalBytes + estimatedBytes) <= quotaBytes;
  }

  Future<void> initialize() async {
    try {
      if (Hive.isBoxOpen(_downloadBoxName)) {
        _downloadBox = Hive.box(_downloadBoxName);
      } else {
        _downloadBox = await Hive.openBox(_downloadBoxName);
      }
      _rebuildSecondaryIndex();
    } catch (e, stack) {
      logError('Download service initialization error', e, stack);
    }
  }

  void _indexRecord(String primaryKey, Map record) {
    void addKey(dynamic val) {
      if (val is String && val.trim().isNotEmpty && val != primaryKey) {
        _secondaryKeyIndex[val.trim()] = primaryKey;
      }
    }

    addKey(record['isrc']);
    addKey(record['youtubeId']);
    addKey(record['jioSaavnId']);
    addKey(record['id']);
    addKey(record['songId']);
  }

  void _rebuildSecondaryIndex() {
    _secondaryKeyIndex.clear();
    if (_downloadBox == null) return;
    for (final key in _downloadBox!.keys) {
      final info = _downloadBox!.get(key) as Map?;
      if (info != null) {
        _indexRecord(key.toString(), info);
      }
    }
  }

  @visibleForTesting
  Box? get downloadBox => _downloadBox;

  /// Add listener for download progress updates
  void addListener(Function(DownloadInfo) listener) {
    _listeners.add(listener);
  }

  /// Remove listener
  void removeListener(Function(DownloadInfo) listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners
  void _notifyListeners(DownloadInfo info) {
    for (final listener in _listeners) {
      listener(info);
    }
  }

  /// Map of all current download progresses/statuses keyed by songId
  Map<String, DownloadInfo> get activeDownloads => Map.unmodifiable(_downloadProgress);

  /// Get status info for a specific song
  DownloadInfo? getDownloadInfo(String songId) => _downloadProgress[songId];

  /// Get download directory (uses custom path from settings if available)
  Future<Directory> _getDownloadDirectory() async {
    final customPath = _settingsService.downloadFolderPath;

    // Try custom path first when provided
    if (customPath != null && customPath.isNotEmpty) {
      final customDir = Directory(customPath);
      try {
        if (!await customDir.exists()) {
          await customDir.create(recursive: true);
        }
        return customDir;
      } catch (e, stack) {
        logError('Failed to use custom download folder: $customPath', e, stack);
      }
    }

    // Primary: app-specific external storage (always writable)
    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        final dir = Directory('${extDir.path}/Downloads/PrismMusic/Audio');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (e, stack) {
      logError('Failed to use external storage directory', e, stack);
    }

    // Fallback: app documents (always writable, scoped to application)
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fallbackDir = Directory('${appDir.path}/Downloads/PrismMusic/Audio');
      if (!await fallbackDir.exists()) {
        await fallbackDir.create(recursive: true);
      }
      return fallbackDir;
    } catch (_) {
      final fallback = Directory('./build/test_downloads');
      if (!fallback.existsSync()) {
        fallback.createSync(recursive: true);
      }
      return fallback;
    }
  }

  /// Get the current download directory path as a string
  Future<String> getDownloadDirectoryPath() async {
    final dir = await _getDownloadDirectory();
    return dir.path;
  }

  /// Check if song is downloaded
  bool isDownloaded(String songId) {
    var info = _downloadBox?.get(songId) as Map?;
    if (info == null && _secondaryKeyIndex.containsKey(songId)) {
      final primaryKey = _secondaryKeyIndex[songId]!;
      info = _downloadBox?.get(primaryKey) as Map?;
    }
    if (info == null) return false;
    final localPath = info['localPath'] as String?;
    if (localPath == null) return false;
    final file = File(localPath);
    if (!file.existsSync()) return false;

    try {
      if (file.lengthSync() < _minValidAudioBytes) {
        return false;
      }
    } catch (_) {
      return false;
    }

    return true;
  }

  /// Check if song is downloaded using any available provider identifier or ISRC
  bool isSongDownloaded(Song song) {
    if (isDownloaded(song.playableId)) return true;
    if (song.isrc != null && song.isrc!.isNotEmpty && isDownloaded(song.isrc!)) return true;
    if (song.youtubeId != null && song.youtubeId!.isNotEmpty && isDownloaded(song.youtubeId!)) return true;
    if (song.jioSaavnId != null && song.jioSaavnId!.isNotEmpty && isDownloaded(song.jioSaavnId!)) return true;
    if (song.id.isNotEmpty && isDownloaded(song.id)) return true;
    return false;
  }

  /// Get local path for a song using any matching key
  String? getLocalPathForSong(Song song) {
    if (isDownloaded(song.playableId)) return getLocalPath(song.playableId);
    if (song.isrc != null && isDownloaded(song.isrc!)) return getLocalPath(song.isrc!);
    if (song.youtubeId != null && isDownloaded(song.youtubeId!)) return getLocalPath(song.youtubeId!);
    if (song.jioSaavnId != null && isDownloaded(song.jioSaavnId!)) return getLocalPath(song.jioSaavnId!);
    if (song.id.isNotEmpty && isDownloaded(song.id)) return getLocalPath(song.id);
    return null;
  }

  /// Get download status
  DownloadStatus getDownloadStatus(String songId) {
    if (_downloadProgress.containsKey(songId)) {
      return _downloadProgress[songId]!.status;
    }
    
    if (isDownloaded(songId)) {
      return DownloadStatus.completed;
    }
    
    return DownloadStatus.notDownloaded;
  }

  /// Get download progress
  double getDownloadProgress(String songId) {
    return _downloadProgress[songId]?.progress ?? 0.0;
  }

  /// Get local file path if downloaded
  String? getLocalPath(String songId) {
    var info = _downloadBox?.get(songId) as Map?;
    if (info == null && _secondaryKeyIndex.containsKey(songId)) {
      final primaryKey = _secondaryKeyIndex[songId]!;
      info = _downloadBox?.get(primaryKey) as Map?;
    }
    return info?['localPath'] as String?;
  }

  /// Download a song with optional priority
  Future<bool> downloadSong(
    Song song, {
    StreamInfo? resolvedStream,
    AudioQuality? quality,
    DownloadPriority priority = DownloadPriority.normal,
  }) async {
    if (isDownloaded(song.playableId)) {
      logDebug('Song already downloaded: ${song.title}');
      return true;
    }

    // Permissions: Default downloads use app-specific external storage which
    // requires no runtime permissions. Only check storage permissions if a
    // custom download directory is configured.
    final customFolder = _settingsService.downloadFolderPath;
    if (customFolder != null && customFolder.isNotEmpty && Platform.isAndroid) {
      try {
        final plugin = DeviceInfoPlugin();
        final androidInfo = await plugin.androidInfo;
        if (androidInfo.version.sdkInt >= 30) {
          if (!await Permission.manageExternalStorage.isGranted) {
            await Permission.manageExternalStorage.request();
          }
        } else {
          if (!await Permission.storage.isGranted) {
            await Permission.storage.request();
          }
        }
      } catch (e) {
        logError('Custom folder permission check failed: $e');
      }
    }

    // Check if currently downloading or queued (allow retry if failed)
    if (_downloadProgress.containsKey(song.playableId)) {
      final currentStatus = _downloadProgress[song.playableId]!.status;
      if (currentStatus == DownloadStatus.downloading ||
          currentStatus == DownloadStatus.queued) {
        logDebug('Song already downloading or queued: ${song.title}');
        return false;
      }
      // Remove failed downloads to allow retry
      if (currentStatus == DownloadStatus.failed) {
        _downloadProgress.remove(song.playableId);
        _cancelTokens.remove(song.playableId);
      }
    }

    // Wi-Fi only check: if downloadWifiOnly is enabled, verify network is Wi-Fi or Ethernet
    if (_settingsService.downloadWifiOnly) {
      try {
        final connectivityResults = await Connectivity().checkConnectivity();
        final hasWifi = connectivityResults.contains(ConnectivityResult.wifi) ||
            connectivityResults.contains(ConnectivityResult.ethernet);
        if (!hasWifi) {
          logDebug('Download skipped: Wi-Fi only is enabled and network is not Wi-Fi');
          final blockedInfo = DownloadInfo(
            songId: song.playableId,
            status: DownloadStatus.failed,
            progress: 0.0,
            error: 'Wi-Fi only enabled. Connect to Wi-Fi to download.',
            songTitle: song.title,
            artist: song.artist,
            thumbnailUrl: song.thumbnailUrl,
          );
          _downloadProgress[song.playableId] = blockedInfo;
          _notifyListeners(blockedInfo);
          return false;
        }
      } catch (e) {
        logError('Connectivity check failed: $e');
      }
    }

    // Storage quota check
    final quotaAllowed = await checkStorageQuotaAllowed();
    if (!quotaAllowed) {
      final quotaMB = _settingsService.downloadStorageQuotaMB;
      logDebug('Download skipped: Storage quota ($quotaMB MB) reached');
      final blockedInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.failed,
        progress: 0.0,
        error: 'Storage quota reached ($quotaMB MB). Adjust quota in Settings.',
        songTitle: song.title,
        artist: song.artist,
        thumbnailUrl: song.thumbnailUrl,
      );
      _downloadProgress[song.playableId] = blockedInfo;
      _notifyListeners(blockedInfo);
      return false;
    }

    if (_activeDownloadIds.length >= _maxConcurrentDownloads) {
      logDebug('Max concurrent downloads reached ($_maxConcurrentDownloads). Queueing: ${song.title} (priority: ${priority.name})');
      final completer = Completer<bool>();
      final queuedInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.queued,
        progress: 0.0,
        songTitle: song.title,
        artist: song.artist,
        thumbnailUrl: song.thumbnailUrl,
      );
      _downloadProgress[song.playableId] = queuedInfo;
      _downloadQueue.add(
        QueuedDownload(
          song: song,
          resolvedStream: resolvedStream,
          quality: quality,
          completer: completer,
          priority: priority,
        ),
      );
      _sortQueue();
      _notifyListeners(queuedInfo);
      return completer.future;
    }

    return _executeDownload(song, resolvedStream: resolvedStream, quality: quality);
  }

  Future<bool> _executeDownload(
    Song song, {
    StreamInfo? resolvedStream,
    AudioQuality? quality,
  }) async {
    _activeDownloadIds.add(song.playableId);
    try {
      return await _downloadSongInternal(
        song,
        resolvedStream: resolvedStream,
        quality: quality,
      );
    } finally {
      _activeDownloadIds.remove(song.playableId);
      _processNextInQueue();
    }
  }

  void _processNextInQueue() {
    if (_downloadQueue.isEmpty) return;
    if (_activeDownloadIds.length >= _maxConcurrentDownloads) return;

    _sortQueue();
    final next = _downloadQueue.removeAt(0);
    // If was cancelled while queued, advance to next
    if (!_downloadProgress.containsKey(next.song.playableId) ||
        _downloadProgress[next.song.playableId]!.status != DownloadStatus.queued) {
      _processNextInQueue();
      return;
    }

    _executeDownload(
      next.song,
      resolvedStream: next.resolvedStream,
      quality: next.quality,
    ).then((success) {
      if (!next.completer.isCompleted) {
        next.completer.complete(success);
      }
    }).catchError((e) {
      if (!next.completer.isCompleted) {
        next.completer.complete(false);
      }
    });
  }

  Future<bool> _downloadSongInternal(
    Song song, {
    StreamInfo? resolvedStream,
    AudioQuality? quality,
  }) async {
    // Create cancel token for this download
    final cancelToken = CancelToken();
    _cancelTokens[song.playableId] = cancelToken;
    String? tempFilePath;

    try {
      // Update status to downloading
      var downloadInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.downloading,
        progress: 0.0,
        songTitle: song.title,
        artist: song.artist,
        thumbnailUrl: song.thumbnailUrl,
      );
      _downloadProgress[song.playableId] = downloadInfo;
      _notifyListeners(downloadInfo);

      String? streamUrl;
      Map<String, String>? headers;

      if (resolvedStream != null) {
        streamUrl = resolvedStream.url;
        headers = resolvedStream.headers;
      } else if (song.streamUrl != null &&
          song.streamUrl!.isNotEmpty &&
          isAcceptableStreamUrl(song.streamUrl!)) {
        streamUrl = song.streamUrl!;
      } else {
        try {
          final effectiveQuality = quality ??
              AudioQuality.fromString(_settingsService.downloadAudioQuality);
          final streamInfo = await _streamLoaderService.loadStream(
            song,
            useCache: false, // Force fresh stream URL for downloading
            preferredQuality: effectiveQuality,
          );
          streamUrl = streamInfo.url;
          headers = streamInfo.headers;
        } catch (e) {
          logError('Failed to get stream URL: $e');
          streamUrl = null;
        }
      }

      if (streamUrl == null || !isAcceptableStreamUrl(streamUrl)) {
        downloadInfo = downloadInfo.copyWith(
          status: DownloadStatus.failed,
          error:
              streamUrl == null ? 'Failed to get stream URL' : 'Stream URL failed validation',
        );
        if (streamUrl != null) {
          logError('Rejected untrusted stream URL scheme/host for download');
        }
        _downloadProgress[song.playableId] = downloadInfo;
        _notifyListeners(downloadInfo);
        _cancelTokens.remove(song.playableId);
        return false;
      }

      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      
      // Create safe filename (id and title are untrusted provider data)
      final fileName = downloadFileName(song.playableId, song.title);
      final filePath = '${downloadDir.path}/$fileName';
      tempFilePath = '$filePath.tmp';
      final tempFile = File(tempFilePath);

      int existingBytes = 0;
      if (await tempFile.exists()) {
        existingBytes = await tempFile.length();
      }

      final requestHeaders = Map<String, String>.from(headers ?? {});
      if (existingBytes > 0) {
        requestHeaders['Range'] = 'bytes=$existingBytes-';
      }

      // Download file to temp destination with HTTP Range resume support
      final response = await _dio.get<ResponseBody>(
        streamUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: requestHeaders,
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status != null && (status == 200 || status == 206),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final isPartial = response.statusCode == 206;
      final fileMode = (isPartial && existingBytes > 0) ? FileMode.append : FileMode.write;
      if (!isPartial) {
        existingBytes = 0;
      }

      final responseBody = response.data;
      if (responseBody == null) {
        throw Exception('Received empty response body for download');
      }

      final rawContentLength = response.headers.value(Headers.contentLengthHeader);
      final streamLength = rawContentLength != null ? int.tryParse(rawContentLength) ?? -1 : -1;
      final totalExpectedBytes = streamLength > 0 ? (existingBytes + streamLength) : -1;

      final sink = tempFile.openWrite(mode: fileMode);
      int totalReceived = existingBytes;

      try {
        await for (final chunk in responseBody.stream) {
          sink.add(chunk);
          totalReceived += chunk.length;
          if (totalExpectedBytes > 0) {
            final progress = (totalReceived / totalExpectedBytes).clamp(0.0, 1.0);
            final progressInf = downloadInfo.copyWith(progress: progress);
            _downloadProgress[song.playableId] = progressInf;
            _notifyListeners(progressInf);
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }

      final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';

      if (!await tempFile.exists()) {
        throw Exception('Download finished but file was not created');
      }

      final fileSize = await tempFile.length();
      if (fileSize < _minValidAudioBytes) {
        await tempFile.delete();
        throw Exception('Downloaded file is too small ($fileSize bytes) and likely invalid');
      }

      if (!_isLikelyAudioContentType(contentType) || !await _looksLikeAudioFile(tempFile)) {
        await tempFile.delete();
        throw Exception('Downloaded content is not a valid audio file (content-type: $contentType)');
      }

      // Compute SHA-256 checksum of the validated file
      final fileBytes = await tempFile.readAsBytes();
      final calculatedChecksum = sha256.convert(fileBytes).toString();

      // Atomically promote validated temp file to target path
      final targetFile = File(filePath);
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(filePath);

      // 1. Download and persist high-resolution offline artwork alongside audio
      String? localArtworkPath;
      if (song.thumbnailUrl.isNotEmpty) {
        try {
          final downloadDir = await _getDownloadDirectory();
          final artworkName =
              '${sanitizePathComponent(song.playableId, maxLength: 64)}_artwork.jpg';
          final artworkFile = File('${downloadDir.path}/$artworkName');
          await _dio.download(
            song.thumbnailUrl,
            artworkFile.path,
            options: Options(receiveTimeout: const Duration(seconds: 15)),
          );
          if (await artworkFile.exists() && await artworkFile.length() > 512) {
            localArtworkPath = artworkFile.path;
          }
        } catch (e) {
          logDebug('Offline artwork caching skipped or failed: $e');
        }
      }

      // 2. Fetch and persist offline word/synced lyrics alongside audio
      String? localLyricsPath;
      try {
        final lyrics = await _fetchOfflineLyrics(song);
        if (lyrics != null && lyrics.trim().isNotEmpty) {
          final downloadDir = await _getDownloadDirectory();
          final lyricsName =
              '${sanitizePathComponent(song.playableId, maxLength: 64)}_lyrics.lrc';
          final lyricsFile = File('${downloadDir.path}/$lyricsName');
          await lyricsFile.writeAsString(lyrics, flush: true);
          localLyricsPath = lyricsFile.path;
          logDebug('Offline lyrics saved to $localLyricsPath');
        }
      } catch (e) {
        logDebug('Offline lyrics caching skipped or failed: $e');
      }

      // Save enriched metadata to Hive
      final downloadRecord = {
        'songId': song.playableId,
        'id': song.id,
        'youtubeId': song.youtubeId,
        'jioSaavnId': song.jioSaavnId,
        'title': song.title,
        'artist': song.artist,
        'artists': song.artists,
        'album': song.album,
        'duration': song.duration.inSeconds,
        'thumbnailUrl': song.thumbnailUrl,
        'localArtworkPath': localArtworkPath,
        'localLyricsPath': localLyricsPath,
        'localPath': filePath,
        'fileSize': fileSize,
        'contentType': contentType,
        'bitrate': resolvedStream?.bitrate ?? 0,
        'isrc': song.isrc,
        'checksum': calculatedChecksum,
        'quality': (quality ?? AudioQuality.fromString(_settingsService.downloadAudioQuality)).name,
        'downloadedAt': DateTime.now().toIso8601String(),
      };
      await _downloadBox?.put(song.playableId, downloadRecord);
      _indexRecord(song.playableId, downloadRecord);

      // Update status to completed
      downloadInfo = downloadInfo.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: filePath,
      );
      _downloadProgress[song.playableId] = downloadInfo;
      _notifyListeners(downloadInfo);
      _cancelTokens.remove(song.playableId);

      logDebug('Successfully downloaded: ${song.title} to $filePath');
      return true;
    } catch (e, stack) {
      // Note: do not delete tempFilePath on cancel or network errors to enable resume on retry

      // Check if download was cancelled
      if (e is DioException && e.type == DioExceptionType.cancel) {
        logDebug('Download cancelled for: ${song.title} (partial download kept for resume)');
        _downloadProgress.remove(song.playableId);
        _notifyListeners(
          DownloadInfo(
            songId: song.playableId,
            status: DownloadStatus.notDownloaded,
            songTitle: song.title,
            artist: song.artist,
            thumbnailUrl: song.thumbnailUrl,
          ),
        );
        return false;
      }
      
      logError('Error downloading song', e, stack);
      
      var errorInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.failed,
        error: e.toString(),
        songTitle: song.title,
        artist: song.artist,
        thumbnailUrl: song.thumbnailUrl,
      );
      _downloadProgress[song.playableId] = errorInfo;
      _notifyListeners(errorInfo);
      _cancelTokens.remove(song.playableId);
      
      return false;
    }
  }

  /// Delete downloaded song
  Future<bool> deleteSong(String songId) async {
    try {
      final info = _downloadBox?.get(songId) as Map?;
      if (info == null) return false;

      final localPath = info['localPath'] as String?;
      if (localPath != null && await DownloadPathGuard.canDelete(localPath)) {
        await File(localPath).delete();
      }

      final artworkPath = info['localArtworkPath'] as String?;
      if (artworkPath != null && await DownloadPathGuard.canDelete(artworkPath)) {
        final af = File(artworkPath);
        if (await af.exists()) await af.delete();
      }

      final lyricsPath = info['localLyricsPath'] as String?;
      if (lyricsPath != null && await DownloadPathGuard.canDelete(lyricsPath)) {
        final lf = File(lyricsPath);
        if (await lf.exists()) await lf.delete();
      }

      final tempFile = File('$localPath.tmp');
      if (await tempFile.exists() && await DownloadPathGuard.canDelete(tempFile.path)) {
        await tempFile.delete();
      }

      await _downloadBox?.delete(songId);
      _secondaryKeyIndex.removeWhere((k, v) => v == songId || k == songId);
      final removedInfo = DownloadInfo(
        songId: songId,
        status: DownloadStatus.notDownloaded,
        progress: 0.0,
      );
      _downloadProgress.remove(songId);
      _notifyListeners(removedInfo);
      
      logDebug('Deleted downloaded song: $songId');
      return true;
    } catch (e, stack) {
      logError('Error deleting song', e, stack);
      return false;
    }
  }

  /// Returns the local artwork file path for [songId] if present.
  String? getLocalArtworkPath(String songId) {
    var info = _downloadBox?.get(songId) as Map?;
    if (info == null && _secondaryKeyIndex.containsKey(songId)) {
      final primaryKey = _secondaryKeyIndex[songId]!;
      info = _downloadBox?.get(primaryKey) as Map?;
    }
    return info?['localArtworkPath'] as String?;
  }

  /// Returns the local lyrics file path for [songId] if present.
  String? getLocalLyricsPath(String songId) {
    var info = _downloadBox?.get(songId) as Map?;
    if (info == null && _secondaryKeyIndex.containsKey(songId)) {
      final primaryKey = _secondaryKeyIndex[songId]!;
      info = _downloadBox?.get(primaryKey) as Map?;
    }
    return info?['localLyricsPath'] as String?;
  }

  /// Returns the cached offline lyrics string for [songId] if saved on disk.
  Future<String?> getLocalLyrics(String songId) async {
    final path = getLocalLyricsPath(songId);
    if (path == null) return null;
    final file = File(path);
    if (await file.exists()) {
      return file.readAsString();
    }
    return null;
  }

  Future<String?> _fetchOfflineLyrics(Song song) async {
    try {
      final ds = _lyricsDataSource ??
          (getIt.isRegistered<LyricsDataSource>() ? getIt<LyricsDataSource>() : null);
      if (ds != null) {
        final res = await ds.getSyncedLyrics(
          song.title,
          song.artist,
          duration: song.duration,
          songId: song.id,
        );
        if (res?.syncedLyrics != null && res!.syncedLyrics!.isNotEmpty) {
          final buffer = StringBuffer();
          for (final line in res.syncedLyrics!) {
            final min = (line.startTimeMs ~/ 60000).toString().padLeft(2, '0');
            final sec = ((line.startTimeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
            final hun = ((line.startTimeMs % 1000) ~/ 10).toString().padLeft(2, '0');
            if (line.words != null && line.words!.isNotEmpty) {
              buffer.write('[$min:$sec.$hun]');
              for (final w in line.words!) {
                final wMin = (w.startTimeMs ~/ 60000).toString().padLeft(2, '0');
                final wSec = ((w.startTimeMs % 60000) ~/ 1000).toString().padLeft(2, '0');
                final wHun = ((w.startTimeMs % 1000) ~/ 10).toString().padLeft(2, '0');
                buffer.write('<$wMin:$wSec.$wHun>${w.text} ');
              }
              buffer.writeln();
            } else {
              buffer.writeln('[$min:$sec.$hun]${line.text}');
            }
          }
          return buffer.toString();
        }
        if (res?.plainLyrics != null && res!.plainLyrics!.isNotEmpty) {
          return res.plainLyrics;
        }
      }
    } catch (e) {
      logDebug('Offline lyrics fetch error: $e');
    }
    return null;
  }

  /// Verify the file integrity of a downloaded song against its recorded checksum, file size, and magic bytes.
  Future<bool> verifyDownloadIntegrity(String songId) async {
    var info = _downloadBox?.get(songId) as Map?;
    if (info == null && _secondaryKeyIndex.containsKey(songId)) {
      final primaryKey = _secondaryKeyIndex[songId]!;
      info = _downloadBox?.get(primaryKey) as Map?;
    }
    if (info == null) return false;

    final localPath = info['localPath'] as String?;
    if (localPath == null) return false;

    final file = File(localPath);
    if (!await file.exists()) return false;

    try {
      final len = await file.length();
      if (len < _minValidAudioBytes) return false;

      final expectedSize = info['fileSize'];
      if (expectedSize is int && expectedSize > 0 && len != expectedSize) {
        logError('Integrity check failed: file size mismatch ($len != $expectedSize)');
        return false;
      }

      if (!await _looksLikeAudioFile(file)) {
        logError('Integrity check failed: invalid audio magic bytes');
        return false;
      }

      final expectedChecksum = info['checksum'] as String?;
      if (expectedChecksum != null && expectedChecksum.isNotEmpty) {
        final bytes = await file.readAsBytes();
        final actualChecksum = sha256.convert(bytes).toString();
        if (actualChecksum != expectedChecksum) {
          logError('Integrity check failed: checksum mismatch (expected $expectedChecksum, got $actualChecksum)');
          return false;
        }
      }

      return true;
    } catch (e) {
      logError('Integrity verification exception: $e');
      return false;
    }
  }

  /// Get all downloaded songs
  List<Map<String, dynamic>> getAllDownloadedSongs() {
    if (_downloadBox == null) return [];
    
    final songs = <Map<String, dynamic>>[];
    for (final key in _downloadBox!.keys) {
      final info = _downloadBox!.get(key) as Map?;
      if (info != null) {
        final localPath = info['localPath'] as String?;
        if (localPath != null && File(localPath).existsSync()) {
          songs.add(Map<String, dynamic>.from(info));
        }
      }
    }
    return songs;
  }

  /// Get all downloaded songs asynchronously to avoid blocking the UI thread
  /// with synchronous file-system stat/existence checks.
  Future<List<Map<String, dynamic>>> getAllDownloadedSongsAsync() async {
    if (_downloadBox == null) return [];

    final songs = <Map<String, dynamic>>[];
    for (final key in _downloadBox!.keys) {
      final info = _downloadBox!.get(key) as Map?;
      if (info != null) {
        final localPath = info['localPath'] as String?;
        if (localPath != null && await File(localPath).exists()) {
          songs.add(Map<String, dynamic>.from(info));
        }
      }
    }
    return songs;
  }

  /// Maps a raw download Hive record to a strongly typed domain Song entity.
  static Song mapDownloadToSong(Map<String, dynamic> songData) {
    return Song(
      id: songData['songId']?.toString() ?? '',
      title: songData['title'] ?? 'Unknown',
      artist: songData['artist'] ?? 'Unknown Artist',
      duration: Duration(seconds: songData['duration'] ?? 0),
      thumbnails: (songData['localArtworkPath'] != null &&
              File(songData['localArtworkPath']).existsSync())
          ? Thumbnails.fromUrl(songData['localArtworkPath'])
          : (songData['thumbnailUrl'] != null
              ? Thumbnails.fromUrl(songData['thumbnailUrl'])
              : Thumbnails.empty()),
      album: songData['album'],
      artists: (songData['artists'] is List)
          ? List<String>.from(songData['artists'])
          : [songData['artist'] ?? 'Unknown Artist'],
      isrc: songData['isrc'],
      streamUrl: songData['localPath'],
      source: MusicSource.local,
    );
  }

  /// Returns all validated downloaded songs as domain Song entities.
  List<Song> getDownloadedSongsList() {
    return getAllDownloadedSongs().map(mapDownloadToSong).toList();
  }

  /// Fuzzy and substring search within downloaded songs.
  List<Song> searchDownloadedSongs(String query) {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    final songs = getDownloadedSongsList();
    final matched = <({Song song, double score})>[];

    for (final song in songs) {
      final titleNorm = song.title.toLowerCase();
      final artistNorm = song.artist.toLowerCase();
      final albumNorm = (song.album ?? '').toLowerCase();

      final containsTitle = titleNorm.contains(cleanQuery);
      final containsArtist = artistNorm.contains(cleanQuery);
      final containsAlbum = albumNorm.contains(cleanQuery);

      if (containsTitle || containsArtist || containsAlbum) {
        final simTitle =
            UnicodeSearchMatcher.computeSimilarity(song.title, cleanQuery);
        final simArtist =
            UnicodeSearchMatcher.computeSimilarity(song.artist, cleanQuery);
        final baseScore = containsTitle ? 1.0 : (containsArtist ? 0.8 : 0.6);
        final score = baseScore + (simTitle > simArtist ? simTitle : simArtist);
        matched.add((song: song, score: score));
      }
    }

    matched.sort((a, b) => b.score.compareTo(a.score));
    return matched.map((m) => m.song).toList();
  }

  /// Get total download size
  Future<int> getTotalDownloadSize() async {
    int totalSize = 0;
    final songs = getAllDownloadedSongs();
    
    for (final song in songs) {
      final localPath = song['localPath'] as String?;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          totalSize += await file.length();
        }
      }
    }
    
    return totalSize;
  }

  /// Format bytes to readable string
  String formatBytes(int bytes) => Formatters.formatBytes(bytes);

  /// Cancel download
  void cancelDownload(String songId) {
    // If waiting in queue, cancel and remove cleanly without I/O
    final queueIndex =
        _downloadQueue.indexWhere((item) => item.song.playableId == songId);
    if (queueIndex != -1) {
      final item = _downloadQueue.removeAt(queueIndex);
      if (!item.completer.isCompleted) {
        item.completer.complete(false);
      }
      final prev = _downloadProgress.remove(songId);
      _notifyListeners(
        DownloadInfo(
          songId: songId,
          status: DownloadStatus.notDownloaded,
          songTitle: prev?.songTitle ?? item.song.title,
          artist: prev?.artist ?? item.song.artist,
          thumbnailUrl: prev?.thumbnailUrl ?? item.song.thumbnailUrl,
        ),
      );
      return;
    }

    final prev = _downloadProgress[songId];
    _cancelTokens[songId]?.cancel();
    _cancelTokens.remove(songId);
    _downloadProgress.remove(songId);
    if (prev != null) {
      _notifyListeners(
        DownloadInfo(
          songId: songId,
          status: DownloadStatus.notDownloaded,
          songTitle: prev.songTitle,
          artist: prev.artist,
          thumbnailUrl: prev.thumbnailUrl,
        ),
      );
    }
  }

  /// Retries a failed or cancelled download
  Future<bool> retryDownload(Song song) async {
    _downloadProgress.remove(song.playableId);
    _cancelTokens.remove(song.playableId);
    return downloadSong(song);
  }

  /// Reconciles storage state by purging invalid Hive records whose files no longer exist
  /// or are corrupted/truncated, and cleaning up orphaned temporary (.tmp) files.
  Future<int> reconcileStorageState() async {
    int cleanedCount = 0;
    try {
      final downloadDir = await _getDownloadDirectory();

      // 1. Clean up leftover temporary files
      if (await downloadDir.exists()) {
        final entities = downloadDir.listSync();
        for (final entity in entities) {
          if (entity is File && entity.path.endsWith('.tmp')) {
            try {
              await entity.delete();
              cleanedCount++;
              logDebug('Cleaned orphaned temp file: ${entity.path}');
            } catch (_) {}
          }
        }
      }

      // 2. Reconcile Hive records against disk
      if (_downloadBox != null) {
        final keysToRemove = <dynamic>[];
        for (final key in _downloadBox!.keys) {
          final info = _downloadBox!.get(key) as Map?;
          if (info == null) {
            keysToRemove.add(key);
            continue;
          }
          final localPath = info['localPath'] as String?;
          if (localPath == null) {
            keysToRemove.add(key);
            continue;
          }
          final file = File(localPath);
          if (!file.existsSync() || file.lengthSync() < _minValidAudioBytes) {
            keysToRemove.add(key);
          }
        }
        for (final key in keysToRemove) {
          await _downloadBox!.delete(key);
          cleanedCount++;
          logDebug('Purged stale download metadata for key: $key');
        }
      }
    } catch (e, stack) {
      logError('Error reconciling download storage state', e, stack);
    }
    return cleanedCount;
  }

  bool _isLikelyAudioContentType(String value) {
    final ctype = value.toLowerCase();
    if (ctype.isEmpty) return true;
    return ctype.startsWith('audio/') ||
        ctype.contains('application/octet-stream') ||
        ctype.contains('video/mp4') ||
        ctype.contains('application/vnd.apple.mpegurl');
  }

  Future<bool> _looksLikeAudioFile(File file) async {
    try {
      final stream = file.openRead(0, 64);
      final bytes = <int>[];
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }

      if (bytes.isEmpty) return false;

      // Obvious HTML/XML payload check.
      final headText = String.fromCharCodes(bytes).toLowerCase().trimLeft();
      if (headText.startsWith('<!doctype') || headText.startsWith('<html') || headText.startsWith('<?xml')) {
        return false;
      }

      // Common audio container signatures.
      if (bytes.length >= 4) {
        final b0 = bytes[0], b1 = bytes[1], b2 = bytes[2], b3 = bytes[3];

        // ID3 (mp3), OggS, RIFF (wav), fLaC, ADTS sync word 0xFFFx
        if (b0 == 0x49 && b1 == 0x44 && b2 == 0x33) return true;
        if (b0 == 0x4F && b1 == 0x67 && b2 == 0x67 && b3 == 0x53) return true;
        if (b0 == 0x52 && b1 == 0x49 && b2 == 0x46 && b3 == 0x46) return true;
        if (b0 == 0x66 && b1 == 0x4C && b2 == 0x61 && b3 == 0x43) return true;
        if (b0 == 0xFF && (b1 & 0xF0) == 0xF0) return true;

        // Matroska/WebM EBML header: 1A 45 DF A3
        if (b0 == 0x1A && b1 == 0x45 && b2 == 0xDF && b3 == 0xA3) return true;
      }

      // MP4/M4A ftyp usually appears at bytes 4..7
      if (bytes.length >= 12) {
        final ftyp = String.fromCharCodes(bytes.sublist(4, 8));
        if (ftyp == 'ftyp') return true;
      }

      return false;
    } catch (_) {
      return false;
    }
  }
}

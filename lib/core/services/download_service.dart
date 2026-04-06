import 'dart:io';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

enum DownloadStatus {
  notDownloaded,
  downloading,
  completed,
  failed,
}

class DownloadInfo {
  final String songId;
  final DownloadStatus status;
  final double progress;
  final String? localPath;
  final String? error;

  DownloadInfo({
    required this.songId,
    required this.status,
    this.progress = 0.0,
    this.localPath,
    this.error,
  });

  DownloadInfo copyWith({
    String? songId,
    DownloadStatus? status,
    double? progress,
    String? localPath,
    String? error,
  }) {
    return DownloadInfo(
      songId: songId ?? this.songId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
    );
  }
}

class DownloadService {
  static const String _downloadBoxName = 'downloads';
  static const int _minValidAudioBytes = 16 * 1024;
  final MusicRepository _musicRepository;
  final Dio _dio = Dio();
  
  Box? _downloadBox;
  final Map<String, DownloadInfo> _downloadProgress = {};
  final List<Function(DownloadInfo)> _listeners = [];

  DownloadService(this._musicRepository);

  Future<void> initialize() async {
    try {
      if (Hive.isBoxOpen(_downloadBoxName)) {
        _downloadBox = Hive.box(_downloadBoxName);
      } else {
        _downloadBox = await Hive.openBox(_downloadBoxName);
      }
    } catch (e, stack) {
      logError('Download service initialization error', e, stack);
    }
  }

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

  /// Get download directory (uses custom path from settings if available)
  Future<Directory> _getDownloadDirectory() async {
    final customPath = SettingsService.instance.downloadFolderPath;

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

    // Alternative: public Downloads (may work on older Android or rooted devices)
    try {
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final dir = Directory('${downloadsDir.path}/PrismMusic/Audio');
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return dir;
      }
    } catch (e, stack) {
      logError('Failed to use public Downloads folder', e, stack);
    }

    // Fallback: app documents (always writable, but less visible)
    final appDir = await getApplicationDocumentsDirectory();
    final fallbackDir = Directory('${appDir.path}/Downloads/PrismMusic/Audio');
    if (!await fallbackDir.exists()) {
      await fallbackDir.create(recursive: true);
    }
    return fallbackDir;
  }

  /// Get the current download directory path as a string
  Future<String> getDownloadDirectoryPath() async {
    final dir = await _getDownloadDirectory();
    return dir.path;
  }

  /// Check if song is downloaded
  bool isDownloaded(String songId) {
    final info = _downloadBox?.get(songId) as Map?;
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
    final info = _downloadBox?.get(songId) as Map?;
    return info?['localPath'] as String?;
  }

  /// Download a song
  Future<bool> downloadSong(Song song) async {
    if (isDownloaded(song.playableId)) {
      logDebug('Song already downloaded: ${song.title}');
      return true;
    }

    // Check if currently downloading (but allow retry if failed)
    if (_downloadProgress.containsKey(song.playableId)) {
      final currentStatus = _downloadProgress[song.playableId]!.status;
      if (currentStatus == DownloadStatus.downloading) {
        logDebug('Song already downloading: ${song.title}');
        return false;
      }
      // Remove failed downloads to allow retry
      if (currentStatus == DownloadStatus.failed) {
        _downloadProgress.remove(song.playableId);
      }
    }

    try {
      // Update status to downloading
      final downloadInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
      _downloadProgress[song.playableId] = downloadInfo;
      _notifyListeners(downloadInfo);

      // Get stream URL
      final streamResult = await _musicRepository.getStreamUrl(
        song.playableId,
        preferredQuality: AudioQuality.high,
      );

      String? streamUrl;
      streamResult.fold(
        (failure) {
          logError('Failed to get stream URL: ${failure.message}');
          streamUrl = null;
        },
        (streamInfo) {
          streamUrl = streamInfo.url;
        },
      );

      if (streamUrl == null) {
        final errorInfo = downloadInfo.copyWith(
          status: DownloadStatus.failed,
          error: 'Failed to get stream URL',
        );
        _downloadProgress[song.playableId] = errorInfo;
        _notifyListeners(errorInfo);
        return false;
      }

      // Get download directory
      final downloadDir = await _getDownloadDirectory();
      
      // Create safe filename
      final safeTitle = song.title.replaceAll(RegExp(r'[^\w\s-]'), '');
      final fileName = '${song.playableId}_$safeTitle.m4a';
      final filePath = '${downloadDir.path}/$fileName';

      // Download file with progress tracking and proper headers
      final response = await _dio.download(
        streamUrl!,
        filePath,
        options: Options(
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Language': 'en-US,en;q=0.9',
            'Range': 'bytes=0-',
          },
          responseType: ResponseType.stream,
          followRedirects: true,
          validateStatus: (status) => status != null && (status == 200 || status == 206),
        ),
        onReceiveProgress: (received, total) {
          if (total > 0) {
            final progress = received / total;
            final progressInfo = downloadInfo.copyWith(progress: progress);
            _downloadProgress[song.playableId] = progressInfo;
            _notifyListeners(progressInfo);
          }
        },
      );

      final downloadedFile = File(filePath);
      final contentType = response.headers.value(Headers.contentTypeHeader) ?? '';

      if (!await downloadedFile.exists()) {
        throw Exception('Download finished but file was not created');
      }

      final fileSize = await downloadedFile.length();
      if (fileSize < _minValidAudioBytes) {
        await downloadedFile.delete();
        throw Exception('Downloaded file is too small ($fileSize bytes) and likely invalid');
      }

      if (!_isLikelyAudioContentType(contentType) || !await _looksLikeAudioFile(downloadedFile)) {
        await downloadedFile.delete();
        throw Exception('Downloaded content is not a valid audio file (content-type: $contentType)');
      }

      // Save metadata to Hive
      await _downloadBox?.put(song.playableId, {
        'songId': song.playableId,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'duration': song.duration.inSeconds,
        'thumbnailUrl': song.thumbnailUrl,
        'localPath': filePath,
        'fileSize': fileSize,
        'contentType': contentType,
        'downloadedAt': DateTime.now().toIso8601String(),
      });

      // Update status to completed
      final completedInfo = downloadInfo.copyWith(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: filePath,
      );
      _downloadProgress[song.playableId] = completedInfo;
      _notifyListeners(completedInfo);

      logDebug('Successfully downloaded: ${song.title} to $filePath');
      return true;
    } catch (e, stack) {
      logError('Error downloading song', e, stack);
      
      final errorInfo = DownloadInfo(
        songId: song.playableId,
        status: DownloadStatus.failed,
        error: e.toString(),
      );
      _downloadProgress[song.playableId] = errorInfo;
      _notifyListeners(errorInfo);
      
      return false;
    }
  }

  /// Delete downloaded song
  Future<bool> deleteSong(String songId) async {
    try {
      final info = _downloadBox?.get(songId) as Map?;
      if (info == null) return false;

      final localPath = info['localPath'] as String?;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }

      await _downloadBox?.delete(songId);
      _downloadProgress.remove(songId);
      
      logDebug('Deleted downloaded song: $songId');
      return true;
    } catch (e, stack) {
      logError('Error deleting song', e, stack);
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
  String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Cancel download
  void cancelDownload(String songId) {
    _downloadProgress.remove(songId);
    // Note: Dio doesn't easily support cancellation without CancelToken
    // This is a simplified version
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

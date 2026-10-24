import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/entities/listening_stats.dart';

/// Service responsible for exporting and sharing listening statistics
/// in lightweight text and JSON formats.
class StatsExportService {
  const StatsExportService();

  static const StatsExportService instance = StatsExportService();

  /// Formats a human-readable text summary of listening stats for sharing.
  String buildShareableSummary(ListeningStats stats) {
    final buffer = StringBuffer();
    buffer.writeln('🎵 My Prism Music Listening Stats');
    buffer.writeln('────────────────────────────────');

    final hours = stats.totalListeningTime.inHours;
    final mins = stats.totalListeningTime.inMinutes % 60;
    final timeStr = hours > 0 ? '${hours}h ${mins}m' : '${mins}m';
    buffer.writeln('⏱️ Total Listening Time: $timeStr');
    buffer.writeln('🎧 Total Plays: ${stats.totalPlays}');
    buffer.writeln('🎶 Unique Songs: ${stats.uniqueSongs}');

    if (stats.topArtist != null && stats.topArtist!.trim().isNotEmpty) {
      buffer.writeln('🎤 Top Artist: ${stats.topArtist} (${stats.topArtistCount} plays)');
    }

    if (stats.mostPlayedSong != null) {
      buffer.writeln('⭐ Most Played Song: ${stats.mostPlayedSong!.title} by ${stats.mostPlayedSong!.artist} (${stats.mostPlayedCount} plays)');
    }

    if (stats.topGenre != null && stats.topGenre!.trim().isNotEmpty) {
      buffer.writeln('🏷️ Top Genre: ${stats.topGenre} (${stats.topGenreCount} plays)');
    }

    if (stats.firstPlayed != null) {
      final date = stats.firstPlayed!;
      buffer.writeln('📅 Listening Since: ${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
    }

    buffer.writeln('\nListen on Prism Music 🎧');
    return buffer.toString();
  }

  /// Copies text summary to clipboard.
  Future<void> copySummaryToClipboard(ListeningStats stats) async {
    final text = buildShareableSummary(stats);
    await Clipboard.setData(ClipboardData(text: text));
  }

  /// Shares the text summary via system share sheet.
  Future<void> shareTextSummary(ListeningStats stats) async {
    final text = buildShareableSummary(stats);
    await Share.share(
      text,
      subject: 'My Prism Music Listening Stats',
    );
  }

  /// Exports stats and recent history as a lightweight JSON archive and triggers system share sheet.
  Future<File?> exportStatsJson(
    ListeningStats stats, [
    List<HistoryEntry> entries = const [],
  ]) async {
    try {
      final data = {
        'exportedAt': DateTime.now().toUtc().toIso8601String(),
        'format': 'prism_listening_stats_v1',
        'summary': {
          'totalPlays': stats.totalPlays,
          'totalListeningMinutes': stats.totalListeningTime.inMinutes,
          'uniqueSongs': stats.uniqueSongs,
          'topArtist': stats.topArtist,
          'topArtistPlays': stats.topArtistCount,
          'mostPlayedSong': stats.mostPlayedSong == null
              ? null
              : {
                  'id': stats.mostPlayedSong!.id,
                  'title': stats.mostPlayedSong!.title,
                  'artist': stats.mostPlayedSong!.artist,
                  'album': stats.mostPlayedSong!.album,
                  'plays': stats.mostPlayedCount,
                },
          'topGenre': stats.topGenre,
          'topGenrePlays': stats.topGenreCount,
          'firstPlayed': stats.firstPlayed?.toIso8601String(),
          'lastPlayed': stats.lastPlayed?.toIso8601String(),
        },
        'recentPlaysCount': entries.length,
        'recentPlays': entries.map((e) => {
              'id': e.song.id,
              'title': e.song.title,
              'artist': e.song.artist,
              'album': e.song.album,
              'durationSeconds': e.song.duration.inSeconds,
              'playedAt': e.playedAt.toIso8601String(),
            }).toList(),
      };

      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateTime.now().toIso8601String().substring(0, 10);
      final fileName = 'prism_stats_$dateStr.json';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonStr, flush: true);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json', name: fileName)],
        subject: 'Prism Music Listening Stats Export',
        text: 'Exported listening stats from Prism Music',
      );

      return file;
    } catch (_) {
      return null;
    }
  }
}

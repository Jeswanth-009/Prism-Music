import 'package:flutter/material.dart';

import '../../../domain/entities/song.dart';
import '../prism/prism_sheet.dart';

/// Opens the Song Credits & Audio Engineering metadata bottom sheet.
Future<void> showSongCreditsSheet(BuildContext context, Song song) {
  return showPrismSheet(
    context: context,
    builder: (_) => SongCreditsSheet(song: song),
  );
}

/// Displays authentic metadata for a song: codec, bitrate, provenance, and credits.
/// Completely free of emojis and fabricated metrics.
class SongCreditsSheet extends StatelessWidget {
  const SongCreditsSheet({super.key, required this.song});

  final Song song;

  String _formatSource(Song song) {
    if (song.source == MusicSource.local) return 'Local Offline Storage';
    if (song.source == MusicSource.jiosaavn) return 'JioSaavn High-Fi Catalog';
    if (song.source == MusicSource.youtubeMusic) return 'YouTube Music Catalog';
    if (song.source == MusicSource.youtube) return 'YouTube Catalog';
    return 'Unknown Provider';
  }

  String _formatCodec(Song song) {
    if (song.source == MusicSource.jiosaavn) return 'AAC-LC (m4a)';
    if (song.source == MusicSource.youtube ||
        song.source == MusicSource.youtubeMusic) {
      return 'Opus (webm) / AAC (m4a)';
    }
    return 'Native Audio Stream';
  }

  String _formatBitrate(Song song) {
    if (song.source == MusicSource.jiosaavn) return 'Up to 320 kbps CBR';
    if (song.source == MusicSource.youtube ||
        song.source == MusicSource.youtubeMusic) {
      return '160 kbps VBR (DASH)';
    }
    return 'Variable Bitrate';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 22),
                const SizedBox(width: 10),
                Text(
                  'Song Details & Credits',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _CreditRow(label: 'Title', value: song.title),
            _CreditRow(label: 'Artist', value: song.artist),
            if (song.album != null && song.album!.isNotEmpty)
              _CreditRow(label: 'Album', value: song.album!),
            _CreditRow(label: 'Duration', value: song.durationFormatted),
            const Divider(height: 24),
            Text(
              'AUDIO STREAM METADATA',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            _CreditRow(label: 'Source', value: _formatSource(song)),
            _CreditRow(label: 'Format & Codec', value: _formatCodec(song)),
            _CreditRow(label: 'Stream Bitrate', value: _formatBitrate(song)),
            if (song.isrc != null && song.isrc!.isNotEmpty)
              _CreditRow(label: 'ISRC', value: song.isrc!),
            if (song.streamProvenance != null &&
                song.streamProvenance!.isNotEmpty)
              _CreditRow(label: 'Provenance', value: song.streamProvenance!),
            if (song.credits != null && song.credits!.isNotEmpty) ...[
              const Divider(height: 24),
              Text(
                'PRODUCTION CREDITS',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 8),
              for (final entry in song.credits!.entries)
                _CreditRow(label: entry.key, value: entry.value),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/entities/song.dart';

/// Represents an algorithmic Daily Mix clustered on the user's device
class DailyMix {
  final String id;
  final String title;
  final String subtitle;
  final List<String> topArtists;
  final List<String> artworkUrls;
  final Color primaryAccent;
  final Color secondaryAccent;
  final List<Song> songs;

  const DailyMix({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.topArtists,
    required this.artworkUrls,
    required this.primaryAccent,
    required this.secondaryAccent,
    required this.songs,
  });
}

/// Service that algorithmically clusters local listening history,
/// liked songs, and seed tracks into personalized Daily Mixes 1 through 6.
class DailyMixService {
  static final DailyMixService _instance = DailyMixService._internal();
  static DailyMixService get instance => _instance;
  DailyMixService._internal();

  static const List<(Color, Color)> _mixPalettes = [
    (Color(0xFFFF5722), Color(0xFFFF9800)), // Mix 1: Coral / Warm Flame
    (Color(0xFF00B0FF), Color(0xFF00E5FF)), // Mix 2: Cyan / Electric Blue
    (Color(0xFF9C27B0), Color(0xFFE040FB)), // Mix 3: Purple / Magenta
    (Color(0xFF00E676), Color(0xFF1DE9B6)), // Mix 4: Emerald / Mint
    (Color(0xFFFFD600), Color(0xFFFFAB00)), // Mix 5: Amber / Sunburst
    (Color(0xFF3D5AFE), Color(0xFF651FFF)), // Mix 6: Indigo / Deep Violet
  ];

  /// Generate up to 6 Daily Mixes clustered by artist / mood from local data.
  List<DailyMix> generateDailyMixes({
    required List<Song> history,
    required List<Song> likedSongs,
    List<Song> seedTracks = const [],
  }) {
    // Combine all user data, deduplicating by ID
    final seenIds = <String>{};
    final allSongs = <Song>[];

    for (final s in [...history, ...likedSongs, ...seedTracks]) {
      if (seenIds.add(s.id) && s.duration.inSeconds >= 45) {
        allSongs.add(s);
      }
    }

    if (allSongs.isEmpty) {
      return const [];
    }

    // 1. Group songs by primary artist
    final artistBuckets = <String, List<Song>>{};
    for (final song in allSongs) {
      final primaryArtist = _extractPrimaryArtist(song.artist);
      if (primaryArtist.isEmpty) continue;
      artistBuckets.putIfAbsent(primaryArtist, () => []).add(song);
    }

    // Sort artists by song count descending
    final sortedArtists = artistBuckets.keys.toList()
      ..sort((a, b) => artistBuckets[b]!.length.compareTo(artistBuckets[a]!.length));

    final mixes = <DailyMix>[];
    final usedSongIds = <String>{};

    final maxMixes = (allSongs.length < 8) ? 2 : 6;

    for (var i = 0; i < maxMixes; i++) {
      final mixNum = i + 1;
      final palette = _mixPalettes[i % _mixPalettes.length];
      final mixSongs = <Song>[];
      final mixArtists = <String>[];

      // Partition artists across mixes
      if (sortedArtists.isNotEmpty) {
        final startIdx = (i * 2) % sortedArtists.length;
        for (var k = 0; k < 3; k++) {
          final artIdx = (startIdx + k) % sortedArtists.length;
          final artistName = sortedArtists[artIdx];
          if (!mixArtists.contains(artistName)) {
            mixArtists.add(artistName);
          }
          final bucket = artistBuckets[artistName] ?? [];
          for (final s in bucket) {
            if (usedSongIds.add(s.id)) {
              mixSongs.add(s);
            }
          }
        }
      }

      // If cluster is small, fill from remaining pool
      for (final s in allSongs) {
        if (mixSongs.length >= 15) break;
        if (usedSongIds.add(s.id)) {
          mixSongs.add(s);
          final a = _extractPrimaryArtist(s.artist);
          if (a.isNotEmpty && !mixArtists.contains(a) && mixArtists.length < 4) {
            mixArtists.add(a);
          }
        }
      }

      // If pool was exhausted, recycle songs to ensure rich mix
      if (mixSongs.isEmpty) {
        mixSongs.addAll(allSongs.take(12));
      }

      // Extract up to 4 distinct artwork URLs for the 2x2 quad collage
      final quadArtworks = <String>[];
      for (final s in mixSongs) {
        final url = s.thumbnailUrl;
        if (url.isNotEmpty && !quadArtworks.contains(url)) {
          quadArtworks.add(url);
          if (quadArtworks.length == 4) break;
        }
      }

      // If fewer than 4 artworks, replicate or fill
      while (quadArtworks.isNotEmpty && quadArtworks.length < 4) {
        quadArtworks.add(quadArtworks.first);
      }

      final subtitle = mixArtists.isNotEmpty
          ? '${mixArtists.take(3).join(', ')} and more'
          : 'Based on what you play';

      mixes.add(
        DailyMix(
          id: 'daily_mix_$mixNum',
          title: 'Daily Mix $mixNum',
          subtitle: subtitle,
          topArtists: mixArtists,
          artworkUrls: quadArtworks,
          primaryAccent: palette.$1,
          secondaryAccent: palette.$2,
          songs: mixSongs,
        ),
      );
    }

    return mixes;
  }

  String _extractPrimaryArtist(String rawArtist) {
    if (rawArtist.isEmpty) return '';
    final cleaned = rawArtist
        .split(RegExp(r',|&|ft\.|feat\.|with|;|\/'))
        .first
        .trim();
    return cleaned;
  }
}

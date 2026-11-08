import 'package:flutter/material.dart';
import 'curated_playlists.dart';

/// Represents a musical genre or mood with visual attributes and associated playlists.
class MusicGenre {
  final String id;
  final String name;
  final IconData icon;
  final List<Color> gradient;
  final String description;
  final bool isMood;
  final List<CuratedPlaylist> playlists;

  const MusicGenre({
    required this.id,
    required this.name,
    required this.icon,
    required this.gradient,
    required this.description,
    this.isMood = false,
    this.playlists = const [],
  });

  int get playlistCount => playlists.length;
}

/// Service providing genre and mood categories with curated playlists.
class GenreService {
  static final GenreService instance = GenreService._();
  GenreService._();
  factory GenreService() => instance;

  List<MusicGenre>? _cachedGenres;

  /// Retrieve all genres and moods
  List<MusicGenre> getAllGenres() {
    _cachedGenres ??= _buildGenreCatalog();
    return _cachedGenres!;
  }

  /// Filter to only musical genres
  List<MusicGenre> getGenresOnly() {
    return getAllGenres().where((g) => !g.isMood).toList();
  }

  /// Filter to only moods and activity themes
  List<MusicGenre> getMoodsOnly() {
    return getAllGenres().where((g) => g.isMood).toList();
  }

  /// Find genre by ID
  MusicGenre? getGenreById(String id) {
    try {
      return getAllGenres().firstWhere((g) => g.id.toLowerCase() == id.toLowerCase());
    } catch (_) {
      return null;
    }
  }

  /// Search genres by name or description
  List<MusicGenre> searchGenres(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return getAllGenres();
    return getAllGenres()
        .where((g) =>
            g.name.toLowerCase().contains(clean) ||
            g.description.toLowerCase().contains(clean))
        .toList();
  }

  List<MusicGenre> _buildGenreCatalog() {
    final allPlaylists = CuratedPlaylists.all;

    CuratedPlaylist? findPl(String id) {
      try {
        return allPlaylists.firstWhere((p) => p.id == id);
      } catch (_) {
        return null;
      }
    }

    List<CuratedPlaylist> collect(List<String> ids, List<CuratedPlaylist> fallbacks) {
      final list = <CuratedPlaylist>[];
      for (final id in ids) {
        final p = findPl(id);
        if (p != null) list.add(p);
      }
      return list.isNotEmpty ? list : fallbacks;
    }

    return [
      // ── Pop & Mainstream ──
      MusicGenre(
        id: 'pop',
        name: 'Pop',
        icon: Icons.star_rounded,
        gradient: const [Color(0xFFf093fb), Color(0xFFf5576c)],
        description: 'Chart-toppers, synthpop anthems, and worldwide pop certified hits.',
        playlists: collect(
          ['pop_certified', 'top_100_global', 'the_hit_list', 'hashtag_hits'],
          [
            const CuratedPlaylist(
              id: 'pop_essentials',
              name: 'Pop Essentials',
              playlistId: 'RDCLAK5uy_lBNUteBRencHzKelu5iDHwLF6mYqjL-JU',
              category: 'Pop',
              gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
              icon: Icons.star,
            ),
          ],
        ),
      ),

      // ── Bollywood & Indian ──
      MusicGenre(
        id: 'bollywood',
        name: 'Bollywood & Hindi',
        icon: Icons.movie_rounded,
        gradient: const [Color(0xFFe52d27), Color(0xFFb31217)],
        description: 'Timeless Bollywood melodies, high-energy party hits, and romantic ballads.',
        playlists: collect(
          ['bollywood_hitlist', 'make_out_jams_bollywood', 'pop_tadka', 'i_pop_hits'],
          [
            const CuratedPlaylist(
              id: 'bollywood_hits',
              name: 'Bollywood Top Hits',
              playlistId: 'RDCLAK5uy_n9Fbdw7e6ap-98_A-8JYBmPv64v-Uaq1g',
              category: 'Bollywood',
              gradient: [Color(0xFFe52d27), Color(0xFFb31217)],
              icon: Icons.movie,
            ),
          ],
        ),
      ),

      // ── Tollywood & Telugu ──
      MusicGenre(
        id: 'tollywood',
        name: 'Tollywood & Telugu',
        icon: Icons.movie_filter_rounded,
        gradient: const [Color(0xFF667eea), Color(0xFF764ba2)],
        description: 'Blockbuster Tollywood beats, dance numbers, and lyrical melodies.',
        playlists: collect(
          [
            'tollywood_hitlist',
            'new_music_telugu',
            'tollywood_dance_hitlist',
            'tollywood_party',
            'iconic_tollywood_hits',
          ],
          [],
        ),
      ),

      // ── Rock & Alternative ──
      MusicGenre(
        id: 'rock',
        name: 'Rock & Alternative',
        icon: Icons.electric_bolt_rounded,
        gradient: const [Color(0xFF232526), Color(0xFF414345)],
        description: 'Classic riffs, alternative overdrive, indie anthems, and stadium rock.',
        playlists: const [
          CuratedPlaylist(
            id: 'rock_classics',
            name: 'Rock Classics',
            playlistId: 'PL4fGSI1pDJn63E2m3X5P1vX2bC5oU6v9a',
            category: 'Rock',
            gradient: [Color(0xFF232526), Color(0xFF414345)],
            icon: Icons.electric_bolt_rounded,
          ),
          CuratedPlaylist(
            id: 'alt_rock_drive',
            name: 'Alternative Rock Drive',
            playlistId: 'PL4fGSI1pDJn5yJ3b8k2l1m4n5o6p7q8r9',
            category: 'Rock',
            gradient: [Color(0xFF4b6cb7), Color(0xFF182848)],
            icon: Icons.album_rounded,
          ),
        ],
      ),

      // ── Hip-Hop & Rap ──
      MusicGenre(
        id: 'hiphop',
        name: 'Hip-Hop & Rap',
        icon: Icons.album_rounded,
        gradient: const [Color(0xFF8A2387), Color(0xFFE94057)],
        description: 'Heavy basslines, lyrical flows, global rap, and street heat.',
        playlists: const [
          CuratedPlaylist(
            id: 'rap_caviar_curated',
            name: 'Hip-Hop Heavyweights',
            playlistId: 'PL4fGSI1pDJn7t8x9y0z1a2b3c4d5e6f7g',
            category: 'Hip-Hop',
            gradient: [Color(0xFF8A2387), Color(0xFFE94057)],
            icon: Icons.album_rounded,
          ),
        ],
      ),

      // ── Electronic & Dance ──
      MusicGenre(
        id: 'electronic',
        name: 'Electronic & Dance',
        icon: Icons.headphones_rounded,
        gradient: const [Color(0xFF00c6ff), Color(0xFF0072ff)],
        description: 'EDM festival anthems, melodic house, synthwave, and techno grooves.',
        playlists: const [
          CuratedPlaylist(
            id: 'edm_mainstage',
            name: 'EDM Mainstage',
            playlistId: 'PL4fGSI1pDJn4h5i6j7k8l9m0n1o2p3q4r',
            category: 'Electronic',
            gradient: [Color(0xFF00c6ff), Color(0xFF0072ff)],
            icon: Icons.headphones_rounded,
          ),
        ],
      ),

      // ── R&B & Soul ──
      MusicGenre(
        id: 'rnb',
        name: 'R&B & Soul',
        icon: Icons.nightlife_rounded,
        gradient: const [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
        description: 'Smooth harmonies, contemporary soul, velvety vocals, and late-night vibes.',
        playlists: const [
          CuratedPlaylist(
            id: 'rnb_vibes',
            name: 'Midnight R&B',
            playlistId: 'PL4fGSI1pDJn2q3w4e5r6t7y8u9i0o1p2a',
            category: 'R&B',
            gradient: [Color(0xFF8E2DE2), Color(0xFF4A00E0)],
            icon: Icons.nightlife_rounded,
          ),
        ],
      ),

      // ── Lo-Fi & Chill (Mood) ──
      MusicGenre(
        id: 'lofi_chill',
        name: 'Lo-Fi & Study',
        icon: Icons.coffee_rounded,
        gradient: const [Color(0xFFE65100), Color(0xFFF57C00)],
        description: 'Gentle vinyl crackle, mellow jazzy chords, and focus beats to study to.',
        isMood: true,
        playlists: collect(
          ['autumn_lofi_chill'],
          [
            const CuratedPlaylist(
              id: 'lofi_study_beats',
              name: 'Lo-Fi Study Session',
              playlistId: 'RDCLAK5uy_m0zJk1W7b8q761vP-m5_cQG8lM6nZ7w9c',
              category: 'Lo-Fi',
              gradient: [Color(0xFFE65100), Color(0xFFF57C00)],
              icon: Icons.coffee_rounded,
            ),
          ],
        ),
      ),

      // ── Workout & Energy (Mood) ──
      MusicGenre(
        id: 'workout',
        name: 'Workout & Energy',
        icon: Icons.fitness_center_rounded,
        gradient: const [Color(0xFFFF416C), Color(0xFFFF4B2B)],
        description: 'High-BPM fuel, cardio boosts, and motivation for the gym.',
        isMood: true,
        playlists: collect(
          ['the_short_list', 'tollywood_party'],
          [
            const CuratedPlaylist(
              id: 'workout_pump',
              name: 'Cardio & Strength Pump',
              playlistId: 'PL4fGSI1pDJn3k4l5m6n7o8p9q0r1s2t3u',
              category: 'Workout',
              gradient: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
              icon: Icons.fitness_center_rounded,
            ),
          ],
        ),
      ),

      // ── Sleep & Calm (Mood) ──
      MusicGenre(
        id: 'sleep_calm',
        name: 'Sleep & Ambient',
        icon: Icons.nights_stay_rounded,
        gradient: const [Color(0xFF141E30), Color(0xFF243B55)],
        description: 'Drift away with soothing acoustics, ambient soundscapes, and rain.',
        isMood: true,
        playlists: collect(
          ['monsoon_rain_melodies'],
          [
            const CuratedPlaylist(
              id: 'deep_sleep_sounds',
              name: 'Deep Sleep & Relaxation',
              playlistId: 'RDCLAK5uy_kQ7Z3u8pM7d9k5L2c8a1b4e6f9g8h7j6',
              category: 'Sleep',
              gradient: [Color(0xFF141E30), Color(0xFF243B55)],
              icon: Icons.nights_stay_rounded,
            ),
          ],
        ),
      ),

      // ── Party & Celebration (Mood) ──
      MusicGenre(
        id: 'party',
        name: 'Party & Celebration',
        icon: Icons.celebration_rounded,
        gradient: const [Color(0xFFF7971E), Color(0xFFFFD200)],
        description: 'Weekend bangers, dance floor fillers, and festive celebration beats.',
        isMood: true,
        playlists: collect(
          ['festive_celebration_hits', 'tollywood_dance_hitlist', 'country_hotlist'],
          [],
        ),
      ),
    ];
  }
}

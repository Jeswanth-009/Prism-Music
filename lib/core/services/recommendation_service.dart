import 'dart:math';

import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../../domain/repositories/library_repository.dart';
import '../utils/logger.dart';
import 'settings_service.dart';

enum RecommendationMode {
  similar, // Similar songs to currently playing
  discover, // Discover new songs user might like
}

/// Regular expression to detect official music videos
final _officialMusicRegex = RegExp(
  r"official\s(video|audio|music\svideo|lyric\svideo|visualizer)",
  caseSensitive: false,
);

/// Non-music title patterns — interviews, reactions, podcasts, etc.
final _nonMusicTitleRegex = RegExp(
  r'interview|reacts? to|talks? about|talks? upcoming|responds to|'
  r'reveals|breaks down|explains|podcast|episode|ep\.?\s*\d|'
  r'behind the scenes|making of|documentary|trailer|teaser|'
  r'unboxing|haul|vlog|Q&A|AMA|livestream|live stream|'
  r'freestyle|cipher|top \d|ranking|tier list|'
  r'reaction|commentary|review|roast|exposed|drama|'
  r'tutorial|how to|lesson|learn|guide|tips',
  caseSensitive: false,
);

/// Non-music channel/artist patterns
final _nonMusicArtistRegex = RegExp(
  r'entertainment tonight|billboard news|billboard and billboard|access hollywood|'
  r'the tonight show|jimmy kimmel|jimmy fallon|late night|good morning|today show|'
  r'the breakfast club|hot 97|siriusxm|genius|complex|xxl mag|the fader|'
  r'pitchfork|nardwuar|zane lowe|react|fine brothers|'
  r'first we feast|hot ones|npr music|colors show|vevo lift|'
  r'podcast|radio|news|reacts|reaction|commentary',
  caseSensitive: false,
);

/// Returns true if a song result is likely NOT actual music
bool _isLikelyNonMusic(Song song) {
  if (_nonMusicTitleRegex.hasMatch(song.title)) return true;
  if (_nonMusicArtistRegex.hasMatch(song.artist)) return true;
  return false;
}

bool _isLikelyNonMusicArtistName(String artist) {
  return _nonMusicArtistRegex.hasMatch(artist);
}

/// Universal Recommendation Service
///
/// This service provides intelligent music recommendations by:
/// 1. Learning from ALL playback history (not just currently playing)
/// 2. Using multiple sources (JioSaavn suggestions, YouTube Mix, search-based)
/// 3. Building a user taste profile based on listening patterns
/// 4. Respecting language preferences automatically
class RecommendationService {
  static const String _settingsBoxName = 'recommendation_settings';
  static const String _profileBoxName = 'user_taste_profile';

  final MusicRepository _musicRepository;
  final LibraryRepository _libraryRepository;
  final SettingsService _settingsService = SettingsService.instance;
  final Random _rng = Random();

  Box? _settingsBox;
  Box? _profileBox;

  // User taste profile - built from listening history
  Map<String, int> _artistPlayCounts = {};
  Map<String, int> _genrePlayCounts = {};
  Map<String, int> _languagePlayCounts = {};
  Set<String> _recentlyPlayedKeys = {};
  DateTime? _profileCacheTime;
  static const _profileCacheDuration = Duration(minutes: 5);

  RecommendationService(this._musicRepository, this._libraryRepository);

  Future<void> initialize() async {
    try {
      // Open settings box
      if (Hive.isBoxOpen(_settingsBoxName)) {
        _settingsBox = Hive.box(_settingsBoxName);
      } else {
        _settingsBox = await Hive.openBox(_settingsBoxName);
      }

      // Open taste profile box
      if (Hive.isBoxOpen(_profileBoxName)) {
        _profileBox = Hive.box(_profileBoxName);
      } else {
        _profileBox = await Hive.openBox(_profileBoxName);
      }

      // Load cached taste profile
      _loadCachedProfile();

      logDebug('RecommendationService: Initialized successfully');
    } catch (e) {
      logError('Recommendation service initialization error', e, StackTrace.current);
      rethrow;
    }
  }

  void _loadCachedProfile() {
    try {
      final artistData = _profileBox?.get('artist_counts');
      if (artistData is Map) {
        _artistPlayCounts = Map<String, int>.from(artistData);
      }

      final genreData = _profileBox?.get('genre_counts');
      if (genreData is Map) {
        _genrePlayCounts = Map<String, int>.from(genreData);
      }

      final languageData = _profileBox?.get('language_counts');
      if (languageData is Map) {
        _languagePlayCounts = Map<String, int>.from(languageData);
      }

      logDebug('Loaded cached taste profile: ${_artistPlayCounts.length} artists, ${_genrePlayCounts.length} genres, ${_languagePlayCounts.length} languages');
    } catch (e) {
      logError('Error loading cached profile', e, StackTrace.current);
    }
  }

  Future<void> _saveTasteProfile() async {
    try {
      await _profileBox?.put('artist_counts', _artistPlayCounts);
      await _profileBox?.put('genre_counts', _genrePlayCounts);
      await _profileBox?.put('language_counts', _languagePlayCounts);
      await _profileBox?.put('last_updated', DateTime.now().toIso8601String());
    } catch (e) {
      logError('Error saving taste profile', e, StackTrace.current);
    }
  }

  // Get current recommendation mode
  RecommendationMode get mode {
    try {
      final modeString = _settingsBox?.get('recommendation_mode', defaultValue: 'similar') ?? 'similar';
      return modeString == 'discover'
          ? RecommendationMode.discover
          : RecommendationMode.similar;
    } catch (e) {
      logError('Error getting recommendation mode', e, StackTrace.current);
      return RecommendationMode.similar;
    }
  }

  // Set recommendation mode
  Future<void> setMode(RecommendationMode mode) async {
    await _settingsBox?.put(
      'recommendation_mode',
      mode == RecommendationMode.discover ? 'discover' : 'similar'
    );
  }

  /// Record a song play - call this whenever a song is played
  /// This updates the user's taste profile for better recommendations
  Future<void> recordPlay(Song song) async {
    try {
      // Update artist count
      final artistKey = song.artist.toLowerCase().trim();
      _artistPlayCounts[artistKey] = (_artistPlayCounts[artistKey] ?? 0) + 1;

      // Update genre count
      final genre = _detectGenre(song);
      if (genre != null) {
        _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;
      }

      // Update language count
      final language = _detectLanguage(song);
      if (language != null) {
        _languagePlayCounts[language] = (_languagePlayCounts[language] ?? 0) + 1;
      }

      // Add to recently played
      final playKey = '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
      _recentlyPlayedKeys.add(playKey);

      // Keep only last 200 recently played keys in memory
      if (_recentlyPlayedKeys.length > 200) {
        _recentlyPlayedKeys = _recentlyPlayedKeys.toList().sublist(_recentlyPlayedKeys.length - 200).toSet();
      }

      // Save profile periodically (every 5 plays)
      final totalPlays = _artistPlayCounts.values.fold(0, (a, b) => a + b);
      if (totalPlays % 5 == 0) {
        await _saveTasteProfile();
      }

      logDebug('Recorded play: ${song.artist} - ${song.title} (language: $language, genre: $genre)');
    } catch (e) {
      logError('Error recording play', e, StackTrace.current);
    }
  }

  // Get recommendations based on current mode
  Future<List<Song>> getRecommendations({
    required Song currentSong,
    int limit = 10,
  }) async {
    // Refresh listening profile
    await _refreshListeningProfile();

    if (mode == RecommendationMode.similar) {
      return _getSimilarSongs(currentSong, limit);
    } else {
      return _getDiscoverySongs(currentSong, limit);
    }
  }

  // ──────────────────────────────────────────────────────────────────
  // Listening profile — extracts top artists, genres, languages from history
  // ──────────────────────────────────────────────────────────────────

  Future<void> _refreshListeningProfile() async {
    if (_profileCacheTime != null &&
        DateTime.now().difference(_profileCacheTime!) < _profileCacheDuration) {
      return; // still fresh
    }

    try {
      final historyResult = await _libraryRepository.getListeningHistory(limit: 100);
      historyResult.fold(
        (failure) => logError('Failed to load listening history for profile'),
        (songs) {
          // Build recently played set from history
          _recentlyPlayedKeys = songs
              .map((s) => '${s.title.toLowerCase()}|${s.artist.toLowerCase()}')
              .toSet();

          // Update play counts from history (supplements in-memory counts)
          for (final s in songs) {
            final artistKey = s.artist.toLowerCase().trim();
            _artistPlayCounts[artistKey] = (_artistPlayCounts[artistKey] ?? 0) + 1;

            final genre = _detectGenre(s);
            if (genre != null) {
              _genrePlayCounts[genre] = (_genrePlayCounts[genre] ?? 0) + 1;
            }

            final language = _detectLanguage(s);
            if (language != null) {
              _languagePlayCounts[language] = (_languagePlayCounts[language] ?? 0) + 1;
            }
          }

          _profileCacheTime = DateTime.now();
          logDebug('Refreshed listening profile: ${_artistPlayCounts.length} artists, ${_genrePlayCounts.length} genres, ${_languagePlayCounts.length} languages, ${_recentlyPlayedKeys.length} recent tracks');
        },
      );
    } catch (e) {
      logError('Error building listening profile', e, StackTrace.current);
    }
  }

  /// Get top N entries from a play count map
  List<String> _getTopN(Map<String, int> counts, int n) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(n).map((e) => e.key).toList();
  }

  /// Get preferred language based on listening history
  String? get _preferredLanguage {
    if (_languagePlayCounts.isEmpty) return null;
    return _getTopN(_languagePlayCounts, 1).firstOrNull;
  }

  /// Get top artists based on listening history
  List<String> get _topArtists => _getTopN(_artistPlayCounts, 20)
      .where((artist) => !_isLikelyNonMusicArtistName(artist))
      .take(10)
      .toList();

  /// Get preferred genre based on listening history
  String? get _preferredGenre {
    if (_genrePlayCounts.isEmpty) return null;
    return _getTopN(_genrePlayCounts, 1).firstOrNull;
  }

  // ──────────────────────────────────────────────────────────────────
  // SIMILAR mode — songs that sound like what's playing
  // Uses multiple sources: JioSaavn suggestions, YouTube Mix, and search
  // ──────────────────────────────────────────────────────────────────

  Future<List<Song>> _getSimilarSongs(Song song, int limit) async {
    final allResults = <Song>[];

    try {
      logDebug('Getting similar songs for: ${song.artist} - ${song.title}');

      final genre = _detectGenre(song) ?? _preferredGenre;
      final language = _detectLanguage(song) ?? _preferredLanguage;
      final langTag = language != null ? ' $language' : '';
      logDebug('Detected language=$language, genre=$genre');

      final futures = <Future>[];

      // Strategy 1: JioSaavn song suggestions (if JioSaavn song)
      if (song.jioSaavnId != null) {
        futures.add(
          _musicRepository.getJioSaavnSuggestions(song.jioSaavnId!, limit: limit * 2)
              .then((result) {
            result.fold(
              (failure) => logDebug('JioSaavn suggestions failed: ${failure.message}'),
              (songs) {
                logDebug('Found ${songs.length} from JioSaavn suggestions');
                allResults.addAll(songs);
              },
            );
          }),
        );
      }

      // Strategy 2: YouTube Mix/Radio playlist
      if (song.youtubeId != null) {
        futures.add(
          _musicRepository.getRelatedSongs(song.youtubeId!, limit: limit * 2)
              .then((result) {
            result.fold(
              (failure) => logDebug('YouTube related failed: ${failure.message}'),
              (songs) {
                logDebug('Found ${songs.length} from YouTube Mix');
                allResults.addAll(songs);
              },
            );
          }),
        );
      }

      // Strategy 3: Search for similar songs by artist + title context
      futures.add(
        _musicRepository.searchSongs(
          '${song.artist} ${song.title.split('(').first.trim()} songs$langTag',
          limit: 15,
        ).then((r) => r.fold((f) => null, (songs) => allResults.addAll(songs))),
      );

      // Strategy 4: Genre + language based new songs
      futures.add(
        _musicRepository.searchSongs(
          '${genre ?? "pop"} songs ${DateTime.now().year}$langTag',
          limit: 12,
        ).then((r) => r.fold((f) => null, (songs) => allResults.addAll(songs))),
      );

      // Strategy 5: Top artists from history (cross-seed)
      final topArtists = _topArtists;
      if (topArtists.isNotEmpty) {
        // Pick a random top artist that's different from current
        final otherArtists = topArtists.where(
          (a) => a.toLowerCase() != song.artist.toLowerCase()
        ).toList();
        if (otherArtists.isNotEmpty) {
          final randomArtist = otherArtists[_rng.nextInt(otherArtists.length)];
          futures.add(
            _musicRepository.searchSongs(
              '$randomArtist songs$langTag',
              limit: 10,
            ).then((r) => r.fold((f) => null, (songs) => allResults.addAll(songs))),
          );
        }
      }

      // Strategy 6: Similar artists search
      futures.add(
        _musicRepository.searchSongs(
          '${song.artist} similar artists songs$langTag',
          limit: 10,
        ).then((r) => r.fold((f) => null, (songs) => allResults.addAll(songs))),
      );

      await Future.wait(futures);

      // Filter out current song, duplicates, covers, and recently played
      final filtered = _filterAndDedup(allResults, song);

      // Rank with language affinity, artist diversity, and quality scoring
      final ranked = _rankSimilar(filtered, song, language);
      final topPool = ranked.take(limit * 2).toList();
      topPool.shuffle(_rng);

      logDebug('Returning top $limit similar songs (${allResults.length} raw → ${filtered.length} filtered)');
      return topPool.take(limit).toList();
    } catch (e) {
      logError('Error getting similar songs', e, StackTrace.current);
      return [];
    }
  }

  /// Rank songs for similar mode
  List<Song> _rankSimilar(List<Song> songs, Song currentSong, String? preferredLanguage) {
    final currentArtist = currentSong.artist.toLowerCase();

    final scored = songs.map((song) {
      int score = 0;
      final songArtist = song.artist.toLowerCase();

      // Core ranking: STRONGLY penalize same artist for variety
      if (songArtist == currentArtist) {
        score -= 5;
      } else {
        score += 4;
      }

      // Bonus for artists in listening history
      if (_artistPlayCounts.containsKey(songArtist)) {
        score += min(3, _artistPlayCounts[songArtist]! ~/ 3); // Capped bonus
      }

      // Language affinity — same language ranks much higher
      if (preferredLanguage != null) {
        final songLanguage = _detectLanguage(song);
        if (songLanguage == preferredLanguage) {
          score += 6; // Same language → strong boost
        } else if (songLanguage != null && songLanguage != preferredLanguage) {
          score -= 4; // Different non-English → penalty
        }
      }

      // Official content is higher quality
      if (_officialMusicRegex.hasMatch(song.title)) {
        score += 2;
      }

      // Ideal duration (2.5 – 5 min)
      final mins = song.duration.inSeconds / 60;
      if (mins >= 2.5 && mins <= 5) {
        score += 1;
      }

      // Skip songs we've already heard recently
      final key = '${song.title.toLowerCase()}|$songArtist';
      if (_recentlyPlayedKeys.contains(key)) {
        score -= 3;
      }

      // Random jitter for freshness
      score += _rng.nextInt(2);

      return _ScoredSong(song: song, score: score);
    }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.song).toList();
  }

  // ──────────────────────────────────────────────────────────────────
  // Shared filter: dedup, remove covers/remixes, skip recent plays
  // ──────────────────────────────────────────────────────────────────

  List<Song> _filterAndDedup(List<Song> candidates, Song current) {
    final seenTracks = <String>{};
    final currentKey = '${current.title.toLowerCase()}|${current.artist.toLowerCase()}';
    seenTracks.add(currentKey);

    final filtered = <Song>[];

    for (final s in candidates) {
      final trackKey = '${s.title.toLowerCase()}|${s.artist.toLowerCase()}';

      if (seenTracks.contains(trackKey)) continue;
      if (s.duration.inSeconds < 90 || s.duration.inSeconds > 420) continue;

      // Reject non-music content
      if (_isLikelyNonMusic(s)) continue;

      final titleLower = s.title.toLowerCase();
      if (titleLower.contains('cover') ||
          titleLower.contains('karaoke') ||
          titleLower.contains('instrumental') ||
          titleLower.contains('playlist') ||
          titleLower.contains('compilation') ||
          titleLower.contains('mashup') ||
          titleLower.contains('megamix') ||
          titleLower.contains('nonstop') ||
          titleLower.contains('non-stop')) {
        continue;
      }

      seenTracks.add(trackKey);
      filtered.add(s);
    }

    return filtered;
  }

  // ──────────────────────────────────────────────────────────────────
  // DISCOVER mode — find new music based on entire taste profile
  // ──────────────────────────────────────────────────────────────────

  Future<List<Song>> _getDiscoverySongs(Song song, int limit) async {
    final allResults = <Song>[];

    try {
      logDebug('Getting discovery songs based on full taste profile');

      final countryName = _settingsService.selectedCountry.name;
      final currentYear = DateTime.now().year;
      final genre = _detectGenre(song) ?? _preferredGenre;
      final language = _detectLanguage(song) ?? _preferredLanguage;
      final langTag = language != null ? ' $language' : '';
      logDebug('Discover: language=$language, genre=$genre');

      final queries = <String>[];
      final topArtists = _topArtists;

      // ── History-based personalized queries ──
      if (topArtists.length >= 3) {
        // Combine top artists for variety
        queries.add('${topArtists[0]} ${topArtists[1]} songs$langTag');
        queries.add('${topArtists[2]} new songs $currentYear$langTag');
      } else if (topArtists.isNotEmpty) {
        queries.add('${topArtists.first} new songs $currentYear$langTag');
      }

      // Current song as discovery seed
      if (song.artist.toLowerCase() != topArtists.firstOrNull?.toLowerCase()) {
        queries.add('${song.artist} songs $currentYear$langTag');
      }

      // ── Genre-based queries ──
      if (genre != null) {
        queries.add('best $genre songs $currentYear$langTag');
        queries.add('$genre new artists songs $currentYear$langTag');
        queries.add('trending $genre music$langTag');
      }

      // ── Cross-genre exploration ──
      final allGenres = ['Pop', 'Rock', 'Hip Hop Rap', 'R&B Soul', 'Electronic Dance',
                         'Jazz', 'Country', 'Indie Alternative', 'Latin', 'Reggae'];
      final otherGenres = allGenres.where(
        (g) => g.toLowerCase() != (genre ?? '').toLowerCase()
      ).toList();
      otherGenres.shuffle(_rng);
      if (otherGenres.isNotEmpty) {
        queries.add('best ${otherGenres.first} songs all time$langTag');
      }

      // ── Language-specific trending ──
      if (language != null) {
        queries.add('trending $language music $currentYear');
        queries.add('new $language songs $currentYear');
      }

      // ── Global fallbacks ──
      if (queries.length < 4) {
        queries.add('best new songs $currentYear $countryName$langTag');
        queries.add('trending songs $currentYear$langTag');
      }

      // Run ALL searches in parallel
      final futures = queries.take(8).map((query) {
        logDebug('Discovery query: "$query"');
        return _musicRepository.searchSongs(query, limit: 12);
      }).toList();

      final results = await Future.wait(futures);
      for (final result in results) {
        result.fold(
          (failure) => logDebug('Discovery search failed'),
          (songs) => allResults.addAll(songs),
        );
      }

      // ── Filter for TRUE discovery ──
      final seenTracks = <String>{};
      final currentKey = '${song.title.toLowerCase()}|${song.artist.toLowerCase()}';
      seenTracks.add(currentKey);

      final filtered = <Song>[];
      final currentArtistLower = song.artist.toLowerCase();

      for (final s in allResults) {
        final trackKey = '${s.title.toLowerCase()}|${s.artist.toLowerCase()}';

        if (_isLikelyNonMusicArtistName(s.artist)) continue;
        if (seenTracks.contains(trackKey)) continue;

        // Keep unknown-duration items (duration=0). Reject only clearly invalid lengths.
        final durationSec = s.duration.inSeconds;
        if (durationSec > 0 && (durationSec < 45 || durationSec > 720)) continue;

        if (_isLikelyNonMusic(s)) continue;

        final titleLower = s.title.toLowerCase();
        if (titleLower.contains('karaoke') ||
            titleLower.contains('instrumental') ||
            titleLower.contains('playlist') ||
            titleLower.contains('compilation') ||
            titleLower.contains('mashup') ||
            titleLower.contains('megamix') ||
            titleLower.contains('nonstop') ||
            titleLower.contains('non-stop')) {
          continue;
        }

        seenTracks.add(trackKey);
        filtered.add(s);
      }

      logDebug('Filtered to ${filtered.length} unique discovery songs');

      if (filtered.isEmpty) {
        logDebug('Discovery empty after filtering, falling back to similar mode');
        return _getSimilarSongs(song, limit);
      }

      // ── Score: favor official, ideal duration, true discovery, language ──
      final scored = filtered.map((s) {
        int score = 0;
        final sArtist = s.artist.toLowerCase();

        // Language affinity
        if (language != null) {
          final sLang = _detectLanguage(s);
          if (sLang == language) {
            score += 6;
          } else if (sLang != null && sLang != language) {
            score -= 4;
          }
        }

        // Official content priority
        if (_officialMusicRegex.hasMatch(s.title.toLowerCase())) {
          score += 3;
        }

        // Ideal duration (3-4 min)
        final durationMins = s.duration.inSeconds / 60;
        if (durationMins >= 3 && durationMins <= 4) {
          score += 2;
        }

        // True discovery bonus: artist NOT in listening history
        if (!_artistPlayCounts.containsKey(sArtist)) {
          score += 4; // Strong bonus for new artists
        } else {
          // Small bonus for known artists (user likes them)
          score += 1;
        }

        // Keep some variety, but do not hard-block same artist tracks.
        if (sArtist == currentArtistLower) {
          score -= 2;
        }

        // Penalize songs we've already heard
        final key = '${s.title.toLowerCase()}|$sArtist';
        if (_recentlyPlayedKeys.contains(key)) {
          score -= 5; // Strong penalty
        }

        return _ScoredSong(song: s, score: score);
      }).toList();

      scored.sort((a, b) => b.score.compareTo(a.score));

      final topPool = scored.map((s) => s.song).take(limit * 2).toList();
      topPool.shuffle(_rng);

      final output = topPool.take(limit).toList();
      if (output.isEmpty) {
        logDebug('Discovery scored output empty, falling back to similar mode');
        return _getSimilarSongs(song, limit);
      }

      logDebug('Returning ${output.length} discovery songs');
      return output;
    } catch (e) {
      logError('Error getting discovery songs', e, StackTrace.current);
      return [];
    }
  }

  // Detect genre from song characteristics
  String? _detectGenre(Song song) {
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();
    final combined = '$title $artist ${song.genre ?? ''}';

    // Return explicit genre if available
    if (song.genre != null && song.genre!.isNotEmpty) {
      return song.genre;
    }

    if (combined.contains('rap') || combined.contains('hip hop') || combined.contains('trap')) {
      return 'Hip Hop Rap';
    }
    if (combined.contains('rock') || combined.contains('metal') || combined.contains('punk')) {
      return 'Rock';
    }
    if (combined.contains('edm') || combined.contains('electronic') || combined.contains('dance') || combined.contains('dj')) {
      return 'Electronic Dance';
    }
    if (combined.contains('country') || combined.contains('folk') || combined.contains('bluegrass')) {
      return 'Country';
    }
    if (combined.contains('r&b') || combined.contains('soul') || combined.contains('rnb')) {
      return 'R&B Soul';
    }
    if (combined.contains('jazz') || combined.contains('blues')) {
      return 'Jazz';
    }
    if (combined.contains('reggae') || combined.contains('dancehall')) {
      return 'Reggae';
    }
    if (combined.contains('classical') || combined.contains('orchestra') || combined.contains('symphony')) {
      return 'Classical';
    }
    if (combined.contains('latin') || combined.contains('reggaeton') || combined.contains('salsa') || combined.contains('bachata')) {
      return 'Latin';
    }
    if (combined.contains('k-pop') || combined.contains('kpop') || combined.contains('korean')) {
      return 'K-Pop';
    }
    if (combined.contains('bollywood') || combined.contains('hindi')) {
      return 'Bollywood';
    }
    if (combined.contains('indie') || combined.contains('alternative')) {
      return 'Indie Alternative';
    }
    if (combined.contains('pop')) {
      return 'Pop';
    }

    return null;
  }

  // ──────────────────────────────────────────────────────────────────
  // Language detection — comprehensive detection from multiple signals
  // ──────────────────────────────────────────────────────────────────

  static final _hindiKeywords = RegExp(
    r'hindi|bollywood|arijit|atif|shreya|neha kakkar|jubin|'
    r'badshah|yo yo|honey singh|armaan malik|darshan|sonu nigam|'
    r'kumar sanu|kishore kumar|lata|asha bhosle|alka yagnik|'
    r'udit narayan|mohd rafi|sunidhi|shankar|t-series|'
    r'zee music|tips official|saregama|yrf|eros now|'
    r'gaana|hungama|sony music india',
    caseSensitive: false,
  );

  static final _punjabiKeywords = RegExp(
    r'punjabi|sidhu|ap dhillon|diljit|guru randhawa|harrdy|'
    r'karan aujla|ammy virk|jassie gill|garry sandhu|jasmine sandlas|'
    r'b praak|jaani|amrinder gill|gurdas maan|speed records|'
    r'white hill music|jass records',
    caseSensitive: false,
  );

  static final _tamilKeywords = RegExp(
    r'tamil|anirudh|yuvan|ar rahman|sid sriram|'
    r'harris jayaraj|d imman|hiphop tamizha|'
    r'sony music south|think music|sun tv|'
    r'kollywood|vijay|ajith',
    caseSensitive: false,
  );

  static final _teluguKeywords = RegExp(
    r'telugu|tollywood|devi sri|thaman|aditya music|'
    r'mango music|sri balaji|lahari music|anup rubens|'
    r'dsp|armaan|sid sriram',
    caseSensitive: false,
  );

  static final _spanishKeywords = RegExp(
    r'spanish|latino|reggaeton|bad bunny|j balvin|ozuna|'
    r'daddy yankee|maluma|nicky jam|anuel|karol g|'
    r'rauw alejandro|rosalía|farruko|becky g|sech|'
    r'bachata|salsa|merengue|cumbia|corrido|regional mexicano',
    caseSensitive: false,
  );

  static final _koreanKeywords = RegExp(
    r'korean|k-pop|kpop|bts|blackpink|twice|stray kids|'
    r'aespa|newjeans|ive|seventeen|exo|nct|txt|ateez|'
    r'itzy|le sserafim|hybe|sm entertainment|jyp|yg',
    caseSensitive: false,
  );

  static final _japaneseKeywords = RegExp(
    r'japanese|j-pop|jpop|anime|yoasobi|ado|kenshi yonezu|'
    r'official hige|lisa|vaundy|fujii kaze|imase|'
    r'one ok rock|radwimps|sony music japan',
    caseSensitive: false,
  );

  /// Detect language/region from song's title, artist name, and script
  String? _detectLanguage(Song song) {
    final combined = '${song.title} ${song.artist}'.toLowerCase();
    final original = '${song.title} ${song.artist}';

    // Check non-Latin scripts
    if (RegExp(r'[\u0900-\u097F]').hasMatch(original)) return 'Hindi';
    if (RegExp(r'[\u0A00-\u0A7F]').hasMatch(original)) return 'Punjabi';
    if (RegExp(r'[\u0B80-\u0BFF]').hasMatch(original)) return 'Tamil';
    if (RegExp(r'[\u0C00-\u0C7F]').hasMatch(original)) return 'Telugu';
    if (RegExp(r'[\uAC00-\uD7AF\u1100-\u11FF]').hasMatch(original)) return 'Korean';
    if (RegExp(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]').hasMatch(original)) return 'Japanese';
    if (RegExp(r'[\u0600-\u06FF]').hasMatch(original)) return 'Arabic';
    if (RegExp(r'[\u0980-\u09FF]').hasMatch(original)) return 'Bengali';

    // Keyword-based detection
    if (_hindiKeywords.hasMatch(combined)) return 'Hindi';
    if (_punjabiKeywords.hasMatch(combined)) return 'Punjabi';
    if (_tamilKeywords.hasMatch(combined)) return 'Tamil';
    if (_teluguKeywords.hasMatch(combined)) return 'Telugu';
    if (_spanishKeywords.hasMatch(combined)) return 'Spanish';
    if (_koreanKeywords.hasMatch(combined)) return 'Korean';
    if (_japaneseKeywords.hasMatch(combined)) return 'Japanese';

    return null; // English or unknown
  }

  // Get recommendation description based on mode
  String getModeDescription() {
    switch (mode) {
      case RecommendationMode.similar:
        return 'Playing songs with a similar vibe';
      case RecommendationMode.discover:
        return 'Discovering new music based on your taste';
    }
  }

  String getModeName() {
    switch (mode) {
      case RecommendationMode.similar:
        return 'Similar';
      case RecommendationMode.discover:
        return 'Discover';
    }
  }

  /// Get a summary of the user's taste profile (for debugging or display)
  Map<String, dynamic> getTasteProfileSummary() {
    return {
      'topArtists': _topArtists.take(5).toList(),
      'preferredGenre': _preferredGenre,
      'preferredLanguage': _preferredLanguage,
      'totalArtistsTracked': _artistPlayCounts.length,
      'totalGenresTracked': _genrePlayCounts.length,
      'totalLanguagesTracked': _languagePlayCounts.length,
      'recentlyPlayedCount': _recentlyPlayedKeys.length,
    };
  }
}

/// Helper class for scoring songs by relevance
class _ScoredSong {
  final Song song;
  final int score;

  _ScoredSong({required this.song, required this.score});
}

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/datasources/remote/youtube/youtube_music_datasource.dart';
import '../../domain/entities/song.dart';
import '../../presentation/blocs/player/player_bloc.dart';
import '../../presentation/blocs/player/player_event.dart';
import '../utils/media_share_helper.dart';

/// Supported types of deep links within Prism Music.
enum DeepLinkType {
  song,
  playlist,
  search,
  unknown,
}

/// Represents the structured data extracted from an incoming deep link or shared text.
class ParsedDeepLink {
  final DeepLinkType type;
  final String? id;
  final String? title;
  final String? artist;
  final String? album;
  final String? artworkUrl;
  final String? query;
  final String raw;

  const ParsedDeepLink({
    required this.type,
    this.id,
    this.title,
    this.artist,
    this.album,
    this.artworkUrl,
    this.query,
    required this.raw,
  });

  bool get isValid =>
      type != DeepLinkType.unknown &&
      ((id != null && id!.isNotEmpty) || (query != null && query!.isNotEmpty));

  @override
  String toString() =>
      'ParsedDeepLink(type: $type, id: $id, title: $title, artist: $artist, query: $query)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ParsedDeepLink &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          id == other.id &&
          title == other.title &&
          artist == other.artist &&
          album == other.album &&
          artworkUrl == other.artworkUrl &&
          query == other.query &&
          raw == other.raw;

  @override
  int get hashCode =>
      type.hashCode ^
      id.hashCode ^
      title.hashCode ^
      artist.hashCode ^
      album.hashCode ^
      artworkUrl.hashCode ^
      query.hashCode ^
      raw.hashCode;
}

/// Service that listens for cold-start deep links and runtime incoming links/shares,
/// parses song/playlist references, and initiates playback in [PlayerBloc].
class DeepLinkService {
  static const MethodChannel _channel = MethodChannel('com.prismmusic/deep_link');

  final PlayerBloc _playerBloc;
  final YouTubeMusicDataSource? _dataSource;
  final MethodChannel _platformChannel;

  final StreamController<ParsedDeepLink> _linkController =
      StreamController<ParsedDeepLink>.broadcast();

  /// Stream of successfully parsed deep link events.
  Stream<ParsedDeepLink> get linkStream => _linkController.stream;

  DeepLinkService({
    required PlayerBloc playerBloc,
    YouTubeMusicDataSource? dataSource,
    MethodChannel? platformChannel,
  })  : _playerBloc = playerBloc,
        _dataSource = dataSource,
        _platformChannel = platformChannel ?? _channel;

  /// Initializes deep link listeners and inspects for any cold-start launch URI.
  Future<void> initialize() async {
    try {
      _platformChannel.setMethodCallHandler(_handleMethodCall);
      final initialLink =
          await _platformChannel.invokeMethod<String>('getInitialLink');
      if (initialLink != null && initialLink.trim().isNotEmpty) {
        debugPrint('DeepLinkService: Handling cold-start link: $initialLink');
        await handleRawLink(initialLink.trim());
      }
    } catch (e) {
      debugPrint('DeepLinkService: Error during platform initialization: $e');
    }
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onDeepLink') {
      final rawLink = call.arguments as String?;
      if (rawLink != null && rawLink.trim().isNotEmpty) {
        debugPrint('DeepLinkService: Handling runtime link: $rawLink');
        await handleRawLink(rawLink.trim());
      }
    }
  }

  /// Parses an arbitrary input string (which can be a full URL, custom scheme URI,
  /// or text snippet shared from external apps containing a URL).
  static ParsedDeepLink parse(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      return ParsedDeepLink(type: DeepLinkType.unknown, raw: input);
    }

    // 1. Extract URL candidate if input is part of a larger shared text block
    final urlRegex = RegExp(r'(prism:\/\/[^\s]+|https?:\/\/[^\s]+)');
    final match = urlRegex.firstMatch(trimmed);
    final linkToParse = match != null ? match.group(0)! : trimmed;

    final uri = Uri.tryParse(linkToParse);
    if (uri != null && uri.hasScheme) {
      // 2. Custom Prism Scheme: prism://song?id=... or prism://playlist?id=...
      if (uri.scheme == 'prism') {
        final host = (uri.host.isNotEmpty ? uri.host : uri.path)
            .replaceAll('/', '')
            .toLowerCase();

        if (host == 'song') {
          final id = uri.queryParameters['id'];
          if (id != null && id.isNotEmpty) {
            return ParsedDeepLink(
              type: DeepLinkType.song,
              id: id,
              title: uri.queryParameters['title'],
              artist: uri.queryParameters['artist'],
              album: uri.queryParameters['album'],
              artworkUrl: uri.queryParameters['artwork'],
              raw: input,
            );
          }
        } else if (host == 'playlist') {
          final id = uri.queryParameters['id'];
          if (id != null && id.isNotEmpty) {
            return ParsedDeepLink(
              type: DeepLinkType.playlist,
              id: id,
              title: uri.queryParameters['name'],
              raw: input,
            );
          }
        } else if (host == 'search') {
          final q = uri.queryParameters['q'];
          if (q != null && q.isNotEmpty) {
            return ParsedDeepLink(
              type: DeepLinkType.search,
              query: q,
              raw: input,
            );
          }
        }
      }

      // 3. YouTube and YouTube Music URLs
      final hostLower = uri.host.toLowerCase();
      if (hostLower.contains('youtube.com')) {
        // Track: /watch?v=...
        if (uri.path.startsWith('/watch')) {
          final v = uri.queryParameters['v'];
          if (v != null && MediaShareHelper.isValidYouTubeVideoId(v)) {
            return ParsedDeepLink(
              type: DeepLinkType.song,
              id: v,
              raw: input,
            );
          }
        }

        // Playlist: /playlist?list=...
        if (uri.path.startsWith('/playlist')) {
          final list = uri.queryParameters['list'];
          if (list != null && MediaShareHelper.isValidYouTubePlaylistId(list)) {
            return ParsedDeepLink(
              type: DeepLinkType.playlist,
              id: list,
              raw: input,
            );
          }
        }

        // Embed or direct path: /v/ID or /embed/ID
        if (uri.pathSegments.length >= 2 &&
            (uri.pathSegments[0] == 'v' || uri.pathSegments[0] == 'embed')) {
          final id = uri.pathSegments[1];
          if (MediaShareHelper.isValidYouTubeVideoId(id)) {
            return ParsedDeepLink(
              type: DeepLinkType.song,
              id: id,
              raw: input,
            );
          }
        }
      }

      // 4. Shortened YouTube links: youtu.be/<id>
      if (hostLower == 'youtu.be') {
        final id = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : '';
        if (MediaShareHelper.isValidYouTubeVideoId(id)) {
          return ParsedDeepLink(
            type: DeepLinkType.song,
            id: id,
            raw: input,
          );
        }
      }
    }

    // 5. Raw 11-char YouTube Video ID fallback
    if (trimmed.length == 11 && MediaShareHelper.isValidYouTubeVideoId(trimmed)) {
      return ParsedDeepLink(
        type: DeepLinkType.song,
        id: trimmed,
        raw: input,
      );
    }

    return ParsedDeepLink(type: DeepLinkType.unknown, raw: input);
  }

  /// Processes the link, parses its metadata, emits to [linkStream], and launches
  /// playback if the link points to a song or playlist.
  Future<void> handleRawLink(String rawInput) async {
    final parsed = parse(rawInput);
    if (!parsed.isValid) {
      debugPrint('DeepLinkService: Unable to resolve link: $rawInput');
      return;
    }

    _linkController.add(parsed);

    if (parsed.type == DeepLinkType.song && parsed.id != null) {
      await _playSongFromDeepLink(parsed);
    } else if (parsed.type == DeepLinkType.playlist && parsed.id != null) {
      await _playPlaylistFromDeepLink(parsed);
    }
  }

  Future<void> _playSongFromDeepLink(ParsedDeepLink parsed) async {
    Song song;
    final id = parsed.id!;

    if (parsed.title != null && parsed.artist != null) {
      song = Song(
        id: id,
        youtubeId: id,
        title: parsed.title!,
        artist: parsed.artist!,
        album: parsed.album,
        thumbnails: parsed.artworkUrl != null
            ? Thumbnails.fromUrl(parsed.artworkUrl!)
            : Thumbnails.empty(),
        duration: Duration.zero,
      );
    } else if (_dataSource != null) {
      try {
        song = await _dataSource.getSongDetails(id);
      } catch (e) {
        debugPrint('DeepLinkService: Failed to resolve YouTube song details ($id): $e');
        song = Song(
          id: id,
          youtubeId: id,
          title: 'YouTube Track ($id)',
          artist: 'Prism Music',
          duration: Duration.zero,
          thumbnails: Thumbnails.empty(),
        );
      }
    } else {
      song = Song(
        id: id,
        youtubeId: id,
        title: 'YouTube Track ($id)',
        artist: 'Prism Music',
        duration: Duration.zero,
        thumbnails: Thumbnails.empty(),
      );
    }

    _playerBloc.add(PlaySongEvent(
      song: song,
      queue: [song],
      queueIndex: 0,
      userInitiated: true,
    ));
  }

  Future<void> _playPlaylistFromDeepLink(ParsedDeepLink parsed) async {
    final playlistId = parsed.id!;
    if (_dataSource != null) {
      try {
        final playlist = await _dataSource.getPlaylistDetails(playlistId);
        final songs = playlist.songs;
        if (songs != null && songs.isNotEmpty) {
          _playerBloc.add(PlaySongEvent(
            song: songs.first,
            queue: songs,
            queueIndex: 0,
            userInitiated: true,
          ));
        }
      } catch (e) {
        debugPrint('DeepLinkService: Failed to resolve playlist details ($playlistId): $e');
      }
    }
  }

  void dispose() {
    _linkController.close();
  }
}

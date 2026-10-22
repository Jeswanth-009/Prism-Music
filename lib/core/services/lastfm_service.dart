import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class LastFmService {
  /// Credentials provided at build time via `--dart-define=LASTFM_API_KEY=...`
  /// and `--dart-define=LASTFM_API_SECRET=...`. Never commit production secrets.
  static const String _apiKey = String.fromEnvironment('LASTFM_API_KEY');
  static const String _apiSecret = String.fromEnvironment('LASTFM_API_SECRET');

  static const String secureKeyCustomApiKey = 'lastfm_custom_api_key';
  static const String secureKeyCustomApiSecret = 'lastfm_custom_api_secret';
  static const String legacySessionBoxName = 'lastfm_session';
  static const String secureKeySession = 'lastfm_session_key';
  static const String secureKeyUsername = 'lastfm_username';
  static const String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';

  static String? _staticCustomApiKey;
  static String? _staticCustomApiSecret;

  final FlutterSecureStorage _secureStorage;
  final http.Client? _httpClient;

  String? _customApiKey;
  String? _customApiSecret;
  String? _sessionKey;
  String? _username;

  /// Effective API Key (custom user credentials take precedence over build-time defaults)
  String get apiKey => (_customApiKey != null && _customApiKey!.isNotEmpty)
      ? _customApiKey!
      : ((_staticCustomApiKey != null && _staticCustomApiKey!.isNotEmpty)
          ? _staticCustomApiKey!
          : _apiKey);

  /// Effective API Secret (custom user credentials take precedence over build-time defaults)
  String get apiSecret => (_customApiSecret != null && _customApiSecret!.isNotEmpty)
      ? _customApiSecret!
      : ((_staticCustomApiSecret != null && _staticCustomApiSecret!.isNotEmpty)
          ? _staticCustomApiSecret!
          : _apiSecret);

  /// Whether valid API credentials are present
  bool get hasValidCredentials => apiKey.isNotEmpty && apiSecret.isNotEmpty;

  /// Whether custom credentials have been configured by the user
  bool get hasCustomCredentials =>
      (_customApiKey != null && _customApiKey!.isNotEmpty) ||
      (_staticCustomApiKey != null && _staticCustomApiKey!.isNotEmpty);

  /// The Last.fm integration is configured if either build-time or user credentials exist.
  static bool get isConfigured =>
      (_apiKey.isNotEmpty && _apiSecret.isNotEmpty) ||
      ((_staticCustomApiKey != null && _staticCustomApiKey!.isNotEmpty) &&
          (_staticCustomApiSecret != null && _staticCustomApiSecret!.isNotEmpty));

  LastFmService({
    FlutterSecureStorage? secureStorage,
    http.Client? httpClient,
  })  : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _httpClient = httpClient;

  Future<void> initialize() async {
    try {
      // 1. Read custom credentials if saved
      _customApiKey = await _secureStorage.read(key: secureKeyCustomApiKey);
      _customApiSecret = await _secureStorage.read(key: secureKeyCustomApiSecret);
      _staticCustomApiKey = _customApiKey;
      _staticCustomApiSecret = _customApiSecret;

      // 2. Read session key and username from OS-backed secure storage.
      _sessionKey = await _secureStorage.read(key: secureKeySession);
      _username = await _secureStorage.read(key: secureKeyUsername);

      // 3. Read-through migration from legacy plain-text Hive box if present.
      if (_sessionKey == null || _username == null) {
        await _migrateFromLegacyHiveBox();
      }
    } catch (e, stack) {
      logError('Last.fm initialization error', e, stack);
    }
  }

  /// Saves user-provided custom Last.fm API credentials to secure storage.
  Future<void> setCustomCredentials({
    required String apiKey,
    required String apiSecret,
  }) async {
    _customApiKey = apiKey.trim();
    _customApiSecret = apiSecret.trim();
    _staticCustomApiKey = _customApiKey;
    _staticCustomApiSecret = _customApiSecret;
    await _secureStorage.write(key: secureKeyCustomApiKey, value: _customApiKey);
    await _secureStorage.write(key: secureKeyCustomApiSecret, value: _customApiSecret);
  }

  /// Removes custom Last.fm credentials and logs out active session.
  Future<void> clearCustomCredentials() async {
    _customApiKey = null;
    _customApiSecret = null;
    _staticCustomApiKey = null;
    _staticCustomApiSecret = null;
    await _secureStorage.delete(key: secureKeyCustomApiKey);
    await _secureStorage.delete(key: secureKeyCustomApiSecret);
    await logout();
  }

  Future<void> _migrateFromLegacyHiveBox() async {
    try {
      Box? legacyBox;
      if (Hive.isBoxOpen(legacySessionBoxName)) {
        legacyBox = Hive.box(legacySessionBoxName);
      } else {
        try {
          if (await Hive.boxExists(legacySessionBoxName)) {
            legacyBox = await Hive.openBox(legacySessionBoxName);
          }
        } catch (_) {
          // Hive home path not configured in headless unit test environment
        }
      }

      if (legacyBox != null) {
        final legacyKey = legacyBox.get('session_key')?.toString();
        final legacyUser = legacyBox.get('username')?.toString();

        if (legacyKey != null && legacyKey.isNotEmpty && _sessionKey == null) {
          _sessionKey = legacyKey;
          await _secureStorage.write(key: secureKeySession, value: legacyKey);
        }
        if (legacyUser != null && legacyUser.isNotEmpty && _username == null) {
          _username = legacyUser;
          await _secureStorage.write(key: secureKeyUsername, value: legacyUser);
        }

        // Delete plain-text credentials from disk and close the legacy box.
        await legacyBox.clear();
        await legacyBox.deleteFromDisk();
      }
    } catch (e, stack) {
      logError('Last.fm migration from Hive box failed', e, stack);
    }
  }

  bool get isAuthenticated =>
      hasValidCredentials && _sessionKey != null && _sessionKey!.isNotEmpty;

  String? get username => _username;

  // Generate API signature for authenticated requests
  String _generateSignature(Map<String, String> params) {
    final sortedParams = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final signatureString =
        sortedParams.map((e) => '${e.key}${e.value}').join() + apiSecret;
    return md5.convert(utf8.encode(signatureString)).toString();
  }

  Future<bool> authenticate(String username, String password) async {
    if (!hasValidCredentials) return false;

    try {
      final authParams = {
        'method': 'auth.getMobileSession',
        'username': username,
        'password': password,
        'api_key': apiKey,
      };
      authParams['api_sig'] = _generateSignature(authParams);
      authParams['format'] = 'json';

      final client = _httpClient;
      final response = client != null
          ? await client.post(Uri.parse(_baseUrl), body: authParams)
          : await http.post(Uri.parse(_baseUrl), body: authParams);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('session')) {
          final session = data['session'];
          if (session is Map && session['key'] != null) {
            _sessionKey = session['key'].toString();
            _username = username;
            await _secureStorage.write(key: secureKeySession, value: _sessionKey!);
            await _secureStorage.write(key: secureKeyUsername, value: username);
            return true;
          }
        }
      }
      return false;
    } catch (e, stack) {
      // Redact: Never log credentials or passwords
      logError('Last.fm authentication error', e, stack);
      return false;
    }
  }

  Future<void> logout() async {
    _sessionKey = null;
    _username = null;
    try {
      await _secureStorage.delete(key: secureKeySession);
      await _secureStorage.delete(key: secureKeyUsername);
    } catch (e, stack) {
      logError('Last.fm logout error', e, stack);
    }
  }

  // Scrobble a track
  Future<bool> scrobble({
    required String track,
    required String artist,
    required String album,
    DateTime? timestamp,
  }) async {
    if (!isAuthenticated || _sessionKey == null) return false;

    try {
      final params = {
        'method': 'track.scrobble',
        'artist': artist,
        'track': track,
        'timestamp': ((timestamp ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000).toString(),
        'api_key': apiKey,
        'sk': _sessionKey!,
      };
      if (album.isNotEmpty) params['album'] = album;

      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final client = _httpClient;
      final response = client != null
          ? await client.post(Uri.parse(_baseUrl), body: params)
          : await http.post(Uri.parse(_baseUrl), body: params);

      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Scrobble error', e, stack);
      return false;
    }
  }

  // Update "Now Playing"
  Future<bool> updateNowPlaying({
    required String track,
    required String artist,
    required String album,
  }) async {
    if (!isAuthenticated || _sessionKey == null) return false;

    try {
      final params = {
        'method': 'track.updateNowPlaying',
        'artist': artist,
        'track': track,
        'api_key': apiKey,
        'sk': _sessionKey!,
      };
      if (album.isNotEmpty) params['album'] = album;

      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final client = _httpClient;
      final response = client != null
          ? await client.post(Uri.parse(_baseUrl), body: params)
          : await http.post(Uri.parse(_baseUrl), body: params);

      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Update now playing error', e, stack);
      return false;
    }
  }

  // Get user's top tracks
  Future<List<Map<String, dynamic>>> getTopTracks({
    int limit = 20,
    String period = '7day',
  }) async {
    if (!isAuthenticated || username == null) return [];

    try {
      final params = {
        'method': 'user.getTopTracks',
        'user': username!,
        'period': period,
        'limit': limit.toString(),
        'api_key': apiKey,
        'format': 'json',
      };

      final client = _httpClient;
      final response = client != null
          ? await client.get(Uri.parse(_baseUrl).replace(queryParameters: params))
          : await http.get(Uri.parse(_baseUrl).replace(queryParameters: params));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('toptracks') && data['toptracks'] is Map && data['toptracks'].containsKey('track')) {
          final tracks = data['toptracks']['track'] as List;
          return tracks.map((track) => {
            'name': track['name'],
            'artist': track['artist']['name'],
            'playcount': track['playcount'],
            'image': track['image']?.lastWhere(
              (img) => img['size'] == 'large',
              orElse: () => {'#text': ''},
            )['#text'],
          }).toList().cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e, stack) {
      logError('Get top tracks error', e, stack);
      return [];
    }
  }

  // Get user's recent tracks
  Future<List<Map<String, dynamic>>> getRecentTracks({int limit = 20}) async {
    if (!isAuthenticated || username == null) return [];

    try {
      final params = {
        'method': 'user.getRecentTracks',
        'user': username!,
        'limit': limit.toString(),
        'api_key': apiKey,
        'format': 'json',
      };

      final client = _httpClient;
      final response = client != null
          ? await client.get(Uri.parse(_baseUrl).replace(queryParameters: params))
          : await http.get(Uri.parse(_baseUrl).replace(queryParameters: params));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map && data.containsKey('recenttracks') && data['recenttracks'] is Map && data['recenttracks'].containsKey('track')) {
          final tracks = data['recenttracks']['track'] as List;
          return tracks.map((track) => {
            'name': track['name'],
            'artist': track['artist']['#text'] ?? track['artist']['name'],
            'album': track['album']['#text'] ?? '',
            'image': track['image']?.lastWhere(
              (img) => img['size'] == 'large',
              orElse: () => {'#text': ''},
            )['#text'],
          }).toList().cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e, stack) {
      logError('Get recent tracks error', e, stack);
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getRecommendedTracks({int limit = 20}) async {
    return getTopTracks(limit: limit, period: '1month');
  }

  Future<bool> loveTrack({
    required String track,
    required String artist,
  }) async {
    if (!isAuthenticated || _sessionKey == null) return false;

    try {
      final params = {
        'method': 'track.love',
        'artist': artist,
        'track': track,
        'api_key': apiKey,
        'sk': _sessionKey!,
      };

      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final client = _httpClient;
      final response = client != null
          ? await client.post(Uri.parse(_baseUrl), body: params)
          : await http.post(Uri.parse(_baseUrl), body: params);

      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Loved tracks error', e, stack);
      return false;
    }
  }

  Future<bool> unloveTrack({
    required String track,
    required String artist,
  }) async {
    if (!isAuthenticated || _sessionKey == null) return false;

    try {
      final params = {
        'method': 'track.unlove',
        'artist': artist,
        'track': track,
        'api_key': apiKey,
        'sk': _sessionKey!,
      };

      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';

      final client = _httpClient;
      final response = client != null
          ? await client.post(Uri.parse(_baseUrl), body: params)
          : await http.post(Uri.parse(_baseUrl), body: params);

      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Unlove track error', e, stack);
      return false;
    }
  }
}

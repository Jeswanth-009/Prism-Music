import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';

class LastFmService {
  static const String _apiKey = 'YOUR_LASTFM_API_KEY'; // Replace with your API key
  static const String _apiSecret = 'YOUR_LASTFM_API_SECRET'; // Replace with your API secret
  static const String _sessionBoxName = 'lastfm_session';
  static const String _baseUrl = 'https://ws.audioscrobbler.com/2.0/';
  
  Box? _sessionBox;
  String? _sessionKey;
  
  Future<void> initialize() async {
    try {
      // Check if box is already open
      if (Hive.isBoxOpen(_sessionBoxName)) {
        _sessionBox = Hive.box(_sessionBoxName);
      } else {
        _sessionBox = await Hive.openBox(_sessionBoxName);
      }
      _sessionKey = _sessionBox?.get('session_key');
    } catch (e, stack) {
      logError('Last.fm initialization error', e, stack);
      // Continue without Last.fm if initialization fails
    }
  }
  
  bool get isAuthenticated => _sessionKey != null;
  
  String? get username => _sessionBox?.get('username');
  
  // Generate API signature for authenticated requests
  String _generateSignature(Map<String, String> params) {
    final sortedParams = params.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final signatureString = sortedParams.map((e) => '${e.key}${e.value}').join() + _apiSecret;
    return md5.convert(utf8.encode(signatureString)).toString();
  }
  
  Future<bool> authenticate(String username, String password) async {
    try {
      // Get auth token
      final authParams = {
        'method': 'auth.getMobileSession',
        'username': username,
        'password': password,
        'api_key': _apiKey,
      };
      authParams['api_sig'] = _generateSignature(authParams);
      authParams['format'] = 'json';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: authParams,
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('session')) {
          _sessionKey = data['session']['key'];
          await _sessionBox?.put('session_key', _sessionKey);
          await _sessionBox?.put('username', username);
          return true;
        }
      }
      return false;
    } catch (e, stack) {
      logError('Last.fm authentication error', e, stack);
      return false;
    }
  }
  
  Future<void> logout() async {
    _sessionKey = null;
    await _sessionBox?.delete('session_key');
    await _sessionBox?.delete('username');
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
        'api_key': _apiKey,
        'sk': _sessionKey!,
      };
      if (album.isNotEmpty) params['album'] = album;
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: params,
      );
      
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
        'api_key': _apiKey,
        'sk': _sessionKey!,
      };
      if (album.isNotEmpty) params['album'] = album;
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: params,
      );
      
      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Update now playing error', e, stack);
      return false;
    }
  }
  
  // Get user's top tracks
  Future<List<Map<String, dynamic>>> getTopTracks({
    int limit = 20,
    String period = '7day', // overall | 7day | 1month | 3month | 6month | 12month
  }) async {
    if (!isAuthenticated || username == null) return [];
    
    try {
      final params = {
        'method': 'user.getTopTracks',
        'user': username!,
        'period': period,
        'limit': limit.toString(),
        'api_key': _apiKey,
        'format': 'json',
      };
      
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: params),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('toptracks') && data['toptracks'].containsKey('track')) {
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
        'api_key': _apiKey,
        'format': 'json',
      };
      
      final response = await http.get(
        Uri.parse(_baseUrl).replace(queryParameters: params),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.containsKey('recenttracks') && data['recenttracks'].containsKey('track')) {
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
  
  // Get personalized recommendations (using top tracks as proxy)
  Future<List<Map<String, dynamic>>> getRecommendedTracks({int limit = 20}) async {
    // Last.fm doesn't have a direct recommendations endpoint in the free API
    // So we'll use top tracks as personalized recommendations
    return getTopTracks(limit: limit, period: '1month');
  }
  
  // Love a track
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
        'api_key': _apiKey,
        'sk': _sessionKey!,
      };
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: params,
      );
      
      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Loved tracks error', e, stack);
      return false;
    }
  }
  
  // Unlove a track
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
        'api_key': _apiKey,
        'sk': _sessionKey!,
      };
      
      params['api_sig'] = _generateSignature(params);
      params['format'] = 'json';
      
      final response = await http.post(
        Uri.parse(_baseUrl),
        body: params,
      );
      
      return response.statusCode == 200;
    } catch (e, stack) {
      logError('Unlove track error', e, stack);
      return false;
    }
  }
}

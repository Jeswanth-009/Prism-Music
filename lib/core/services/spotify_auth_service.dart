import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Service managing Spotify Client Credentials OAuth authentication.
/// Provides temporary Bearer access tokens to query Spotify's Web API for
/// uncapped playlist metadata and accurate ISRC codes without user login.
class SpotifyAuthService {
  final Dio _dio;
  final SettingsService _settingsService;

  String? _cachedToken;
  DateTime? _tokenExpiry;

  SpotifyAuthService({Dio? dio, SettingsService? settingsService})
      : _dio = dio ?? Dio(),
        _settingsService = settingsService ?? SettingsService.instance;

  /// Whether Spotify developer credentials have been entered by the user.
  bool get isConfigured {
    final clientId = _settingsService.spotifyClientId?.trim();
    final clientSecret = _settingsService.spotifyClientSecret?.trim();
    return clientId != null &&
        clientId.isNotEmpty &&
        clientSecret != null &&
        clientSecret.isNotEmpty;
  }

  /// Invalidate cached token on 401 or settings change.
  void invalidateToken() {
    _cachedToken = null;
    _tokenExpiry = null;
  }

  /// Request or return a cached valid Spotify API Bearer token.
  /// Returns null if credentials are unconfigured or authentication fails.
  Future<String?> getValidAccessToken() async {
    final clientId = _settingsService.spotifyClientId?.trim();
    final clientSecret = _settingsService.spotifyClientSecret?.trim();

    if (clientId == null ||
        clientId.isEmpty ||
        clientSecret == null ||
        clientSecret.isEmpty) {
      return null;
    }

    // Reuse valid token if at least 5 minutes remain before expiry
    if (_cachedToken != null &&
        _tokenExpiry != null &&
        DateTime.now().isBefore(_tokenExpiry!)) {
      return _cachedToken;
    }

    return _fetchToken(clientId, clientSecret);
  }

  /// Test whether the provided or stored credentials authenticate successfully.
  Future<bool> testConnection({String? clientId, String? clientSecret}) async {
    final id = clientId?.trim() ?? _settingsService.spotifyClientId?.trim();
    final secret =
        clientSecret?.trim() ?? _settingsService.spotifyClientSecret?.trim();

    if (id == null || id.isEmpty || secret == null || secret.isEmpty) {
      return false;
    }

    final token = await _fetchToken(id, secret);
    return token != null;
  }

  Future<String?> _fetchToken(String clientId, String clientSecret) async {
    try {
      final credentials = base64Encode(utf8.encode('$clientId:$clientSecret'));
      final response = await _dio.post<Map<String, dynamic>>(
        'https://accounts.spotify.com/api/token',
        data: 'grant_type=client_credentials',
        options: Options(
          headers: {
            'Authorization': 'Basic $credentials',
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 500,
        ),
      );

      if (response.statusCode != 200) {
        if (kDebugMode) {
          debugPrint(
            'SpotifyAuthService: Token request failed with HTTP ${response.statusCode}: ${response.data}',
          );
        }
        return null;
      }

      final data = response.data;
      if (data == null) return null;

      final accessToken = data['access_token'] as String?;
      final expiresIn = (data['expires_in'] as num?)?.toInt() ?? 3600;

      if (accessToken == null || accessToken.isEmpty) return null;

      _cachedToken = accessToken;
      // Refresh 5 minutes before expiration to avoid mid-request 401s
      _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 300));
      return _cachedToken;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SpotifyAuthService: Token fetch error: $e');
      }
      return null;
    }
  }
}

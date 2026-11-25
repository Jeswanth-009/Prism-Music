import 'dart:convert';
import 'package:http/http.dart' as http;

/// Client persona context for InnerTube player requests.
enum InnerTubeClientContext {
  android(
    clientName: 'ANDROID',
    clientVersion: '20.10.38',
    userAgent:
        'com.google.android.youtube/20.10.38 (Linux; U; Android 14) gzip',
    isMobile: true,
    extraClientFields: {
      'androidSdkVersion': 34,
    },
  ),
  ios(
    clientName: 'IOS',
    clientVersion: '20.10.4',
    userAgent:
        'com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_2_1 like Mac OS X)',
    isMobile: true,
    extraClientFields: {
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
      'osName': 'iOS',
      'osVersion': '18.2.1.22C161',
    },
  ),
  webRemix(
    clientName: 'WEB_REMIX',
    clientVersion: '1.20240101.01.00',
    userAgent:
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
  ),
  visionOS(
    clientName: 'APPLE_VISION_PRO',
    clientVersion: '1.0.0',
    userAgent: 'Mozilla/5.0 (VisionOS; Mobile/21N307) AppleWebKit/605.1.15',
  ),
  tvSamsung(
    clientName: 'TV_SAMSUNG',
    clientVersion: '2.1.2',
    userAgent: 'Mozilla/5.0 (SMART-TV; Linux; Tizen 5.0) AppleWebKit/538.1',
  );

  final String clientName;
  final String clientVersion;
  final String userAgent;
  final bool isMobile;
  final Map<String, Object> extraClientFields;

  const InnerTubeClientContext({
    required this.clientName,
    required this.clientVersion,
    required this.userAgent,
    this.isMobile = false,
    this.extraClientFields = const {},
  });

  /// HTTP headers matching this InnerTube client for downstream media range requests.
  Map<String, String> get playbackHeaders => {'User-Agent': userAgent};
}

/// Extracted audio format from InnerTube response.
class InnerTubeAudioFormat {
  final int itag;
  final String url;
  final String mimeType;
  final int bitrate;
  final int? contentLength;
  final String? audioQuality;
  final int? sampleRate;
  final int? audioChannels;
  final String clientContextName;

  const InnerTubeAudioFormat({
    required this.itag,
    required this.url,
    required this.mimeType,
    required this.bitrate,
    this.contentLength,
    this.audioQuality,
    this.sampleRate,
    this.audioChannels,
    required this.clientContextName,
  });

  bool get isAudioOnly => mimeType.startsWith('audio/');
  int get bitrateKbps => (bitrate / 1000).round();
}

/// Pure clean-room InnerTube client that queries YouTube's player API across
/// multiple client contexts without external scraping binaries.
class InnerTubeClient {
  static const String _playerEndpoint =
      'https://www.youtube.com/youtubei/v1/player';

  final http.Client _httpClient;

  InnerTubeClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Requests playback stream formats for a video ID using specified [context].
  Future<List<InnerTubeAudioFormat>> fetchAudioFormats(
    String videoId, {
    InnerTubeClientContext context = InnerTubeClientContext.android,
  }) async {
    final payload = <String, dynamic>{
      'context': {
        'client': {
          'clientName': context.clientName,
          'clientVersion': context.clientVersion,
          'hl': 'en',
          'gl': 'US',
          ...context.extraClientFields,
        },
      },
      'videoId': videoId,
      'contentCheckOk': true,
      'racyCheckOk': true,
      if (!context.isMobile)
        'playbackContext': {
          'contentPlaybackContext': {
            'html5Preference': 'HTML5_PREF_WANTS',
            'signatureTimestamp': 19800,
          },
        },
    };

    final uri = Uri.parse(_playerEndpoint);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'User-Agent': context.userAgent,
      if (!context.isMobile) ...{
        'Origin': 'https://www.youtube.com',
        'Referer': 'https://www.youtube.com/',
      },
    };

    final response = await _httpClient
        .post(
          uri,
          headers: headers,
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) {
      throw Exception(
        'InnerTube request failed with status ${response.statusCode} for context ${context.clientName}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final streamingData = data['streamingData'] as Map<String, dynamic>?;
    if (streamingData == null) {
      final playability = data['playabilityStatus'] as Map<String, dynamic>?;
      final status = playability?['status']?.toString();
      final reason = playability?['reason']?.toString();
      throw Exception('InnerTube streamingData unavailable: $status ($reason)');
    }

    final adaptiveFormats =
        (streamingData['adaptiveFormats'] as List?)?.cast<Map<String, dynamic>>() ??
            [];

    final results = <InnerTubeAudioFormat>[];
    for (final fmt in adaptiveFormats) {
      final mime = fmt['mimeType']?.toString() ?? '';
      if (!mime.startsWith('audio/')) continue;

      final url = fmt['url']?.toString();
      if (url == null || url.isEmpty) {
        // Formats requiring JS signature deciphering are skipped in raw TV context
        // in favor of direct stream formats
        continue;
      }

      final itag = fmt['itag'] as int? ?? 0;
      final bitrate = fmt['bitrate'] as int? ?? 0;
      final contentLength = int.tryParse(fmt['contentLength']?.toString() ?? '');
      final audioQuality = fmt['audioQuality']?.toString();
      final sampleRate = int.tryParse(fmt['audioSampleRate']?.toString() ?? '');
      final channels = fmt['audioChannels'] as int?;

      results.add(
        InnerTubeAudioFormat(
          itag: itag,
          url: url,
          mimeType: mime,
          bitrate: bitrate,
          contentLength: contentLength,
          audioQuality: audioQuality,
          sampleRate: sampleRate,
          audioChannels: channels,
          clientContextName: context.clientName,
        ),
      );
    }

    // Sort by bitrate descending (highest quality first)
    results.sort((a, b) => b.bitrate.compareTo(a.bitrate));
    return results;
  }
}

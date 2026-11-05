import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import '../../domain/entities/song.dart';
import '../../domain/repositories/music_repository.dart';
import '../utils/logger.dart';

/// Represents a song submission by a party guest.
class PartyActivityEntry {
  final String guestName;
  final String songTitle;
  final String artist;
  final DateTime timestamp;

  const PartyActivityEntry({
    required this.guestName,
    required this.songTitle,
    required this.artist,
    required this.timestamp,
  });
}

/// Service that spins up an embedded local HTTP server, enabling anyone on the
/// same Wi-Fi / local network to search and queue tracks to Prism Music via a
/// responsive web interface or JSON API.
class CollaborativeQueueService {
  CollaborativeQueueService._();
  static final CollaborativeQueueService instance = CollaborativeQueueService._();

  HttpServer? _server;
  String? _localIp;
  int _port = 8088;
  String _pin = 'PR7K';
  MusicRepository? _musicRepository;
  void Function(Song song, String guestName)? _onSongQueued;
  Song? Function()? _nowPlayingProvider;
  List<Song> Function()? _queueProvider;

  final List<PartyActivityEntry> _activityLog = [];
  final StreamController<List<PartyActivityEntry>> _activityController =
      StreamController<List<PartyActivityEntry>>.broadcast();

  bool get isRunning => _server != null;
  String? get localIp => _localIp;
  int get port => _port;
  String get pin => _pin;
  String get serverUrl => _localIp != null ? 'http://$_localIp:$_port' : 'http://localhost:$_port';
  List<PartyActivityEntry> get activityLog => List.unmodifiable(_activityLog);
  Stream<List<PartyActivityEntry>> get activityStream => _activityController.stream;

  void configure({
    required MusicRepository musicRepository,
    required void Function(Song song, String guestName) onSongQueued,
    Song? Function()? nowPlayingProvider,
    List<Song> Function()? queueProvider,
  }) {
    _musicRepository = musicRepository;
    _onSongQueued = onSongQueued;
    _nowPlayingProvider = nowPlayingProvider;
    _queueProvider = queueProvider;
  }

  /// Starts the party mode server on the local network.
  Future<bool> startServer({int port = 8088}) async {
    if (isRunning) return true;

    try {
      _port = port;
      _pin = _generateRandomPin();
      _localIp = await _findLocalIpAddress();

      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        _port,
        shared: true,
      );

      logDebug('Party Mode server started at http://$_localIp:$_port (PIN: $_pin)');

      _server!.listen(
        _handleRequest,
        onError: (e) {
          logError('Party Mode server error: $e');
        },
      );
      return true;
    } catch (e) {
      logError('Failed to start CollaborativeQueueService: $e');
      await stopServer();
      return false;
    }
  }

  /// Stops the running party mode server.
  Future<void> stopServer() async {
    try {
      await _server?.close(force: true);
    } catch (_) {}
    _server = null;
    logDebug('Party Mode server stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // Add CORS headers for local web client
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.ok;
      await request.response.close();
      return;
    }

    final path = request.uri.path;

    try {
      if (path == '/' || path == '/index.html' || path == '/party') {
        _serveWebClient(request);
      } else if (path == '/api/session') {
        _serveSessionState(request);
      } else if (path == '/api/search') {
        await _handleSearch(request);
      } else if (path == '/api/queue/add' && request.method == 'POST') {
        await _handleQueueAdd(request);
      } else {
        request.response.statusCode = HttpStatus.notFound;
        request.response.write('Not Found');
        await request.response.close();
      }
    } catch (e) {
      logError('Error handling HTTP request $path: $e');
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write(jsonEncode({'error': e.toString()}));
        await request.response.close();
      } catch (_) {}
    }
  }

  void _serveSessionState(HttpRequest request) {
    final nowPlaying = _nowPlayingProvider?.call();
    final queue = _queueProvider?.call() ?? const <Song>[];

    final payload = {
      'status': 'ok',
      'pin': _pin,
      'nowPlaying': nowPlaying != null
          ? {
              'id': nowPlaying.id,
              'title': nowPlaying.title,
              'artist': nowPlaying.artist,
              'thumbnail': nowPlaying.thumbnailUrl,
            }
          : null,
      'queue': queue
          .take(20)
          .map((s) => {
                'id': s.id,
                'title': s.title,
                'artist': s.artist,
                'thumbnail': s.thumbnailUrl,
              })
          .toList(),
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    request.response.close();
  }

  Future<void> _handleSearch(HttpRequest request) async {
    final query = request.uri.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({'results': []}));
      await request.response.close();
      return;
    }

    if (_musicRepository == null) {
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.write(jsonEncode({'error': 'Music repository not configured'}));
      await request.response.close();
      return;
    }

    final searchResult = await _musicRepository!.searchSongs(query, limit: 10);
    final songs = searchResult.fold((_) => <Song>[], (list) => list);

    final payload = {
      'results': songs
          .map((s) => {
                'id': s.id,
                'title': s.title,
                'artist': s.artist,
                'album': s.album,
                'duration': s.duration.inSeconds,
                'thumbnail': s.thumbnailUrl,
                'youtubeId': s.youtubeId,
                'jioSaavnId': s.jioSaavnId,
              })
          .toList(),
    };

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode(payload));
    await request.response.close();
  }

  Future<void> _handleQueueAdd(HttpRequest request) async {
    final bodyStr = await utf8.decoder.bind(request).join();
    final dynamic body = jsonDecode(bodyStr);

    if (body is! Map) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'Invalid JSON body'}));
      await request.response.close();
      return;
    }

    final reqPin = body['pin']?.toString().trim().toUpperCase();
    if (reqPin != _pin) {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'error': 'Incorrect party PIN'}));
      await request.response.close();
      return;
    }

    final title = body['title']?.toString().trim() ?? '';
    final artist = body['artist']?.toString().trim() ?? 'Unknown Artist';
    final id = body['id']?.toString() ?? 'guest_${DateTime.now().millisecondsSinceEpoch}';
    final guestName = body['guestName']?.toString().trim().isNotEmpty == true
        ? body['guestName'].toString().trim()
        : 'Guest';
    final thumbnail = body['thumbnail']?.toString() ?? '';
    final durationSeconds = int.tryParse(body['duration']?.toString() ?? '180') ?? 180;

    if (title.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(jsonEncode({'error': 'Track title cannot be empty'}));
      await request.response.close();
      return;
    }

    final song = Song(
      id: id,
      title: title,
      artist: artist,
      album: body['album']?.toString(),
      duration: Duration(seconds: durationSeconds),
      thumbnails: Thumbnails(medium: thumbnail),
      source: MusicSource.youtube,
      youtubeId: body['youtubeId']?.toString() ?? id,
      recommendationReason: 'Added by $guestName in Party Mode',
    );

    // Record activity entry
    final entry = PartyActivityEntry(
      guestName: guestName,
      songTitle: title,
      artist: artist,
      timestamp: DateTime.now(),
    );
    _activityLog.insert(0, entry);
    if (_activityLog.length > 50) _activityLog.removeLast();
    _activityController.add(List.unmodifiable(_activityLog));

    _onSongQueued?.call(song, guestName);

    request.response.headers.contentType = ContentType.json;
    request.response.write(jsonEncode({'status': 'ok', 'queued': song.title}));
    await request.response.close();
  }

  void _serveWebClient(HttpRequest request) {
    request.response.headers.contentType = ContentType.html;
    request.response.write(_embeddedPartyWebHtml);
    request.response.close();
  }

  Future<String> _findLocalIpAddress() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          if (!addr.isLoopback && addr.address.startsWith('192.168.') ||
              addr.address.startsWith('10.') ||
              addr.address.startsWith('172.')) {
            return addr.address;
          }
        }
      }
      if (interfaces.isNotEmpty && interfaces.first.addresses.isNotEmpty) {
        return interfaces.first.addresses.first.address;
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  String _generateRandomPin() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(4, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  static const String _embeddedPartyWebHtml = '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0">
  <title>Prism Party Mode</title>
  <style>
    :root {
      --bg: #0f1015;
      --card: #181920;
      --card-alt: #22242e;
      --primary: #9d7bff;
      --primary-hover: #b499ff;
      --text: #ffffff;
      --subtext: #8e919e;
      --border: #2e303c;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background-color: var(--bg); color: var(--text); padding: 18px; max-width: 520px; margin: 0 auto; min-height: 100vh; }
    h1 { font-size: 24px; font-weight: 800; color: var(--primary); display: flex; align-items: center; gap: 8px; margin-bottom: 4px; }
    .subtitle { color: var(--subtext); font-size: 13px; margin-bottom: 20px; }
    .card { background: var(--card); border: 1px solid var(--border); border-radius: 14px; padding: 14px; margin-bottom: 16px; }
    .now-playing { display: flex; align-items: center; gap: 12px; }
    .art { width: 48px; height: 48px; border-radius: 8px; background: #282a36; object-fit: cover; }
    .np-info { overflow: hidden; flex: 1; }
    .np-title { font-weight: 700; font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
    .np-artist { font-size: 12px; color: var(--subtext); margin-top: 2px; }
    .badge { font-size: 10px; text-transform: uppercase; letter-spacing: 0.8px; font-weight: 700; color: var(--primary); margin-bottom: 4px; }
    input, button { width: 100%; border-radius: 10px; border: 1px solid var(--border); background: var(--card-alt); color: #fff; font-size: 14px; padding: 12px 14px; outline: none; margin-bottom: 8px; }
    input:focus { border-color: var(--primary); }
    button { background: var(--primary); font-weight: 700; cursor: pointer; border: none; transition: background 0.15s; }
    button:hover { background: var(--primary-hover); }
    .search-row { display: flex; gap: 8px; }
    .search-row input { flex: 1; }
    .search-row button { width: auto; padding: 0 16px; }
    .result-item { display: flex; align-items: center; gap: 10px; padding: 10px; border-bottom: 1px solid var(--border); cursor: pointer; border-radius: 8px; }
    .result-item:hover { background: var(--card-alt); }
    .result-item:last-child { border-bottom: none; }
    .add-btn { width: auto; padding: 6px 12px; font-size: 12px; background: transparent; border: 1px solid var(--primary); color: var(--primary); margin: 0; }
    .add-btn:hover { background: var(--primary); color: #fff; }
    .toast { position: fixed; bottom: 20px; left: 50%; transform: translateX(-50%); background: #22c55e; color: #fff; font-weight: 600; padding: 10px 18px; border-radius: 20px; font-size: 13px; display: none; }
  </style>
</head>
<body>
  <h1>🎉 Prism Party</h1>
  <div class="subtitle">Search and add tracks to the live host queue</div>

  <div class="card">
    <div class="badge">NOW PLAYING</div>
    <div class="now-playing">
      <img id="np-art" class="art" src="" style="display:none;" />
      <div class="np-info">
        <div id="np-title" class="np-title">No track playing</div>
        <div id="np-artist" class="np-artist">Connected to host</div>
      </div>
    </div>
  </div>

  <div class="card">
    <div style="display: flex; gap: 8px; margin-bottom: 8px;">
      <input id="guest-name" type="text" placeholder="Your Name (e.g. Alex)" style="margin-bottom:0;" />
      <input id="guest-pin" type="text" placeholder="PIN" style="width: 80px; text-transform: uppercase; margin-bottom:0;" />
    </div>
    <div class="search-row">
      <input id="search-input" type="text" placeholder="Search songs or artists..." onkeydown="if(event.key==='Enter') searchMusic()" />
      <button onclick="searchMusic()">Search</button>
    </div>
  </div>

  <div id="results-card" class="card" style="display:none;">
    <div class="badge">SEARCH RESULTS</div>
    <div id="results-list"></div>
  </div>

  <div id="toast" class="toast">Added to queue!</div>

  <script>
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('pin')) {
      document.getElementById('guest-pin').value = urlParams.get('pin');
    }

    async function loadSession() {
      try {
        const res = await fetch('/api/session');
        const data = await res.json();
        if (data.nowPlaying) {
          document.getElementById('np-title').innerText = data.nowPlaying.title;
          document.getElementById('np-artist').innerText = data.nowPlaying.artist;
          if (data.nowPlaying.thumbnail) {
            const art = document.getElementById('np-art');
            art.src = data.nowPlaying.thumbnail;
            art.style.display = 'block';
          }
        }
        if (!document.getElementById('guest-pin').value && data.pin) {
          document.getElementById('guest-pin').value = data.pin;
        }
      } catch (e) {}
    }

    async function searchMusic() {
      const q = document.getElementById('search-input').value.trim();
      if (!q) return;
      const res = await fetch('/api/search?q=' + encodeURIComponent(q));
      const data = await res.json();
      const list = document.getElementById('results-list');
      list.innerHTML = '';
      if (!data.results || data.results.length === 0) {
        list.innerHTML = '<div style="color:var(--subtext);font-size:13px;padding:8px;">No songs found</div>';
      } else {
        data.results.forEach(s => {
          const item = document.createElement('div');
          item.className = 'result-item';
          item.innerHTML = `
            <div style="flex:1;overflow:hidden;">
              <div style="font-weight:600;font-size:14px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;">\${s.title}</div>
              <div style="font-size:12px;color:var(--subtext);">\${s.artist}</div>
            </div>
            <button class="add-btn">+ Queue</button>
          `;
          item.querySelector('.add-btn').onclick = () => addToQueue(s);
          list.appendChild(item);
        });
      }
      document.getElementById('results-card').style.display = 'block';
    }

    async function addToQueue(song) {
      const pin = document.getElementById('guest-pin').value.trim();
      const guestName = document.getElementById('guest-name').value.trim() || 'Guest';
      try {
        const res = await fetch('/api/queue/add', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            pin: pin,
            guestName: guestName,
            id: song.id,
            title: song.title,
            artist: song.artist,
            album: song.album,
            thumbnail: song.thumbnail,
            duration: song.duration,
            youtubeId: song.youtubeId
          })
        });
        const resp = await res.json();
        if (res.ok) {
          showToast('Added "' + song.title + '" to queue!');
        } else {
          alert(resp.error || 'Failed to add song');
        }
      } catch (e) {
        alert('Connection error');
      }
    }

    function showToast(msg) {
      const t = document.getElementById('toast');
      t.innerText = msg;
      t.style.display = 'block';
      setTimeout(() => { t.style.display = 'none'; }, 2500);
    }

    loadSession();
    setInterval(loadSession, 5000);
  </script>
</body>
</html>
''';
}

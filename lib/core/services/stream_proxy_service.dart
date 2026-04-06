import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

/// Local HTTP proxy server that forwards YouTube stream requests with proper headers
/// This bypasses the IP-lock issue by proxying through localhost
class StreamProxyService {
  static HttpServer? _server;
  static int? _port;
  static final Dio _dio = Dio();
  
  static bool get isRunning => _server != null;
  static String? get serverUrl => _port != null ? 'http://10.0.2.2:$_port' : null;
  
  /// Start the local proxy server
  static Future<void> start() async {
    if (_server != null) return;
    
    try {
      // Bind to 0.0.0.0 to allow access from Android emulator (10.0.2.2)
      _server = await HttpServer.bind('0.0.0.0', 0); // 0 = random available port
      _port = _server!.port;
      debugPrint('StreamProxyService: Started on port $_port (accessible from emulator at 10.0.2.2:$_port)');
      
      _server!.listen((HttpRequest request) async {
        await _handleRequest(request);
      });
    } catch (e) {
      debugPrint('StreamProxyService: Failed to start - $e');
    }
  }
  
  /// Handle incoming proxy requests
  static Future<void> _handleRequest(HttpRequest request) async {
    try {
      // Get the target URL from query parameter
      final targetUrl = request.uri.queryParameters['url'];
      
      if (targetUrl == null) {
        request.response.statusCode = HttpStatus.badRequest;
        request.response.write('Missing url parameter');
        await request.response.close();
        return;
      }
      
      debugPrint('StreamProxyService: Proxying request to $targetUrl');
      
      // Forward the request with proper headers
      final response = await _dio.get(
        targetUrl,
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            'Accept': '*/*',
            'Accept-Encoding': 'identity;q=1, *;q=0',
            'Accept-Language': 'en-US,en;q=0.9',
            'Connection': 'keep-alive',
            'Origin': 'https://www.youtube.com',
            'Referer': 'https://www.youtube.com/',
            'Range': request.headers.value('range') ?? 'bytes=0-',
          },
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      
      // Copy response headers
      request.response.statusCode = response.statusCode ?? 200;
      response.headers.forEach((name, values) {
        if (name.toLowerCase() != 'transfer-encoding') {
          request.response.headers.add(name, values);
        }
      });
      
      // Enable CORS
      request.response.headers.add('Access-Control-Allow-Origin', '*');
      request.response.headers.add('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
      request.response.headers.add('Access-Control-Allow-Headers', 'Range');
      
      // Stream the response
      final stream = response.data.stream;
      await request.response.addStream(stream);
      await request.response.close();
      
    } catch (e) {
      debugPrint('StreamProxyService: Error handling request - $e');
      request.response.statusCode = HttpStatus.internalServerError;
      request.response.write('Proxy error: $e');
      await request.response.close();
    }
  }
  
  /// Convert a direct YouTube URL to a proxied URL
  static String proxyUrl(String directUrl) {
    if (_port == null) {
      debugPrint('StreamProxyService: Proxy not started, returning direct URL');
      return directUrl;
    }
    
    final encodedUrl = Uri.encodeComponent(directUrl);
    // Use 10.0.2.2 for Android emulator (maps to host localhost)
    final proxied = 'http://10.0.2.2:$_port?url=$encodedUrl';
    debugPrint('StreamProxyService: Proxied URL: $proxied');
    return proxied;
  }
  
  /// Stop the proxy server
  static Future<void> stop() async {
    if (_server != null) {
      await _server!.close();
      _server = null;
      _port = null;
      debugPrint('StreamProxyService: Stopped');
    }
  }
}

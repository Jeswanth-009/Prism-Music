import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/logger.dart';

/// Service that coordinates real-time state with native home-screen widgets.
class WidgetService {
  WidgetService._();

  static final WidgetService instance = WidgetService._();

  static const MethodChannel _channel = MethodChannel('com.prismmusic/widget');

  /// Pushes track metadata and playing state to the native home screen widget.
  Future<void> updateWidget({
    required String title,
    required String artist,
    required bool isPlaying,
    String? artworkPath,
    Uint8List? artworkBytes,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      final Map<String, dynamic> payload = {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
      };
      if (artworkPath != null) {
        payload['artworkPath'] = artworkPath;
      }
      if (artworkBytes != null) {
        payload['artworkBytes'] = artworkBytes;
      }
      await _channel.invokeMethod('updateWidget', payload);
    } catch (e) {
      logDebug('WidgetService: updateWidget failed or not supported: $e');
    }
  }
}

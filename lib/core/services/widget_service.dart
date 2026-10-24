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
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateWidget', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
      });
    } catch (e) {
      logDebug('WidgetService: updateWidget failed or not supported: $e');
    }
  }
}

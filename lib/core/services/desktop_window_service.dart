import 'package:flutter/services.dart';
import '../../domain/entities/song.dart';
import 'desktop_audio_support.dart';

/// Service responsible for updating desktop application window metadata,
/// such as the window title bar matching the currently playing song.
class DesktopWindowService {
  DesktopWindowService._();

  static final DesktopWindowService instance = DesktopWindowService._();

  String _currentTitle = 'Prism Music';

  String get currentTitle => _currentTitle;

  /// Formats the title string for the desktop window
  String formatTitle({Song? song, bool isPlaying = false}) {
    if (song == null || !isPlaying) {
      return 'Prism Music';
    }
    final artist = song.artist.isNotEmpty ? ' • ${song.artist}' : '';
    return 'Prism Music - ${song.title}$artist';
  }

  /// Updates the native desktop window title bar
  Future<void> updateWindowTitle({Song? song, bool isPlaying = false}) async {
    final title = formatTitle(song: song, isPlaying: isPlaying);
    if (title == _currentTitle) return;
    _currentTitle = title;

    if (DesktopAudioSupport.instance.isDesktop) {
      try {
        await SystemChrome.setApplicationSwitcherDescription(
          ApplicationSwitcherDescription(
            label: _currentTitle,
            primaryColor: 0xFF8B7BFF,
          ),
        );
      } catch (_) {
        // Ignored if platform doesn't support switcher description
      }
    }
  }
}

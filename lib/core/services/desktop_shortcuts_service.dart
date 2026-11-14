import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../domain/repositories/library_repository.dart';
import 'audio_player_service.dart';
import 'desktop_audio_support.dart';
import 'media_session_coordinator.dart';

/// Keyboard media shortcut controller for desktop platforms (Windows, Linux, macOS).
class DesktopShortcutsService {
  final AudioPlayerService playerService;
  final LibraryRepository? libraryRepository;
  double _lastUnmutedVolume = 1.0;

  DesktopShortcutsService({
    required this.playerService,
    this.libraryRepository,
  });

  /// Handles desktop key events. Returns true if the key event was consumed.
  bool handleKeyEvent(KeyEvent event, {bool isTextFieldFocused = false}) {
    // Never intercept media keys when typing in an input field
    if (isTextFieldFocused) return false;
    if (event is! KeyDownEvent) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space) {
      if (playerService.playing) {
        playerService.pause();
      } else {
        playerService.play();
      }
      return true;
    }

    if (key == LogicalKeyboardKey.arrowRight) {
      final newPos = playerService.position + const Duration(seconds: 10);
      playerService.seek(newPos);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowLeft) {
      final newPos = playerService.position - const Duration(seconds: 10);
      playerService.seek(newPos < Duration.zero ? Duration.zero : newPos);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowUp) {
      final newVol = DesktopAudioSupport.instance.stepVolume(
        playerService.volume,
        true,
      );
      playerService.setVolume(newVol);
      return true;
    }

    if (key == LogicalKeyboardKey.arrowDown) {
      final newVol = DesktopAudioSupport.instance.stepVolume(
        playerService.volume,
        false,
      );
      playerService.setVolume(newVol);
      return true;
    }

    if (key == LogicalKeyboardKey.keyM) {
      if (playerService.volume > 0.0) {
        _lastUnmutedVolume = playerService.volume;
        playerService.setVolume(0.0);
      } else {
        playerService.setVolume(_lastUnmutedVolume > 0.0 ? _lastUnmutedVolume : 1.0);
      }
      return true;
    }

    if (key == LogicalKeyboardKey.keyJ) {
      MediaSessionCoordinator.instance.skipPrevious();
      return true;
    }

    if (key == LogicalKeyboardKey.keyK) {
      MediaSessionCoordinator.instance.skipNext();
      return true;
    }

    return false;
  }
}

/// Widget wrapper that binds desktop media keyboard shortcuts globally.
class DesktopShortcutsWrapper extends StatelessWidget {
  final Widget child;
  final DesktopShortcutsService service;

  const DesktopShortcutsWrapper({
    super.key,
    required this.child,
    required this.service,
  });

  @override
  Widget build(BuildContext context) {
    if (!DesktopAudioSupport.instance.isDesktop) {
      return child;
    }

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
        final isTextField = focusedWidget is EditableText;
        final handled = service.handleKeyEvent(event, isTextFieldFocused: isTextField);
        return handled ? KeyEventResult.handled : KeyEventResult.ignored;
      },
      child: child,
    );
  }
}

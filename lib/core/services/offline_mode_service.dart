import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'settings_service.dart';

/// Service managing offline mode detection, user toggles, and reactive
/// transitions between online streaming and local offline library playback.
class OfflineModeService {
  static OfflineModeService? _instance;
  final Connectivity _connectivity;
  final SettingsService _settingsService;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  final ValueNotifier<bool> _isOfflineNotifier = ValueNotifier<bool>(false);
  final StreamController<void> _offlineTransitionController =
      StreamController<void>.broadcast();

  bool _isManualOffline = false;

  OfflineModeService({
    Connectivity? connectivity,
    SettingsService? settingsService,
  })  : _connectivity = connectivity ?? Connectivity(),
        _settingsService = settingsService ?? SettingsService.instance;

  static OfflineModeService get instance =>
      _instance ??= OfflineModeService();

  @visibleForTesting
  static void setInstance(OfflineModeService instance) {
    _instance = instance;
  }

  /// Current offline status (true if device has no connection or user forced offline mode).
  bool get isOffline => _isOfflineNotifier.value;

  /// ValueNotifier for listening to offline state changes in UI.
  ValueListenable<bool> get isOfflineNotifier => _isOfflineNotifier;

  /// Stream triggered once whenever the app transitions into offline mode
  /// (used to auto-switch tabs to the local library).
  Stream<void> get onSwitchedToOffline => _offlineTransitionController.stream;

  /// User-configured manual offline mode.
  bool get isManualOffline => _isManualOffline;

  /// Initialize connectivity listeners and check initial state.
  Future<void> initialize() async {
    _isManualOffline = _settingsService.forceOfflineMode;

    try {
      final initialResults = await _connectivity.checkConnectivity();
      _updateState(initialResults, notifyTransition: false);
    } catch (_) {
      // Fallback: assume online unless manual offline mode is enabled
      _isOfflineNotifier.value = _isManualOffline;
    }

    _connectivitySubscription?.cancel();
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      _updateState(results, notifyTransition: true);
    });
  }

  /// Manually force offline mode on or off.
  Future<void> setForceOffline(bool forced) async {
    _isManualOffline = forced;
    await _settingsService.setForceOfflineMode(forced);

    final wasOffline = _isOfflineNotifier.value;
    final nowOffline = _isManualOffline || (await _isNetworkDisconnected());

    if (_isOfflineNotifier.value != nowOffline) {
      _isOfflineNotifier.value = nowOffline;
      if (!wasOffline && nowOffline) {
        _offlineTransitionController.add(null);
      }
    }
  }

  Future<bool> _isNetworkDisconnected() async {
    try {
      final results = await _connectivity.checkConnectivity();
      return _areResultsOffline(results);
    } catch (_) {
      return false;
    }
  }

  bool _areResultsOffline(List<ConnectivityResult> results) {
    if (results.isEmpty) return true;
    return results.length == 1 && results.first == ConnectivityResult.none;
  }

  void _updateState(List<ConnectivityResult> results,
      {required bool notifyTransition}) {
    final wasOffline = _isOfflineNotifier.value;
    final networkOffline = _areResultsOffline(results);
    final nowOffline = _isManualOffline || networkOffline;

    _isOfflineNotifier.value = nowOffline;

    if (notifyTransition && !wasOffline && nowOffline) {
      _offlineTransitionController.add(null);
    }
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _offlineTransitionController.close();
    _isOfflineNotifier.dispose();
  }
}

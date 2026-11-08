import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/entities/user_profile.dart';

/// Service managing local user profiles on multi-user or shared devices.
class UserProfileService {
  static final UserProfileService instance = UserProfileService._();
  UserProfileService._();
  factory UserProfileService() => instance;

  static const String _boxName = 'user_profiles_box';
  static const String _activeIdKey = '__active_profile_id__';

  static final UserProfile defaultProfile = UserProfile(
    id: 'default',
    name: 'Primary',
    avatarEmoji: '🎧',
    avatarColorValue: 0xFF8B7BFF,
    createdAt: DateTime(2026, 1, 1),
  );

  Box? _box;
  final _profileController = StreamController<UserProfile>.broadcast();
  UserProfile? _activeProfile;
  bool _initialized = false;

  Stream<UserProfile> get activeProfileStream => _profileController.stream;

  Future<void> initialize() async {
    if (_initialized && _box != null && _box!.isOpen) return;

    try {
      _box = await Hive.openBox(_boxName);
      if (_box!.isEmpty || !_box!.containsKey(defaultProfile.id)) {
        await _box!.put(defaultProfile.id, defaultProfile.toMap());
      }

      final activeId = _box!.get(_activeIdKey) as String? ?? defaultProfile.id;
      final raw = _box!.get(activeId);
      if (raw != null && raw is Map) {
        _activeProfile = UserProfile.fromMap(raw);
      } else {
        _activeProfile = defaultProfile;
      }
      _initialized = true;
    } catch (e) {
      debugPrint('UserProfileService: Initialization warning: $e');
      _activeProfile = defaultProfile;
      _initialized = true;
    }
  }

  /// Get currently active profile
  UserProfile getActiveProfile() {
    return _activeProfile ?? defaultProfile;
  }

  /// Get all registered profiles
  List<UserProfile> getAllProfiles() {
    if (_box == null || !_box!.isOpen) return [defaultProfile];

    final profiles = <UserProfile>[];
    for (final key in _box!.keys) {
      if (key == _activeIdKey) continue;
      final val = _box!.get(key);
      if (val is Map) {
        profiles.add(UserProfile.fromMap(val));
      }
    }

    if (profiles.isEmpty) {
      profiles.add(defaultProfile);
    }
    return profiles;
  }

  /// Create a new local profile
  Future<UserProfile> createProfile({
    required String name,
    String avatarEmoji = '🎵',
    int avatarColorValue = 0xFF8B7BFF,
    bool isKidsMode = false,
  }) async {
    await initialize();
    final id = 'profile_${DateTime.now().millisecondsSinceEpoch}';
    final profile = UserProfile(
      id: id,
      name: name.trim().isEmpty ? 'User' : name.trim(),
      avatarEmoji: avatarEmoji,
      avatarColorValue: avatarColorValue,
      isKidsMode: isKidsMode,
      createdAt: DateTime.now(),
    );

    await _box?.put(id, profile.toMap());
    return profile;
  }

  /// Switch active profile
  Future<void> switchProfile(String profileId) async {
    await initialize();
    final raw = _box?.get(profileId);
    if (raw != null && raw is Map) {
      final updated = UserProfile.fromMap(raw).copyWith(
        lastActiveAt: DateTime.now(),
      );
      await _box?.put(profileId, updated.toMap());
      await _box?.put(_activeIdKey, profileId);
      _activeProfile = updated;
      _profileController.add(updated);
    }
  }

  /// Update an existing profile
  Future<void> updateProfile(UserProfile profile) async {
    await initialize();
    await _box?.put(profile.id, profile.toMap());
    if (_activeProfile?.id == profile.id) {
      _activeProfile = profile;
      _profileController.add(profile);
    }
  }

  /// Delete a profile (cannot delete if it's the only one left)
  Future<bool> deleteProfile(String profileId) async {
    await initialize();
    final all = getAllProfiles();
    if (all.length <= 1) return false;

    await _box?.delete(profileId);

    if (_activeProfile?.id == profileId) {
      final fallback = all.firstWhere((p) => p.id != profileId, orElse: () => defaultProfile);
      await switchProfile(fallback.id);
    }

    return true;
  }

  @visibleForTesting
  void resetForTest() {
    _activeProfile = defaultProfile;
    _initialized = false;
  }

  void dispose() {
    _profileController.close();
  }
}

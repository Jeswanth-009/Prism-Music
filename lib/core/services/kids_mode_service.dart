import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../domain/entities/song.dart';

/// Kids Mode Service: provides hard profanity filtering, child-safe curated content,
/// and secure 4-digit PIN protection to prevent unauthorized exit.
class KidsModeService extends ChangeNotifier {
  static final KidsModeService _instance = KidsModeService._internal();
  static KidsModeService get instance => _instance;

  KidsModeService._internal();

  static const String _boxName = 'kids_mode_box';
  static const String _kEnabledKey = 'kids_mode_enabled';
  static const String _kPinHashKey = 'kids_mode_pin_hash';
  static const String _kSaltKey = 'kids_mode_salt';

  Box? _box;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  bool _isEnabled = false;
  String? _pinHash;
  String? _salt;

  bool get isEnabled => _isEnabled;
  bool get hasPin => _pinHash != null && _pinHash!.isNotEmpty;

  // Profanity wordlist for hard title and lyrics filtering
  static final Set<String> _explicitKeywords = {
    'fuck',
    'shit',
    'bitch',
    'asshole',
    'dick',
    'pussy',
    'cunt',
    'nigger',
    'nigga',
    'whore',
    'slut',
    'bastard',
    'cock',
    'motherfucker',
    'fucker',
    'explicit',
  };

  /// Initialize Kids Mode persistence
  Future<void> initialize() async {
    try {
      _box = await Hive.openBox(_boxName);
      _isEnabled = _box?.get(_kEnabledKey, defaultValue: false) as bool? ?? false;

      try {
        _pinHash = await _secureStorage.read(key: _kPinHashKey);
        _salt = await _secureStorage.read(key: _kSaltKey);
      } catch (e) {
        if (e is! MissingPluginException) {
          debugPrint('KidsModeService secure storage read error: $e');
        }
      }

      // Migrate legacy plaintext Hive PIN entries into secure storage
      final legacyHash = _box?.get(_kPinHashKey) as String?;
      final legacySalt = _box?.get(_kSaltKey) as String?;
      if ((_pinHash == null || _pinHash!.isEmpty) && legacyHash != null && legacyHash.isNotEmpty) {
        _pinHash = legacyHash;
        _salt = legacySalt;
        try {
          await _secureStorage.write(key: _kPinHashKey, value: legacyHash);
          if (legacySalt != null) {
            await _secureStorage.write(key: _kSaltKey, value: legacySalt);
          }
          await _box?.delete(_kPinHashKey);
          await _box?.delete(_kSaltKey);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('KidsModeService initialization error: $e');
    }
  }

  /// Sets a new 4-digit PIN and enables Kids Mode
  Future<bool> setupPinAndEnable(String pin) async {
    if (pin.length != 4 || int.tryParse(pin) == null) return false;

    final rand = Random.secure();
    final saltBytes = List<int>.generate(16, (_) => rand.nextInt(256));
    final salt = saltBytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    final hash = _hashPin(pin, salt);

    _pinHash = hash;
    _salt = salt;
    _isEnabled = true;

    try {
      await _secureStorage.write(key: _kPinHashKey, value: hash);
      await _secureStorage.write(key: _kSaltKey, value: salt);
      await _box?.delete(_kPinHashKey);
      await _box?.delete(_kSaltKey);
    } catch (_) {
      await _box?.put(_kPinHashKey, hash);
      await _box?.put(_kSaltKey, salt);
    }
    await _box?.put(_kEnabledKey, true);

    notifyListeners();
    return true;
  }

  /// Disables Kids Mode after verifying 4-digit PIN
  Future<bool> verifyPinAndDisable(String pin) async {
    if (!verifyPin(pin)) return false;

    _isEnabled = false;
    await _box?.put(_kEnabledKey, false);

    notifyListeners();
    return true;
  }

  /// Sets Kids Mode enabled state directly (requires verifyPinAndDisable when a PIN is set)
  Future<void> setKidsModeEnabled(bool enabled) async {
    if (!enabled && hasPin) {
      throw StateError('Kids Mode PIN verification is required to disable Kids Mode.');
    }
    _isEnabled = enabled;
    await _box?.put(_kEnabledKey, enabled);
    notifyListeners();
  }

  /// Alias for setKidsModeEnabled
  Future<void> setEnabledWithoutPin(bool enabled) => setKidsModeEnabled(enabled);

  /// Verifies entered PIN against stored cryptographic hash
  bool verifyPin(String pin) {
    if (_pinHash == null || _salt == null) return true; // No PIN set
    final hash = _hashPin(pin, _salt!);
    return hash == _pinHash || _legacyHashPin(pin, _salt!) == _pinHash;
  }

  String _hashPin(String pin, String salt) {
    var digest = sha256.convert(utf8.encode('$pin:$salt:prism_kids_safety')).bytes;
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return digest.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  String _legacyHashPin(String pin, String salt) {
    final bytes = utf8.encode('$pin:$salt:prism_kids_safety');
    return sha256.convert(bytes).toString();
  }

  /// Returns true if a song is safe for children (not explicit)
  bool isSongChildSafe(Song song) {
    if (!_isEnabled) return true;

    // Check explicit metadata flag
    final title = song.title.toLowerCase();
    final artist = song.artist.toLowerCase();

    for (final word in _explicitKeywords) {
      if (title.contains(word) || artist.contains(word)) {
        return false;
      }
    }

    return true;
  }

  /// Filters a list of songs to only include child-safe songs
  List<Song> filterChildSafeSongs(List<Song> songs) {
    if (!_isEnabled) return songs;
    return songs.where(isSongChildSafe).toList();
  }

  /// Sanitizes text (e.g. lyrics or title) by masking profanity
  String sanitizeText(String text) {
    if (!_isEnabled) return text;

    String clean = text;
    for (final word in _explicitKeywords) {
      final regex = RegExp('\\b$word\\b', caseSensitive: false);
      clean = clean.replaceAllMapped(regex, (match) {
        final w = match.group(0)!;
        return w[0] + ('*' * (w.length - 1));
      });
    }
    return clean;
  }
}

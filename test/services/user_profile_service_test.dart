import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/services/user_profile_service.dart';
import 'package:prism_music/domain/entities/user_profile.dart';

void main() {
  group('UserProfileService & UserProfile', () {
    test('UserProfile serialization toMap and fromMap preserves fields', () {
      final profile = UserProfile(
        id: 'test_123',
        name: 'Family Kid',
        avatarEmoji: '🦄',
        avatarColorValue: 0xFFFF416C,
        isKidsMode: true,
        createdAt: DateTime(2026, 5, 1),
      );

      final map = profile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.id, equals(profile.id));
      expect(restored.name, equals(profile.name));
      expect(restored.avatarEmoji, equals('🦄'));
      expect(restored.avatarColorValue, equals(0xFFFF416C));
      expect(restored.isKidsMode, isTrue);
    });

    test('defaultProfile is properly configured with primary settings', () {
      final def = UserProfileService.defaultProfile;
      expect(def.id, equals('default'));
      expect(def.name, equals('Primary'));
      expect(def.avatarEmoji, isNotEmpty);
      expect(def.isKidsMode, isFalse);
    });

    test('getActiveProfile returns fallback when uninitialized', () {
      final service = UserProfileService();
      final active = service.getActiveProfile();
      expect(active, isNotNull);
      expect(active.id, equals('default'));
    });
  });
}

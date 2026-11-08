import 'package:equatable/equatable.dart';

/// Represents a local user profile for multi-user / shared devices (e.g. family tablet).
class UserProfile extends Equatable {
  final String id;
  final String name;
  final String avatarEmoji;
  final int avatarColorValue;
  final bool isKidsMode;
  final DateTime createdAt;
  final DateTime? lastActiveAt;

  const UserProfile({
    required this.id,
    required this.name,
    this.avatarEmoji = '🎧',
    this.avatarColorValue = 0xFF8B7BFF,
    this.isKidsMode = false,
    required this.createdAt,
    this.lastActiveAt,
  });

  UserProfile copyWith({
    String? id,
    String? name,
    String? avatarEmoji,
    int? avatarColorValue,
    bool? isKidsMode,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarEmoji: avatarEmoji ?? this.avatarEmoji,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
      isKidsMode: isKidsMode ?? this.isKidsMode,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'avatarEmoji': avatarEmoji,
      'avatarColorValue': avatarColorValue,
      'isKidsMode': isKidsMode,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt?.toIso8601String(),
    };
  }

  factory UserProfile.fromMap(Map<dynamic, dynamic> map) {
    return UserProfile(
      id: map['id'] as String? ?? 'default',
      name: map['name'] as String? ?? 'Profile',
      avatarEmoji: map['avatarEmoji'] as String? ?? '🎧',
      avatarColorValue: (map['avatarColorValue'] as num?)?.toInt() ?? 0xFF8B7BFF,
      isKidsMode: map['isKidsMode'] as bool? ?? false,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        avatarEmoji,
        avatarColorValue,
        isKidsMode,
        createdAt,
        lastActiveAt,
      ];
}

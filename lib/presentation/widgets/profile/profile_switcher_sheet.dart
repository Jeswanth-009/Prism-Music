import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/user_profile_service.dart';
import '../../../domain/entities/user_profile.dart';
import '../../blocs/library/library.dart';
import '../../blocs/search/search.dart';
import '../../theme/prism_theme.dart';

/// Bottom sheet for switching and managing local device profiles (e.g. family tablet).
class ProfileSwitcherSheet extends StatefulWidget {
  const ProfileSwitcherSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const ProfileSwitcherSheet(),
    );
  }

  @override
  State<ProfileSwitcherSheet> createState() => _ProfileSwitcherSheetState();
}

class _ProfileSwitcherSheetState extends State<ProfileSwitcherSheet> {
  late List<UserProfile> _profiles;
  late UserProfile _activeProfile;

  static const List<String> _emojiPresets = [
    '🎧', '🎸', '🎹', '🥁', '🎤', '🦄', '🚀', '🐱', '🎮', '🌈', '⚡', '🌟',
  ];

  static const List<int> _colorPresets = [
    0xFF8B7BFF, 0xFF6355E8, 0xFFFF416C, 0xFF00C6FF, 0xFF38EF7D, 0xFFF7971E, 0xFFE94057,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfiles();
  }

  void _loadProfiles() {
    setState(() {
      _profiles = UserProfileService.instance.getAllProfiles();
      _activeProfile = UserProfileService.instance.getActiveProfile();
    });
  }

  Future<void> _switchProfile(UserProfile profile) async {
    if (profile.id == _activeProfile.id) {
      Navigator.pop(context);
      return;
    }

    await UserProfileService.instance.switchProfile(profile.id);

    // Reload library and search history for the new active profile
    if (getIt.isRegistered<LibraryBloc>()) {
      getIt<LibraryBloc>().add(const LoadLibraryEvent());
    }
    if (mounted) {
      try {
        context.read<LibraryBloc>().add(const LoadLibraryEvent());
      } catch (_) {}
      try {
        context.read<SearchBloc>().add(const LoadSearchHistoryEvent());
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Switched to ${profile.name}'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showAddProfileDialog() {
    final nameCtrl = TextEditingController();
    String selectedEmoji = _emojiPresets.first;
    int selectedColor = _colorPresets.first;
    bool isKidsMode = false;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final isDark = Theme.of(dialogCtx).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? PrismColors.inkRaised : PrismColors.paperRaised,
            title: const Text('Add Local Profile'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Profile Name',
                      hintText: 'e.g. Mom, Alex, Kids',
                    ),
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  const Text('Choose Avatar', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _emojiPresets.map((emoji) {
                      final isSelected = selectedEmoji == emoji;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedEmoji = emoji),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? PrismColors.accentDark.withOpacity(0.25)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? PrismColors.accentDark : Colors.white12,
                            ),
                          ),
                          child: Text(emoji, style: const TextStyle(fontSize: 20)),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Color Accent', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _colorPresets.map((colorVal) {
                      final isSelected = selectedColor == colorVal;
                      return GestureDetector(
                        onTap: () => setDialogState(() => selectedColor = colorVal),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: Color(colorVal),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kids Mode', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Filter explicit songs & content', style: TextStyle(fontSize: 12)),
                    value: isKidsMode,
                    onChanged: (val) => setDialogState(() => isKidsMode = val),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  if (name.isNotEmpty) {
                    await UserProfileService.instance.createProfile(
                      name: name,
                      avatarEmoji: selectedEmoji,
                      avatarColorValue: selectedColor,
                      isKidsMode: isKidsMode,
                    );
                    if (dialogCtx.mounted) {
                      Navigator.pop(dialogCtx);
                    }
                    if (mounted) {
                      _loadProfiles();
                    }
                  }
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _deleteProfile(UserProfile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${profile.name}"?'),
        content: const Text('This will remove this local profile and its profile-specific data from this device.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await UserProfileService.instance.deleteProfile(profile.id);
      _loadProfiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? PrismColors.inkRaised : PrismColors.paperRaised,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Profiles',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _showAddProfileDialog,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Add Profile'),
              ),
            ],
          ),
          Text(
            'Local profiles for multi-user family devices',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _profiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final profile = _profiles[index];
              final isActive = profile.id == _activeProfile.id;

              return ListTile(
                onTap: () => _switchProfile(profile),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isActive ? PrismColors.accentDark : Colors.white10,
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                tileColor: isActive
                    ? PrismColors.accentDark.withOpacity(0.12)
                    : Colors.white.withOpacity(0.04),
                leading: CircleAvatar(
                  backgroundColor: Color(profile.avatarColorValue),
                  child: Text(profile.avatarEmoji, style: const TextStyle(fontSize: 18)),
                ),
                title: Row(
                  children: [
                    Text(
                      profile.name,
                      style: TextStyle(
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                    if (profile.isKidsMode) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'KIDS',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isActive)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: PrismColors.accentDark,
                        size: 20,
                      )
                    else if (_profiles.length > 1 && profile.id != 'default')
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white54),
                        onPressed: () => _deleteProfile(profile),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

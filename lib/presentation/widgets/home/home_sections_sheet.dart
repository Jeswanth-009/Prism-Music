import 'package:flutter/material.dart';
import '../../../core/services/settings_service.dart';
import '../prism/prism_sheet.dart';

/// Modal sheet allowing users to declutter and personalize their Home feed sections.
class HomeSectionsCustomizerSheet extends StatefulWidget {
  const HomeSectionsCustomizerSheet({super.key, required this.onChanged});

  final VoidCallback onChanged;

  static Future<void> show(BuildContext context, {required VoidCallback onChanged}) {
    return showPrismSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HomeSectionsCustomizerSheet(onChanged: onChanged),
    );
  }

  @override
  State<HomeSectionsCustomizerSheet> createState() =>
      _HomeSectionsCustomizerSheetState();
}

class _HomeSectionsCustomizerSheetState
    extends State<HomeSectionsCustomizerSheet> {
  final _settings = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledList = _settings.enabledHomeSections;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Customize Home',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Choose which sections appear in your feed',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _settings.resetHomeSections();
                      widget.onChanged();
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 6),
                itemCount: HomeSectionId.values.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 20, endIndent: 20),
                itemBuilder: (context, index) {
                  final section = HomeSectionId.values[index];
                  final isEnabled = enabledList.contains(section.name);

                  return SwitchListTile.adaptive(
                    value: isEnabled,
                    title: Text(
                      section.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      section.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    onChanged: (val) {
                      _settings.setHomeSectionEnabled(section, val);
                      widget.onChanged();
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

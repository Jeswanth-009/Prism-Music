import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/settings_service.dart';
import '../prism/prism_sheet.dart';

/// Modal sheet allowing users to reorder via drag-and-drop, toggle visibility,
/// and personalize their Home feed sections.
class HomeSectionsCustomizerSheet extends StatefulWidget {
  const HomeSectionsCustomizerSheet({super.key, required this.onChanged});

  final VoidCallback onChanged;

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onChanged,
  }) {
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
  late List<HomeSectionId> _order;

  @override
  void initState() {
    super.initState();
    _order = List<HomeSectionId>.from(_settings.homeSectionsOrder);
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) newIndex -= 1;
      final item = _order.removeAt(oldIndex);
      _order.insert(newIndex, item);
    });
    HapticFeedback.selectionClick();
    _settings.setHomeSectionsOrder(_order);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabledList = _settings.enabledHomeSections;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
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
                          'Drag handle to reorder; toggle to show or hide',
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
                      setState(() {
                        _order = List<HomeSectionId>.from(_settings.homeSectionsOrder);
                      });
                      widget.onChanged();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Reset'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ReorderableListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                itemCount: _order.length,
                onReorder: _onReorder,
                itemBuilder: (context, index) {
                  final section = _order[index];
                  final isEnabled = enabledList.contains(section.name);

                  return Container(
                    key: ValueKey('section_${section.name}'),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 2, 12, 2),
                      title: Text(
                        section.label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isEnabled
                              ? theme.colorScheme.onSurface
                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      subtitle: Text(
                        section.description,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch.adaptive(
                            value: isEnabled,
                            onChanged: (val) {
                              _settings.setHomeSectionEnabled(section, val);
                              widget.onChanged();
                              if (mounted) setState(() {});
                            },
                          ),
                          const SizedBox(width: 8),
                          ReorderableDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(
                                Icons.drag_handle_rounded,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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

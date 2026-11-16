import 'package:flutter/material.dart';

import '../../theme/prism_theme.dart';

/// Floating frosted search bar header with integrated clear and acoustic recognition actions.
/// Strictly uses vector iconography (no emojis).
class SearchHeaderBar extends StatelessWidget {
  const SearchHeaderBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
    required this.onRecognizeTap,
    this.embedded = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;
  final VoidCallback onRecognizeTap;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasText = controller.text.isNotEmpty;

    return Row(
      children: [
        if (!embedded) ...[
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(PrismRadius.pill),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(
                  Icons.search_rounded,
                  size: 22,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.search,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search songs, artists, albums...',
                      hintStyle: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: onChanged,
                    onSubmitted: onSubmitted,
                  ),
                ),
                if (hasText)
                  IconButton(
                    onPressed: onClear,
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                  ),
                IconButton(
                  onPressed: onRecognizeTap,
                  icon: const Icon(Icons.graphic_eq_rounded, size: 20),
                  tooltip: 'Identify song',
                  visualDensity: VisualDensity.compact,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

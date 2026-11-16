import 'package:flutter/material.dart';
import '../../theme/prism_theme.dart';

/// Available Home feed mood filters.
enum HomeMoodFilter {
  all('All', Icons.auto_awesome_rounded),
  focus('Focus', Icons.lightbulb_outline_rounded),
  chill('Chill', Icons.nightlight_round),
  workout('Workout', Icons.fitness_center_rounded),
  energy('Energy', Icons.bolt_rounded),
  relax('Relax', Icons.spa_rounded),
  commute('Commute', Icons.directions_car_rounded);

  final String label;
  final IconData icon;
  const HomeMoodFilter(this.label, this.icon);
}

/// Sticky / pinned horizontal pill bar for instant in-feed mood filtering.
/// Pure vector iconography with zero emojis.
class HomeMoodFilterBar extends StatelessWidget {
  const HomeMoodFilterBar({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final HomeMoodFilter selected;
  final ValueChanged<HomeMoodFilter> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: HomeMoodFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mood = HomeMoodFilter.values[index];
          final isSelected = mood == selected;

          return Center(
            child: FilterChip(
              avatar: Icon(
                mood.icon,
                size: 16,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              label: Text(mood.label),
              labelStyle: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant,
              ),
              selected: isSelected,
              selectedColor: theme.colorScheme.primaryContainer,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
              showCheckmark: false,
              side: BorderSide(
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.6)
                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
                width: 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(PrismRadius.pill),
              ),
              onSelected: (_) => onSelect(mood),
            ),
          );
        },
      ),
    );
  }
}

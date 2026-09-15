import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_state.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import 'charts_hub_page.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_page.dart';

const double _kNavBarHeight = 62;
const double _kNavBarBottomPadding = 12;

/// App shell: tabbed content with a floating navigation pill and the
/// persistent mini player above it.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          // Subtle single-hue tint at the top; otherwise flat surface.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.04),
                    scheme.surface,
                    scheme.surface,
                  ],
                  stops: const [0, 0.22, 1],
                ),
              ),
            ),
          ),
          IndexedStack(
            index: _currentIndex,
            children: const [
              HomeTab(),
              SearchPage(embedded: true),
              ChartsHubPage(),
              LibraryTab(),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + _kNavBarHeight + _kNavBarBottomPadding + 10,
            child: BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) {
                if (state.currentSong == null) return const SizedBox.shrink();
                return const MiniPlayer();
              },
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottomPadding > 0 ? bottomPadding : _kNavBarBottomPadding,
            child: _PrismNavBar(
              currentIndex: _currentIndex,
              onSelect: (index) => setState(() => _currentIndex = index),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrismNavBar extends StatelessWidget {
  const _PrismNavBar({required this.currentIndex, required this.onSelect});

  final int currentIndex;
  final ValueChanged<int> onSelect;

  static const _items = [
    (icon: Icons.home_rounded, selected: Icons.home_rounded, label: 'Home'),
    (icon: Icons.search_rounded, selected: Icons.search_rounded, label: 'Search'),
    (
      icon: Icons.bar_chart_rounded,
      selected: Icons.bar_chart_rounded,
      label: 'Charts',
    ),
    (
      icon: Icons.library_music_outlined,
      selected: Icons.library_music_rounded,
      label: 'Library',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = context.prismSpec;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: spec.hairline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isSelected = i == currentIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: PrismMotion.base,
                curve: PrismMotion.curve,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? spec.accentSoft : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSelected ? item.selected : item.icon,
                      size: 21,
                      color: isSelected
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.label,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

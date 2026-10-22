import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_state.dart';
import '../blocs/theme/theme.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import 'charts_hub_page.dart';
import 'home_tab.dart';
import 'library_tab.dart';
import 'search_page.dart';


/// App shell: tabbed content with a floating navigation pill and the
/// persistent mini player above it.
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    this.tabBuilders,
  });

  /// Optional custom tab builders, primarily used for testing or modular shells.
  /// If null, [defaultTabBuilders] are used.
  final List<WidgetBuilder>? tabBuilders;

  static final List<WidgetBuilder> defaultTabBuilders = [
    (_) => const HomeTab(),
    (_) => const SearchPage(embedded: true),
    (_) => const ChartsHubPage(embedded: true),
    (_) => const LibraryTab(),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  final Set<int> _visitedTabs = {0};

  void _onTabSelect(int index) {
    if (_currentIndex == index && _visitedTabs.contains(index)) return;
    setState(() {
      _currentIndex = index;
      _visitedTabs.add(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final builders = widget.tabBuilders ?? HomePage.defaultTabBuilders;

    return Scaffold(
      extendBody: false,
      body: BlocListener<PlayerBloc, PlayerState>(
        listenWhen: (prev, next) =>
            prev.currentSong?.id != next.currentSong?.id,
        listener: (context, state) {
          // App-wide dynamic accent: retint the chrome from artwork.
          final song = state.currentSong;
          if (song != null && song.thumbnailUrl.isNotEmpty) {
            context.read<ThemeBloc>().add(
              UpdateDynamicColorEvent(imageUrl: song.thumbnailUrl),
            );
          }
        },
        child: Stack(
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
              children: [
                for (var i = 0; i < builders.length; i++)
                  _visitedTabs.contains(i)
                      ? builders[i](context)
                      : const SizedBox.shrink(),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, state) {
                if (state.currentSong == null) return const SizedBox.shrink();
                return const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: MiniPlayer(),
                );
              },
            ),
            _PrismNavBar(
              currentIndex: _currentIndex,
              onSelect: _onTabSelect,
            ),
          ],
        ),
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
        color: scheme.surfaceContainer,
        border: Border(top: BorderSide(color: spec.hairline)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_items.length, (i) {
          final item = _items[i];
          final isSelected = i == currentIndex;
          return Expanded(
            child: Semantics(
              button: true,
              selected: isSelected,
              label: '${item.label} tab',
              child: Tooltip(
                message: item.label,
                child: FocusableActionDetector(
                  actions: {
                    ActivateIntent: CallbackAction<ActivateIntent>(
                      onInvoke: (_) => onSelect(i),
                    ),
                  },
                  child: InkWell(
                    onTap: () => onSelect(i),
                    borderRadius: BorderRadius.circular(PrismRadius.md),
                    child: AnimatedContainer(
                      duration: PrismMotion.baseOf(context),
                      curve: PrismMotion.curve,
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? spec.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(PrismRadius.md),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSelected ? item.selected : item.icon,
                            size: 22,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.label,
                            maxLines: 1,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}


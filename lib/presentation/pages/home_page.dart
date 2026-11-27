import 'dart:async';
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../blocs/player/player_bloc.dart';
import '../blocs/player/player_state.dart';
import '../blocs/theme/theme.dart';
import '../theme/prism_theme.dart';
import '../widgets/player/mini_player.dart';
import '../widgets/common/adaptive_layout.dart';
import '../widgets/common/offline_banner.dart';
import '../widgets/dialogs/prism_update_dialog.dart';
import '../../core/di/injection.dart';
import '../../core/error/exceptions.dart';
import '../../core/services/app_update_service.dart';
import '../../core/services/stream_loader_service.dart';
import '../../core/services/instance_health_service.dart';
import '../../core/services/offline_mode_service.dart';
import '../../core/services/deep_link_service.dart';
import '../widgets/prism/prism_sheet.dart';
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
    this.initialIndex = 0,
    this.enableUpdateCheck,
  });

  /// Optional custom tab builders, primarily used for testing or modular shells.
  /// If null, [defaultTabBuilders] are used.
  final List<WidgetBuilder>? tabBuilders;

  /// Initial tab index to select on mount (0: Home, 1: Search, 2: Charts, 3: Library).
  final int initialIndex;

  /// Whether to check for updates on mount. Defaults to true when using [defaultTabBuilders].
  final bool? enableUpdateCheck;

  static final List<WidgetBuilder> defaultTabBuilders = [
    (_) => const HomeTab(),
    (_) => const SearchPage(embedded: true),
    (_) => const ChartsHubPage(embedded: true),
    (_) => const LibraryTab(),
  ];

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  late int _currentIndex;
  late final Set<int> _visitedTabs;
  final Map<int, Widget> _cachedTabWidgets = {};
  Timer? _updateCheckTimer;
  bool _isUpdateDialogShowing = false;
  StreamSubscription<void>? _offlineTransitionSub;
  StreamSubscription<GeoRestrictionException>? _geoRestrictionSub;
  StreamSubscription<ParsedDeepLink>? _deepLinkSub;

  bool get _shouldCheckUpdates =>
      widget.enableUpdateCheck ?? (widget.tabBuilders == null);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _visitedTabs = {widget.initialIndex};
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_shouldCheckUpdates) {
        _checkUpdateOnLaunch();
        InstanceHealthService().startBackgroundHealthProbes();
      }
    });

    if (getIt.isRegistered<StreamLoaderService>()) {
      _geoRestrictionSub = getIt<StreamLoaderService>()
          .onGeoRestrictionDetected
          .listen((geoEx) {
        if (!mounted) return;
        showPrismToast(
          context,
          '${geoEx.provider} audio is geo-restricted in your region. Switched to alternative audio.',
        );
      });
    }

    _offlineTransitionSub =
        OfflineModeService.instance.onSwitchedToOffline.listen((_) {
      if (!mounted) return;
      if (_currentIndex == 0 || _currentIndex == 2) {
        setState(() {
          _currentIndex = 3;
          _visitedTabs.add(3);
        });
        showPrismToast(
          context,
          'Offline mode active — switched to local library',
        );
      }
    });

    if (getIt.isRegistered<DeepLinkService>()) {
      final deepLinkService = getIt<DeepLinkService>();
      deepLinkService.initialize();
      _deepLinkSub = deepLinkService.linkStream.listen((parsed) {
        if (!mounted) return;
        if (parsed.type == DeepLinkType.song) {
          showPrismToast(
            context,
            'Playing shared song${parsed.title != null ? ': ${parsed.title}' : ''}',
          );
        } else if (parsed.type == DeepLinkType.playlist) {
          showPrismToast(
            context,
            'Opening shared playlist${parsed.title != null ? ': ${parsed.title}' : ''}',
          );
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSub?.cancel();
    _offlineTransitionSub?.cancel();
    _geoRestrictionSub?.cancel();
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _shouldCheckUpdates) {
      AppUpdateService.instance.onAppResumedAfterInstall();
      _checkUpdateOnLaunch(delay: const Duration(milliseconds: 600));
    }
  }

  void _checkUpdateOnLaunch({Duration delay = const Duration(milliseconds: 1500)}) {
    if (!mounted || !_shouldCheckUpdates || _isUpdateDialogShowing) return;
    _updateCheckTimer?.cancel();
    _updateCheckTimer = Timer(delay, () async {
      if (!mounted || _isUpdateDialogShowing) return;

      final info = await AppUpdateService.instance.checkForUpdate();
      if (!mounted || info == null || !info.hasUpdate || _isUpdateDialogShowing) {
        return;
      }

      // Do not show if dismissed in this app session
      if (AppUpdateService.instance.isDismissed(info.latestVersion)) return;

      _isUpdateDialogShowing = true;
      try {
        await PrismUpdateDialog.show(context, info);
      } finally {
        _isUpdateDialogShowing = false;
      }
    });
  }

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
    final isTablet = AdaptiveBreakpoints.isTablet(context);

    final contentStack = Stack(
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
                  ? TickerMode(
                      enabled: _currentIndex == i,
                      child: _cachedTabWidgets.putIfAbsent(
                        i,
                        () => builders[i](context),
                      ),
                    )
                  : const SizedBox.shrink(),
          ],
        ),
      ],
    );

    if (isTablet) {
      return Scaffold(
        extendBody: false,
        body: BlocListener<PlayerBloc, PlayerState>(
          listenWhen: (prev, next) =>
              prev.currentSong?.id != next.currentSong?.id ||
              (next.playbackNotification != null &&
                  next.playbackNotification != prev.playbackNotification),
          listener: (context, state) {
            if (state.playbackNotification != null) {
              showPrismToast(context, state.playbackNotification!);
            }
            final song = state.currentSong;
            if (song != null && song.thumbnailUrl.isNotEmpty) {
              context.read<ThemeBloc>().add(
                UpdateDynamicColorEvent(imageUrl: song.thumbnailUrl),
              );
            }
          },
          child: Row(
            children: [
              NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: _onTabSelect,
                backgroundColor: scheme.surfaceContainer,
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_rounded),
                    selectedIcon: Icon(Icons.home_rounded),
                    label: Text('Home'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.search_rounded),
                    selectedIcon: Icon(Icons.search_rounded),
                    label: Text('Search'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bar_chart_rounded),
                    selectedIcon: Icon(Icons.bar_chart_rounded),
                    label: Text('Charts'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.library_music_rounded),
                    selectedIcon: Icon(Icons.library_music_rounded),
                    label: Text('Library'),
                  ),
                ],
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: Column(
                  children: [
                    OfflineBanner(
                      onTap: () => _onTabSelect(3),
                    ),
                    Expanded(child: contentStack),
                    BlocBuilder<PlayerBloc, PlayerState>(
                      builder: (context, state) {
                        if (state.currentSong == null) return const SizedBox.shrink();
                        return const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: MiniPlayer(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBody: false,
      body: BlocListener<PlayerBloc, PlayerState>(
        listenWhen: (prev, next) =>
            prev.currentSong?.id != next.currentSong?.id ||
            (next.playbackNotification != null &&
                next.playbackNotification != prev.playbackNotification),
        listener: (context, state) {
          if (state.playbackNotification != null) {
            showPrismToast(context, state.playbackNotification!);
          }
          // App-wide dynamic accent: retint the chrome from artwork.
          final song = state.currentSong;
          if (song != null && song.thumbnailUrl.isNotEmpty) {
            context.read<ThemeBloc>().add(
              UpdateDynamicColorEvent(imageUrl: song.thumbnailUrl),
            );
          }
        },
        child: contentStack,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            OfflineBanner(
              onTap: () => _onTabSelect(3),
            ),
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
      icon: Icons.library_music_rounded,
      selected: Icons.library_music_rounded,
      label: 'Library',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spec = context.prismSpec;

    // Floating capsule: detached from the screen edge, one consistent
    // treatment for every tab. It sits on the scaffold surface and reads
    // as a control, not a chrome strip.
    return Container(
      margin: const EdgeInsets.fromLTRB(
        PrismSpacing.lg,
        PrismSpacing.xs,
        PrismSpacing.lg,
        PrismSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        border: Border.all(color: spec.hairline),
        boxShadow: [
          BoxShadow(
            color: PrismColors.scrim.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: PrismSpacing.sm,
        vertical: PrismSpacing.xs + 2,
      ),
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
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                    child: AnimatedContainer(
                      duration: PrismMotion.baseOf(context),
                      curve: PrismMotion.curve,
                      constraints: const BoxConstraints(minHeight: 48),
                      decoration: BoxDecoration(
                        color:
                            isSelected ? spec.accentSoft : Colors.transparent,
                        borderRadius: BorderRadius.circular(PrismRadius.pill),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            item.icon,
                            size: PrismIconSize.lg,
                            color: isSelected
                                ? scheme.primary
                                : scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: PrismSpacing.xxs),
                          Text(
                            item.label,
                            maxLines: 1,
                            style: PrismText.overline(context)?.copyWith(
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


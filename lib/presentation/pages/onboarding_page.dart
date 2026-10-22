import 'package:flutter/material.dart';

import '../../core/services/settings_service.dart';
import '../theme/prism_theme.dart';
import 'home_page.dart';

/// First-launch onboarding: three slides introducing the app, then straight
/// into the shell. Shown once; completion persists.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _page = 0;

  static const _slides = [
    (
      icon: Icons.music_note_rounded,
      title: 'All your music,\none app',
      body:
          'Search and stream millions of songs from YouTube Music and '
          'JioSaavn with fast playback — no account, no sign-up required.',
    ),
    (
      icon: Icons.shield_outlined,
      title: 'Private by design',
      body:
          'Your likes, playlists, and listening history stay on your device without user tracking. Streams are fetched directly from external providers (YouTube/JioSaavn), and optional features like Last.fm scrobbling are entirely up to you.',
    ),
    (
      icon: Icons.verified_user_outlined,
      title: 'Transparent\nPermissions',
      body:
          'We only ask for permissions that improve your listening:\n\n'
          '• Media Notifications: Playback controls in notification tray & lock screen\n'
          '• Background Audio: Continuous music when phone is locked or multitasking\n'
          '• Storage & Backups: Strictly for offline downloads and local backups',
    ),
    (
      icon: Icons.rocket_launch_rounded,
      title: 'Ready to listen?',
      body:
          'Synced lyrics, a 10-band equalizer, sleep timer, and offline '
          'downloads. Find your favorite track or dive into trending discovery mixes.',
    ),
  ];

  void _finish({int initialIndex = 0}) async {
    await SettingsService.instance.setOnboardingComplete();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => HomePage(initialIndex: initialIndex),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLast = _page == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _finish(initialIndex: 0),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (index) => setState(() => _page = index),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 108,
                            height: 108,
                            decoration: BoxDecoration(
                              color: context.prismSpec.accentSoft,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(
                              slide.icon,
                              size: 52,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            slide.title,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            slide.body,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: PrismMotion.base,
                    curve: PrismMotion.curve,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: .3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
              child: isLast
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: () => _finish(initialIndex: 1),
                            icon: const Icon(Icons.search_rounded, size: 20),
                            label: const Text('Search & Play Music'),
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton.icon(
                            onPressed: () => _finish(initialIndex: 0),
                            icon: const Icon(Icons.explore_outlined, size: 20),
                            label: const Text('Explore Trending & Home'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () {
                          _controller.nextPage(
                            duration: PrismMotion.slow,
                            curve: PrismMotion.curve,
                          );
                        },
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Next',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

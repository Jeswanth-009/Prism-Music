import 'package:flutter/material.dart';

/// The 6 dynamic living soundscape phases throughout the day
enum LivingPhase {
  dawn,
  focus,
  afternoon,
  sunset,
  primeNight,
  midnight,
}

/// Represents the visual & musical state of a living time soundscape
class LivingSoundscape {
  final LivingPhase phase;
  final String uppercaseTagline;
  final String title;
  final String subtitle;
  final String greeting;
  final IconData icon;
  final Color primaryAccent;
  final List<String> moodQueries;

  const LivingSoundscape({
    required this.phase,
    required this.uppercaseTagline,
    required this.title,
    required this.subtitle,
    required this.greeting,
    required this.icon,
    required this.primaryAccent,
    required this.moodQueries,
  });
}

/// Service that provides time-of-day awareness, living soundscapes,
/// and dynamic theme suggestions that make the app feel alive.
class LivingTimeService {
  static final LivingTimeService _instance = LivingTimeService._internal();
  static LivingTimeService get instance => _instance;
  LivingTimeService._internal();

  /// Determine the living phase for a given timestamp
  LivingPhase getCurrentPhase([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final timeVal = dt.hour + (dt.minute / 60.0);

    // 05:00 - 08:30: Dawn
    if (timeVal >= 5.0 && timeVal < 8.5) return LivingPhase.dawn;
    // 08:30 - 12:00: Mid-Morning Focus
    if (timeVal >= 8.5 && timeVal < 12.0) return LivingPhase.focus;
    // 12:00 - 17:00: Afternoon Boost
    if (timeVal >= 12.0 && timeVal < 17.0) return LivingPhase.afternoon;
    // 17:00 - 20:30: Sunset & Evening
    if (timeVal >= 17.0 && timeVal < 20.5) return LivingPhase.sunset;
    // 20:30 - 23:30: Prime Night
    if (timeVal >= 20.5 && timeVal < 23.5) return LivingPhase.primeNight;
    // 23:30 - 05:00: Midnight Dreamscapes
    return LivingPhase.midnight;
  }

  /// Returns the tailored soundscape configuration for the current moment
  LivingSoundscape getSoundscape([DateTime? now]) {
    final dt = now ?? DateTime.now();
    final phase = getCurrentPhase(dt);
    final isWeekend =
        dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;

    switch (phase) {
      case LivingPhase.dawn:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: isWeekend
              ? 'LAZY WEEKEND MORNING VIBES.'
              : 'START YOUR DAY WITH CLARITY & PEACE.',
          title: 'Morning Brew & Acoustic Strings',
          subtitle: 'Gentle keys, acoustic guitars, and peaceful morning warmth',
          greeting: 'Good morning',
          icon: Icons.wb_sunny_rounded,
          primaryAccent: const Color(0xFFFFA726),
          moodQueries: const [
            'acoustic morning',
            'peaceful piano',
            'morning coffee',
            'gentle acoustic',
          ],
        );
      case LivingPhase.focus:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: isWeekend
              ? 'CREATIVE WEEKEND IN PURSUIT.'
              : 'LOCK IN, FOCUS, AND GET INTO THE FLOW.',
          title: 'Deep Work & Instrumental Flow',
          subtitle: 'Ambient electronics, focus lo-fi beats, and coding grooves',
          greeting: 'Good morning',
          icon: Icons.psychology_rounded,
          primaryAccent: const Color(0xFF29B6F6),
          moodQueries: const [
            'lofi focus',
            'ambient coding',
            'deep instrumental',
            'synthwave flow',
          ],
        );
      case LivingPhase.afternoon:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: 'MIDDAY BOOST & FEEL-GOOD VIBES.',
          title: 'Afternoon Groove & Indie Pop',
          subtitle:
              'Feel-good anthems and indie pop to power through your day',
          greeting: 'Good afternoon',
          icon: Icons.electric_bolt_rounded,
          primaryAccent: const Color(0xFFFF7043),
          moodQueries: const [
            'indie pop',
            'upbeat groove',
            'afternoon hits',
            'feel good acoustic',
          ],
        );
      case LivingPhase.sunset:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: isWeekend
              ? 'SATURDAY NIGHT ENERGY IS RISING.'
              : 'UNWIND FROM WORK OR GEAR UP FOR THE GYM.',
          title: isWeekend
              ? 'Weekend Hype & Party Rhythms'
              : 'Sunset Sessions & Evening Hype',
          subtitle:
              'Golden-hour chillouts, synthpop, and workout power anthems',
          greeting: 'Good evening',
          icon: Icons.flare_rounded,
          primaryAccent: const Color(0xFFAB47BC),
          moodQueries: const [
            'sunset chill',
            'workout hype',
            'golden hour vibes',
            'evening gym',
          ],
        );
      case LivingPhase.primeNight:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: 'SET THE MOOD RIGHT FOR A RELAXING NIGHT.',
          title: 'Late Night Lounge',
          subtitle:
              'Warm melodies, slow R&B, retro 90s romance, and intimate vocals',
          greeting: 'Good evening',
          icon: Icons.nightlife_rounded,
          primaryAccent: const Color(0xFF7E57C2),
          moodQueries: const [
            'late night lounge',
            'retro romance',
            'slow r&b',
            'candlelight acoustic',
          ],
        );
      case LivingPhase.midnight:
        return LivingSoundscape(
          phase: phase,
          uppercaseTagline: 'TRANQUIL TUNES TO LULL YOU TO SLEEP.',
          title: 'Sweet Dreams',
          subtitle:
              'Soft ambient, rain sleepscapes, binaural tones, and peaceful piano',
          greeting: 'Late night listening',
          icon: Icons.bedtime_rounded,
          primaryAccent: const Color(0xFF5C6BC0),
          moodQueries: const [
            'sleep ambience',
            'midnight lofi',
            'rain sounds piano',
            'deep sleep',
          ],
        );
    }
  }
}

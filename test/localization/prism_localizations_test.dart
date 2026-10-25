import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prism_music/core/localization/prism_localizations.dart';

void main() {
  group('PrismLocalizations', () {
    test('provides English defaults', () {
      final loc = PrismLocalizations(const Locale('en'));
      expect(loc.home, 'Home');
      expect(loc.search, 'Search');
      expect(loc.library, 'Library');
      expect(loc.settings, 'Settings');
      expect(loc.play, 'Play');
      expect(loc.pause, 'Pause');
      expect(loc.restoreQueue, 'Restore Queue on Launch');
    });

    test('provides Hindi strings', () {
      final loc = PrismLocalizations(const Locale('hi'));
      expect(loc.home, 'होम');
      expect(loc.search, 'खोजें');
      expect(loc.library, 'लाइब्रेरी');
      expect(loc.settings, 'सेटिंग्स');
      expect(loc.play, 'चलाएं');
      expect(loc.pause, 'रोकें');
    });

    test('provides Telugu strings', () {
      final loc = PrismLocalizations(const Locale('te'));
      expect(loc.home, 'హోమ్');
      expect(loc.search, 'శోధించండి');
      expect(loc.library, 'లైబ్రరీ');
      expect(loc.settings, 'సెట్టింగ్‌లు');
      expect(loc.play, 'ప్లే');
    });

    test('provides Tamil strings', () {
      final loc = PrismLocalizations(const Locale('ta'));
      expect(loc.home, 'முகப்பு');
      expect(loc.search, 'தேடு');
      expect(loc.library, 'நூலகம்');
      expect(loc.settings, 'அமைப்புகள்');
    });

    test('provides Spanish, French, and German strings', () {
      final es = PrismLocalizations(const Locale('es'));
      expect(es.home, 'Inicio');
      expect(es.search, 'Buscar');

      final fr = PrismLocalizations(const Locale('fr'));
      expect(fr.home, 'Accueil');
      expect(fr.search, 'Rechercher');

      final de = PrismLocalizations(const Locale('de'));
      expect(de.home, 'Startseite');
      expect(de.search, 'Suchen');
    });

    test('falls back gracefully to English on unsupported locale', () {
      final loc = PrismLocalizations(const Locale('ja'));
      expect(loc.home, 'Home');
      expect(loc.search, 'Search');
    });

    test('lists 7 supported regional and international languages', () {
      expect(supportedPrismLanguages.length, 7);
      expect(
        supportedPrismLanguages.map((l) => l.code),
        containsAll(['en', 'hi', 'te', 'ta', 'es', 'fr', 'de']),
      );
    });
  });
}

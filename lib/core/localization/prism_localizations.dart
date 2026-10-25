import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Supported regional and international languages in Prism Music.
class PrismLanguage {
  final String code;
  final String englishName;
  final String nativeName;

  const PrismLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
  });
}

const List<PrismLanguage> supportedPrismLanguages = [
  PrismLanguage(code: 'en', englishName: 'English', nativeName: 'English'),
  PrismLanguage(code: 'hi', englishName: 'Hindi', nativeName: 'हिन्दी'),
  PrismLanguage(code: 'te', englishName: 'Telugu', nativeName: 'తెలుగు'),
  PrismLanguage(code: 'ta', englishName: 'Tamil', nativeName: 'தமிழ்'),
  PrismLanguage(code: 'es', englishName: 'Spanish', nativeName: 'Español'),
  PrismLanguage(code: 'fr', englishName: 'French', nativeName: 'Français'),
  PrismLanguage(code: 'de', englishName: 'German', nativeName: 'Deutsch'),
];

/// Multi-language localization dictionary for core UI strings across navigation,
/// playback controls, library management, and search.
class PrismLocalizations {
  final Locale locale;

  PrismLocalizations(this.locale);

  static PrismLocalizations of(BuildContext context) {
    return Localizations.of<PrismLocalizations>(context, PrismLocalizations) ??
        PrismLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<PrismLocalizations> delegate =
      _PrismLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('te'),
    Locale('ta'),
    Locale('es'),
    Locale('fr'),
    Locale('de'),
  ];

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'home': 'Home',
      'search': 'Search',
      'library': 'Library',
      'settings': 'Settings',
      'play': 'Play',
      'pause': 'Pause',
      'resume': 'Resume',
      'next': 'Next',
      'previous': 'Previous',
      'queue': 'Queue',
      'lyrics': 'Lyrics',
      'playlists': 'Playlists',
      'likedSongs': 'Liked Songs',
      'downloads': 'Downloads',
      'recentlyPlayed': 'Recently Played',
      'smartPlaylists': 'Smart Playlists',
      'audioQuality': 'Audio Quality',
      'language': 'App Language',
      'restoreQueue': 'Restore Queue on Launch',
      'noResults': 'No results found',
      'allMatched': 'All tracks matched and imported!',
      'diagnostics': 'Provider Health Diagnostics',
      'clearQueue': 'Clear Saved Queue',
    },
    'hi': {
      'home': 'होम',
      'search': 'खोजें',
      'library': 'लाइब्रेरी',
      'settings': 'सेटिंग्स',
      'play': 'चलाएं',
      'pause': 'रोकें',
      'resume': 'फिर से शुरू करें',
      'next': 'अगला',
      'previous': 'पिछला',
      'queue': 'कतार',
      'lyrics': 'बोल',
      'playlists': 'प्लेलिस्ट',
      'likedSongs': 'पसंदीदा गाने',
      'downloads': 'डाउनलोड',
      'recentlyPlayed': 'हाल ही में बजाए गए',
      'smartPlaylists': 'स्मार्ट प्लेलिस्ट',
      'audioQuality': 'ऑडियो गुणवत्ता',
      'language': 'ऐप की भाषा',
      'restoreQueue': 'शुरू होने पर कतार बहाल करें',
      'noResults': 'कोई परिणाम नहीं मिला',
      'allMatched': 'सभी ट्रैक मेल खा गए और आयात किए गए!',
      'diagnostics': 'प्रदाता स्वास्थ्य निदान',
      'clearQueue': 'सहेजी गई कतार साफ़ करें',
    },
    'te': {
      'home': 'హోమ్',
      'search': 'శోధించండి',
      'library': 'లైబ్రరీ',
      'settings': 'సెట్టింగ్‌లు',
      'play': 'ప్లే',
      'pause': 'పాజ్',
      'resume': 'పునఃప్రారంభించు',
      'next': 'తదుపరి',
      'previous': 'మునుపటి',
      'queue': 'క్యూ',
      'lyrics': 'సాహిత్యం',
      'playlists': 'ప్లేజాబితాలు',
      'likedSongs': 'ఇష్టపడిన పాటలు',
      'downloads': 'డౌన్‌లోడ్‌లు',
      'recentlyPlayed': 'ఇటీవల ప్లే చేసినవి',
      'smartPlaylists': 'స్మార్ట్ ప్లేజాబితాలు',
      'audioQuality': 'ఆడియో నాణ్యత',
      'language': 'యాప్ భాష',
      'restoreQueue': 'ప్రారంభించినప్పుడు క్యూని పునరుద్ధరించండి',
      'noResults': 'ఫలితాలు కనుగొనబడలేదు',
      'allMatched': 'అన్ని ట్రాక్‌లు సరిపోలాయి మరియు దిగుమతి చేయబడ్డాయి!',
      'diagnostics': 'ప్రొవైడర్ హెల్త్ డయాగ్నస్టిక్స్',
      'clearQueue': 'సేవ్ చేసిన క్యూను తొలగించండి',
    },
    'ta': {
      'home': 'முகப்பு',
      'search': 'தேடு',
      'library': 'நூலகம்',
      'settings': 'அமைப்புகள்',
      'play': 'இயக்கு',
      'pause': 'இடைநிறுத்து',
      'resume': 'மீண்டும் தொடங்கு',
      'next': 'அடுத்தது',
      'previous': 'முந்தையது',
      'queue': 'வரிசை',
      'lyrics': 'பாடல் வரிகள்',
      'playlists': 'பிளேலிஸ்ட்கள்',
      'likedSongs': 'விருப்பமான பாடல்கள்',
      'downloads': 'பதிவிறக்கங்கள்',
      'recentlyPlayed': 'சமீபத்தில் இசைத்தவை',
      'smartPlaylists': 'ஸ்மார்ட் பிளேலிஸ்ட்கள்',
      'audioQuality': 'ஆடியோ தரம்',
      'language': 'செயலி மொழி',
      'restoreQueue': 'தொடங்கும் போது வரிசையை மீட்டெடு',
      'noResults': 'முடிவுகள் எதுவும் இல்லை',
      'allMatched': 'அனைத்து பாடல்களும் பொருந்தி இறக்குமதி செய்யப்பட்டன!',
      'diagnostics': 'வழங்குநர் நோயறிதல்',
      'clearQueue': 'சேமிக்கப்பட்ட வரிசையை அழிக்கவும்',
    },
    'es': {
      'home': 'Inicio',
      'search': 'Buscar',
      'library': 'Biblioteca',
      'settings': 'Ajustes',
      'play': 'Reproducir',
      'pause': 'Pausa',
      'resume': 'Reanudar',
      'next': 'Siguiente',
      'previous': 'Anterior',
      'queue': 'Cola',
      'lyrics': 'Letras',
      'playlists': 'Listas',
      'likedSongs': 'Canciones favoritas',
      'downloads': 'Descargas',
      'recentlyPlayed': 'Escuchado recientemente',
      'smartPlaylists': 'Listas inteligentes',
      'audioQuality': 'Calidad de audio',
      'language': 'Idioma de la app',
      'restoreQueue': 'Restaurar cola al inicio',
      'noResults': 'No se encontraron resultados',
      'allMatched': '¡Todas las pistas coincidieron e importadas!',
      'diagnostics': 'Diagnósticos de proveedores',
      'clearQueue': 'Borrar cola guardada',
    },
    'fr': {
      'home': 'Accueil',
      'search': 'Rechercher',
      'library': 'Bibliothèque',
      'settings': 'Paramètres',
      'play': 'Lire',
      'pause': 'Pause',
      'resume': 'Reprendre',
      'next': 'Suivant',
      'previous': 'Précédent',
      'queue': 'File d\'attente',
      'lyrics': 'Paroles',
      'playlists': 'Playlists',
      'likedSongs': 'Titres likés',
      'downloads': 'Téléchargements',
      'recentlyPlayed': 'Écoutés récemment',
      'smartPlaylists': 'Playlists intelligentes',
      'audioQuality': 'Qualité audio',
      'language': 'Langue de l\'application',
      'restoreQueue': 'Restaurer la file au démarrage',
      'noResults': 'Aucun résultat trouvé',
      'allMatched': 'Toutes les pistes ont été associées et importées !',
      'diagnostics': 'Diagnostics des fournisseurs',
      'clearQueue': 'Effacer la file enregistrée',
    },
    'de': {
      'home': 'Startseite',
      'search': 'Suchen',
      'library': 'Bibliothek',
      'settings': 'Einstellungen',
      'play': 'Abspielen',
      'pause': 'Pause',
      'resume': 'Fortsetzen',
      'next': 'Weiter',
      'previous': 'Zurück',
      'queue': 'Warteschlange',
      'lyrics': 'Songtext',
      'playlists': 'Wiedergabelisten',
      'likedSongs': 'Lieblingslieder',
      'downloads': 'Downloads',
      'recentlyPlayed': 'Zuletzt gespielt',
      'smartPlaylists': 'Smarte Playlists',
      'audioQuality': 'Audioqualität',
      'language': 'App-Sprache',
      'restoreQueue': 'Warteschlange beim Start wiederherstellen',
      'noResults': 'Keine Ergebnisse gefunden',
      'allMatched': 'Alle Titel abgeglichen und importiert!',
      'diagnostics': 'Anbieter-Diagnose',
      'clearQueue': 'Gespeicherte Warteschlange löschen',
    },
  };

  String _get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  String get home => _get('home');
  String get search => _get('search');
  String get library => _get('library');
  String get settings => _get('settings');
  String get play => _get('play');
  String get pause => _get('pause');
  String get resume => _get('resume');
  String get next => _get('next');
  String get previous => _get('previous');
  String get queue => _get('queue');
  String get lyrics => _get('lyrics');
  String get playlists => _get('playlists');
  String get likedSongs => _get('likedSongs');
  String get downloads => _get('downloads');
  String get recentlyPlayed => _get('recentlyPlayed');
  String get smartPlaylists => _get('smartPlaylists');
  String get audioQuality => _get('audioQuality');
  String get language => _get('language');
  String get restoreQueue => _get('restoreQueue');
  String get noResults => _get('noResults');
  String get allMatched => _get('allMatched');
  String get diagnostics => _get('diagnostics');
  String get clearQueue => _get('clearQueue');
}

class _PrismLocalizationsDelegate
    extends LocalizationsDelegate<PrismLocalizations> {
  const _PrismLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return PrismLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<PrismLocalizations> load(Locale locale) {
    return SynchronousFuture<PrismLocalizations>(PrismLocalizations(locale));
  }

  @override
  bool shouldReload(_PrismLocalizationsDelegate old) => false;
}

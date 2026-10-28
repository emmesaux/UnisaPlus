import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Gestisce le preferenze dell'applicazione:
/// - Modalità tema: Sistema, Chiaro, Scuro
/// - Lingua dell'app: Predefinita di sistema, Italiano, Inglese
///
/// Notifica i widget in ascolto alla variazione delle impostazioni e
/// persiste le scelte su archiviazione sicura (FlutterSecureStorage).
class SettingsService extends ChangeNotifier {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _kThemeModeKey = 'app_theme_mode';
  static const _kLocaleKey = 'app_locale';

  final _storage = const FlutterSecureStorage();

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  /// Restituisce true se l'app è attualmente renderizzata con tema scuro.
  bool isDarkMode(BuildContext context) {
    if (_themeMode == ThemeMode.dark) return true;
    if (_themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  /// Inizializza e carica le impostazioni salvate su storage.
  Future<void> init() async {
    try {
      final savedTheme = await _storage.read(key: _kThemeModeKey);
      if (savedTheme == 'light') {
        _themeMode = ThemeMode.light;
      } else if (savedTheme == 'dark') {
        _themeMode = ThemeMode.dark;
      } else {
        _themeMode = ThemeMode.system;
      }

      final savedLocale = await _storage.read(key: _kLocaleKey);
      if (savedLocale == 'it') {
        _locale = const Locale('it');
      } else if (savedLocale == 'en') {
        _locale = const Locale('en');
      } else {
        _locale = null; // Segue la lingua del dispositivo
      }
      notifyListeners();
    } catch (_) {
      // In caso di errore di lettura dello storage, usa le impostazioni predefinite
    }
  }

  /// Imposta la modalità tema e la persiste.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    try {
      final val = mode == ThemeMode.light
          ? 'light'
          : mode == ThemeMode.dark
              ? 'dark'
              : 'system';
      await _storage.write(key: _kThemeModeKey, value: val);
    } catch (_) {}
  }

  /// Inverte rapidamente il tema tra chiaro e scuro.
  Future<void> toggleTheme(BuildContext context) async {
    final dark = isDarkMode(context);
    await setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
  }

  /// Imposta la lingua selezionata (null = lingua di sistema) e la persiste.
  Future<void> setLocale(Locale? loc) async {
    if (_locale == loc) return;
    _locale = loc;
    notifyListeners();
    try {
      final val = loc == null
          ? 'system'
          : loc.languageCode;
      await _storage.write(key: _kLocaleKey, value: val);
    } catch (_) {}
  }
}


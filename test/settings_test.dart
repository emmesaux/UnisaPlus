import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:unisa_plus/l10n/app_localizations.dart';
import 'package:unisa_plus/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppLocalizations fornisce stringhe in italiano e inglese', () {
    final it = AppLocalizations(const Locale('it'));
    final en = AppLocalizations(const Locale('en'));

    expect(it.navOrario, 'Orario');
    expect(en.navOrario, 'Timetable');

    expect(it.navAltro, 'Altro');
    expect(en.navAltro, 'More');

    expect(it.secCarriera, 'Carriera & Didattica');
    expect(en.secCarriera, 'Career & Studies');

    expect(it.temaTitolo, 'Tema dell’app');
    expect(en.temaTitolo, 'App theme');

    expect(it.linguaTitolo, 'Lingua');
    expect(en.linguaTitolo, 'Language');
  });

  test('SettingsService gestisce stato e default', () {
    final settings = SettingsService.instance;
    expect(settings.themeMode, ThemeMode.system);
    expect(settings.locale, isNull);
  });
}


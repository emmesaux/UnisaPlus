import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:upgrader/upgrader.dart';
import 'screens/spid_cie_entry_screen.dart';
import 'screens/home_screen.dart';
import 'screens/selezione_corso_screen.dart';
import 'services/api_service.dart';
import 'services/auth_service.dart';
import 'services/cineca_login_service.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  await initializeDateFormatting('en_US');
  await SettingsService.instance.init();
  runApp(const UniApp());
}

class UniApp extends StatefulWidget {
  const UniApp({super.key});

  @override
  State<UniApp> createState() => _UniAppState();
}

class _UniAppState extends State<UniApp> {
  late final ApiService _api = ApiService(
    baseUrl: 'https://easycourse.unisa.it/EasyApp/api',
  );
  late final AuthService _auth = AuthService(_api);

  // Controllo aggiornamenti: confronta la versione installata con quella
  // pubblicata su App Store (iOS) e Google Play (Android) e, se ne esiste una
  // piu' recente, mostra un popup. Riproposto al massimo una volta al giorno.
  late final Upgrader _upgrader = Upgrader(
    messages: UpgraderMessages(code: 'it'),
    durationUntilAlertAgain: const Duration(days: 1),
  );

  bool _checkingSession = true;
  bool _loggedIn = false;
  // "Dopo" (o salvataggio) nella scelta corso: non riproporla in questa
  // sessione. Salvando, serveSceltaCorso diventa comunque false.
  bool _sceltaCorsoRimandata = false;
  StreamSubscription<Uri>? _appLinkSubscription;

  @override
  void initState() {
    super.initState();
    _restore();
    _listenAppLinks();
  }

  Future<void> _listenAppLinks() async {
    final links = AppLinks();
    try {
      final initialUri = await links.getInitialLink();
      if (initialUri != null) await _handleAppLink(initialUri);
    } catch (_) {
      // Nessun deep link iniziale: si prosegue con la schermata normale.
    }
    if (!mounted) return;
    _appLinkSubscription = links.uriLinkStream.listen(_handleAppLink);
  }

  Future<void> _handleAppLink(Uri uri) async {
    final url = uri.toString();
    final cineca = CinecaLoginService();
    if (!cineca.isAppHandback(url)) return;
    final header = cineca.extractBasicAuthHeader(url);
    if (header == null) return;
    try {
      final profilo = await cineca.fetchProfilo(header);
      await _auth.completaLoginCineca(profilo);
      if (mounted) setState(() => _loggedIn = true);
    } catch (_) {
      // Il login resta nella schermata di ingresso se il callback è invalido.
    }
  }

  @override
  void dispose() {
    _appLinkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _restore() async {
    bool loggedIn = false;
    try {
      final user = await _auth.restoreSession();
      loggedIn = user != null;
    } catch (_) {
      // Nessuna sessione salvata leggibile (es. storage non disponibile):
      // si ricomincia dalla schermata di accesso.
      loggedIn = false;
    }
    setState(() {
      _loggedIn = loggedIn;
      _checkingSession = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: SettingsService.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'Unisa Plus',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: SettingsService.instance.themeMode,
          locale: SettingsService.instance.locale,
          supportedLocales: const [
            Locale('it'),
            Locale('en'),
          ],
          home: _checkingSession
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _loggedIn && _auth.serveSceltaCorso && !_sceltaCorsoRimandata
              // Primo accesso (o nuovo anno accademico): come nell'app campus
              // si chiedono corso e anno, poi si cambiano da Altro.
              ? SelezioneCorsoScreen(
                  authService: _auth,
                  primoAccesso: true,
                  onSalvato: () => setState(() => _sceltaCorsoRimandata = true),
                )
              : _loggedIn
              ? UpgradeAlert(
                  upgrader: _upgrader,
                  child: HomeScreen(
                    authService: _auth,
                    onLogout: () => setState(() {
                      _loggedIn = false;
                      _sceltaCorsoRimandata = false;
                    }),
                  ),
                )
              // Schermata "di ingresso": accesso con SPID/CIE, oppure
              // consultazione delle aule libere senza autenticarsi.
              : SpidCieEntryScreen(
                  authService: _auth,
                  onLoggedIn: () => setState(() => _loggedIn = true),
                ),
        );
      },
    );
  }
}

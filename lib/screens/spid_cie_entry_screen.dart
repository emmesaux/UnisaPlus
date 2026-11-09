import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../l10n/app_localizations.dart';
import '../services/auth_service.dart';
import '../services/demo_mode.dart';
import '../services/settings_service.dart';
import '../widgets/app_arrow.dart';
import '../widgets/app_logo.dart';
import 'aule_libere_screen.dart';
import 'mappa_reale_screen.dart';
import 'presenza_pubblica_screen.dart';
import 'servizi_utili_screen.dart';
import 'spid_cie_login_screen.dart';

/// Schermata iniziale: scegliere di accedere (SPID, CIE o credenziali
/// UNISA, scelte dentro la pagina dell'Identity Provider), oppure
/// consultare le aule libere senza autenticarsi (e informazione pubblica).
class SpidCieEntryScreen extends StatelessWidget {
  const SpidCieEntryScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
  });

  final AuthService authService;
  final VoidCallback onLoggedIn;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const AppLogo(size: 48, borderRadius: 12),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              kAppName,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            Text(
                              kAppTagline,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.toggleLanguageTooltip,
                        // La bandierina riflette la lingua effettivamente mostrata
                        // (scelta manuale o, se assente, quella di sistema), così
                        // all'avvio non è mai incoerente con i testi.
                        icon: Text(
                          l10n.isEnglish ? '🇬🇧' : '🇮🇹',
                          style: const TextStyle(fontSize: 20),
                        ),
                        onPressed: () {
                          SettingsService.instance.setLocale(
                            Locale(l10n.isEnglish ? 'it' : 'en'),
                          );
                        },
                      ),
                      IconButton(
                        tooltip: l10n.toggleThemeTooltip,
                        icon: Icon(
                          SettingsService.instance.isDarkMode(context)
                              ? Icons.light_mode_outlined
                              : Icons.dark_mode_outlined,
                        ),
                        onPressed: () => SettingsService.instance.toggleTheme(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    '${l10n.welcomeTo} $kAppName',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.loginSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Image.asset(
                        'assets/loghi/spid-ico-circle-bb.png',
                        height: 18,
                        width: 18,
                      ),
                    ),
                    label: Text(l10n.loginWithSpid),
                    onPressed: () => _apriLogin(context),
                  ),
                  const SizedBox(height: 10),
                  _SpidProvidersStrip(onTap: () => _apriLogin(context)),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    icon: SvgPicture.asset(
                      'assets/loghi/logo_cie_id.svg',
                      height: 22,
                      colorFilter: ColorFilter.mode(
                        scheme.primary,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: Text(l10n.loginWithCie),
                    onPressed: () => _apriLogin(context),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    l10n.orBrowseFreely,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: Text(l10n.freeRoomsNow),
                    subtitle: Text(l10n.freeRoomsNowSub),
                    trailing: const AppArrow(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: Text(l10n.freeRoomsNow)),
                          body: AuleLibereScreen(api: authService.api),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: Text(l10n.checkInWithoutLogin),
                    subtitle: Text(l10n.checkInWithoutLoginSub),
                    trailing: const AppArrow(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PresenzaPubblicaScreen(api: authService.api),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.map_outlined),
                    title: Text(l10n.campusMap),
                    subtitle: Text(l10n.campusMapSub),
                    trailing: const AppArrow(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappaRealeScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hub_outlined),
                    title: Text(l10n.usefulServices),
                    subtitle: Text(l10n.usefulServicesSub),
                    trailing: const AppArrow(),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ServiziUtiliScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Accesso dimostrativo per la verifica App Store (Apple
                  // Guideline 2.1a): mostra dati di esempio su tutte le
                  // schermate, senza SPID/CIE. Credenziali nelle note di review.
                  OutlinedButton.icon(
                    onPressed: () => _apriDemo(context),
                    icon: const Icon(Icons.verified_user_outlined, size: 18),
                    label: Text(l10n.demoMode),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.onSurfaceVariant,
                      textStyle: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 18),
                  // Disclaimer: app non ufficiale (copre la Guideline 5.2.3).
                  Text(
                    l10n.isEnglish
                        ? 'Unofficial, independent app — not affiliated with, '
                            'endorsed by, or developed by the University of Salerno.'
                        : 'App non ufficiale e indipendente — non affiliata, '
                            'approvata o sviluppata dall\'Università degli Studi di Salerno.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _apriLogin(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SpidCieLoginScreen(
          authService: authService,
          onLoggedIn: () {
            Navigator.of(context).pop();
            onLoggedIn();
          },
        ),
      ),
    );
  }

  /// Dialog per i recensori App Store: inserendo le credenziali comunicate
  /// nelle "App Review Information" si entra in modalità dimostrativa, con
  /// dati di esempio su orario, libretto, esami, presenze e saldo mensa.
  void _apriDemo(BuildContext context) {
    final userCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        String? errore;
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> accedi() async {
              if (!DemoMode.matches(userCtrl.text, passCtrl.text)) {
                setStateDialog(() => errore = 'Credenziali non valide.');
                return;
              }
              await authService.loginDemo();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              onLoggedIn();
            }

            return AlertDialog(
              title: const Text('Accesso dimostrativo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Riservato alla verifica App Store. Mostra dati di esempio '
                    'su tutte le schermate, senza SPID/CIE.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: userCtrl,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: const InputDecoration(
                      labelText: 'Utente',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => accedi(),
                  ),
                  if (errore != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      errore!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: accedi,
                  child: const Text('Accedi'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Riquadro scuro con l'ora corrente in cifre grandi, come un vero
/// tabellone: e il primo elemento che si vede, prima ancora del saluto.
/// Striscia con i loghi reali dei gestori di identità SPID supportati.
/// Tutti aprono lo stesso accesso CINECA (dove si sceglie il gestore);
/// i loghi sono quelli ufficiali AgID.
class _SpidProvidersStrip extends StatelessWidget {
  const _SpidProvidersStrip({required this.onTap});
  final VoidCallback onTap;

  static const _providers = [
    'spid-idp-posteid.png',
    'spid-idp-timid.png',
    'spid-idp-arubaid.png',
    'spid-idp-infocertid.png',
    'spid-idp-lepidaid.png',
    'spid-idp-namirialid.png',
    'spid-idp-sielteid.png',
    'spid-idp-spiditalia.png',
    'spid-idp-teamsystemid.png',
    'spid-idp-intesaid.png',
    'spid-idp-etnaid.png',
    'spid-idp-infocamereid.png',
    'spid-idp-intesigroupspid.png',
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'con il tuo gestore SPID',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final p in _providers) _logo(p)],
        ),
      ],
    );
  }

  Widget _logo(String file) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 64,
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
          child: Image.asset(
            'assets/loghi/$file',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}


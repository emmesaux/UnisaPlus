import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/preferenze_corso.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../theme/app_theme.dart';
import 'agenda_esami_screen.dart';
import 'bacheca_esiti_screen.dart';
import 'libretto_screen.dart';
import 'mappa_campus_screen.dart';
import 'mensa_screen.dart';
import 'messaggi_screen.dart';
import 'piano_studi_screen.dart';
import 'selezione_corso_screen.dart';
import 'servizi_utili_screen.dart';
import 'tasse_screen.dart';

/// Raccoglie le funzioni di carriera, campus e servizi in un'unica
/// voce di navigazione strutturata per sezioni.
class AltroScreen extends StatelessWidget {
  const AltroScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // --- SEZIONE: CARRIERA & DIDATTICA ---
        _SezioneHeader(titolo: l10n.secCarriera),
        _Voce(
          icon: Icons.auto_stories_outlined,
          titolo: l10n.librettoTitolo,
          sottotitolo: l10n.librettoSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.librettoAppBar)),
                body: LibrettoScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.account_tree_outlined,
          titolo: l10n.pianoStudiTitolo,
          sottotitolo: l10n.pianoStudiSub,
          badge: l10n.nuovoBadge,
          coloreBadge: AppColors.smeraldo,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PianoStudiScreen(authService: authService),
            ),
          ),
        ),
        _Voce(
          icon: Icons.fact_check_outlined,
          titolo: l10n.bachecaEsitiTitolo,
          sottotitolo: l10n.bachecaEsitiSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.bachecaEsitiTitolo)),
                body: BachecaEsitiScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.menu_book_outlined,
          titolo: l10n.agendaEsamiTitolo,
          sottotitolo: l10n.agendaEsamiSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.agendaEsamiTitolo)),
                body: AgendaEsamiScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.account_balance_wallet_outlined,
          titolo: l10n.tasseTitolo,
          sottotitolo: l10n.tasseSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.tasseAppBar)),
                body: TasseScreen(authService: authService),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- SEZIONE: CAMPUS & SERVIZI ---
        _SezioneHeader(titolo: l10n.secCampus),
        _Voce(
          icon: Icons.map_outlined,
          titolo: l10n.mappaTitolo,
          sottotitolo: l10n.mappaSub,
          badge: 'Mappe & GPS',
          coloreBadge: AppColors.arancio,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MappaCampusScreen(api: authService.api),
            ),
          ),
        ),
        _Voce(
          icon: Icons.hub_outlined,
          titolo: l10n.serviziTitolo,
          sottotitolo: l10n.serviziSub,
          badge: 'Link Utili',
          coloreBadge: AppColors.zolfo,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const ServiziUtiliScreen(),
            ),
          ),
        ),
        _Voce(
          icon: Icons.restaurant_outlined,
          titolo: l10n.mensaTitolo,
          sottotitolo: l10n.mensaSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.mensaTitolo)),
                body: MensaScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.mail_outline,
          titolo: l10n.messaggiTitolo,
          sottotitolo: l10n.messaggiSub,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: Text(l10n.messaggiTitolo)),
                body: MessaggiScreen(authService: authService),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- SEZIONE: IMPOSTAZIONI ---
        _SezioneHeader(titolo: l10n.secImpostazioni),
        ValueListenableBuilder<PreferenzeCorso?>(
          valueListenable: authService.preferenzeCorso,
          builder: (context, pref, _) => _Voce(
            icon: Icons.school_outlined,
            titolo: l10n.corsoAnnoTitolo,
            sottotitolo: pref == null
                ? l10n.corsoAnnoNonImpostato
                : '${pref.corsoLabel} · ${pref.annoLabel}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SelezioneCorsoScreen(authService: authService),
              ),
            ),
          ),
        ),
        ListenableBuilder(
          listenable: SettingsService.instance,
          builder: (context, _) {
            final mode = SettingsService.instance.themeMode;
            final themeLabel = mode == ThemeMode.light
                ? l10n.temaSubChiaro
                : mode == ThemeMode.dark
                    ? l10n.temaSubScuro
                    : l10n.temaSubSistema;
            final loc = SettingsService.instance.locale;
            final langLabel = loc == null
                ? l10n.linguaSubSistema
                : loc.languageCode == 'en'
                    ? 'English'
                    : 'Italiano';

            return Column(
              children: [
                _Voce(
                  icon: Icons.palette_outlined,
                  titolo: l10n.temaTitolo,
                  sottotitolo: themeLabel,
                  onTap: () => _mostraSelettoreTema(context),
                ),
                _Voce(
                  icon: Icons.language_outlined,
                  titolo: l10n.linguaTitolo,
                  sottotitolo: langLabel,
                  onTap: () => _mostraSelettoreLingua(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _mostraSelettoreTema(BuildContext context) {
    final l10n = context.l10n;
    final current = SettingsService.instance.themeMode;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  l10n.temaDialogTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.brightness_auto_outlined),
                title: Text(l10n.temaOpzioneSistema),
                subtitle: Text(l10n.temaSubSistema),
                value: ThemeMode.system,
                groupValue: current,
                onChanged: (mode) {
                  if (mode != null) {
                    SettingsService.instance.setThemeMode(mode);
                  }
                  Navigator.of(sheetContext).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.light_mode_outlined),
                title: Text(l10n.temaOpzioneChiaro),
                subtitle: Text(l10n.temaSubChiaro),
                value: ThemeMode.light,
                groupValue: current,
                onChanged: (mode) {
                  if (mode != null) {
                    SettingsService.instance.setThemeMode(mode);
                  }
                  Navigator.of(sheetContext).pop();
                },
              ),
              RadioListTile<ThemeMode>(
                secondary: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.temaOpzioneScuro),
                subtitle: Text(l10n.temaSubScuro),
                value: ThemeMode.dark,
                groupValue: current,
                onChanged: (mode) {
                  if (mode != null) {
                    SettingsService.instance.setThemeMode(mode);
                  }
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _mostraSelettoreLingua(BuildContext context) {
    final l10n = context.l10n;
    final current = SettingsService.instance.locale;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  l10n.linguaDialogTitle,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              RadioListTile<String>(
                secondary: const Icon(Icons.phonelink_setup_outlined),
                title: Text(l10n.linguaOpzioneSistema),
                subtitle: Text(l10n.linguaSubSistema),
                value: 'system',
                groupValue: current == null ? 'system' : current.languageCode,
                onChanged: (_) {
                  SettingsService.instance.setLocale(null);
                  Navigator.of(sheetContext).pop();
                },
              ),
              RadioListTile<String>(
                secondary: const Text('🇮🇹', style: TextStyle(fontSize: 20)),
                title: const Text('Italiano'),
                value: 'it',
                groupValue: current == null ? 'system' : current.languageCode,
                onChanged: (_) {
                  SettingsService.instance.setLocale(const Locale('it'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              RadioListTile<String>(
                secondary: const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                title: const Text('English'),
                value: 'en',
                groupValue: current == null ? 'system' : current.languageCode,
                onChanged: (_) {
                  SettingsService.instance.setLocale(const Locale('en'));
                  Navigator.of(sheetContext).pop();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }
}

class _SezioneHeader extends StatelessWidget {
  const _SezioneHeader({required this.titolo});
  final String titolo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        titolo.toUpperCase(),
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
          color: scheme.primary,
        ),
      ),
    );
  }
}

class _Voce extends StatelessWidget {
  const _Voce({
    required this.icon,
    required this.titolo,
    required this.sottotitolo,
    required this.onTap,
    this.badge,
    this.coloreBadge,
  });

  final IconData icon;
  final String titolo;
  final String sottotitolo;
  final VoidCallback onTap;
  final String? badge;
  final Color? coloreBadge;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: scheme.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titolo,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (coloreBadge ?? scheme.primary)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: coloreBadge ?? scheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sottotitolo,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
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
    final en = l10n.isEnglish;
    void go(Widget page) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page));
    Scaffold sc(String titolo, Widget body) =>
        Scaffold(appBar: AppBar(title: Text(titolo)), body: body);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        _SezioneHeader(titolo: l10n.secCarriera),
        const SizedBox(height: 10),
        _TileGrid(tiles: [
          _TileData(Icons.auto_stories_outlined, 'Libretto', AppColors.mare,
              () => go(sc(l10n.librettoAppBar,
                  LibrettoScreen(authService: authService)))),
          _TileData(Icons.account_tree_outlined, en ? 'Study plan' : 'Piano studi',
              const Color(0xFF2E5EAA),
              () => go(PianoStudiScreen(authService: authService)),
              badge: l10n.nuovoBadge),
          _TileData(Icons.fact_check_outlined, en ? 'Results' : 'Esiti',
              AppColors.smeraldo,
              () => go(sc(l10n.bachecaEsitiTitolo,
                  BachecaEsitiScreen(authService: authService)))),
          _TileData(Icons.menu_book_outlined, en ? 'Exams' : 'Esami',
              AppColors.corallo,
              () => go(sc(l10n.agendaEsamiTitolo,
                  AgendaEsamiScreen(authService: authService)))),
          _TileData(Icons.account_balance_wallet_outlined, en ? 'Fees' : 'Tasse',
              AppColors.mareChiaro,
              () => go(sc(l10n.tasseAppBar,
                  TasseScreen(authService: authService)))),
        ]),
        const SizedBox(height: 24),
        _SezioneHeader(titolo: l10n.secCampus),
        const SizedBox(height: 10),
        _TileGrid(tiles: [
          _TileData(Icons.map_outlined, en ? 'Map' : 'Mappa', AppColors.arancio,
              () => go(MappaCampusScreen(api: authService.api))),
          _TileData(Icons.hub_outlined, en ? 'Services' : 'Servizi',
              const Color(0xFF7B5EA7), () => go(const ServiziUtiliScreen())),
          _TileData(Icons.restaurant_outlined, en ? 'Canteen' : 'Mensa',
              AppColors.corallo,
              () => go(sc(l10n.mensaTitolo, MensaScreen(authService: authService)))),
          _TileData(Icons.mail_outline, en ? 'Messages' : 'Messaggi',
              const Color(0xFF158A8A),
              () => go(sc(l10n.messaggiTitolo,
                  MessaggiScreen(authService: authService)))),
        ]),
        const SizedBox(height: 20),

        // --- SEZIONE: IMPOSTAZIONI ---
        _SezioneHeader(titolo: l10n.secImpostazioni),
        const SizedBox(height: 10),
        ListenableBuilder(
          listenable: Listenable.merge(
              [authService.preferenzeCorso, SettingsService.instance]),
          builder: (context, _) {
            final pref = authService.preferenzeCorso.value;
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
            return _TileGrid(tiles: [
              _TileData(Icons.school_outlined, en ? 'Course' : 'Corso',
                  AppColors.mare,
                  () => go(SelezioneCorsoScreen(authService: authService)),
                  subtitle: pref == null ? l10n.corsoAnnoNonImpostato : pref.annoLabel),
              _TileData(Icons.palette_outlined, en ? 'Theme' : 'Tema',
                  const Color(0xFF7B5EA7), () => _mostraSelettoreTema(context),
                  subtitle: themeLabel),
              _TileData(Icons.language_outlined, en ? 'Language' : 'Lingua',
                  const Color(0xFF158A8A), () => _mostraSelettoreLingua(context),
                  subtitle: langLabel),
            ]);
          },
        )
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

class _TileData {
  const _TileData(this.icon, this.label, this.colore, this.onTap,
      {this.badge, this.subtitle});
  final IconData icon;
  final String label;
  final Color colore;
  final VoidCallback onTap;
  final String? badge;
  final String? subtitle;
}

/// Griglia di quadretti (3 per riga) tramite Wrap: l'ultima riga incompleta
/// non lascia celle vuote, niente spazi inutili.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.tiles});
  final List<_TileData> tiles;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        const spacing = 12.0;
        final w = (c.maxWidth - spacing * 2) / 3;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final t in tiles) SizedBox(width: w, child: _Tile(data: t)),
          ],
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.data});
  final _TileData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.outlineVariant),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: data.colore.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(data.icon, color: data.colore, size: 22),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (data.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      data.subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontSize: 11,
                          ),
                    ),
                  ],
                ],
              ),
              if (data.badge != null)
                Positioned(
                  top: -4,
                  right: -2,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.smeraldo,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      data.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

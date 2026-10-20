import 'package:flutter/material.dart';
import '../models/preferenze_corso.dart';
import '../services/auth_service.dart';
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
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        // --- SEZIONE: CARRIERA & DIDATTICA ---
        const _SezioneHeader(titolo: 'Carriera & Didattica'),
        _Voce(
          icon: Icons.auto_stories_outlined,
          titolo: 'Libretto e previsione laurea',
          sottotitolo: 'Esami sostenuti, medie, CFU e simulatore voto di laurea',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Libretto e laurea')),
                body: LibrettoScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.account_tree_outlined,
          titolo: 'Piano di studi',
          sottotitolo: 'Insegnamenti per anno di corso, CFU conseguiti e da sostenere',
          badge: 'Nuovo',
          coloreBadge: AppColors.smeraldo,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PianoStudiScreen(authService: authService),
            ),
          ),
        ),
        _Voce(
          icon: Icons.fact_check_outlined,
          titolo: 'Bacheca esiti',
          sottotitolo: 'Esiti pubblicati, presa visione, accetta o rifiuta voto',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Bacheca esiti')),
                body: BachecaEsitiScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.menu_book_outlined,
          titolo: 'Agenda esami',
          sottotitolo: 'Esami prenotati e appelli disponibili',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Agenda esami')),
                body: AgendaEsamiScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.account_balance_wallet_outlined,
          titolo: 'Tasse',
          sottotitolo: 'Contributi universitari, scadenze, stato pagamenti e IUV',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Tasse universitarie')),
                body: TasseScreen(authService: authService),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- SEZIONE: CAMPUS & SERVIZI ---
        const _SezioneHeader(titolo: 'Campus & Servizi'),
        _Voce(
          icon: Icons.map_outlined,
          titolo: 'Mappa dei Campus',
          sottotitolo: 'Fisciano e Baronissi: edifici, aule, biblioteche, CUS e bus',
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
          titolo: 'Servizi e collegamenti utili',
          sottotitolo: 'Biblioteche di Ateneo, ADISURC, CUS Salerno, Esse3 e CLA',
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
          titolo: 'Mensa ADISURC',
          sottotitolo: 'QR dinamico di accesso e saldo borsellino',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Mensa')),
                body: MensaScreen(authService: authService),
              ),
            ),
          ),
        ),
        _Voce(
          icon: Icons.mail_outline,
          titolo: 'Messaggi',
          sottotitolo: 'Avvisi di Ateneo e del tuo Dipartimento',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('Messaggi')),
                body: MessaggiScreen(authService: authService),
              ),
            ),
          ),
        ),

        const SizedBox(height: 20),

        // --- SEZIONE: IMPOSTAZIONI ---
        const _SezioneHeader(titolo: 'Impostazioni'),
        ValueListenableBuilder<PreferenzeCorso?>(
          valueListenable: authService.preferenzeCorso,
          builder: (context, pref, _) => _Voce(
            icon: Icons.school_outlined,
            titolo: 'Corso e anno',
            sottotitolo: pref == null
                ? 'Non impostati: scegli per vedere l’orario'
                : '${pref.corsoLabel} · ${pref.annoLabel}',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => SelezioneCorsoScreen(authService: authService),
              ),
            ),
          ),
        ),
      ],
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

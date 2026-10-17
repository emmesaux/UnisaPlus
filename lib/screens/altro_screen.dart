import 'package:flutter/material.dart';
import '../models/preferenze_corso.dart';
import '../services/auth_service.dart';
import 'agenda_esami_screen.dart';
import 'bacheca_esiti_screen.dart';
import 'libretto_screen.dart';
import 'mensa_screen.dart';
import 'messaggi_screen.dart';
import 'selezione_corso_screen.dart';
import 'tasse_screen.dart';

/// Raccoglie le funzioni meno frequenti in un'unica voce di
/// navigazione, per non superare le 5 destinazioni consigliate nella
/// barra inferiore (oltre si affollano e i target diventano piccoli).
class AltroScreen extends StatelessWidget {
  const AltroScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
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
        _Voce(
          icon: Icons.restaurant_outlined,
          titolo: 'Mensa',
          sottotitolo: 'QR di accesso e saldo ADiSURC',
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
        // Impostazioni: corso e anno scelti al primo accesso.
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

class _Voce extends StatelessWidget {
  const _Voce({required this.icon, required this.titolo, required this.sottotitolo, required this.onTap});
  final IconData icon;
  final String titolo;
  final String sottotitolo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(4)),
              child: Icon(icon, color: scheme.onSurface, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titolo, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(sottotitolo, style: Theme.of(context).textTheme.bodySmall),
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

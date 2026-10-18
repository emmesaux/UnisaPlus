import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'aule_libere_screen.dart';
import 'mappa_campus_screen.dart';
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
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Tabellone: ora e orario reali, come intestazione.
                  _Tabellone(ora: TimeOfDay.now()),
                  const SizedBox(height: 24),
                  Text(
                    'Bentornato in $kAppName',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Accedi con SPID o CIE per vedere orario, libretto, esami, tasse, mensa e la tua presenza.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Accedi con SPID'),
                    onPressed: () => _apriLogin(context),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.credit_card),
                    label: const Text('Accedi con CIE'),
                    onPressed: () => _apriLogin(context),
                  ),
                  const SizedBox(height: 28),
                  Divider(color: scheme.outlineVariant),
                  const SizedBox(height: 16),
                  Text(
                    'Senza accedere',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.meeting_room_outlined),
                    title: const Text('Vedi le aule libere ora'),
                    subtitle: const Text(
                      'Disponibilita pubblica, nessun account richiesto',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => Scaffold(
                          appBar: AppBar(title: const Text('Aule libere')),
                          body: AuleLibereScreen(api: authService.api),
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.how_to_reg_outlined),
                    title: const Text('Rileva presenza con matricola'),
                    subtitle: const Text('Più matricole, senza SPID/CIE'),
                    trailing: const Icon(Icons.chevron_right),
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
                    title: const Text('Mappa dei Campus'),
                    subtitle: const Text('Fisciano e Baronissi: edifici, aule, CUS e bus'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MappaCampusScreen(),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.hub_outlined),
                    title: const Text('Servizi e collegamenti utili'),
                    subtitle: const Text('Biblioteche & sale studio, ADISURC, CUS Salerno'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ServiziUtiliScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Puoi rilevare una o più presenze con la matricola senza accedere. '
                    'Per vedere i tuoi dati personali usa SPID o CIE.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
}

/// Riquadro scuro con l'ora corrente in cifre grandi, come un vero
/// tabellone: e il primo elemento che si vede, prima ancora del saluto.
class _Tabellone extends StatelessWidget {
  const _Tabellone({required this.ora});
  final TimeOfDay ora;

  @override
  Widget build(BuildContext context) {
    final hh = ora.hour.toString().padLeft(2, '0');
    final mm = ora.minute.toString().padLeft(2, '0');
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inchiostro,
        borderRadius: BorderRadius.circular(6),
      ),
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Text(
            'UNIVERSITA DI SALERNO',
            style: AppTheme.codice(size: 12, color: AppColors.nebbiaChiara),
          ),
          const SizedBox(height: 8),
          Text(
            '$hh:$mm',
            style: AppTheme.numerico(
              size: 56,
              color: AppColors.pietra,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

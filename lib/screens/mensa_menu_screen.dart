import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/adisurc_service.dart';
import '../widgets/app_segmented.dart';

/// Menù della mensa (Pranzo / Cena) della settimana, dalla pagina ufficiale
/// ADiSURC di Fisciano e Baronissi. Aperta toccando una mensa sulla mappa.
class MensaMenuScreen extends StatefulWidget {
  const MensaMenuScreen({super.key, this.titolo = 'Menù della Mensa'});
  final String titolo;

  @override
  State<MensaMenuScreen> createState() => _MensaMenuScreenState();
}

class _MensaMenuScreenState extends State<MensaMenuScreen> {
  final _adisurc = AdisurcService();
  late Future<List<MensaMenuGiorno>> _future;
  bool _cena = false; // false = Pranzo, true = Cena

  @override
  void initState() {
    super.initState();
    // Dopo le 16:00 proponi direttamente la cena.
    _cena = DateTime.now().hour >= 16;
    _future = _adisurc.getMenuSettimana();
  }

  Future<void> _apriPdf(String url) async {
    final ok = await launchUrl(Uri.parse(url),
        mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il menù')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.titolo)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: AppSegmented<bool>(
              value: _cena,
              onChanged: (v) => setState(() => _cena = v),
              segments: const [
                AppSegment(value: false, label: 'Pranzo', icon: Icons.light_mode_outlined),
                AppSegment(value: true, label: 'Cena', icon: Icons.nightlight_outlined),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<MensaMenuGiorno>>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _Errore(
                    onRetry: () => setState(
                        () => _future = _adisurc.getMenuSettimana()),
                  );
                }
                final giorni = snap.data ?? const [];
                if (giorni.isEmpty) {
                  return _Errore(
                    messaggio:
                        'Nessun menù pubblicato al momento sul sito ADiSURC.',
                    onRetry: () => setState(
                        () => _future = _adisurc.getMenuSettimana()),
                  );
                }
                final oggi = DateTime.now().weekday;
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: giorni.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final g = giorni[i];
                    final url = _cena ? g.cenaPdfUrl : g.pranzoPdfUrl;
                    final isOggi = g.weekday == oggi;
                    return _GiornoCard(
                      giorno: g,
                      cena: _cena,
                      url: url,
                      evidenzia: isOggi,
                      onApri: url == null ? null : () => _apriPdf(url),
                      scheme: scheme,
                    );
                  },
                );
              },
            ),
          ),
          // Fonte ufficiale.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Icon(Icons.verified_outlined, size: 14, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Fonte: menù ufficiale ADiSURC Campania',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GiornoCard extends StatelessWidget {
  const _GiornoCard({
    required this.giorno,
    required this.cena,
    required this.url,
    required this.evidenzia,
    required this.onApri,
    required this.scheme,
  });
  final MensaMenuGiorno giorno;
  final bool cena;
  final String? url;
  final bool evidenzia;
  final VoidCallback? onApri;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: evidenzia ? scheme.primaryContainer.withValues(alpha: 0.5) : scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: evidenzia ? scheme.primary : scheme.outlineVariant,
          width: evidenzia ? 1.4 : 1,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      giorno.nomeGiorno,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    if (evidenzia) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('Oggi',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: scheme.onPrimary)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  giorno.dataLabel,
                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          if (onApri != null)
            FilledButton.tonalIcon(
              onPressed: onApri,
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
              label: Text(cena ? 'Cena' : 'Pranzo'),
            )
          else
            Text(
              'non disp.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _Errore extends StatelessWidget {
  const _Errore({this.messaggio, required this.onRetry});
  final String? messaggio;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restaurant_outlined, size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              messaggio ?? 'Impossibile caricare il menù della mensa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../widgets/app_arrow.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/presenza.dart';
import '../services/api_service.dart';
import '../services/easybadge_service.dart';
import '../theme/app_theme.dart';
import 'presenze_screen.dart';

/// Rilevazione e consultazione presenze tramite la propria matricola, collegata
/// agli endpoint reali EasyBadge di UNISA (`TimbratureApi.php`,
/// `corso_iscritti.php` e `timbrature.php`). Registra la presenza della
/// matricola inserita, inquadrando il QR della lezione proiettato in aula.
class PresenzaPubblicaScreen extends StatefulWidget {
  const PresenzaPubblicaScreen({
    super.key,
    required this.api,
    this.autenticazione = false,
    this.matricolaIniziale,
  });

  final ApiService api;
  final bool autenticazione;
  final String? matricolaIniziale;

  @override
  State<PresenzaPubblicaScreen> createState() => _PresenzaPubblicaScreenState();
}

class _PresenzaPubblicaScreenState extends State<PresenzaPubblicaScreen> {
  final _badgeService = EasyBadgeService();
  final _matricolaController = TextEditingController();
  final _codiceController = TextEditingController();

  bool _scanning = false;
  bool _sending = false;
  bool _codeFromQr = false;
  String? _feedback;
  bool _success = false;

  String _matricolaConsultazione = '';
  Future<List<CorsoPresenza>>? _corsiFuture;

  @override
  void initState() {
    super.initState();
    final iniziale = widget.matricolaIniziale?.trim().toUpperCase();
    if (iniziale != null && iniziale.isNotEmpty) {
      _matricolaController.text = iniziale;
      _matricolaConsultazione = iniziale;
      _corsiFuture = _badgeService.getCorsi(iniziale);
    }
    _caricaUltimaMatricola();
  }

  Future<void> _caricaUltimaMatricola() async {
    final saved = await _badgeService.getUltimaMatricola();
    if (!mounted || saved == null || saved.isEmpty) return;
    setState(() {
      _matricolaController.text = saved;
      _matricolaConsultazione = saved;
      _corsiFuture = _badgeService.getCorsi(saved);
    });
  }

  @override
  void dispose() {
    _matricolaController.dispose();
    _codiceController.dispose();
    super.dispose();
  }

  bool _isValidMatricola(String m) => RegExp(r'^[A-Z0-9]{5,16}$').hasMatch(m);

  Future<void> _scan(BarcodeCapture capture) async {
    if (!_scanning) return;
    final value = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (value == null || value.trim().isEmpty) return;
    final estratto = EasyBadgeService.estraiCodiceLezione(
      value.trim(),
      fromQr: true,
    );
    setState(() {
      _scanning = false;
      _codiceController.text = estratto;
      _codeFromQr = true;
    });
  }

  Future<void> _submit() async {
    final codice = _codiceController.text.trim();
    final matricola = _matricolaController.text.trim().toUpperCase();

    if (matricola.isEmpty || !_isValidMatricola(matricola)) {
      setState(() {
        _feedback = 'Inserisci una matricola valida (solo lettere e numeri).';
        _success = false;
      });
      return;
    }
    if (codice.isEmpty) {
      setState(() {
        _feedback =
            'Scansiona il QR proiettato in aula o inserisci il codice lezione.';
        _success = false;
      });
      return;
    }

    setState(() {
      _sending = true;
      _feedback = null;
    });
    await _badgeService.saveUltimaMatricola(matricola);

    try {
      final msg = await _badgeService.rilevaPresenza(
        matricola: matricola,
        codiceLezioneRaw: codice,
        autenticazione: widget.autenticazione,
        fromQr: _codeFromQr,
      );
      if (!mounted) return;
      setState(() {
        _sending = false;
        _feedback = msg;
        _success = true;
        _codiceController.clear();
        _codeFromQr = false;
        _matricolaConsultazione = matricola;
        _corsiFuture = _badgeService.getCorsi(matricola);
      });
    } on EasyBadgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _feedback = e.message;
        _success = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _feedback =
            'Impossibile contattare il servizio EasyBadge. Riprova più tardi.';
        _success = false;
      });
    }
  }

  void _consultaPresenzeMatricola() {
    final target = _matricolaController.text.trim().toUpperCase().isNotEmpty
        ? _matricolaController.text.trim().toUpperCase()
        : _matricolaConsultazione;
    if (target.isEmpty) {
      setState(() {
        _feedback = 'Inserisci la tua matricola per consultare le presenze.';
        _success = false;
      });
      return;
    }
    _badgeService.saveUltimaMatricola(target);
    setState(() {
      _matricolaConsultazione = target;
      _corsiFuture = _badgeService.getCorsi(target);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.autenticazione
              ? 'Rilevazione presenze'
              : 'Presenze senza accesso',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(
            'Rileva presenza in aula',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Inserisci la tua matricola (es. 0512112345 o NF12100013) e '
            'inquadra il QR proiettato dal docente in aula oppure digita il '
            'codice lezione.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _matricolaController,
            keyboardType: TextInputType.text,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            style: AppTheme.codice(size: 15, color: scheme.onSurface),
            decoration: InputDecoration(
              labelText: 'La tua matricola',
              hintText: 'Es. 0512112345',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: IconButton(
                tooltip: 'Consulta corsi e presenze di questa matricola',
                onPressed: _sending ? null : _consultaPresenzeMatricola,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _consultaPresenzeMatricola(),
          ),
          const SizedBox(height: 12),
          if (_scanning)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    MobileScanner(onDetect: _scan),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: () => setState(() => _scanning = false),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                            _scanning = true;
                            _feedback = null;
                          }),
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text('Scansiona QR lezione proiettato in aula'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _codiceController,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTheme.codice(size: 14, color: scheme.onSurface),
                  onChanged: (_) => _codeFromQr = false,
                  decoration: const InputDecoration(
                    labelText: 'Codice lezione',
                    hintText: 'Codice estratto dal QR o comunicato dal docente',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.how_to_reg),
            label: const Text('Registra presenza'),
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_success ? const Color(0xFF2E7D5B) : AppColors.corallo)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _success ? const Color(0xFF2E7D5B) : AppColors.corallo,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _success ? Icons.check_circle : Icons.error_outline,
                    color:
                        _success ? const Color(0xFF2E7D5B) : AppColors.corallo,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _feedback!,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 16),

          // --- Consultazione presenze tramite matricola ---
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consulta le tue presenze',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _matricolaConsultazione.isNotEmpty
                          ? 'Riepilogo frequenza per matricola $_matricolaConsultazione'
                          : 'Inserisci la matricola sopra e tocca la lente per vedere i tuoi corsi',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Aggiorna presenze',
                onPressed: _consultaPresenzeMatricola,
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_corsiFuture != null)
            FutureBuilder<List<CorsoPresenza>>(
              future: _corsiFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Impossibile caricare le presenze per $_matricolaConsultazione. Verifica la connessione e riprova.',
                      style: TextStyle(color: scheme.error),
                    ),
                  );
                }
                final corsi = snapshot.data ?? [];
                if (corsi.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Text(
                      'Nessun corso con presenze registrate trovato per la matricola $_matricolaConsultazione.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final corso in corsi)
                      _CorsoPresenzaPubblicaTile(
                        corso: corso,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PresenzeCorsoScreen(
                              badge: _badgeService,
                              matricola: _matricolaConsultazione,
                              corso: corso,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _CorsoPresenzaPubblicaTile extends StatelessWidget {
  const _CorsoPresenzaPubblicaTile({required this.corso, required this.onTap});

  final CorsoPresenza corso;
  final VoidCallback onTap;

  String _ore(int minuti) {
    if (minuti <= 0) return '0 h';
    if (minuti % 60 == 0) return '${minuti ~/ 60} h';
    return '${minuti ~/ 60}h ${minuti % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colore = corso.stato == 'frequentante'
        ? const Color(0xFF2E7D5B)
        : (corso.stato == 'in_frequenza' ? AppColors.zolfo : scheme.primary);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(corso.nome, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          '${_ore(corso.frequentateMinuti)} frequentate su ${_ore(corso.svolteMinuti)}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        leading: Text(
          '${corso.percentuale.toStringAsFixed(0)}%',
          style: AppTheme.numerico(size: 18, color: colore),
        ),
        trailing: const AppArrow(),
      ),
    );
  }
}

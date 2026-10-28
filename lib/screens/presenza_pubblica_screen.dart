import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/presenza.dart';
import '../services/api_service.dart';
import '../services/easybadge_service.dart';
import '../theme/app_theme.dart';
import 'presenze_screen.dart';

/// Rilevazione e consultazione presenze senza accesso (tramite matricola),
/// collegata agli endpoint reali EasyBadge di UNISA (`TimbratureApi.php`,
/// `corso_iscritti.php` e `timbrature.php`).
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
  final _matricole = <String>[];

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

  void _addMatricola() {
    final matricola = _matricolaController.text.trim().toUpperCase();
    if (matricola.isEmpty) return;
    if (!_isValidMatricola(matricola)) {
      setState(() {
        _feedback = 'Inserisci una matricola valida (solo lettere e numeri).';
        _success = false;
      });
      return;
    }
    if (_matricole.contains(matricola)) {
      setState(() {
        _feedback = 'La matricola $matricola è già presente nella lista.';
        _success = false;
      });
      return;
    }
    _badgeService.saveUltimaMatricola(matricola);
    setState(() {
      _matricole.add(matricola);
      _matricolaController.clear();
      _feedback = null;
      _matricolaConsultazione = matricola;
      _corsiFuture = _badgeService.getCorsi(matricola);
    });
  }

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
    // Se l'utente ha scritto la matricola nel campo senza premere "+",
    // la includiamo automaticamente così basta un solo tocco.
    final pendingInput = _matricolaController.text.trim().toUpperCase();
    final targetMatricole = <String>[..._matricole];
    if (pendingInput.isNotEmpty) {
      if (!_isValidMatricola(pendingInput)) {
        setState(() {
          _feedback = 'La matricola "$pendingInput" non è valida.';
          _success = false;
        });
        return;
      }
      if (!targetMatricole.contains(pendingInput)) {
        targetMatricole.add(pendingInput);
      }
    }

    final codice = _codiceController.text.trim();
    if (targetMatricole.isEmpty) {
      setState(() {
        _feedback = 'Inserisci almeno una matricola.';
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

    await _badgeService.saveUltimaMatricola(targetMatricole.first);

    final okMessages = <String>[];
    final errorMessages = <String>[];
    final fallite = <String>[];

    for (final matricola in targetMatricole) {
      try {
        final msg = await _badgeService.rilevaPresenza(
          matricola: matricola,
          codiceLezioneRaw: codice,
          autenticazione: widget.autenticazione,
          fromQr: _codeFromQr,
        );
        okMessages.add(targetMatricole.length == 1 ? msg : '$matricola: $msg');
      } on EasyBadgeException catch (e) {
        fallite.add(matricola);
        errorMessages.add(
          targetMatricole.length == 1 ? e.message : '$matricola: ${e.message}',
        );
      } catch (_) {
        fallite.add(matricola);
        errorMessages.add(
          '$matricola: impossibile contattare il servizio EasyBadge.',
        );
      }
    }

    if (!mounted) return;
    final primaMatricola = targetMatricole.first;
    setState(() {
      _sending = false;
      _matricolaConsultazione = primaMatricola;
      _corsiFuture = _badgeService.getCorsi(primaMatricola);
      if (fallite.isEmpty) {
        _feedback = okMessages.join('\n');
        _matricole.clear();
        _codiceController.clear();
        _codeFromQr = false;
        _success = true;
      } else {
        final parts = <String>[
          if (okMessages.isNotEmpty) ...okMessages,
          ...errorMessages,
        ];
        _feedback = parts.join('\n');
        if (_matricole.isNotEmpty) {
          _matricole
            ..clear()
            ..addAll(fallite);
        }
        _success = false;
      }
    });
  }

  void _consultaPresenzeMatricola() {
    final input = _matricolaController.text.trim().toUpperCase();
    final target = input.isNotEmpty
        ? input
        : (_matricole.isNotEmpty ? _matricole.first : _matricolaConsultazione);
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
            widget.autenticazione
                ? 'Puoi rilevare la presenza per una o più matricole. '
                      'Inquadra il QR proiettato dal docente oppure digita il codice lezione.'
                : 'Inserisci la tua matricola (es. 0512112345 o NF12100013) e inquadra il QR proiettato dal docente in aula oppure digita il codice lezione.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
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
              labelText: 'Matricola studente',
              hintText: 'Es. 0512112345',
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Consulta corsi e presenze di questa matricola',
                    onPressed: _sending ? null : _consultaPresenzeMatricola,
                    icon: const Icon(Icons.search),
                  ),
                  IconButton(
                    tooltip: 'Aggiungi più matricole',
                    onPressed: _sending ? null : _addMatricola,
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                  ),
                ],
              ),
            ),
            onSubmitted: (_) => _consultaPresenzeMatricola(),
          ),
          if (_matricole.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Matricole da registrare (${_matricole.length})',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _matricole
                  .map(
                    (matricola) => InputChip(
                      label: Text(
                        matricola,
                        style: AppTheme.codice(
                          size: 13,
                          color: scheme.onSurface,
                        ),
                      ),
                      onDeleted: _sending
                          ? null
                          : () => setState(() => _matricole.remove(matricola)),
                    ),
                  )
                  .toList(),
            ),
          ],
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
                    color: _success
                        ? const Color(0xFF2E7D5B)
                        : AppColors.corallo,
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

          // --- Consultazione presenze tramite matricola (senza accesso) ---
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
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

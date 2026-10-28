import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/preferenze_corso.dart';
import '../models/presenza.dart';
import '../services/auth_service.dart';
import '../services/easybadge_service.dart';
import '../theme/app_theme.dart';
import 'presenze_screen.dart';
import 'presenza_pubblica_screen.dart';

/// Tesserino universitario digitale, rilevazione presenza e consultazione
/// delle presenze per ciascun insegnamento.
///
/// La presenza in aula si rileva inquadrando il codice QR che il docente
/// proietta (oppure digitando il codice aula): non serve un QR statico
/// dello studente perché in UNISA è lo studente a scansionare il QR
/// dell'aula, mentre per la mensa si usa il QR dinamico TOTP nella
/// scheda Mensa.
class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  final _badgeService = EasyBadgeService();
  final _codeCtrl = TextEditingController();

  bool _scanning = false;
  bool _submittingCode = false;
  String? _feedback;
  bool _feedbackOk = false;

  late Future<List<CorsoPresenza>> _corsiPresenze;

  @override
  void initState() {
    super.initState();
    _corsiPresenze = _caricaPresenze();
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<List<CorsoPresenza>> _caricaPresenze() {
    final matricola = widget.authService.currentUser?.matricola ?? '';
    if (matricola.isEmpty) return Future.value([]);
    return _badgeService.getCorsi(matricola);
  }

  void _ricaricaPresenze() {
    setState(() => _corsiPresenze = _caricaPresenze());
  }

  Future<void> _copiaMatricola(String matricola) async {
    final m = matricola.trim();
    if (m.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: m));
    await HapticFeedback.lightImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('Matricola $m copiata negli appunti'),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (!_scanning) return;
    final raw = capture.barcodes.isNotEmpty
        ? capture.barcodes.first.rawValue
        : null;
    if (raw == null || raw.trim().isEmpty) return;
    setState(() => _scanning = false);
    await _invia(raw, fromQr: true);
  }

  Future<void> _submitCodiceManuale() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _submittingCode = true);
    await _invia(code, fromQr: false);
    if (mounted) {
      setState(() => _submittingCode = false);
      if (_feedbackOk) {
        _codeCtrl.clear();
      }
    }
  }

  /// Invia il codice lezione (decodificato da QR Base64 o digitato) a
  /// `TimbratureApi.php` con `autenticazione: true` e aggiorna le presenze.
  Future<void> _invia(String codice, {required bool fromQr}) async {
    final matricola = widget.authService.currentUser?.matricola ?? '';
    try {
      final serverMessage = await _badgeService.rilevaPresenza(
        matricola: matricola,
        codiceLezioneRaw: codice,
        autenticazione: true,
        fromQr: fromQr,
      );
      if (!mounted) return;
      setState(() {
        _feedback = serverMessage;
        _feedbackOk = true;
        _corsiPresenze = _caricaPresenze();
      });
    } on EasyBadgeException catch (e) {
      if (!mounted) return;
      setState(() {
        _feedback = e.message;
        _feedbackOk = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _feedback =
            'Non è stato possibile registrare la presenza: il servizio non ha risposto. Riprova.';
        _feedbackOk = false;
      });
    }
  }

  String _iniziali(String nomeCompleto) {
    final parti = nomeCompleto
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parti.isEmpty) return 'U';
    if (parti.length == 1) return parti.first.substring(0, 1).toUpperCase();
    return '${parti.first[0]}${parti.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.authService.currentUser;
    final matricola = user?.matricola ?? '';
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: () async => _ricaricaPresenze(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          // --- Tesserino universitario digitale con matricola copiabile ---
          ValueListenableBuilder<PreferenzeCorso?>(
            valueListenable: widget.authService.preferenzeCorso,
            builder: (context, pref, _) {
              final corsoLabel = (pref?.corsoLabel ?? '').isNotEmpty
                  ? pref!.corsoLabel
                  : (user?.classDes ?? '');
              final annoLabel = pref?.annoLabel ?? '';
              return Container(
                decoration: BoxDecoration(
                  color: AppColors.inchiostro,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.mare.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TESSERINO STUDENTE · UNISA',
                            style: AppTheme.codice(
                              size: 10,
                              color: AppColors.pietra,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        if ((user?.userType ?? '').isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF2E7D5B,
                              ).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user!.userType.toUpperCase(),
                              style: AppTheme.codice(
                                size: 10,
                                color: const Color(0xFF7CE2B3),
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _iniziali(user?.nomeCompleto ?? ''),
                            style: AppTheme.numerico(
                              size: 18,
                              color: AppColors.zolfo,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nomeCompleto ?? 'Studente',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(color: AppColors.pietra),
                              ),
                              if ((user?.email ?? '').isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  user!.email,
                                  style: const TextStyle(
                                    color: AppColors.nebbiaChiara,
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (corsoLabel.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              corsoLabel,
                              style: const TextStyle(
                                color: AppColors.pietra,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (annoLabel.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Anno / Partizione: $annoLabel',
                                style: const TextStyle(
                                  color: AppColors.nebbiaChiara,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    // Matricola copiabile con tocco singolo o tenendo premuto
                    Tooltip(
                      message: 'Tocca o tieni premuto per copiare la matricola',
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          onTap: matricola.isNotEmpty
                              ? () => _copiaMatricola(matricola)
                              : null,
                          onLongPress: matricola.isNotEmpty
                              ? () => _copiaMatricola(matricola)
                              : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Text(
                                  'MATRICOLA',
                                  style: AppTheme.codice(
                                    size: 11,
                                    color: AppColors.nebbiaChiara,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    matricola.isNotEmpty ? matricola : '—',
                                    style: AppTheme.codice(
                                      size: 16,
                                      color: AppColors.zolfo,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (matricola.isNotEmpty) ...[
                                  const Text(
                                    'Copia',
                                    style: TextStyle(
                                      color: AppColors.nebbiaChiara,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(
                                    Icons.copy_rounded,
                                    size: 15,
                                    color: AppColors.zolfo,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // --- Rilevazione presenza ---
          Text(
            'Rileva la tua presenza',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PresenzaPubblicaScreen(
                  api: widget.authService.api,
                  autenticazione: true,
                  matricolaIniziale: matricola,
                ),
              ),
            ),
            icon: const Icon(Icons.people_alt_outlined),
            label: const Text('Rileva per più matricole'),
          ),
          const SizedBox(height: 4),
          Text(
            'Inquadra il codice QR proiettato dal docente in aula oppure inserisci il codice lezione.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (!_scanning)
            FilledButton.icon(
              onPressed: () => setState(() {
                _scanning = true;
                _feedback = null;
              }),
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scansiona QR lezione'),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 300,
                child: Stack(
                  children: [
                    MobileScanner(onDetect: _onDetect),
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
            ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _codeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: AppTheme.codice(size: 14, color: scheme.onSurface),
                  decoration: const InputDecoration(
                    labelText: 'Oppure digita il codice lezione',
                    hintText: 'Codice comunicato dal docente',
                  ),
                  onSubmitted: (_) => _submitCodiceManuale(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: _submittingCode ? null : _submitCodiceManuale,
                child: _submittingCode
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Invia'),
              ),
            ],
          ),
          if (_feedback != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    (_feedbackOk ? const Color(0xFF2E7D5B) : AppColors.corallo)
                        .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: _feedbackOk
                      ? const Color(0xFF2E7D5B)
                      : AppColors.corallo,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _feedbackOk ? Icons.check_circle : Icons.error_outline,
                    color: _feedbackOk
                        ? const Color(0xFF2E7D5B)
                        : AppColors.corallo,
                  ),
                  const SizedBox(width: 8),
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

          // --- Sezione "Le mie presenze" integrata nel Badge ---
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le mie presenze',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Frequenza registrata per ciascun insegnamento',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _ricaricaPresenze,
                tooltip: 'Aggiorna presenze',
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<CorsoPresenza>>(
            future: _corsiPresenze,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return _StatoPresenzeBox(
                  icon: Icons.cloud_off_outlined,
                  titolo: 'Presenze non disponibili',
                  messaggio:
                      'Il servizio presenze non ha risposto. Tocca aggiorna per riprovare.',
                  onRetry: _ricaricaPresenze,
                );
              }
              final corsi = snapshot.data ?? [];
              if (corsi.isEmpty) {
                return _StatoPresenzeBox(
                  icon: Icons.fact_check_outlined,
                  titolo: 'Nessun corso con presenze',
                  messaggio:
                      'Quando le tue presenze saranno registrate le vedrai qui, corso per corso.',
                  onRetry: _ricaricaPresenze,
                );
              }
              return Column(
                children: [
                  for (final corso in corsi)
                    _CorsoPresenzaCard(
                      corso: corso,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PresenzeCorsoScreen(
                            badge: _badgeService,
                            matricola: matricola,
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

class _CorsoPresenzaCard extends StatelessWidget {
  const _CorsoPresenzaCard({required this.corso, required this.onTap});
  final CorsoPresenza corso;
  final VoidCallback onTap;

  Color _coloreStato(String stato, ColorScheme scheme) {
    switch (stato) {
      case 'frequentante':
        return const Color(0xFF2E7D5B);
      case 'in_frequenza':
        return AppColors.zolfo;
      default:
        return scheme.primary;
    }
  }

  String _ore(int minuti) {
    if (minuti <= 0) return '0 h';
    if (minuti % 60 == 0) return '${minuti ~/ 60} h';
    return '${minuti ~/ 60}h ${minuti % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colore = _coloreStato(corso.stato, scheme);
    final prog = (corso.percentuale / 100).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${corso.percentuale.toStringAsFixed(0)}%',
                      style: AppTheme.numerico(size: 20, color: colore),
                    ),
                    Text(
                      'presenza',
                      style: AppTheme.codice(
                        size: 10,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: scheme.outlineVariant,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      corso.nome,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_ore(corso.frequentateMinuti)} frequentate su ${_ore(corso.svolteMinuti)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: prog,
                        minHeight: 4,
                        backgroundColor: scheme.surfaceContainerHighest,
                        color: colore,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatoPresenzeBox extends StatelessWidget {
  const _StatoPresenzeBox({
    required this.icon,
    required this.titolo,
    required this.messaggio,
    required this.onRetry,
  });
  final IconData icon;
  final String titolo;
  final String messaggio;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, size: 36, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(titolo, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            messaggio,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
    );
  }
}

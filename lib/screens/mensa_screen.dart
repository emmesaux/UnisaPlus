import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'adisurc_login_screen.dart';
import '../services/adisurc_service.dart';
import '../services/auth_service.dart';
import '../services/mensa_qr_service.dart';
import '../theme/app_theme.dart';

/// Mensa: saldo del borsellino ADiSURC, QR di accesso reale e menù giornaliero/settimanale.
class MensaScreen extends StatefulWidget {
  const MensaScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<MensaScreen> createState() => _MensaScreenState();
}

class _MensaScreenState extends State<MensaScreen> {
  final _adisurc = AdisurcService();
  final _qrService = MensaQrService();
  late Future<WalletAdisurc?> _saldo;
  late Future<List<MensaMenuGiorno>> _menuSettimana;
  int? _selectedWeekday;
  bool _scanningAssociazione = false;
  String? _erroreAssociazione;

  MensaCard? _carta;
  Timer? _tickQr;

  @override
  void initState() {
    super.initState();
    _saldo = _adisurc.getSaldo();
    _menuSettimana = _adisurc.getMenuSettimana();
    _aggiornaCarta();
  }

  @override
  void dispose() {
    _tickQr?.cancel();
    super.dispose();
  }

  Future<void> _ricaricaTutto() async {
    setState(() {
      _erroreAssociazione = null;
      _saldo = _adisurc.getSaldo();
      _menuSettimana = _adisurc.getMenuSettimana();
    });
    await _aggiornaCarta();
  }

  Future<void> _aggiornaCarta() async {
    final carta = await _adisurc.caricaCartaMensa();
    if (!mounted) return;
    setState(() => _carta = carta);
    _tickQr?.cancel();
    if (carta != null) {
      _tickQr = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {});
      });
    }
  }

  Future<void> _onDetectAssociazione(BarcodeCapture capture) async {
    final raw =
        capture.barcodes.isNotEmpty ? capture.barcodes.first.rawValue : null;
    if (raw == null) return;
    setState(() => _scanningAssociazione = false);
    try {
      await _adisurc.associaConQr(raw);
      await _ricaricaTutto();
    } catch (e) {
      if (mounted) {
        setState(() => _erroreAssociazione = e.toString());
      }
    }
  }

  Future<void> _loginAdisurc() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdisurcLoginScreen(
          service: _adisurc,
          onLoggedIn: (_) {
            if (mounted) {
              Navigator.of(context).pop();
              _ricaricaTutto();
            }
          },
        ),
      ),
    );
  }

  Future<void> _apriUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _ricaricaTutto,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          _tesserino(context),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Saldo ADiSURC',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                onPressed: _ricaricaTutto,
                tooltip: 'Aggiorna saldo, QR e menù',
                icon: const Icon(Icons.refresh, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Accedendo con SPID o CIE vengono caricati sia il saldo del borsellino sia il tesserino QR mensa.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _cardSaldo(context),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loginAdisurc,
            icon: const Icon(Icons.login),
            label: Text(
              _adisurc.loggato
                  ? 'Riaccedi ad ADiSURC con SPID o CIE'
                  : 'Accedi ad ADiSURC con SPID o CIE',
            ),
          ),
          const SizedBox(height: 8),
          if (!_scanningAssociazione)
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _scanningAssociazione = true;
                _erroreAssociazione = null;
              }),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(
                _adisurc.associato
                    ? 'Associa tramite QR dal portale ADiSURC'
                    : 'Associa questo telefono con QR',
              ),
            )
          else
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 280,
                child: Stack(
                  children: [
                    MobileScanner(onDetect: _onDetectAssociazione),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton.filled(
                        onPressed: () =>
                            setState(() => _scanningAssociazione = false),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (_erroreAssociazione != null) ...[
            const SizedBox(height: 10),
            Text(_erroreAssociazione!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 28),
          Divider(color: scheme.outlineVariant),
          const SizedBox(height: 16),
          _sezioneMenuMensa(context),
        ],
      ),
    );
  }

  Widget _sezioneMenuMensa(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oggiWeekday = DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Menù della mensa',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Fisciano e Baronissi · Lun–Ven (Pranzo 12:00–15:00 · Cena 19:00–21:00)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _apriUrl(AdisurcService.mensaMenuPageUrl),
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Sito ADiSURC'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<MensaMenuGiorno>>(
          future: _menuSettimana,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final giorni = snapshot.data ?? const <MensaMenuGiorno>[];
            if (giorni.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Consulta i menù aggiornati del giorno e della settimana sul portale ADiSURC.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          _apriUrl(AdisurcService.mensaMenuPageUrl),
                      icon: const Icon(Icons.restaurant_menu),
                      label: const Text('Apri pagina Menù ADiSURC'),
                    ),
                  ],
                ),
              );
            }

            final targetWeekday =
                _selectedWeekday ??
                (oggiWeekday >= 1 && oggiWeekday <= 5
                    ? oggiWeekday
                    : giorni.first.weekday);
            final selezionato = giorni.firstWhere(
              (g) => g.weekday == targetWeekday,
              orElse: () => giorni.first,
            );
            final isOggi = selezionato.weekday == oggiWeekday;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selezionato.settimanaLabel.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      selezionato.settimanaLabel.toUpperCase(),
                      style: AppTheme.codice(
                        size: 11,
                        color: scheme.primary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                // Selettore rapido dei giorni della settimana
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final g in giorni)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _GiornoChip(
                            giorno: g,
                            selected: g.weekday == selezionato.weekday,
                            isOggi: g.weekday == oggiWeekday,
                            onTap: () =>
                                setState(() => _selectedWeekday = g.weekday),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Card in evidenza per il giorno selezionato (oggi di default)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inchiostro,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOggi
                          ? AppColors.zolfo.withValues(alpha: 0.65)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 18,
                            color: AppColors.zolfo,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selezionato.nomeGiorno} · ${selezionato.dataLabel}',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(color: AppColors.pietra),
                            ),
                          ),
                          if (isOggi)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.zolfo,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'OGGI',
                                style: AppTheme.codice(
                                  size: 10,
                                  color: AppColors.inchiostro,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          if (selezionato.pranzoPdfUrl != null)
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.zolfo,
                                  foregroundColor: AppColors.inchiostro,
                                ),
                                onPressed: () =>
                                    _apriUrl(selezionato.pranzoPdfUrl!),
                                icon: const Icon(
                                  Icons.wb_sunny_outlined,
                                  size: 18,
                                ),
                                label: const Text('Menù Pranzo'),
                              ),
                            ),
                          if (selezionato.pranzoPdfUrl != null &&
                              selezionato.cenaPdfUrl != null)
                            const SizedBox(width: 10),
                          if (selezionato.cenaPdfUrl != null)
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.pietra,
                                  side: const BorderSide(
                                    color: AppColors.nebbia,
                                  ),
                                ),
                                onPressed: () =>
                                    _apriUrl(selezionato.cenaPdfUrl!),
                                icon: const Icon(
                                  Icons.nights_stay_outlined,
                                  size: 18,
                                ),
                                label: const Text('Menù Cena'),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // Elenco compatto di tutta la settimana
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: const EdgeInsets.only(top: 4),
                    title: Text(
                      'Tutti i menù della settimana (${giorni.length} giorni)',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    children: [
                      for (final g in giorni)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: scheme.outlineVariant),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          g.nomeGiorno,
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleSmall,
                                        ),
                                        if (g.weekday == oggiWeekday) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.primary.withValues(
                                                alpha: 0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              'OGGI',
                                              style: AppTheme.codice(
                                                size: 9,
                                                color: scheme.primary,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      g.dataLabel,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              if (g.pranzoPdfUrl != null)
                                TextButton.icon(
                                  onPressed: () => _apriUrl(g.pranzoPdfUrl!),
                                  icon: const Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Pranzo'),
                                ),
                              if (g.cenaPdfUrl != null)
                                TextButton.icon(
                                  onPressed: () => _apriUrl(g.cenaPdfUrl!),
                                  icon: const Icon(
                                    Icons.nights_stay_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Cena'),
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// Tesserino con il QR mensa reale (TOTP) quando i dati carta sono
  /// disponibili; altrimenti uno stato onesto, non un QR finto.
  Widget _tesserino(BuildContext context) {
    final user = widget.authService.currentUser;
    final carta = _carta;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inchiostro,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Tesserino mensa ADiSURC',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppColors.pietra),
          ),
          if ((user?.nomeCompleto ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              user!.nomeCompleto,
              style: const TextStyle(color: AppColors.nebbiaChiara),
            ),
          ],
          const SizedBox(height: 20),
          if (carta != null && carta.valida) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: QrImageView(
                data: _qrService.contenutoQr(carta),
                size: 184,
                backgroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            _contatoreRotazione(carta),
            const SizedBox(height: 6),
            Text(
              'Carta ${carta.cardId} · Aggiornamento tra ${_qrService.secondiAllaRotazione(carta)}s',
              textAlign: TextAlign.center,
              style: AppTheme.codice(
                size: 11,
                color: AppColors.zolfo,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Inquadra il codice al tornello della mensa.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.nebbiaChiara, fontSize: 12),
            ),
          ] else ...[
            const Icon(
              Icons.qr_code_2_outlined,
              size: 72,
              color: AppColors.nebbia,
            ),
            const SizedBox(height: 12),
            const Text(
              'Accedi con SPID/CIE qui sotto per attivare automaticamente il QR mensa su questo telefono.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.nebbiaChiara, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _contatoreRotazione(MensaCard carta) {
    final restanti = _qrService.secondiAllaRotazione(carta);
    final frazione = restanti / carta.cardInterval;
    return SizedBox(
      width: 184,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: LinearProgressIndicator(
          value: frazione.clamp(0.0, 1.0),
          minHeight: 4,
          backgroundColor: const Color(0xFF2A303C),
          color: AppColors.zolfo,
        ),
      ),
    );
  }

  Widget _cardSaldo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FutureBuilder<WalletAdisurc?>(
      future: _saldo,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        return Column(
          children: [
            ValueListenableBuilder<bool>(
              valueListenable: _adisurc.isDemo,
              builder: (context, isDemo, _) {
                if (!isDemo || waiting) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 16,
                        color: AppColors.nebbia,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _adisurc.loggato
                              ? 'Saldo borsellino non restituito dal portale ADiSURC per questa sessione.'
                              : 'Dispositivo non ancora collegato ad ADiSURC: accedi con SPID/CIE per vedere il saldo.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: scheme.primary,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Saldo disponibile',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (waiting)
                            const Padding(
                              padding: EdgeInsets.only(top: 6),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else
                            Text(
                              snapshot.data != null
                                  ? '${snapshot.data!.saldo.toStringAsFixed(2)} ${snapshot.data!.valuta}'
                                  : '–',
                              style: AppTheme.numerico(
                                size: 24,
                                color: scheme.onSurface,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _GiornoChip extends StatelessWidget {
  const _GiornoChip({
    required this.giorno,
    required this.selected,
    required this.isOggi,
    required this.onTap,
  });

  final MensaMenuGiorno giorno;
  final bool selected;
  final bool isOggi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = selected ? AppColors.mare : scheme.surfaceContainerHigh;
    final fg = selected ? AppColors.pietra : scheme.onSurface;
    final sub = selected ? AppColors.nebbiaChiara : scheme.onSurfaceVariant;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected
                  ? AppColors.mare
                  : (isOggi ? AppColors.zolfo : scheme.outlineVariant),
              width: isOggi ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    giorno.nomeGiornoBreve,
                    style: AppTheme.codice(
                      size: 12,
                      color: fg,
                      weight: FontWeight.w700,
                    ),
                  ),
                  if (isOggi) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.zolfo,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                giorno.dataBreve,
                style: TextStyle(fontSize: 11, color: sub),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

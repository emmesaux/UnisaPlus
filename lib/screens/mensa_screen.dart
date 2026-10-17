import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'adisurc_login_screen.dart';
import '../services/adisurc_service.dart';
import '../services/auth_service.dart';
import '../services/mensa_qr_service.dart';
import '../theme/app_theme.dart';

/// Mensa: saldo del borsellino ADiSURC e QR di accesso reale.
///
/// Il QR mensa NON è `MENSA:matricola` (una stringa inventata che nessun
/// tornello accetta): è un codice TOTP a tempo derivato dai dati carta
/// ADiSURC, con lo stesso algoritmo dell'app ufficiale. Senza i dati
/// carta (prima dell'associazione) non si mostra alcun QR, invece di uno
/// falso.
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
  bool _scanningAssociazione = false;
  String? _erroreAssociazione;

  MensaCard? _carta;
  Timer? _tickQr;

  @override
  void initState() {
    super.initState();
    _saldo = _adisurc.getSaldo();
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
    });
    await _aggiornaCarta();
  }

  Future<void> _aggiornaCarta() async {
    final carta = await _adisurc.caricaCartaMensa();
    if (!mounted) return;
    setState(() => _carta = carta);
    _tickQr?.cancel();
    if (carta != null) {
      // Il codice TOTP ruota: si ridisegna ogni secondo per aggiornare QR
      // e contatore.
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return RefreshIndicator(
      onRefresh: _ricaricaTutto,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _tesserino(context),
          const SizedBox(height: 28),
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
                tooltip: 'Aggiorna saldo e QR',
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
        ],
      ),
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

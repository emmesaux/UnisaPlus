import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/cineca_rest_service.dart';
import '../theme/app_theme.dart';

class TasseScreen extends StatefulWidget {
  const TasseScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<TasseScreen> createState() => _TasseScreenState();
}

class _TasseScreenState extends State<TasseScreen> {
  List<TassaFattura> _tasse = [];
  bool _loading = true;
  String? _errore;
  int _filtro = 0; // 0 = Tutte, 1 = Da pagare, 2 = Pagate

  @override
  void initState() {
    super.initState();
    _carica();
  }

  Future<void> _carica() async {
    setState(() {
      _loading = true;
      _errore = null;
    });
    try {
      final lista = await widget.authService.getTasseReali();
      if (!mounted) return;
      setState(() {
        _tasse = lista;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errore = e.toString();
        _loading = false;
      });
    }
  }

  double _parseImporto(String raw) {
    final clean = raw
        .replaceAll('€', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.')
        .trim();
    return double.tryParse(clean) ?? 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errore != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: scheme.error),
              const SizedBox(height: 12),
              Text(
                _errore!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _carica,
                icon: const Icon(Icons.refresh),
                label: const Text('Riprova'),
              ),
            ],
          ),
        ),
      );
    }

    final daPagareList = _tasse.where((t) => !t.pagata).toList();
    final pagateList = _tasse.where((t) => t.pagata).toList();

    final totDaPagare = daPagareList.fold<double>(
      0.0,
      (sum, t) => sum + _parseImporto(t.importo),
    );
    final totPagato = pagateList.fold<double>(
      0.0,
      (sum, t) => sum + _parseImporto(t.importo),
    );

    final filtrate = _tasse.where((t) {
      if (_filtro == 1) return !t.pagata;
      if (_filtro == 2) return t.pagata;
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        children: [
          // Riepilogo importi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DA PAGARE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: daPagareList.isNotEmpty
                              ? AppTheme.warning
                              : scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€ ${totDaPagare.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${daPagareList.length} avvisi aperti',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 44,
                  color: scheme.outlineVariant,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TOTALE VERSATO',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '€ ${totPagato.toStringAsFixed(2)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${pagateList.length} rate pagate',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Filtri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Tutte (${_tasse.length})'),
                  selected: _filtro == 0,
                  onSelected: (_) => setState(() => _filtro = 0),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Da pagare (${daPagareList.length})'),
                  selected: _filtro == 1,
                  onSelected: (_) => setState(() => _filtro = 1),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('Pagate (${pagateList.length})'),
                  selected: _filtro == 2,
                  onSelected: (_) => setState(() => _filtro = 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtrate.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'Nessuna tassa presente in questa sezione.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          else
            ...filtrate.map((t) => _TassaCard(tassa: t)),
        ],
      ),
    );
  }
}

class _TassaCard extends StatelessWidget {
  const _TassaCard({required this.tassa});
  final TassaFattura tassa;

  void _copiaIuv(BuildContext context, String iuv) {
    Clipboard.setData(ClipboardData(text: iuv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Codice IUV copiato: $iuv'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final pagata = tassa.pagata;
    final coloreStato = pagata ? AppTheme.success : AppTheme.warning;
    final importoPulito = tassa.importo.contains('€')
        ? tassa.importo
        : '€ ${tassa.importo}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: pagata
              ? scheme.outlineVariant
              : AppTheme.warning.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (tassa.anno.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          'A.A. ${tassa.anno}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    Text(
                      tassa.titolo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    importoPulito,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: coloreStato.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      pagata ? 'Pagata' : 'Da pagare',
                      style: TextStyle(
                        color: coloreStato,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (tassa.scadenza.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.event_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Scadenza: ${tassa.scadenza}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              if (tassa.fattId.isNotEmpty)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_outlined,
                      size: 15,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Fattura #${tassa.fattId}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
          if (tassa.iuv.isNotEmpty) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: () => _copiaIuv(context, tassa.iuv),
              borderRadius: BorderRadius.circular(6),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'IUV: ${tassa.iuv}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (tassa.dettagli.length > 1) ...[
            const Divider(height: 20),
            ...tassa.dettagli.map(
              (d) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        d.titolo,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

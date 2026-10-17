import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/cineca_rest_service.dart';
import '../theme/app_theme.dart';

class BachecaEsitiScreen extends StatefulWidget {
  const BachecaEsitiScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<BachecaEsitiScreen> createState() => _BachecaEsitiScreenState();
}

class _BachecaEsitiScreenState extends State<BachecaEsitiScreen> {
  List<EsitoBacheca> _esiti = [];
  bool _loading = true;
  String? _errore;
  String? _inAggiornamentoId;

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
      final lista = await widget.authService.getBachecaEsitiReali();
      if (!mounted) return;
      setState(() {
        _esiti = lista;
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

  Future<void> _confermaAzione(EsitoBacheca esito, bool accetta) async {
    final azioneTesto = accetta ? 'accettare' : 'rifiutare';
    final conferma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Attenzione'),
        content: Text(
          'Vuoi davvero $azioneTesto il voto (${esito.votoDisplay}) in ${esito.insegnamento}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: accetta
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
            child: Text(accetta ? 'Accetta voto' : 'Rifiuta voto'),
          ),
        ],
      ),
    );

    if (conferma != true || !mounted) return;

    setState(() => _inAggiornamentoId = esito.applistaId);
    try {
      final aggiornato = await widget.authService.modificaEsitoBachecaReale(
        esito: esito,
        accetta: accetta,
      );
      if (!mounted) return;
      setState(() {
        final idx = _esiti.indexWhere((e) => e.applistaId == esito.applistaId);
        if (idx >= 0) {
          _esiti[idx] = aggiornato;
        }
        _inAggiornamentoId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accetta
                ? 'Voto accettato per ${esito.insegnamento}.'
                : 'Voto rifiutato per ${esito.insegnamento}.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _inAggiornamentoId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Operazione non riuscita: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
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

    if (_esiti.isEmpty) {
      return RefreshIndicator(
        onRefresh: _carica,
        child: ListView(
          padding: const EdgeInsets.all(32),
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.fact_check_outlined,
              size: 56,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Nessun esito pubblicato in bacheca',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Quando i docenti pubblicheranno gli esiti degli appelli sostenuti, potrai consultarli, accettarli o rifiutarli da qui.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _carica,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        itemCount: _esiti.length,
        itemBuilder: (context, index) {
          final esito = _esiti[index];
          final pv = esito.presaVisione.toUpperCase();
          final accettato = pv == 'A';
          final rifiutato = pv == 'R';
          final busy = _inAggiornamentoId == esito.applistaId;

          Color coloreBadge = scheme.primary;
          String statoLabel = 'In bacheca';
          if (accettato) {
            coloreBadge = AppTheme.success;
            statoLabel = 'Accettato';
          } else if (rifiutato) {
            coloreBadge = scheme.error;
            statoLabel = 'Rifiutato';
          } else if (esito.assente || esito.ritirato) {
            coloreBadge = scheme.outline;
            statoLabel = esito.votoDisplay;
          }

          // Come in EsitiAdapter.java: mostra i pulsanti quando l'esito è valido
          // e non già nello stato corrispondente
          final puoOperare = !esito.assente && !esito.ritirato && esito.voto > 0;
          final mostraAccetta = puoOperare && !accettato;
          final mostraRifiuta = puoOperare && !rifiutato;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: accettato
                    ? AppTheme.success.withValues(alpha: 0.5)
                    : rifiutato
                        ? scheme.error.withValues(alpha: 0.5)
                        : scheme.outlineVariant,
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
                          Text(
                            esito.insegnamento,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          if (esito.dataEsame.isNotEmpty)
                            Text(
                              'Sostenuto il: ${esito.dataEsame}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: coloreBadge.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: coloreBadge.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            esito.votoDisplay,
                            style: TextStyle(
                              color: coloreBadge,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            statoLabel,
                            style: TextStyle(
                              color: coloreBadge,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (mostraAccetta || mostraRifiuta) ...[
                  const SizedBox(height: 14),
                  if (busy)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (mostraRifiuta)
                          OutlinedButton.icon(
                            onPressed: () => _confermaAzione(esito, false),
                            icon: Icon(
                              Icons.close,
                              size: 16,
                              color: scheme.error,
                            ),
                            label: Text(
                              'Rifiuta',
                              style: TextStyle(color: scheme.error),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                color: scheme.error.withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        if (mostraRifiuta && mostraAccetta)
                          const SizedBox(width: 10),
                        if (mostraAccetta)
                          FilledButton.icon(
                            onPressed: () => _confermaAzione(esito, true),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Accetta'),
                          ),
                      ],
                    ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

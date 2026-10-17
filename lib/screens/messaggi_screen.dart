import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/easycourse_combo_service.dart';
import '../services/unisa_news_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Pagina Avvisi e Messaggi, divisa come l'app Campus in due sezioni:
/// - **News Ateneo** (da `web.unisa.it`)
/// - **News Dipartimento** (dal sito del Dipartimento UNISA associato al
///   corso di studi dello studente, con possibilità di cambiare dipartimento).
class MessaggiScreen extends StatefulWidget {
  const MessaggiScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<MessaggiScreen> createState() => _MessaggiScreenState();
}

class _MessaggiScreenState extends State<MessaggiScreen> {
  final _newsService = UnisaNewsService();
  final _comboService = EasyCourseComboService();

  int _sezione = 0; // 0 = News Ateneo, 1 = News Dipartimento
  late Future<List<AvvisoUnisa>> _futureAteneo;
  Future<List<AvvisoUnisa>>? _futureDipartimento;
  DipartimentoUnisa? _dipartimento;

  @override
  void initState() {
    super.initState();
    _futureAteneo = _newsService.getNewsAteneo();
    _inizializzaDipartimento();
    widget.authService.preferenzeCorso.addListener(_onPreferenzeChanged);
  }

  @override
  void dispose() {
    widget.authService.preferenzeCorso.removeListener(_onPreferenzeChanged);
    super.dispose();
  }

  void _onPreferenzeChanged() {
    _inizializzaDipartimento();
  }

  Future<void> _inizializzaDipartimento() async {
    final pref = widget.authService.preferenzeCorso.value;
    final user = widget.authService.currentUser;

    var dip = UnisaNewsService.trovaDipartimento(
      facoltaCode: pref?.facoltaCode ?? '',
      corsoValore: pref?.corsoValore ?? user?.corsoCodice ?? '',
      corsoLabel: pref?.corsoLabel ?? user?.classDes ?? '',
    );

    // Se la preferenza è stata salvata prima dell'aggiunta di facoltaCode,
    // risaliamo al facolta_code interrogando il combo per quel corso.
    if (dip == null && pref != null && pref.corsoValore.isNotEmpty) {
      try {
        final corsi = await _comboService.getCorsi(pref.aa);
        final match = corsi
            .where((c) => c.valore == pref.corsoValore)
            .firstOrNull;
        if (match != null && match.facoltaCode.isNotEmpty) {
          dip = UnisaNewsService.trovaDipartimento(
            facoltaCode: match.facoltaCode,
            corsoValore: match.valore,
            corsoLabel: match.label,
          );
        }
      } catch (_) {}
    }

    dip ??= UnisaNewsService.dipartimenti.first;
    if (!mounted) return;
    setState(() {
      _dipartimento = dip;
      _futureDipartimento = _newsService.getNewsDipartimento(dip!);
    });
  }

  void _cambiaDipartimento(DipartimentoUnisa nuovo) {
    setState(() {
      _dipartimento = nuovo;
      _futureDipartimento = _newsService.getNewsDipartimento(nuovo);
    });
  }

  void _ricaricaCorrente() {
    setState(() {
      if (_sezione == 0) {
        _futureAteneo = _newsService.getNewsAteneo();
      } else if (_dipartimento != null) {
        _futureDipartimento = _newsService.getNewsDipartimento(_dipartimento!);
      }
    });
  }

  Future<void> _apriSelettoreDipartimento() async {
    final scelto = await showModalBottomSheet<DipartimentoUnisa>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          builder: (context, scrollController) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Text(
                    'Scegli il Dipartimento',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: UnisaNewsService.dipartimenti.length,
                    itemBuilder: (context, i) {
                      final d = UnisaNewsService.dipartimenti[i];
                      final attivo = d.codice == _dipartimento?.codice;
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: attivo
                                ? AppColors.mare
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            d.sigla,
                            style: AppTheme.codice(
                              size: 11,
                              color: attivo
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(d.nome),
                        trailing: attivo
                            ? const Icon(Icons.check, color: AppColors.mare)
                            : null,
                        onTap: () => Navigator.of(context).pop(d),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    if (scelto != null) {
      _cambiaDipartimento(scelto);
    }
  }

  Future<void> _apriDettaglioAvviso(AvvisoUnisa avviso) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DettaglioAvvisoSheet(
        avviso: avviso,
        newsService: _newsService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Selettore tra News Ateneo e News Dipartimento (stile Campus)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<int>(
                  segments: const [
                    ButtonSegment<int>(
                      value: 0,
                      icon: Icon(Icons.account_balance_outlined, size: 18),
                      label: Text('News Ateneo'),
                    ),
                    ButtonSegment<int>(
                      value: 1,
                      icon: Icon(Icons.domain_outlined, size: 18),
                      label: Text('News Dipartimento'),
                    ),
                  ],
                  selected: {_sezione},
                  onSelectionChanged: (sel) {
                    setState(() => _sezione = sel.first);
                  },
                ),
              ),
            ],
          ),
        ),
        if (_sezione == 1 && _dipartimento != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: _apriSelettoreDipartimento,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mare.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _dipartimento!.sigla,
                        style: AppTheme.codice(
                          size: 11,
                          color: AppColors.mare,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _dipartimento!.nome,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Cambia',
                      style: AppTheme.codice(
                        size: 11,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: _sezione == 0
              ? _buildLista(_futureAteneo, isDipartimento: false)
              : _buildLista(_futureDipartimento, isDipartimento: true),
        ),
      ],
    );
  }

  Widget _buildLista(
    Future<List<AvvisoUnisa>>? future, {
    required bool isDipartimento,
  }) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return FutureBuilder<List<AvvisoUnisa>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Impossibile caricare gli avvisi',
            message: isDipartimento
                ? 'Il sito del dipartimento (${_dipartimento?.sigla ?? ""}) non è al momento raggiungibile.'
                : 'Il portale web di Ateneo non è al momento raggiungibile.',
            onRetry: _ricaricaCorrente,
          );
        }
        final avvisi = snapshot.data ?? const [];
        if (avvisi.isEmpty) {
          return EmptyState(
            icon: Icons.campaign_outlined,
            title: 'Nessun avviso',
            message: isDipartimento
                ? 'Non sono presenti avvisi recenti per il dipartimento selezionato.'
                : 'Gli avvisi di Ateneo appariranno qui.',
            onRetry: _ricaricaCorrente,
          );
        }
        final scheme = Theme.of(context).colorScheme;
        return RefreshIndicator(
          onRefresh: () async => _ricaricaCorrente(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
            itemCount: avvisi.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final a = avvisi[i];
              return Container(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _apriDettaglioAvviso(a),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: (isDipartimento
                                        ? AppColors.mare
                                        : AppColors.zolfo)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                a.categoria.toUpperCase(),
                                style: AppTheme.codice(
                                  size: 10,
                                  color: isDipartimento
                                      ? AppColors.mare
                                      : scheme.onSurface,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (a.dataLabel.isNotEmpty)
                              Text(
                                a.dataLabel,
                                style: AppTheme.codice(
                                  size: 11,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right,
                              size: 18,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          a.titolo,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (a.sottotitolo.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            a.sottotitolo,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _DettaglioAvvisoSheet extends StatefulWidget {
  const _DettaglioAvvisoSheet({
    required this.avviso,
    required this.newsService,
  });

  final AvvisoUnisa avviso;
  final UnisaNewsService newsService;

  @override
  State<_DettaglioAvvisoSheet> createState() => _DettaglioAvvisoSheetState();
}

class _DettaglioAvvisoSheetState extends State<_DettaglioAvvisoSheet> {
  late final Future<String> _dettaglio;

  @override
  void initState() {
    super.initState();
    _dettaglio = widget.newsService.getDettaglioAvviso(widget.avviso.url);
  }

  Future<void> _apriSulSito() async {
    final uri = Uri.tryParse(widget.avviso.url);
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mare.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    widget.avviso.categoria.toUpperCase(),
                    style: AppTheme.codice(
                      size: 10,
                      color: AppColors.mare,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.avviso.dataLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.avviso.dataLabel,
                    style: AppTheme.codice(
                      size: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(
              widget.avviso.titolo,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (widget.avviso.sottotitolo.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                widget.avviso.sottotitolo,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            FutureBuilder<String>(
              future: _dettaglio,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final testo = snapshot.data ?? '';
                if (testo.isEmpty) {
                  return Text(
                    'Apri la pagina ufficiale per consultare gli allegati e il testo integrale dell’avviso.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  );
                }
                return SelectableText(
                  testo,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _apriSulSito,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Apri avviso sul sito UNISA'),
            ),
          ],
        );
      },
    );
  }
}


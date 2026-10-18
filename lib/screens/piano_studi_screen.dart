import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/cineca_rest_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

enum FiltroPiano {
  tutti('Tutti gli esami'),
  daSostenere('Da sostenere'),
  superati('Superati');

  const FiltroPiano(this.label);
  final String label;
}

class PianoStudiScreen extends StatefulWidget {
  const PianoStudiScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<PianoStudiScreen> createState() => _PianoStudiScreenState();
}

class _PianoStudiScreenState extends State<PianoStudiScreen> {
  late Future<LibrettoDati> _future;
  FiltroPiano _filtro = FiltroPiano.tutti;
  String _ricerca = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _carica();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _carica() {
    _future = widget.authService.getLibrettoReale();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano di studi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Ricarica piano di studi',
            onPressed: () => setState(_carica),
          ),
        ],
      ),
      body: FutureBuilder<LibrettoDati>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: scheme.error),
                    const SizedBox(height: 12),
                    Text(
                      'Impossibile caricare il piano di studi',
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${snapshot.error}',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Riprova'),
                      onPressed: () => setState(_carica),
                    ),
                  ],
                ),
              ),
            );
          }

          final dati = snapshot.data;
          if (dati == null || dati.esami.isEmpty) {
            return const EmptyState(
              icon: Icons.schema_outlined,
              title: 'Nessun insegnamento trovato',
              message: 'Il piano di studi non risulta ancora caricato su Esse3.',
            );
          }

          final stats = dati.statistiche;
          final tuttiEsami = dati.esami;

          // Esami filtrati per stato e ricerca
          final esamiFiltrati = tuttiEsami.where((e) {
            if (_filtro == FiltroPiano.superati && !e.superato) return false;
            if (_filtro == FiltroPiano.daSostenere && e.superato) return false;

            if (_ricerca.isNotEmpty) {
              final q = _ricerca.toLowerCase();
              return e.descrizione.toLowerCase().contains(q) ||
                  e.codice.toLowerCase().contains(q) ||
                  e.cfuTesto.toLowerCase().contains(q);
            }
            return true;
          }).toList();

          // Raggruppamento per Anno di Corso
          final Map<String, List<EsameLibretto>> perAnno = {};
          for (final e in esamiFiltrati) {
            final annoKey = _normalizzaAnno(e.annoCorso);
            perAnno.putIfAbsent(annoKey, () => []).add(e);
          }

          // Ordinamento chiavi anni
          final anniOrdinati = perAnno.keys.toList()
            ..sort((a, b) => a.compareTo(b));

          final numSuperati = tuttiEsami.where((e) => e.superato).length;
          final numDaSostenere = tuttiEsami.length - numSuperati;
          final cfuOttenuti = stats.cfuAcquisiti;
          final cfuTotali = stats.cfuTotali > 0 ? stats.cfuTotali : 180;
          final progresso = (cfuOttenuti / cfuTotali).clamp(0.0, 1.0);

          return RefreshIndicator(
            onRefresh: () async => setState(_carica),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Card riepilogo avanzamento CFU e Piano
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: scheme.outlineVariant),
                  ),
                  color: AppColors.mare.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Avanzamento CFU',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '$cfuOttenuti',
                                      style: AppTheme.numerico(
                                        size: 28,
                                        color: AppColors.zolfo,
                                      ),
                                    ),
                                    Text(
                                      ' / $cfuTotali CFU',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: scheme.outlineVariant),
                              ),
                              child: Text(
                                '${(progresso * 100).toStringAsFixed(0)}%',
                                style: AppTheme.numerico(
                                  size: 16,
                                  color: AppColors.smeraldo,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: progresso,
                            minHeight: 8,
                            backgroundColor:
                                scheme.outlineVariant.withValues(alpha: 0.5),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.smeraldo,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Divider(color: scheme.outlineVariant, height: 1),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _InfoCol(
                              label: 'Superati',
                              valore: '$numSuperati',
                              colore: AppColors.smeraldo,
                              icona: Icons.check_circle_outline,
                            ),
                            _InfoCol(
                              label: 'Da sostenere',
                              valore: '$numDaSostenere',
                              colore: AppColors.arancio,
                              icona: Icons.pending_outlined,
                            ),
                            _InfoCol(
                              label: 'Totali piano',
                              valore: '${tuttiEsami.length}',
                              colore: scheme.primary,
                              icona: Icons.format_list_bulleted,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Barra ricerca
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cerca insegnamento o codice...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _ricerca.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _ricerca = '');
                            },
                          )
                        : null,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                  ),
                  onChanged: (v) => setState(() => _ricerca = v.trim()),
                ),

                const SizedBox(height: 12),

                // Chips filtro
                SegmentedButton<FiltroPiano>(
                  segments: FiltroPiano.values.map((f) {
                    return ButtonSegment(
                      value: f,
                      label: Text(f.label, style: const TextStyle(fontSize: 12)),
                    );
                  }).toList(),
                  selected: {_filtro},
                  onSelectionChanged: (set) {
                    if (set.isNotEmpty) {
                      setState(() => _filtro = set.first);
                    }
                  },
                ),

                const SizedBox(height: 16),

                // Sezioni per Anno di Corso
                if (anniOrdinati.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        'Nessun insegnamento corrisponde ai filtri selezionati.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  for (final anno in anniOrdinati) ...[
                    _SezioneAnno(
                      titoloAnno: _titoloAnno(anno),
                      esami: perAnno[anno]!,
                      onTapEsame: (e) => _mostraDettaglioEsame(context, e),
                    ),
                    const SizedBox(height: 14),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  String _normalizzaAnno(String raw) {
    final trim = raw.trim();
    if (trim == '1' || trim == '01' || trim.toLowerCase().contains('primo')) {
      return '1';
    }
    if (trim == '2' || trim == '02' || trim.toLowerCase().contains('secondo')) {
      return '2';
    }
    if (trim == '3' || trim == '03' || trim.toLowerCase().contains('terzo')) {
      return '3';
    }
    if (trim == '4' || trim == '04' || trim.toLowerCase().contains('quarto')) {
      return '4';
    }
    if (trim == '5' || trim == '05' || trim.toLowerCase().contains('quinto')) {
      return '5';
    }
    return '99'; // Altre attività / a scelta / tesi
  }

  String _titoloAnno(String annoKey) {
    switch (annoKey) {
      case '1':
        return '1° Anno di Corso';
      case '2':
        return '2° Anno di Corso';
      case '3':
        return '3° Anno di Corso';
      case '4':
        return '4° Anno di Corso';
      case '5':
        return '5° Anno di Corso';
      default:
        return 'Attività a Scelta / Tesi / Ulteriori CFU';
    }
  }

  void _mostraDettaglioEsame(BuildContext context, EsameLibretto esame) {
    final scheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                        color: (esame.superato
                                ? AppColors.smeraldo
                                : scheme.primary)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        esame.cfuTesto,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: esame.superato
                              ? AppColors.smeraldo
                              : scheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (esame.codice.isNotEmpty)
                      Text(
                        'Cod. ${esame.codice}',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  esame.descrizione,
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 16),
                _DettaglioRiga(
                  icon: Icons.calendar_today_outlined,
                  label: 'Anno di corso',
                  valore: esame.annoCorso.isNotEmpty ? esame.annoCorso : 'Non specificato',
                ),
                _DettaglioRiga(
                  icon: esame.superato
                      ? Icons.check_circle_outline
                      : Icons.pending_outlined,
                  label: 'Stato esame',
                  valore: esame.stato,
                  coloreValore: esame.superato ? AppColors.smeraldo : AppColors.arancio,
                ),
                if (esame.superato) ...[
                  _DettaglioRiga(
                    icon: Icons.grade_outlined,
                    label: 'Voto conseguito',
                    valore: esame.votoDisplay.isNotEmpty
                        ? esame.votoDisplay
                        : (esame.idoneita ? 'Idoneo' : 'Superato'),
                    coloreValore: AppColors.zolfo,
                  ),
                ],
                if (esame.scoreDetail.isNotEmpty) ...[
                  _DettaglioRiga(
                    icon: Icons.history_outlined,
                    label: 'Dettagli verbalizzazione',
                    valore: esame.scoreDetail,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SezioneAnno extends StatelessWidget {
  const _SezioneAnno({
    required this.titoloAnno,
    required this.esami,
    required this.onTapEsame,
  });

  final String titoloAnno;
  final List<EsameLibretto> esami;
  final void Function(EsameLibretto) onTapEsame;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final superati = esami.where((e) => e.superato).length;
    final cfuAnno = esami.fold<int>(0, (acc, e) => acc + e.cfu);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              titoloAnno,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
            ),
            Text(
              '$superati/${esami.length} completati · $cfuAnno CFU',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: scheme.outlineVariant),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: esami.length,
            separatorBuilder: (_, _) => Divider(
              color: scheme.outlineVariant.withValues(alpha: 0.7),
              height: 1,
            ),
            itemBuilder: (context, index) {
              final e = esami[index];
              return _EsameItemTile(
                esame: e,
                onTap: () => onTapEsame(e),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EsameItemTile extends StatelessWidget {
  const _EsameItemTile({required this.esame, required this.onTap});

  final EsameLibretto esame;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icona di stato
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: (esame.superato
                        ? AppColors.smeraldo
                        : (esame.stato.contains('FREQUENTAT')
                            ? scheme.primary
                            : scheme.outlineVariant))
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                esame.superato
                    ? Icons.check
                    : (esame.stato.contains('FREQUENTAT')
                        ? Icons.hourglass_bottom
                        : Icons.radio_button_unchecked),
                size: 18,
                color: esame.superato
                    ? AppColors.smeraldo
                    : (esame.stato.contains('FREQUENTAT')
                        ? scheme.primary
                        : scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(width: 12),

            // Dati esame
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esame.descrizione,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          esame.superato ? FontWeight.w700 : FontWeight.w500,
                      color: esame.superato
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          esame.cfuTesto,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (esame.codice.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(
                          esame.codice,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10.5,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Voto o Stato
            if (esame.superato)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.zolfo.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  esame.votoDisplay.isNotEmpty ? esame.votoDisplay : 'IDO',
                  style: AppTheme.numerico(
                    size: 14,
                    color: AppColors.zolfo,
                  ),
                ),
              )
            else
              Text(
                esame.stato.contains('FREQUENTAT') ? 'In corso' : 'Pianificato',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: esame.stato.contains('FREQUENTAT')
                      ? scheme.primary
                      : scheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCol extends StatelessWidget {
  const _InfoCol({
    required this.label,
    required this.valore,
    required this.colore,
    required this.icona,
  });

  final String label;
  final String valore;
  final Color colore;
  final IconData icona;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icona, size: 18, color: colore),
        const SizedBox(height: 4),
        Text(
          valore,
          style: AppTheme.numerico(size: 16, color: colore),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
      ],
    );
  }
}

class _DettaglioRiga extends StatelessWidget {
  const _DettaglioRiga({
    required this.icon,
    required this.label,
    required this.valore,
    this.coloreValore,
  });

  final IconData icon;
  final String label;
  final String valore;
  final Color? coloreValore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  valore,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: coloreValore ?? scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

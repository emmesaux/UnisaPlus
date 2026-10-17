import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/cineca_rest_service.dart';
import '../theme/app_theme.dart';

class LibrettoScreen extends StatefulWidget {
  const LibrettoScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<LibrettoScreen> createState() => _LibrettoScreenState();
}

class _EsameSimulatoExtra {
  String nome;
  int cfu;
  int voto;
  _EsameSimulatoExtra({
    required this.nome,
    required this.cfu,
    required this.voto,
  });
}

class _LibrettoScreenState extends State<LibrettoScreen> {
  LibrettoDati? _dati;
  bool _loading = true;
  String? _errore;

  // 0 = Libretto, 1 = Previsione Laurea
  int _sezione = 0;

  // Filtro lista libretto: 0 = Tutti, 1 = Superati, 2 = Da sostenere
  int _filtroEsami = 0;

  // Mappa indice esame -> voto simulato (18..30) per gli esami non ancora superati
  final Map<int, int> _votiSimulati = {};
  final List<_EsameSimulatoExtra> _esamiExtra = [];
  double _puntiTesi = 6.0;
  bool _usaMediaPonderata = true;

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
      final dati = await widget.authService.getLibrettoReale();
      if (!mounted) return;
      setState(() {
        _dati = dati;
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

  Future<void> _aggiungiEsameExtraDialog() async {
    final nomeCtrl = TextEditingController(text: 'Esame a scelta');
    int cfuScelti = 6;
    int votoScelto = 28;

    final aggiunto = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Aggiungi esame simulato'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: nomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome insegnamento',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Crediti (CFU):'),
                  DropdownButton<int>(
                    value: cfuScelti,
                    items: [3, 6, 9, 12, 15, 18]
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text('$c CFU'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => cfuScelti = v);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Voto previsto:'),
                  DropdownButton<int>(
                    value: votoScelto,
                    items: List.generate(13, (i) => 18 + i)
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text('$v/30'),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => votoScelto = v);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Aggiungi'),
            ),
          ],
        ),
      ),
    );

    if (aggiunto == true && mounted) {
      setState(() {
        _esamiExtra.add(
          _EsameSimulatoExtra(
            nome: nomeCtrl.text.trim().isEmpty
                ? 'Esame simulato'
                : nomeCtrl.text.trim(),
            cfu: cfuScelti,
            voto: votoScelto,
          ),
        );
      });
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

    final dati = _dati!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.book_outlined, size: 18),
                label: Text('Libretto'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.school_outlined, size: 18),
                label: Text('Previsione laurea'),
              ),
            ],
            selected: {_sezione},
            onSelectionChanged: (s) => setState(() => _sezione = s.first),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _carica,
            child: _sezione == 0
                ? _buildLibrettoView(context, dati)
                : _buildPrevisioneView(context, dati),
          ),
        ),
      ],
    );
  }

  Widget _buildLibrettoView(BuildContext context, LibrettoDati dati) {
    final scheme = Theme.of(context).colorScheme;
    final stats = dati.statistiche;
    final esamiFiltrati = dati.esami.where((e) {
      if (_filtroEsami == 1) return e.superato;
      if (_filtroEsami == 2) return !e.superato;
      return true;
    }).toList();

    final superatiCount = dati.esami.where((e) => e.superato).length;
    final daSostenereCount = dati.esami.length - superatiCount;
    final progressoCfu = stats.cfuTotali > 0
        ? (stats.cfuAcquisiti / stats.cfuTotali).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        // Card Riepilogo Medie & CFU
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'MEDIA PONDERATA',
                      valore: stats.mediaPonderata.toStringAsFixed(2),
                      sottotitolo:
                          'Base laurea: ${stats.baseLaureaPonderata.toStringAsFixed(2)}/110',
                      evidenzia: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatBox(
                      label: 'MEDIA ARITMETICA',
                      valore: stats.mediaAritmetica.toStringAsFixed(2),
                      sottotitolo:
                          'Base laurea: ${stats.baseLaureaAritmetica.toStringAsFixed(2)}/110',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Crediti acquisiti (CFU)',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${stats.cfuAcquisiti} / ${stats.cfuTotali} CFU',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressoCfu,
                  minHeight: 8,
                  backgroundColor: scheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(scheme.primary),
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
                label: Text('Tutti (${dati.esami.length})'),
                selected: _filtroEsami == 0,
                onSelected: (_) => setState(() => _filtroEsami = 0),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Superati ($superatiCount)'),
                selected: _filtroEsami == 1,
                onSelected: (_) => setState(() => _filtroEsami = 1),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: Text('Da sostenere ($daSostenereCount)'),
                selected: _filtroEsami == 2,
                onSelected: (_) => setState(() => _filtroEsami = 2),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        if (esamiFiltrati.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'Nessun esame in questa categoria.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...esamiFiltrati.map((e) => _EsameLibrettoCard(esame: e)),
      ],
    );
  }

  Widget _buildPrevisioneView(BuildContext context, LibrettoDati dati) {
    final scheme = Theme.of(context).colorScheme;

    // Calcolo combinato: esami superati con voto + esami simulati
    int sommaVoti = 0;
    int numEsami = 0;
    int sommaPesata = 0;
    int sommaCfuVoto = 0;
    int cfuAcquisitiSim = dati.statistiche.cfuAcquisiti;

    for (final e in dati.esami) {
      if (e.superato && e.votoNumerico != null && e.votoNumerico! >= 18) {
        sommaVoti += e.votoNumerico!;
        numEsami++;
        sommaPesata += e.votoNumerico! * e.cfu;
        sommaCfuVoto += e.cfu;
      }
    }

    // Esami del libretto non ancora superati (escludendo OFA)
    final esamiSimulabili = <MapEntry<int, EsameLibretto>>[];
    for (var i = 0; i < dati.esami.length; i++) {
      final e = dati.esami[i];
      if (!e.superato &&
          !e.descrizione.toUpperCase().contains('OFA') &&
          e.cfu > 0) {
        esamiSimulabili.add(MapEntry(i, e));
        final votoSim = _votiSimulati[i];
        if (votoSim != null && votoSim >= 18) {
          sommaVoti += votoSim;
          numEsami++;
          sommaPesata += votoSim * e.cfu;
          sommaCfuVoto += e.cfu;
          cfuAcquisitiSim += e.cfu;
        }
      }
    }

    for (final extra in _esamiExtra) {
      sommaVoti += extra.voto;
      numEsami++;
      sommaPesata += extra.voto * extra.cfu;
      sommaCfuVoto += extra.cfu;
      cfuAcquisitiSim += extra.cfu;
    }

    final mediaAritSim = numEsami > 0
        ? sommaVoti / numEsami
        : dati.statistiche.mediaAritmetica;
    final mediaPondSim = sommaCfuVoto > 0
        ? sommaPesata / sommaCfuVoto
        : dati.statistiche.mediaPonderata;
    final baseAritSim = (mediaAritSim * 110.0) / 30.0;
    final basePondSim = (mediaPondSim * 110.0) / 30.0;

    final baseScelta = _usaMediaPonderata ? basePondSim : baseAritSim;
    final votoLaureaGreggio = baseScelta + _puntiTesi;
    final votoLaureaArrotondato = votoLaureaGreggio.round().clamp(66, 110);
    final possibileLode = votoLaureaGreggio >= 110.5;

    final numSimulatiAttivi = _votiSimulati.length + _esamiExtra.length;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Card principale Previsione Voto di Laurea
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.primary.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'VOTO DI LAUREA PREVISTO',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  if (numSimulatiAttivi > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '+$numSimulatiAttivi esami simulati',
                        style: TextStyle(
                          color: scheme.onPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    possibileLode
                        ? '110L'
                        : '$votoLaureaArrotondato',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ 110  (${votoLaureaGreggio.toStringAsFixed(2)})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'BASE PONDERATA',
                      valore: '${basePondSim.toStringAsFixed(2)}/110',
                      sottotitolo:
                          'Media: ${mediaPondSim.toStringAsFixed(2)}/30',
                      evidenzia: _usaMediaPonderata,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'BASE ARITMETICA',
                      valore: '${baseAritSim.toStringAsFixed(2)}/110',
                      sottotitolo:
                          'Media: ${mediaAritSim.toStringAsFixed(2)}/30',
                      evidenzia: !_usaMediaPonderata,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Calcola voto finale su:',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: true, label: Text('Ponderata')),
                      ButtonSegment(value: false, label: Text('Aritmetica')),
                    ],
                    selected: {_usaMediaPonderata},
                    onSelectionChanged: (s) =>
                        setState(() => _usaMediaPonderata = s.first),
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Slider Punti Tesi / Bonus
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Punti tesi e bonus carriera',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '+${_puntiTesi.toStringAsFixed(1)} pt',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Slider(
                value: _puntiTesi,
                min: 0,
                max: 12,
                divisions: 24,
                label: '+${_puntiTesi.toStringAsFixed(1)} pt',
                onChanged: (v) => setState(() => _puntiTesi = v),
              ),
              Text(
                'Trascina per impostare i punti stimati per la prova finale e gli eventuali bonus (es. laurea in corso, lode).',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Intestazione simulatore esami futuri
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Simula esami mancanti',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'CFU totali con simulazione: $cfuAcquisitiSim / ${dati.statistiche.cfuTotali}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (numSimulatiAttivi > 0)
              TextButton.icon(
                onPressed: () => setState(() {
                  _votiSimulati.clear();
                  _esamiExtra.clear();
                }),
                icon: const Icon(Icons.restart_alt, size: 18),
                label: const Text('Azzera'),
              ),
          ],
        ),
        const SizedBox(height: 8),

        OutlinedButton.icon(
          onPressed: _aggiungiEsameExtraDialog,
          icon: const Icon(Icons.add),
          label: const Text('Aggiungi esame a scelta / extra'),
        ),
        const SizedBox(height: 12),

        // Esami extra aggiunti manualmente
        ..._esamiExtra.asMap().entries.map((entry) {
          final idx = entry.key;
          final ex = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.nome,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${ex.cfu} CFU · Esame simulato',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                DropdownButton<int>(
                  value: ex.voto,
                  underline: const SizedBox.shrink(),
                  items: List.generate(13, (i) => 18 + i)
                      .map(
                        (v) => DropdownMenuItem(
                          value: v,
                          child: Text(
                            '$v/30',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => ex.voto = v);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _esamiExtra.removeAt(idx)),
                ),
              ],
            ),
          );
        }),

        // Esami da sostenere presenti nel libretto
        if (esamiSimulabili.isEmpty && _esamiExtra.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Tutti gli esami del libretto risultano superati! Usa il pulsante sopra per simulare eventuali esami aggiuntivi.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          ...esamiSimulabili.map((entry) {
            final idx = entry.key;
            final esame = entry.value;
            final votoSim = _votiSimulati[idx];
            final attivo = votoSim != null;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: attivo ? scheme.primary : scheme.outlineVariant,
                  width: attivo ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              esame.descrizione,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              esame.cfuTesto,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (attivo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$votoSim/30',
                            style: TextStyle(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        )
                      else
                        Text(
                          'Non simulato',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Text('17', style: TextStyle(fontSize: 11)),
                      Expanded(
                        child: Slider(
                          value: (votoSim ?? 17).toDouble(),
                          min: 17,
                          max: 30,
                          divisions: 13,
                          label: votoSim == null ? 'Escludi' : '$votoSim',
                          onChanged: (val) {
                            final v = val.round();
                            setState(() {
                              if (v <= 17) {
                                _votiSimulati.remove(idx);
                              } else {
                                _votiSimulati[idx] = v;
                              }
                            });
                          },
                        ),
                      ),
                      const Text('30', style: TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.valore,
    required this.sottotitolo,
    this.evidenzia = false,
  });

  final String label;
  final String valore;
  final String sottotitolo;
  final bool evidenzia;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: evidenzia
            ? scheme.primary.withValues(alpha: 0.08)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: evidenzia
              ? scheme.primary.withValues(alpha: 0.35)
              : scheme.outlineVariant,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 10,
              letterSpacing: 0.5,
              color: evidenzia ? scheme.primary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valore,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sottotitolo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _EsameLibrettoCard extends StatelessWidget {
  const _EsameLibrettoCard({required this.esame});
  final EsameLibretto esame;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final superato = esame.superato;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 44,
            decoration: BoxDecoration(
              color: superato ? AppTheme.success : scheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  esame.descrizione,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      esame.cfuTesto,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (esame.codice.isNotEmpty)
                      Text(
                        'Cod. ${esame.codice}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (esame.annoCorso.isNotEmpty)
                      Text(
                        'Anno ${esame.annoCorso}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          if (superato)
            Container(
              constraints: const BoxConstraints(minWidth: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.success.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                esame.votoDisplay,
                style: TextStyle(
                  color: AppTheme.success,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Da sostenere',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

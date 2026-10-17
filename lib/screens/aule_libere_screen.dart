import 'package:flutter/material.dart';
import '../models/aula.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Disponibilità delle aule per edificio, dal servizio EasyRoom reale
/// dell'ateneo. Toccando qualsiasi aula si apre la scansione completa
/// dell'arco della giornata con tutte le fasce libere, quelle occupate,
/// l'insegnamento e il docente.
class AuleLibereScreen extends StatefulWidget {
  const AuleLibereScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<AuleLibereScreen> createState() => _AuleLibereScreenState();
}

class _AuleLibereScreenState extends State<AuleLibereScreen> {
  late Future<List<EdificioAule>> _future;
  final _cercaCtrl = TextEditingController();
  String _query = '';
  bool _soloLibere = false;

  @override
  void initState() {
    super.initState();
    _future = widget.api.getAuleLibere();
  }

  @override
  void dispose() {
    _cercaCtrl.dispose();
    super.dispose();
  }

  void _ricarica() => setState(() {
        _future = widget.api.getAuleLibere();
      });

  List<EdificioAule> _filtra(List<EdificioAule> edifici, DateTime now) {
    final q = _query.trim().toLowerCase();
    return edifici
        .map((e) {
          final edificioMatcha = q.isEmpty || e.nome.toLowerCase().contains(q);
          final aule = e.aule.where((a) {
            if (_soloLibere && !a.liberaOra(now)) return false;
            if (q.isEmpty) return true;
            return edificioMatcha ||
                a.nome.toLowerCase().contains(q) ||
                a.lezioni.any(
                  (l) =>
                      l.nome.toLowerCase().contains(q) ||
                      l.docente.toLowerCase().contains(q),
                );
          }).toList();
          return EdificioAule(nome: e.nome, aule: aule);
        })
        .where((e) => e.aule.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _cercaCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cerca aula, edificio, corso o docente',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => setState(() {
                        _cercaCtrl.clear();
                        _query = '';
                      }),
                    ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Solo aule libere in questo momento',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              Switch(
                value: _soloLibere,
                onChanged: (v) => setState(() => _soloLibere = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<EdificioAule>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final visibili = _filtra(snapshot.data ?? [], now);
              if (visibili.isEmpty) {
                return EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: _query.isNotEmpty
                      ? 'Nessun risultato'
                      : (_soloLibere
                            ? 'Nessuna aula libera ora'
                            : 'Nessuna aula trovata'),
                  message: _query.isNotEmpty
                      ? 'Nessuna aula, edificio o lezione corrisponde a "$_query".'
                      : 'Riprova più tardi oppure disattiva il filtro.',
                  onRetry: _ricarica,
                );
              }
              final libereOra = visibili.fold<int>(
                0,
                (n, e) => n + e.aule.where((a) => a.liberaOra(now)).length,
              );
              final totali = visibili.fold<int>(
                0,
                (n, e) => n + e.aule.length,
              );
              return RefreshIndicator(
                onRefresh: () async => _ricarica(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            '$libereOra libere ora su $totali',
                            style: AppTheme.codice(
                              size: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Tocca un\'aula per gli orari del giorno',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    for (final e in visibili)
                      _EdificioSection(edificio: e, now: now),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

void _apriDettaglioAula(
  BuildContext context,
  String nomeEdificio,
  AulaConOrario aula,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.76,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      expand: false,
      builder: (_, scrollController) => _DettaglioAulaSheet(
        nomeEdificio: nomeEdificio,
        aula: aula,
        scrollController: scrollController,
      ),
    ),
  );
}

class _EdificioSection extends StatelessWidget {
  const _EdificioSection({required this.edificio, required this.now});
  final EdificioAule edificio;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final libereOra = edificio.aule.where((a) => a.liberaOra(now)).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    edificio.nome,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '$libereOra/${edificio.aule.length} libere ora',
                  style: AppTheme.codice(
                    size: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          for (final a in edificio.aule)
            _AulaCard(
              aula: a,
              now: now,
              onTap: () => _apriDettaglioAula(context, edificio.nome, a),
            ),
        ],
      ),
    );
  }
}

class _AulaCard extends StatelessWidget {
  const _AulaCard({
    required this.aula,
    required this.now,
    required this.onTap,
  });

  final AulaConOrario aula;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const verde = Color(0xFF2E7D5B);
    final inCorso = aula.lezioneInCorso(now);
    final prossima = aula.prossimaLezione(now);
    final isLiberaOra = inCorso == null;
    final colore = isLiberaOra ? verde : AppColors.corallo;

    final String statoBadge;
    if (aula.libera) {
      statoBadge = 'Libera tutto il giorno';
    } else if (isLiberaOra && prossima != null) {
      statoBadge = 'Libera fino alle ${prossima.dalleBreve}';
    } else if (isLiberaOra) {
      statoBadge = 'Libera ora';
    } else {
      statoBadge = 'Occupata fino alle ${inCorso.alleBreve}';
    }

    final lezioniOrd = aula.lezioniOrdinate;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: colore),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                aula.nome,
                                style: AppTheme.numerico(
                                  size: 16,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: colore,
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                statoBadge,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                        if (lezioniOrd.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (final l in lezioniOrd)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${l.dalleBreve}–${l.alleBreve}  ',
                                    style: AppTheme.codice(
                                      size: 12,
                                      color: l.inCorsoOra(now)
                                          ? AppColors.corallo
                                          : scheme.onSurfaceVariant,
                                      weight: l.inCorsoOra(now)
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      l.docente.trim().isNotEmpty
                                          ? '${l.nome} · ${l.docente}'
                                          : l.nome,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            fontWeight: l.inCorsoOra(now)
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ] else ...[
                          const SizedBox(height: 4),
                          Text(
                            'Nessuna lezione in programma oggi · Tocca per dettagli',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DettaglioAulaSheet extends StatelessWidget {
  const _DettaglioAulaSheet({
    required this.nomeEdificio,
    required this.aula,
    required this.scrollController,
  });

  final String nomeEdificio;
  final AulaConOrario aula;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    const verde = Color(0xFF2E7D5B);
    final inCorso = aula.lezioneInCorso(now);
    final prossima = aula.prossimaLezione(now);
    final fasce = aula.fasceGiornaliere();

    final bool isLiberaOra = inCorso == null;
    final Color statoColore = isLiberaOra ? verde : AppColors.corallo;
    final String statoTitolo;
    final String statoSottotitolo;

    if (aula.libera) {
      statoTitolo = 'Libera tutto il giorno';
      statoSottotitolo =
          'Non ci sono lezioni previste in quest\'aula per l\'intera giornata.';
    } else if (isLiberaOra && prossima != null) {
      statoTitolo = 'Libera ora · fino alle ${prossima.dalleBreve}';
      statoSottotitolo =
          'Prossima lezione alle ${prossima.dalleBreve}: ${prossima.nome}';
    } else if (isLiberaOra) {
      statoTitolo = 'Libera ora · fino a chiusura';
      statoSottotitolo =
          'Tutte le lezioni di oggi in quest\'aula sono terminate.';
    } else {
      statoTitolo = 'Occupata ora · fino alle ${inCorso.alleBreve}';
      statoSottotitolo = inCorso.docente.trim().isNotEmpty
          ? '${inCorso.nome} (${inCorso.docente})'
          : inCorso.nome;
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (nomeEdificio.isNotEmpty)
                    Text(
                      nomeEdificio.toUpperCase(),
                      style: AppTheme.codice(
                        size: 11,
                        color: scheme.primary,
                        weight: FontWeight.w700,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    aula.nome,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Banner stato attuale
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: statoColore.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: statoColore),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isLiberaOra
                    ? Icons.check_circle_outline
                    : Icons.schedule_outlined,
                color: statoColore,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      statoTitolo,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: statoColore,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      statoSottotitolo,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Barra visiva dell'arco della giornata
        Text(
          'Arco della giornata (${fasce.first.dalle} – ${fasce.last.alle})',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        _BarraArcoGiornata(fasce: fasce),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendaDot(colore: verde, label: 'Aula libera'),
            const SizedBox(width: 16),
            _LegendaDot(colore: AppColors.corallo, label: 'Lezione in aula'),
          ],
        ),
        const SizedBox(height: 20),

        Text(
          'Disponibilità e lezioni fascia per fascia',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        for (final f in fasce) _FasciaRow(fascia: f, now: now),
      ],
    );
  }
}

class _BarraArcoGiornata extends StatelessWidget {
  const _BarraArcoGiornata({required this.fasce});
  final List<FasciaGiornalieraAula> fasce;

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF2E7D5B);
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        height: 18,
        child: Row(
          children: [
            for (final f in fasce)
              if (f.durataMinuti > 0)
                Expanded(
                  flex: f.durataMinuti,
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    color: f.libera ? verde : AppColors.corallo,
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _LegendaDot extends StatelessWidget {
  const _LegendaDot({required this.colore, required this.label});
  final Color colore;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colore,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _FasciaRow extends StatelessWidget {
  const _FasciaRow({required this.fascia, required this.now});
  final FasciaGiornalieraAula fascia;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const verde = Color(0xFF2E7D5B);
    final isAdesso = fascia.inCorsoOra(now);
    final colore = fascia.libera ? verde : AppColors.corallo;
    final lezione = fascia.lezione;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isAdesso
            ? colore.withValues(alpha: 0.08)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isAdesso ? colore : scheme.outlineVariant,
          width: isAdesso ? 1.5 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 4, color: colore),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${fascia.dalle} – ${fascia.alle}',
                          style: AppTheme.codice(
                            size: 13,
                            color: scheme.onSurface,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (fascia.durataLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            '(${fascia.durataLabel})',
                            style: AppTheme.codice(
                              size: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (isAdesso)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.zolfo,
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              'ORA',
                              style: AppTheme.codice(
                                size: 9,
                                color: AppColors.inchiostro,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: colore.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fascia.libera ? 'LIBERA' : 'LEZIONE',
                            style: AppTheme.codice(
                              size: 10,
                              color: colore,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (lezione == null)
                      Text(
                        'Aula libera per studio individuale o sosta',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    else ...[
                      Text(
                        lezione.nome,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (lezione.docente.trim().isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              size: 14,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                lezione.docente,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

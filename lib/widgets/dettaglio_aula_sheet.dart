import 'package:flutter/material.dart';
import '../models/aula.dart';
import '../theme/app_theme.dart';

/// Scheda modale con i dettagli completi dell'aula: stato di occupazione in
/// tempo reale, capienza, prossima lezione e scansione di tutte le fasce
/// orarie della giornata (lezioni e ore libere).
class DettaglioAulaSheet extends StatelessWidget {
  const DettaglioAulaSheet({
    super.key,
    required this.nomeEdificio,
    required this.aula,
    required this.scrollController,
  });

  final String nomeEdificio;
  final AulaConOrario aula;
  final ScrollController scrollController;

  static void mostra(
    BuildContext context, {
    required String nomeEdificio,
    required AulaConOrario aula,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => DettaglioAulaSheet(
          nomeEdificio: nomeEdificio,
          aula: aula,
          scrollController: scrollController,
        ),
      ),
    );
  }

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
                  if (aula.capacity != null && aula.capacity!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 15,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Capienza: ${aula.capacity} posti a sedere',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
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
            const _LegendaDot(colore: verde, label: 'Aula libera'),
            const SizedBox(width: 16),
            const _LegendaDot(colore: AppColors.corallo, label: 'Lezione in aula'),
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
                        const SizedBox(width: 8),
                        Text(
                          '(${fascia.durataLabel})',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colore.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            fascia.libera ? 'LIBERA' : 'LEZIONE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: colore,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (lezione != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        lezione.nome,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (lezione.docente.trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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


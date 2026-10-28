import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lezione.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/board_row.dart';
import '../widgets/empty_state.dart';
import 'esame_dettaglio_screen.dart';

/// Agenda esami: appelli reali dall'API studente dell'ateneo
/// (`unisa.app.cineca.it`, stesso endpoint di campus), divisi tra quelli
/// a cui lo studente è già iscritto (Prenotati) e quelli ancora aperti
/// (Prenotabili). Nessun dato di esempio.
class AgendaEsamiScreen extends StatefulWidget {
  const AgendaEsamiScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<AgendaEsamiScreen> createState() => _AgendaEsamiScreenState();
}

class _AgendaEsamiScreenState extends State<AgendaEsamiScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  late Future<List<EsameAgenda>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.authService.getAppelliReali();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _ricarica() => setState(() {
        _future = widget.authService.getAppelliReali();
      });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'Prenotati'),
            Tab(text: 'Prenotabili'),
          ],
        ),
        Expanded(
          child: FutureBuilder<List<EsameAgenda>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Esami non disponibili',
                  message:
                      'Il servizio esami dell’ateneo non ha risposto. Riprova tra poco.',
                  upstream: true,
                  onRetry: _ricarica,
                );
              }
              final tutti = snapshot.data ?? [];
              final prenotati = tutti.where((e) => e.prenotato).toList()
                ..sort((a, b) => a.data.compareTo(b.data));
              final prenotabili = tutti.where((e) => e.prenotabile).toList();
              return TabBarView(
                controller: _tab,
                children: [
                  // Prenotati: lista semplice (come prima), uno sotto l'altro.
                  _ListaAppelli(
                    appelli: prenotati,
                    aTendina: false,
                    vuotoTitolo: 'Nessun esame prenotato',
                    vuotoMessaggio:
                        'Gli appelli a cui ti iscrivi compaiono qui.',
                    badge: 'Prenotato',
                    badgeColor: const Color(0xFF2E7D5B),
                    onRetry: _ricarica,
                  ),
                  // Prenotabili: raggruppati per materia, a tendina.
                  _ListaAppelli(
                    appelli: prenotabili,
                    aTendina: true,
                    vuotoTitolo: 'Nessun appello prenotabile',
                    vuotoMessaggio:
                        'Quando il tuo corso apre nuovi appelli li vedrai qui.',
                    onRetry: _ricarica,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ListaAppelli extends StatelessWidget {
  const _ListaAppelli({
    required this.appelli,
    required this.vuotoTitolo,
    required this.vuotoMessaggio,
    required this.onRetry,
    required this.aTendina,
    this.badge,
    this.badgeColor,
  });

  final List<EsameAgenda> appelli;
  final String vuotoTitolo;
  final String vuotoMessaggio;
  final VoidCallback onRetry;
  final bool aTendina;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    if (appelli.isEmpty) {
      return EmptyState(
        icon: Icons.menu_book_outlined,
        title: vuotoTitolo,
        message: vuotoMessaggio,
        onRetry: onRetry,
      );
    }
    if (!aTendina) {
      // Lista semplice (prenotati): una card per appello, con materia in
      // alto e aula + docente in evidenza.
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          for (final e in appelli) _AppelloCard(appello: e, badge: badge, badgeColor: badgeColor),
        ],
      );
    }
    // Raggruppa per materia: ogni materia è una tendina.
    final perMateria = <String, List<EsameAgenda>>{};
    for (final a in appelli) {
      perMateria.putIfAbsent(a.insegnamento, () => []).add(a);
    }
    final materie = perMateria.keys.toList()..sort();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final materia in materie)
          _MateriaTendina(
            materia: materia,
            appelli: perMateria[materia]!..sort((a, b) => a.data.compareTo(b.data)),
            apertaInizio: materie.length == 1,
          ),
      ],
    );
  }
}

/// Tendina per una materia (appelli prenotabili): intestazione con pallino
/// colorato, nome e numero di appelli; dentro, una card per appello con
/// aula e docente in evidenza.
class _MateriaTendina extends StatelessWidget {
  const _MateriaTendina({required this.materia, required this.appelli, required this.apertaInizio});

  final String materia;
  final List<EsameAgenda> appelli;
  final bool apertaInizio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colore = coloreMateria(materia);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: apertaInizio,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14),
          childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: colore, shape: BoxShape.circle)),
          title: Text(materia, style: Theme.of(context).textTheme.titleSmall),
          subtitle: Text(
            [
              '${appelli.length} appell${appelli.length == 1 ? 'o' : 'i'}',
              // Gruppi distinti, così si vede da chiuso per chi sono.
              ...{for (final a in appelli) if (a.partizione.isNotEmpty) a.etichettaGruppo},
            ].join(' · '),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          children: [
            for (final e in appelli) _AppelloCard(appello: e, compatta: true),
          ],
        ),
      ),
    );
  }
}

/// Card di un appello: data a sinistra, materia in alto, e soprattutto
/// AULA (classe) e DOCENTE messi in evidenza con icona e sfondo.
class _AppelloCard extends StatelessWidget {
  const _AppelloCard({required this.appello, this.badge, this.badgeColor, this.compatta = false});
  final EsameAgenda appello;
  final String? badge;
  final Color? badgeColor;
  final bool compatta;

  @override
  Widget build(BuildContext context) {
    final e = appello;
    final scheme = Theme.of(context).colorScheme;
    final colore = coloreMateria(e.insegnamento);
    final ora = e.haOrario ? DateFormat('HH:mm').format(e.data) : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: compatta ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => EsameDettaglioScreen(esame: e)),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colore),
              // Data
              Container(
                width: 62,
                padding: const EdgeInsets.symmetric(vertical: 12),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('d', 'it_IT').format(e.data), style: AppTheme.numerico(size: 22, color: scheme.onSurface)),
                    Text(DateFormat('MMM', 'it_IT').format(e.data).toUpperCase(), style: AppTheme.codice(size: 11, color: scheme.onSurfaceVariant)),
                    if (ora != null) Text(ora, style: AppTheme.codice(size: 11, color: colore)),
                  ],
                ),
              ),
              Container(width: 1, color: scheme.outlineVariant),
              // Contenuto
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(e.insegnamento, style: Theme.of(context).textTheme.titleSmall)),
                          if (badge != null) BoardTag(label: badge!, color: badgeColor ?? const Color(0xFF2E7D5B)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Per chi è l'appello (gruppo) e che tipo di prova.
                      if (e.partizione.isNotEmpty || e.tipoProva.isNotEmpty) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (e.partizione.isNotEmpty)
                              _chip(context, Icons.groups_outlined, e.etichettaGruppo, scheme.tertiary),
                            if (e.tipoProva.isNotEmpty)
                              _chip(context, Icons.edit_note_outlined, e.tipoProva, scheme.secondary),
                          ],
                        ),
                        const SizedBox(height: 6),
                      ],
                      // Aula e docente IN EVIDENZA.
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (e.aula.isNotEmpty) _chip(context, Icons.meeting_room_outlined, e.aula, colore),
                          if (e.docente.isNotEmpty) _chip(context, Icons.person_outline, e.docente, scheme.primary),
                        ],
                      ),
                      if (e.aula.isEmpty && e.docente.isEmpty)
                        Text('Aula e docente non ancora pubblicati', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String testo, Color colore) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colore.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colore),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              testo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

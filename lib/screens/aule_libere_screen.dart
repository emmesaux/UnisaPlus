import 'package:flutter/material.dart';
import '../models/aula.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// Disponibilita delle aule per edificio, dal servizio EasyRoom reale
/// dell'ateneo. E' informazione pubblica: non richiede login. Un'aula
/// senza lezioni oggi e' libera; un'aula con lezioni mostra i suoi orari
/// occupati. Ricercabile per nome aula o edificio.
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

  List<EdificioAule> _filtra(List<EdificioAule> edifici) {
    final q = _query.trim().toLowerCase();
    return edifici
        .map((e) {
          final edificioMatcha = q.isEmpty || e.nome.toLowerCase().contains(q);
          final aule = e.aule.where((a) {
            if (_soloLibere && !a.libera) return false;
            if (q.isEmpty) return true;
            // Se l'edificio corrisponde, mostra tutte le sue aule;
            // altrimenti filtra per nome aula.
            return edificioMatcha || a.nome.toLowerCase().contains(q);
          }).toList();
          return EdificioAule(nome: e.nome, aule: aule);
        })
        .where((e) => e.aule.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _cercaCtrl,
            onChanged: (v) => setState(() => _query = v),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cerca aula o edificio',
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
              Expanded(child: Text('Solo aule libere ora', style: Theme.of(context).textTheme.bodyMedium)),
              Switch(value: _soloLibere, onChanged: (v) => setState(() => _soloLibere = v)),
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
              final visibili = _filtra(snapshot.data ?? []);
              if (visibili.isEmpty) {
                return EmptyState(
                  icon: Icons.meeting_room_outlined,
                  title: _query.isNotEmpty ? 'Nessun risultato' : (_soloLibere ? 'Nessuna aula libera ora' : 'Nessuna aula trovata'),
                  message: _query.isNotEmpty
                      ? 'Nessuna aula o edificio corrisponde a "$_query".'
                      : 'Riprova piu tardi oppure disattiva il filtro.',
                  onRetry: _ricarica,
                );
              }
              final libere = visibili.fold<int>(0, (n, e) => n + e.aule.where((a) => a.libera).length);
              final totali = visibili.fold<int>(0, (n, e) => n + e.aule.length);
              return RefreshIndicator(
                onRefresh: () async => _ricarica(),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '$libere libere su $totali',
                        style: AppTheme.codice(size: 12, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    for (final e in visibili) _EdificioSection(edificio: e),
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

class _EdificioSection extends StatelessWidget {
  const _EdificioSection({required this.edificio});
  final EdificioAule edificio;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final libere = edificio.aule.where((a) => a.libera).length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, top: 8),
            child: Row(
              children: [
                Expanded(child: Text(edificio.nome, style: Theme.of(context).textTheme.titleSmall)),
                Text('$libere/${edificio.aule.length} libere', style: AppTheme.codice(size: 11, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          for (final a in edificio.aule) _AulaCard(aula: a),
        ],
      ),
    );
  }
}

class _AulaCard extends StatelessWidget {
  const _AulaCard({required this.aula});
  final AulaConOrario aula;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const verde = Color(0xFF2E7D5B);
    final colore = aula.libera ? verde : AppColors.corallo;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: colore,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(aula.nome, style: AppTheme.numerico(size: 16, color: scheme.onSurface))),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: colore, borderRadius: BorderRadius.circular(3)),
                          child: Text(
                            aula.libera ? 'Libera' : 'Occupata',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    if (!aula.libera) ...[
                      const SizedBox(height: 8),
                      for (final l in aula.lezioni)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: '${_breve(l.dalle)}–${_breve(l.alle)}  ',
                                  style: AppTheme.codice(size: 12, color: scheme.onSurfaceVariant),
                                ),
                                TextSpan(text: l.nome, style: Theme.of(context).textTheme.bodyMedium),
                              ],
                            ),
                          ),
                        ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Text('Nessuna lezione in programma oggi', style: Theme.of(context).textTheme.bodySmall),
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

  String _breve(String oraHHmmss) => oraHHmmss.length >= 5 ? oraHHmmss.substring(0, 5) : oraHHmmss;
}

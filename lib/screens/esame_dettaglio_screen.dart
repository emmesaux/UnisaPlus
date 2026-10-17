import 'package:add_2_calendar/add_2_calendar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lezione.dart';
import '../theme/app_theme.dart';

/// Dettaglio di un appello d'esame: data, orario, aula, docente, sessione,
/// note, e un pulsante per aggiungerlo al calendario del telefono.
class EsameDettaglioScreen extends StatelessWidget {
  const EsameDettaglioScreen({super.key, required this.esame});
  final EsameAgenda esame;

  Future<void> _aggiungiAlCalendario(BuildContext context) async {
    final inizio = esame.data;
    // Se non c'è orario, lo si segna come evento di un'ora dalle 9:00.
    final start = esame.haOrario ? inizio : DateTime(inizio.year, inizio.month, inizio.day, 9);
    final end = start.add(const Duration(hours: 1));
    final event = Event(
      title: 'Esame: ${esame.insegnamento}',
      description: [
        if (esame.partizione.isNotEmpty) 'Gruppo: ${esame.etichettaGruppo}',
        if (esame.tipoProva.isNotEmpty) 'Prova: ${esame.tipoProva}',
        if (esame.docente.isNotEmpty) 'Docente: ${esame.docente}',
        if (esame.sessione.isNotEmpty) 'Sessione: ${esame.sessione}',
        if (esame.note.isNotEmpty) esame.note,
      ].join('\n'),
      location: esame.aula,
      startDate: start,
      endDate: end,
    );
    final ok = await Add2Calendar.addEvent2Cal(event);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossibile aprire il calendario.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final dataLunga = DateFormat('EEEE d MMMM yyyy', 'it_IT').format(esame.data);
    final ora = esame.haOrario ? DateFormat('HH:mm').format(esame.data) : null;
    return Scaffold(
      appBar: AppBar(title: const Text('Dettaglio esame')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            decoration: BoxDecoration(color: AppColors.inchiostro, borderRadius: BorderRadius.circular(6)),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esame.prenotato)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF2E7D5B), borderRadius: BorderRadius.circular(3)),
                    child: const Text('Prenotato', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
                  ),
                Text(esame.insegnamento, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppColors.pietra)),
                const SizedBox(height: 8),
                Text(
                  dataLunga[0].toUpperCase() + dataLunga.substring(1),
                  style: AppTheme.numerico(size: 18, color: AppColors.zolfo),
                ),
                if (ora != null)
                  Text('ore $ora', style: AppTheme.numerico(size: 15, color: AppColors.nebbiaChiara)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _riga(context, Icons.groups_outlined, 'Gruppo', esame.etichettaGruppo),
          _riga(context, Icons.edit_note_outlined, 'Prova', esame.tipoProva),
          _riga(context, Icons.place_outlined, 'Aula', esame.aula),
          _riga(context, Icons.person_outline, 'Docente', esame.docente),
          _riga(context, Icons.event_note_outlined, 'Sessione', esame.sessione),
          if (esame.corso.isNotEmpty) _riga(context, Icons.school_outlined, 'Corso', esame.corso),
          if (esame.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Note', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(esame.note, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _aggiungiAlCalendario(context),
            icon: const Icon(Icons.event_available),
            label: const Text('Aggiungi al calendario'),
          ),
        ],
      ),
    );
  }

  Widget _riga(BuildContext context, IconData icon, String label, String valore) {
    if (valore.trim().isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: Text(valore, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

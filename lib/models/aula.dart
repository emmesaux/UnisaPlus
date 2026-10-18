/// Modello delle aule, fedele allo schema XML reale restituito da
/// `https://easycourse.unisa.it/EasyRoom/do.php` (nessuna autenticazione
/// richiesta: è un'informazione pubblica).
library;

class LezioneAula {
  final String nome;
  final String docente;
  final String dalle;
  final String alle;

  LezioneAula({
    required this.nome,
    required this.docente,
    required this.dalle,
    required this.alle,
  });

  String get dalleBreve => dalle.length >= 5 ? dalle.substring(0, 5) : dalle;
  String get alleBreve => alle.length >= 5 ? alle.substring(0, 5) : alle;

  int get inizioMinuti => _parseMinuti(dalle);
  int get fineMinuti => _parseMinuti(alle);

  bool inCorsoOra([DateTime? now]) {
    final t = now ?? DateTime.now();
    final m = t.hour * 60 + t.minute;
    return inizioMinuti <= m && m < fineMinuti;
  }

  static int _parseMinuti(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length < 2) return 0;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String formatMinuti(int minuti) {
    final h = (minuti ~/ 60).clamp(0, 23).toString().padLeft(2, '0');
    final m = (minuti % 60).clamp(0, 59).toString().padLeft(2, '0');
    return '$h:$m';
  }
}

/// Singola fascia nell'arco della giornata di un'aula (libera oppure occupata da una lezione).
class FasciaGiornalieraAula {
  final int inizioMinuti;
  final int fineMinuti;
  final LezioneAula? lezione;

  const FasciaGiornalieraAula({
    required this.inizioMinuti,
    required this.fineMinuti,
    this.lezione,
  });

  bool get libera => lezione == null;
  int get durataMinuti => (fineMinuti - inizioMinuti).clamp(0, 24 * 60);

  String get dalle => LezioneAula.formatMinuti(inizioMinuti);
  String get alle => LezioneAula.formatMinuti(fineMinuti);

  String get durataLabel {
    final d = durataMinuti;
    if (d <= 0) return '';
    final h = d ~/ 60;
    final m = d % 60;
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  bool inCorsoOra([DateTime? now]) {
    final t = now ?? DateTime.now();
    final m = t.hour * 60 + t.minute;
    return inizioMinuti <= m && m < fineMinuti;
  }
}

class AulaConOrario {
  final String id;
  final String nome;
  final List<LezioneAula> lezioni;
  final String? mapId;
  final String? capacity;
  final double? coordX;
  final double? coordY;

  AulaConOrario({
    required this.id,
    required this.nome,
    required this.lezioni,
    this.mapId,
    this.capacity,
    this.coordX,
    this.coordY,
  });

  /// True se non c'è nessuna lezione in tutta la giornata.
  bool get libera => lezioni.isEmpty;

  /// Lezioni ordinate per orario di inizio.
  List<LezioneAula> get lezioniOrdinate {
    final copy = List<LezioneAula>.from(lezioni);
    copy.sort((a, b) => a.inizioMinuti.compareTo(b.inizioMinuti));
    return copy;
  }

  /// Restituisce la lezione attualmente in corso (se presente in questo minuto).
  LezioneAula? lezioneInCorso([DateTime? now]) {
    for (final l in lezioniOrdinate) {
      if (l.inCorsoOra(now)) return l;
    }
    return null;
  }

  /// Restituisce la prossima lezione che inizierà più tardi nella giornata.
  LezioneAula? prossimaLezione([DateTime? now]) {
    final t = now ?? DateTime.now();
    final m = t.hour * 60 + t.minute;
    for (final l in lezioniOrdinate) {
      if (l.inizioMinuti > m) return l;
    }
    return null;
  }

  /// True se l'aula è libera in questo preciso momento della giornata.
  bool liberaOra([DateTime? now]) => lezioneInCorso(now) == null;

  /// Costruisce la scansione completa dell'arco della giornata (es. 08:00–20:00)
  /// alternando gli intervalli in cui l'aula è libera e quelli in cui c'è lezione.
  List<FasciaGiornalieraAula> fasceGiornaliere({
    int inizioGiornataMin = 8 * 60,
    int fineGiornataMin = 20 * 60,
  }) {
    final ord = lezioniOrdinate;
    if (ord.isEmpty) {
      return [
        FasciaGiornalieraAula(
          inizioMinuti: inizioGiornataMin,
          fineMinuti: fineGiornataMin,
        ),
      ];
    }

    var start = inizioGiornataMin;
    var end = fineGiornataMin;
    for (final l in ord) {
      if (l.inizioMinuti > 0 && l.inizioMinuti < start) start = l.inizioMinuti;
      if (l.fineMinuti > end) end = l.fineMinuti;
    }

    final fasce = <FasciaGiornalieraAula>[];
    var cursore = start;

    for (final l in ord) {
      final lStart = l.inizioMinuti;
      final lEnd = l.fineMinuti;
      if (lEnd <= lStart) continue;

      if (lStart > cursore) {
        fasce.add(
          FasciaGiornalieraAula(
            inizioMinuti: cursore,
            fineMinuti: lStart,
          ),
        );
      }
      fasce.add(
        FasciaGiornalieraAula(
          inizioMinuti: lStart,
          fineMinuti: lEnd,
          lezione: l,
        ),
      );
      if (lEnd > cursore) {
        cursore = lEnd;
      }
    }

    if (cursore < end) {
      fasce.add(
        FasciaGiornalieraAula(
          inizioMinuti: cursore,
          fineMinuti: end,
        ),
      );
    }

    return fasce;
  }
}

class EdificioAule {
  final String nome;
  final List<AulaConOrario> aule;

  EdificioAule({required this.nome, required this.aule});
}

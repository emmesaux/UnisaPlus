/// Dati di frequenza/presenze letti dal servizio EasyBadge dell'ateneo.
/// È una CONSULTAZIONE dei propri dati (quante ore ho frequentato, a quali
/// lezioni risulto presente): non registra né altera nulla.
library;

class CorsoPresenza {
  final String codice;
  final String nome;
  final double percentuale; // % di presenza
  final int frequentateMinuti;
  final int svolteMinuti;
  final double percentualeConseguimento;
  final String stato; // "frequentante" | "in_frequenza" | altro

  const CorsoPresenza({
    required this.codice,
    required this.nome,
    required this.percentuale,
    required this.frequentateMinuti,
    required this.svolteMinuti,
    required this.percentualeConseguimento,
    required this.stato,
  });
}

class LezionePresenza {
  final String modulo;
  final DateTime inizio;
  final DateTime fine;
  final bool svolta; // la lezione si è tenuta
  final bool presente; // risulto presente
  final DateTime? timestamp;

  const LezionePresenza({
    required this.modulo,
    required this.inizio,
    required this.fine,
    required this.svolta,
    required this.presente,
    this.timestamp,
  });
}

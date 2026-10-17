/// Modello delle aule, fedele allo schema XML reale restituito da
/// `https://easycourse.unisa.it/EasyRoom/do.php` (nessuna autenticazione
/// richiesta: e' un'informazione pubblica).
///
/// Il server non manda un flag "libera/occupata": manda, per ogni
/// edificio, l'elenco delle sue aule, e separatamente l'elenco delle
/// lezioni del giorno con l'id dell'aula in cui si tengono. Un'aula senza
/// nessuna lezione quel giorno e' libera; un'aula con lezioni mostra i
/// suoi orari occupati, cosi lo studente vede gli spazi liberi tra l'una
/// e l'altra.
library;

class LezioneAula {
  final String nome;
  final String docente;
  final String dalle;
  final String alle;

  LezioneAula({required this.nome, required this.docente, required this.dalle, required this.alle});
}

class AulaConOrario {
  final String id;
  final String nome;
  final List<LezioneAula> lezioni;

  AulaConOrario({required this.id, required this.nome, required this.lezioni});

  bool get libera => lezioni.isEmpty;
}

class EdificioAule {
  final String nome;
  final List<AulaConOrario> aule;

  EdificioAule({required this.nome, required this.aule});
}

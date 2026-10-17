class Lezione {
  final String id;
  final String insegnamento;
  final String docente;
  final String corso;
  final String aula;
  final DateTime inizio;
  final DateTime fine;
  final bool prenotabile;
  final bool prenotata;
  final int postiDisponibili;
  final int postiTotali;

  Lezione({
    required this.id,
    required this.insegnamento,
    required this.docente,
    this.corso = '',
    required this.aula,
    required this.inizio,
    required this.fine,
    this.prenotabile = false,
    this.prenotata = false,
    this.postiDisponibili = 0,
    this.postiTotali = 0,
  });

  factory Lezione.fromJson(Map<String, dynamic> json) {
    return Lezione(
      id: json['id'].toString(),
      insegnamento: json['insegnamento'] as String? ?? '',
      docente: json['docente'] as String? ?? '',
      corso: json['corso'] as String? ?? '',
      aula: json['aula'] as String? ?? '',
      inizio: DateTime.parse(json['inizio'] as String),
      fine: DateTime.parse(json['fine'] as String),
      prenotabile: json['prenotabile'] as bool? ?? false,
      prenotata: json['prenotata'] as bool? ?? false,
      postiDisponibili: json['posti_disponibili'] as int? ?? 0,
      postiTotali: json['posti_totali'] as int? ?? 0,
    );
  }
}

class EsameAgenda {
  final String id;
  final String insegnamento;
  final DateTime data;

  /// true quando [data] include anche l'orario (non solo il giorno).
  final bool haOrario;
  final String aula;
  final String docente;
  final String corso;
  final String sessione;
  final String note;

  /// Gruppo a cui è riservato l'appello: partizione per cognome (es.
  /// "A-C", "PEU-Z") o canale/docente. Vuoto = valido per tutti / non noto.
  final String partizione;

  /// Tipo di prova: "Scritto", "Orale", "Scritto e orale", "Prova
  /// intermedia"… Vuoto se l'ateneo non lo indica.
  final String tipoProva;

  /// Etichetta leggibile del gruppo: "Cognomi A-C" per i range di lettere,
  /// altrimenti il valore così com'è (es. "Canale 2").
  String get etichettaGruppo {
    final p = partizione.trim();
    if (RegExp(r'^[A-Za-z]{1,4}\s*-\s*[A-Za-z]{1,4}$').hasMatch(p)) {
      return 'Cognomi ${p.toUpperCase().replaceAll(' ', '')}';
    }
    return p;
  }

  /// true se lo studente risulta già iscritto a questo appello (nel REST
  /// Esse3 corrisponde a `unbookingEnabled`: si può disiscrivere solo se
  /// si è iscritti).
  final bool prenotato;

  /// true se l'appello è aperto alle prenotazioni e lo studente non è
  /// ancora iscritto.
  final bool prenotabile;

  EsameAgenda({
    required this.id,
    required this.insegnamento,
    required this.data,
    this.haOrario = false,
    required this.aula,
    required this.docente,
    this.corso = '',
    this.sessione = '',
    this.note = '',
    this.partizione = '',
    this.tipoProva = '',
    this.prenotato = false,
    this.prenotabile = false,
  });

  factory EsameAgenda.fromJson(Map<String, dynamic> json) {
    return EsameAgenda(
      id: json['id'].toString(),
      insegnamento: json['insegnamento'] as String? ?? '',
      data: DateTime.parse(json['data'] as String),
      haOrario: json['haOrario'] as bool? ?? false,
      aula: json['aula'] as String? ?? '',
      docente: json['docente'] as String? ?? '',
      corso: json['corso'] as String? ?? '',
      sessione: json['sessione'] as String? ?? '',
      note: json['note'] as String? ?? '',
      partizione: json['partizione'] as String? ?? '',
      tipoProva: json['tipoProva'] as String? ?? '',
      prenotato: json['prenotato'] as bool? ?? false,
      prenotabile: json['prenotabile'] as bool? ?? false,
    );
  }
}

class MessaggioAteneo {
  final String id;
  final String titolo;
  final String corpo;
  final DateTime data;
  final bool letto;

  MessaggioAteneo({
    required this.id,
    required this.titolo,
    required this.corpo,
    required this.data,
    this.letto = false,
  });

  factory MessaggioAteneo.fromJson(Map<String, dynamic> json) {
    return MessaggioAteneo(
      id: json['id'].toString(),
      titolo: json['titolo'] as String? ?? '',
      corpo: json['corpo'] as String? ?? '',
      data: DateTime.parse(json['data'] as String),
      letto: json['letto'] as bool? ?? false,
    );
  }
}

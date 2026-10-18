import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../models/aula.dart';
import 'easybadge_service.dart';

/// Client HTTP verso il backend dell'ateneo.
///
/// Il login passa da `CinecaLoginService` (l'Identity Provider OIDC reale
/// di UNISA). I metodi di lettura interrogano i servizi reali: in caso di
/// errore restituiscono uno stato vuoto, MAI dati di esempio. Niente
/// contenuti inventati che sembrano veri: l'interfaccia mostra "nessun
/// dato" o un errore onesto.
///
/// Nota sulla rilevazione presenze: `rilevaPresenza` richiede il token
/// autenticato, mentre `rilevaPresenzaConMatricola` usa il percorso pubblico
/// previsto da EasyCourse per la rilevazione senza login.
class ApiService {
  ApiService({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;
  String corsoCodice = '';
  String matricola = '';
  // Dal profilo CINECA, se presenti: classId = anno di corso (1/2/3),
  // cognome serve a suggerire la partizione (A-C, D-G…).
  String classId = '';
  String classDes = '';
  String cognome = '';

  // Corso e anno scelti dallo studente nel combo di AgendaStudenti
  // (primo accesso / impostazioni): valori del combo da passare tali e
  // quali a grid_call.php. Vuoti = non ancora scelti.
  String corsoOrario = '';
  String anno2Orario = '';
  int? aaOrario;

  static const _timeout = Duration(seconds: 6);

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    // Il token del login reale (CinecaLoginService) è già un header
    // "Basic ..." completo; un eventuale token di altro tipo viene
    // preceduto da "Bearer" come di consueto.
    if (token != null)
      'Authorization': token!.contains(' ') ? token! : 'Bearer $token',
  };

  Uri _u(String path) => Uri.parse('$baseUrl$path');

  /// Legge una lista dal backend reale. In caso di errore restituisce una
  /// lista vuota (stato onesto), MAI dati di esempio: l'interfaccia deve
  /// mostrare "nessun dato", non contenuti inventati che sembrano veri.
  Future<List<dynamic>> _getListReale(String path, {bool auth = true}) async {
    try {
      final resp = await http
          .get(_u(path), headers: auth ? _headers : const {})
          .timeout(_timeout);
      _checkOk(resp);
      return jsonDecode(resp.body) as List<dynamic>;
    } catch (_) {
      return const [];
    }
  }

  /// Orario reale dall'agenda pubblica AgendaStudenti (grid_call.php).
  /// In caso di errore o profilo incompleto restituisce lista vuota (stato
  /// onesto), mai dati inventati.
  Future<List<dynamic>> getOrario(DateTime from, DateTime to) async {
    try {
      return await getOrarioReale(from, to);
    } catch (_) {
      return const [];
    }
  }

  /// true se lo studente ha già scelto corso e anno per l'orario.
  bool get haCorsoOrario =>
      corsoOrario.isNotEmpty && anno2Orario.isNotEmpty && aaOrario != null;

  /// Orario reale. `corso` e `anno2` sono i `valore` del combo AgendaStudenti
  /// scelti dallo studente (es. corso "05121", anno2 "PDS0-2026-A-C|1");
  /// `anno` è l'anno accademico del combo da cui provengono.
  Future<List<dynamic>> getOrarioReale(DateTime from, DateTime to) async {
    if (!haCorsoOrario) {
      throw CorsoNonImpostatoException();
    }
    final body = {
      'include': 'corso',
      'txtcurr': '',
      'anno': aaOrario.toString(),
      'corso': corsoOrario,
      'anno2': anno2Orario,
      'visualizzazione_orario': 'cal',
      'date': _formatAgendaDate(from),
      'periodo_didattico': _periodoDidattico(from),
      '_lang': 'it',
    };
    debugPrint('[ORARIO] richiesta grid_call body=$body');
    final response = await http
        .post(
          Uri.parse('https://easycourse.unisa.it/AgendaStudenti/grid_call.php'),
          headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
          body: body,
        )
        .timeout(_timeout);
    debugPrint('[ORARIO] status=${response.statusCode} len=${response.body.length}');
    _checkOk(response);
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) return const [];
    final cells = decoded['celle'];
    debugPrint('[ORARIO] celle=${cells is List ? cells.length : 'nessuna'}');
    if (cells is! List) return const [];
    return cells.whereType<Map>().map(_orarioCellToJson).toList();
  }

  String _formatAgendaDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';

  /// Semestre: S1 da settembre a gennaio, S2 da febbraio a luglio/agosto.
  String _periodoDidattico(DateTime date) => (date.month >= 9 || date.month <= 1) ? 'S1' : 'S2';

  Map<String, dynamic> _orarioCellToJson(Map cell) {
    final date = _parseAgendaDate(cell['data']?.toString());
    final start = _parseTime(cell['ora_inizio']?.toString());
    final end = _parseTime(cell['ora_fine']?.toString());
    return {
      'id':
          '${cell['data']}-${cell['ora_inizio']}-${cell['nome_insegnamento']}',
      'insegnamento': cell['nome_insegnamento']?.toString() ?? '',
      'docente': cell['docente']?.toString() ?? '',
      'aula': cell['aula']?.toString() ?? '',
      'inizio': DateTime(
        date.year,
        date.month,
        date.day,
        start.$1,
        start.$2,
      ).toIso8601String(),
      'fine': DateTime(
        date.year,
        date.month,
        date.day,
        end.$1,
        end.$2,
      ).toIso8601String(),
    };
  }

  DateTime _parseAgendaDate(String? raw) {
    if (raw == null) return DateTime.now();
    final parts = raw.split(RegExp(r'[-/]'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 1;
      final month = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      return DateTime(year < 100 ? 2000 + year : year, month, day);
    }
    return DateTime.tryParse(raw) ?? DateTime.now();
  }

  (int, int) _parseTime(String? raw) {
    final parts = (raw ?? '00:00').split(':');
    return (
      int.tryParse(parts[0]) ?? 0,
      parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  Future<List<dynamic>> getLezioniPrenotabili(String matricola) =>
      _getListReale('/lezioni_prenotabili/$matricola');

  Future<List<dynamic>> getLezioniPrenotate(String matricola) =>
      _getListReale('/lezioni_prenotate/$matricola');

  Future<void> prenotaLezione(String lezioneId) async {
    try {
      final resp = await http
          .post(
            _u('/salva_prenotazioni'),
            headers: _headers,
            body: jsonEncode({'lezione_id': lezioneId}),
          )
          .timeout(_timeout);
      _checkOk(resp);
    } catch (_) {
      // Nessun backend ancora: in demo l'azione è accettata localmente,
      // la lista rimane quella di esempio.
    }
  }

  Future<void> cancellaPrenotazione(String lezioneId) async {
    try {
      final resp = await http
          .post(
            _u('/cancella_prenotazioni'),
            headers: _headers,
            body: jsonEncode({'lezione_id': lezioneId}),
          )
          .timeout(_timeout);
      _checkOk(resp);
    } catch (_) {
      // Idem: in demo l'azione non ha un backend da aggiornare.
    }
  }

  final EasyBadgeService _easyBadge = EasyBadgeService();

  /// Registra la presenza dell'utente CORRENTE tramite `TimbratureApi.php`
  /// (`action: CreateFromJSON`, `autenticazione: true`).
  Future<String> rilevaPresenza(String codiceAula, {bool fromQr = false}) {
    return _easyBadge.rilevaPresenza(
      matricola: matricola,
      codiceLezioneRaw: codiceAula,
      autenticazione: true,
      fromQr: fromQr,
    );
  }

  /// Registra una presenza dal percorso pubblico (senza sessione autenticata)
  /// tramite `TimbratureApi.php` (`action: CreateFromJSON`, `autenticazione: false`).
  Future<String> rilevaPresenzaConMatricola({
    required String matricola,
    required String codiceAula,
    bool fromQr = false,
  }) {
    return _easyBadge.rilevaPresenza(
      matricola: matricola,
      codiceLezioneRaw: codiceAula,
      autenticazione: false,
      fromQr: fromQr,
    );
  }

  /// Aule per edificio con le lezioni del giorno, dal servizio EasyRoom
  /// reale dell'ateneo (non sotto `baseUrl`: e' un host/servizio diverso).
  /// Risposta XML, nessuna autenticazione richiesta: e' un'informazione
  /// pubblica di disponibilità. Un'aula senza lezioni e' libera.
  static const _auleLibereUrl = 'https://easycourse.unisa.it/EasyRoom/do.php';

  Future<List<EdificioAule>> getAuleLibere() async {
    try {
      final resp = await http.get(Uri.parse(_auleLibereUrl)).timeout(_timeout);
      _checkOk(resp);
      return _parseAuleLibereXml(resp.body);
    } catch (_) {
      // Stato onesto: nessuna aula invece di dati di esempio.
      return const [];
    }
  }

  /// Rispecchia la logica dell'app EasyRoom originale: mappa ogni id aula
  /// al nome del suo edificio, poi assegna ogni lezione all'aula il cui id
  /// combacia con il suo attributo `room`. Le lezioni il cui `room` non
  /// corrisponde a nessuna aula nota (dati incoerenti) vengono scartate.
  List<EdificioAule> _parseAuleLibereXml(String xml) {
    final doc = XmlDocument.parse(xml);
    final root = doc.rootElement;

    final auleInEdificio = <String, List<AulaConOrario>>{};
    final edificioDiAula = <String, String>{};
    final aulaById = <String, AulaConOrario>{};

    for (final office in root.findAllElements('office')) {
      final nomeEdificio = office.getAttribute('name') ?? '';
      final lista = <AulaConOrario>[];
      for (final room in office.findAllElements('room')) {
        final id = room.getAttribute('id') ?? '';
        final mapAttr = room.getAttribute('map');
        final capAttr = room.getAttribute('capacity');
        final xAttr = room.getAttribute('coordX');
        final yAttr = room.getAttribute('coordY');
        final aula = AulaConOrario(
          id: id,
          nome: room.getAttribute('name') ?? '',
          lezioni: [],
          mapId: mapAttr != null && mapAttr.isNotEmpty ? mapAttr : null,
          capacity: capAttr != null && capAttr.isNotEmpty ? capAttr : null,
          coordX: xAttr != null && xAttr.isNotEmpty ? double.tryParse(xAttr) : null,
          coordY: yAttr != null && yAttr.isNotEmpty ? double.tryParse(yAttr) : null,
        );
        lista.add(aula);
        aulaById[id] = aula;
        edificioDiAula[id] = nomeEdificio;
      }
      auleInEdificio[nomeEdificio] = lista;
    }

    for (final cls in root.findAllElements('class')) {
      final roomId = cls.getAttribute('room') ?? '';
      final aula = aulaById[roomId];
      if (aula == null) continue;
      aula.lezioni.add(
        LezioneAula(
          nome: cls.getAttribute('name') ?? '',
          docente: cls.getAttribute('teacher') ?? '',
          dalle: cls.getAttribute('from') ?? '',
          alle: cls.getAttribute('to') ?? '',
        ),
      );
    }

    return auleInEdificio.entries
        .map((e) => EdificioAule(nome: e.key, aule: e.value))
        .toList();
  }

  Future<List<dynamic>> getMessaggi(String matricola) =>
      _getListReale('/messaggi/$matricola');

  void _checkOk(http.Response resp) {
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ApiException(resp.statusCode, resp.body);
    }
  }
}

class ApiException implements Exception {
  final int statusCode;
  final String body;
  ApiException(this.statusCode, this.body);

  @override
  String toString() => 'ApiException($statusCode): $body';
}

/// L'orario non si può caricare finché lo studente non sceglie corso e
/// anno (primo accesso o impostazioni).
class CorsoNonImpostatoException implements Exception {
  @override
  String toString() => 'Scegli corso e anno per vedere il tuo orario.';
}


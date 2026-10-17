import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/lezione.dart';

/// Chiamate REST reali ai servizi studente dell'ateneo su
/// `https://unisa.app.cineca.it/`, esattamente come fa l'app campus:
/// stessi percorsi, stessa autenticazione (header `Basic ...` ottenuto al
/// login CINECA). Niente dati inventati: se il servizio non risponde si
/// propaga l'errore e l'interfaccia mostra uno stato onesto, non un
/// contenuto finto.
class CinecaRestService {
  CinecaRestService({this.apiBase = 'https://unisa.app.cineca.it'});

  final String apiBase;
  static const _timeout = Duration(seconds: 10);

  Map<String, String> _headers(String authHeader) => {
    'Authorization': authHeader,
    'Accept': 'application/json',
  };

  /// Appelli d'esame prenotabili per la carriera attiva.
  /// Campus: GET /students/{stuID}/careers/{matID}/exams
  Future<List<EsameAgenda>> getAppelli({
    required String authHeader,
    required String stuId,
    required String matId,
  }) async {
    final resp = await http
        .get(
          Uri.parse('$apiBase/students/$stuId/careers/$matId/exams'),
          headers: _headers(authHeader),
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CinecaRestException(
        'Appelli non disponibili (${resp.statusCode}).',
      );
    }
    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];
    final mappe = decoded.whereType<Map<String, dynamic>>().toList();
    if (mappe.isNotEmpty) {
      // Serve a verificare i nomi reali dei campi (gruppo, tipo prova).
      debugPrint('[ESAMI] campi appello: ${mappe.first.keys.join(', ')}');
    }
    return mappe.map((e) {
      final aula = [
        e['des_aula'],
        e['des_edificio'],
      ].where((s) => s != null && s.toString().trim().isNotEmpty).join(' - ');
      final prenotato = e['unbookingEnabled'] == true;
      final puoPrenotare =
          (e['bookingEnabled'] == true || e['bookableExam'] == true) &&
          !prenotato;
      final (data, haOrario) = _parseData(e['date']?.toString() ?? e['sessionDate']?.toString());
      // Testi liberi dell'appello dove spesso l'ateneo scrive gruppo e
      // tipo di prova (es. "Scritto - cognomi A-L").
      final testi = [
        e['description'],
        e['des_app'],
        e['desApp'],
        e['note'],
        e['title'],
      ].where((s) => s != null).map((s) => s.toString()).join(' | ');
      return EsameAgenda(
        id: e['adsce_id']?.toString() ?? e['cod']?.toString() ?? '',
        // Primo campo NON vuoto: `??` da solo non scarta le stringhe vuote,
        // per questo la materia poteva risultare assente.
        insegnamento: _primoNonVuoto([
          e['title'],
          e['description'],
          e['ad_des'],
          e['adDes'],
          e['nome'],
        ], fallback: 'Esame'),
        data: data,
        haOrario: haOrario,
        aula: aula,
        docente: e['presidente']?.toString() ?? '',
        corso: _primoNonVuoto([
          e['cds_des'],
          e['courseDescription'],
          e['cds_cod'],
        ]),
        sessione: e['sesDes']?.toString() ?? '',
        note: [e['note'], e['misureComp']]
            .where((s) => s != null && s.toString().trim().isNotEmpty)
            .join('\n'),
        partizione: _partizione(e, testi),
        tipoProva: _tipoProva(e, testi),
        prenotato: prenotato,
        prenotabile: puoPrenotare,
      );
    }).toList()..sort((a, b) => a.data.compareTo(b.data));
  }

  /// Gruppo dell'appello: prima i campi strutturati Esse3 (partizione,
  /// canale, turno), poi il testo dell'appello ("cognomi A-L", "(A-C)",
  /// "canale 2").
  String _partizione(Map<String, dynamic> e, String testi) {
    final campo = _primoNonVuoto([
      e['partizione'],
      e['partition'],
      e['des_partizione'],
      e['partDes'],
      e['part_des'],
      e['fat_part_des'],
      e['dom_part_des'],
      e['canale'],
      e['channel'],
      e['des_canale'],
      e['gruppo'],
      e['turno'],
    ]);
    if (campo.isNotEmpty) return campo;

    final cognomi = RegExp(
      r'\b(?:cognomi?|studenti|partizione|gruppo|lettere)\s*:?\s*\(?\s*([A-Z]{1,4}\s*-\s*[A-Z]{1,4})\b',
      caseSensitive: false,
    ).firstMatch(testi);
    if (cognomi != null) return _normalizzaRange(cognomi.group(1)!);

    final traParentesi =
        RegExp(r'\(\s*([A-Z]{1,4}\s*-\s*[A-Z]{1,4})\s*\)').firstMatch(testi);
    if (traParentesi != null) return _normalizzaRange(traParentesi.group(1)!);

    final canale = RegExp(r'\bcanale\s*:?\s*([A-Z0-9]{1,4})\b', caseSensitive: false)
        .firstMatch(testi);
    if (canale != null) return 'Canale ${canale.group(1)!.toUpperCase()}';
    return '';
  }

  String _normalizzaRange(String r) =>
      r.toUpperCase().replaceAll(RegExp(r'\s+'), '');

  /// Tipo di prova: descrizione o codice Esse3 (tipo gestione appello
  /// S/O/SO, tipo appello PP = prova parziale), poi parole chiave nel testo.
  String _tipoProva(Map<String, dynamic> e, String testi) {
    final des = _primoNonVuoto([
      e['tipoProva'],
      e['tipo_prova'],
      e['tipoGestAppDes'],
      e['tipo_gest_app_des'],
      e['tipoEsaDes'],
      e['tipo_esa_des'],
      e['des_tipo_esame'],
      e['examTypeDescription'],
      e['examType'],
    ]);
    if (des.isNotEmpty) return _capitalizza(des);

    final cod = _primoNonVuoto([
      e['tipoGestAppCod'],
      e['tipo_gest_app_cod'],
    ]).toUpperCase();
    switch (cod) {
      case 'S':
        return 'Scritto';
      case 'O':
        return 'Orale';
      case 'SO':
      case 'OS':
        return 'Scritto e orale';
    }
    final tipoApp = _primoNonVuoto([e['tipoAppCod'], e['tipo_app_cod']]).toUpperCase();
    if (tipoApp == 'PP') return 'Prova parziale';

    final t = testi.toLowerCase();
    if (t.contains('intercors')) return 'Prova intercorso';
    if (t.contains('intermedi') || t.contains('parzial')) return 'Prova intermedia';
    final scritto = t.contains('scritt');
    final orale = t.contains('oral');
    if (scritto && orale) return 'Scritto e orale';
    if (scritto) return 'Scritto';
    if (orale) return 'Orale';
    if (t.contains('pratic')) return 'Prova pratica';
    return '';
  }

  String _capitalizza(String s) {
    final v = s.trim();
    if (v.isEmpty) return v;
    return v[0].toUpperCase() + v.substring(1).toLowerCase();
  }

  /// Primo valore non nullo e non vuoto tra i candidati; altrimenti [fallback].
  String _primoNonVuoto(List<Object?> candidati, {String fallback = ''}) {
    for (final c in candidati) {
      final s = c?.toString().trim();
      if (s != null && s.isNotEmpty) return s;
    }
    return fallback;
  }

  /// Converte il campo `date` dell'appello in una data (con orario quando
  /// presente). Il formato reale è quello .NET usato da Esse3:
  /// `/Date(1736899200000+0100)/` = millisecondi epoch + offset fuso. Si
  /// applica l'offset per ottenere data e ora reali dell'esame. Gestisce
  /// anche i formati ISO e dd/mm/yyyy come ripiego.
  /// Ritorna (data, haOrario).
  (DateTime, bool) _parseData(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (DateTime.fromMillisecondsSinceEpoch(0), false);
    }
    final value = raw.trim();

    // Formato .NET: /Date(ms±hhmm)/
    final net = RegExp(r'/Date\((\d+)([+-]\d{4})?\)/').firstMatch(value);
    if (net != null) {
      final ms = int.parse(net.group(1)!);
      final offset = net.group(2); // es. "+0100"
      var dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      if (offset != null) {
        final sign = offset[0] == '-' ? -1 : 1;
        final oh = int.parse(offset.substring(1, 3));
        final om = int.parse(offset.substring(3, 5));
        dt = dt.add(Duration(hours: sign * oh, minutes: sign * om));
      }
      // dt ora rappresenta l'ora "a muro" locale dell'esame.
      final wall = DateTime(dt.year, dt.month, dt.day, dt.hour, dt.minute);
      final haOrario = dt.hour != 0 || dt.minute != 0;
      return (wall, haOrario);
    }

    // ISO 8601 (con eventuale orario e fuso).
    final iso = DateTime.tryParse(value);
    if (iso != null) {
      final local = iso.isUtc ? iso.toLocal() : iso;
      final haOrario = local.hour != 0 || local.minute != 0;
      return (DateTime(local.year, local.month, local.day, local.hour, local.minute), haOrario);
    }

    // dd/mm/yyyy oppure dd-mm-yyyy (solo data).
    final dmy = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})').firstMatch(value);
    if (dmy != null) {
      return (DateTime(int.parse(dmy.group(3)!), int.parse(dmy.group(2)!), int.parse(dmy.group(1)!)), false);
    }
    return (DateTime.fromMillisecondsSinceEpoch(0), false);
  }

  String _formatDateOrEmpty(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final (dt, _) = _parseData(raw);
    if (dt.millisecondsSinceEpoch <= 0) {
      // Se è già una stringa leggibile non vuota, la ritorniamo pulita
      final clean = raw.trim();
      if (!clean.startsWith('/Date(')) return clean;
      return '';
    }
    final gg = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    return '$gg/$mm/${dt.year}';
  }

  // ---------------------------------------------------------------------------
  // 1. LIBRETTO & STATISTICHE / PREVISIONE LAUREA
  // ---------------------------------------------------------------------------

  /// Libretto universitario completo + medie e base voto di laurea.
  /// Campus:
  /// - GET /students/{matID}/transcript
  /// - GET /students/{stuID}/careers/{matID}/dashboard
  Future<LibrettoDati> getLibretto({
    required String authHeader,
    required String stuId,
    required String matId,
  }) async {
    final headers = _headers(authHeader);
    final transcriptFuture = http
        .get(Uri.parse('$apiBase/students/$matId/transcript'), headers: headers)
        .timeout(_timeout);
    final dashboardFuture = http
        .get(
          Uri.parse('$apiBase/students/$stuId/careers/$matId/dashboard'),
          headers: headers,
        )
        .timeout(_timeout);

    final results = await Future.wait([
      transcriptFuture,
      dashboardFuture.catchError((_) => http.Response('{}', 500)),
    ]);

    final transcriptResp = results[0];
    final dashboardResp = results[1];

    if (transcriptResp.statusCode < 200 || transcriptResp.statusCode >= 300) {
      throw CinecaRestException(
        'Libretto non disponibile (${transcriptResp.statusCode}).',
      );
    }

    final decodedTranscript = jsonDecode(transcriptResp.body);
    final esami = <EsameLibretto>[];
    if (decodedTranscript is List) {
      for (final item in decodedTranscript.whereType<Map<String, dynamic>>()) {
        final descrizione = _primoNonVuoto([
          item['description'],
          item['adDes'],
          item['title'],
        ], fallback: 'Insegnamento');
        final stato = _primoNonVuoto([
          item['StatusDetail'],
          item['statusDetail'],
          item['stato'],
        ], fallback: 'PIANIFICATA').toUpperCase();
        final weightRaw = _primoNonVuoto([
          item['weight'],
          item['peso'],
          item['cfu'],
        ], fallback: '0');
        final cfuNum =
            int.tryParse(RegExp(r'\d+').firstMatch(weightRaw)?.group(0) ?? '') ??
            0;
        final lode = item['Laude'] == true || item['laude'] == true;
        final scoreDetail = _primoNonVuoto([
          item['ScoreDetail'],
          item['scoreDetail'],
        ]);
        final superato = stato == 'SUPERATA' || stato == 'SUPERATO';
        final numMatch = RegExp(r'\d+').firstMatch(scoreDetail)?.group(0);
        final votoNum = superato && numMatch != null ? int.tryParse(numMatch) : null;
        final idoneita = superato && votoNum == null;

        String votoDisplay = '';
        if (superato) {
          if (votoNum != null) {
            votoDisplay = '$votoNum${lode ? 'L' : ''}';
          } else {
            votoDisplay = 'IDO';
          }
        }

        esami.add(
          EsameLibretto(
            codice: _primoNonVuoto([item['code'], item['cod']]),
            annoCorso: _primoNonVuoto([item['OrdAdCod'], item['ordAdCod']]),
            descrizione: descrizione,
            stato: stato,
            superato: superato,
            cfu: cfuNum,
            cfuTesto: weightRaw.contains('CFU') ? weightRaw : '$cfuNum CFU',
            lode: lode,
            scoreDetail: scoreDetail,
            votoNumerico: votoNum,
            idoneita: idoneita,
            votoDisplay: votoDisplay,
          ),
        );
      }
    }

    // Calcolo fallback dalle righe del libretto
    int cfuSuperati = 0;
    int cfuTotaliCalc = 0;
    int sommaVoti = 0;
    int numEsamiConVoto = 0;
    int sommaVotiPesati = 0;
    int sommaCfuConVoto = 0;

    for (final e in esami) {
      cfuTotaliCalc += e.cfu;
      if (e.superato) {
        cfuSuperati += e.cfu;
        if (e.votoNumerico != null && e.votoNumerico! >= 18) {
          sommaVoti += e.votoNumerico!;
          numEsamiConVoto++;
          sommaVotiPesati += e.votoNumerico! * e.cfu;
          sommaCfuConVoto += e.cfu;
        }
      }
    }

    double mediaArit =
        numEsamiConVoto > 0 ? sommaVoti / numEsamiConVoto : 0.0;
    double mediaPond =
        sommaCfuConVoto > 0 ? sommaVotiPesati / sommaCfuConVoto : 0.0;
    double baseArit = (mediaArit * 110.0) / 30.0;
    double basePond = (mediaPond * 110.0) / 30.0;
    int cfuGain = cfuSuperati;
    int cfuTot = cfuTotaliCalc > 0 ? cfuTotaliCalc : 180;

    if (dashboardResp.statusCode >= 200 && dashboardResp.statusCode < 300) {
      try {
        final dash = jsonDecode(dashboardResp.body);
        if (dash is Map<String, dynamic> &&
            dash['stats'] is Map<String, dynamic>) {
          final stats = dash['stats'] as Map<String, dynamic>;
          final cg = double.tryParse(
            stats['cfu_gained']?.toString().replaceAll(',', '.') ?? '',
          );
          final ct = double.tryParse(
            stats['cfu_tot']?.toString().replaceAll(',', '.') ?? '',
          );
          if (cg != null) cfuGain = cg.round();
          if (ct != null && ct > 0) cfuTot = ct.round();

          final bva = double.tryParse(
            stats['BaseVotoAritmetica']?.toString() ?? '',
          );
          final bvp = double.tryParse(
            stats['BaseVotoPonderata']?.toString() ?? '',
          );
          if (bva != null && bva > 0) baseArit = bva;
          if (bvp != null && bvp > 0) basePond = bvp;

          if (stats['medie'] is List) {
            for (final m
                in (stats['medie'] as List).whereType<Map<String, dynamic>>()) {
              final tipo = m['tipo']?.toString().toUpperCase() ?? '';
              final val = double.tryParse(m['value']?.toString() ?? '');
              if (val != null && val > 0) {
                if (tipo == 'A') mediaArit = val;
                if (tipo == 'P') mediaPond = val;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[LIBRETTO] dashboard parse error: $e');
      }
    }

    return LibrettoDati(
      esami: esami,
      statistiche: StatisticheLibretto(
        cfuAcquisiti: cfuGain,
        cfuTotali: cfuTot,
        mediaAritmetica: mediaArit,
        mediaPonderata: mediaPond,
        baseLaureaAritmetica: baseArit,
        baseLaureaPonderata: basePond,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. TASSE UNIVERSITARIE
  // ---------------------------------------------------------------------------

  /// Elenco tasse dello studente divise per anno.
  /// Campus:
  /// - GET /students/{stuID}/payments/overview
  /// - GET /students/{stuID}/payments/{anno}
  /// Fallback Esse3 REST:
  /// - GET https://esse3web.unisa.it/e3rest/api/tasse-service-v1/addebiti-studente?stuId={stuId}
  Future<List<TassaFattura>> getTasse({
    required String authHeader,
    required String stuId,
  }) async {
    final headers = _headers(authHeader);
    final overviewResp = await http
        .get(
          Uri.parse('$apiBase/students/$stuId/payments/overview'),
          headers: headers,
        )
        .timeout(_timeout);

    if (overviewResp.statusCode >= 200 && overviewResp.statusCode < 300) {
      final decoded = jsonDecode(overviewResp.body);
      if (decoded is List && decoded.isNotEmpty) {
        final anni = decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => e['year']?.toString().trim() ?? '')
            .where((y) => y.isNotEmpty)
            .toList();
        anni.sort((a, b) => b.compareTo(a));

        final perAnnoFutures = anni.map((anno) async {
          try {
            final r = await http
                .get(
                  Uri.parse('$apiBase/students/$stuId/payments/$anno'),
                  headers: headers,
                )
                .timeout(_timeout);
            if (r.statusCode < 200 || r.statusCode >= 300) {
              return <TassaFattura>[];
            }
            final list = jsonDecode(r.body);
            if (list is! List) return <TassaFattura>[];
            final fatture = <TassaFattura>[];
            for (final raw in list.whereType<Map<String, dynamic>>()) {
              final detailsRaw = raw['details'];
              if (detailsRaw is! List || detailsRaw.isEmpty) continue;
              final dettagli = detailsRaw
                  .whereType<Map<String, dynamic>>()
                  .map(
                    (d) => TassaDettaglio(
                      titolo: _primoNonVuoto([d['title']], fallback: 'Tassa'),
                      scadenza: _formatDateOrEmpty(d['ClearedDate']?.toString()),
                      dataPagamento: _formatDateOrEmpty(d['DueDate']?.toString()),
                    ),
                  )
                  .toList();
              if (dettagli.isEmpty) continue;

              final primo = dettagli.first;
              // Come in TasseKotlin.java: se DueDate (o paymentDate) non è vuoto, è pagato
              final rawDue =
                  (detailsRaw.first as Map<String, dynamic>)['DueDate']
                      ?.toString()
                      .trim() ??
                  '';
              final rawPayment = raw['paymentDate']?.toString().trim() ?? '';
              final pagata = rawDue.isNotEmpty || rawPayment.isNotEmpty;
              final scadenza = primo.scadenza.isNotEmpty
                  ? primo.scadenza
                  : _formatDateOrEmpty(raw['expirationDate']?.toString());
              final dataPag = primo.dataPagamento.isNotEmpty
                  ? primo.dataPagamento
                  : _formatDateOrEmpty(raw['paymentDate']?.toString());

              fatture.add(
                TassaFattura(
                  fattId: _primoNonVuoto([raw['FattId'], raw['fattId']]),
                  anno: anno,
                  importo: _primoNonVuoto([raw['amount']], fallback: '0.00'),
                  iuv: _primoNonVuoto([raw['iuv']]),
                  titolo: primo.titolo,
                  scadenza: scadenza,
                  dataPagamento: dataPag,
                  pagata: pagata,
                  dettagli: dettagli,
                ),
              );
            }
            return fatture;
          } catch (e) {
            debugPrint('[TASSE] errore anno $anno: $e');
            return <TassaFattura>[];
          }
        });

        final lists = await Future.wait(perAnnoFutures);
        return lists.expand((x) => x).toList();
      }
    }

    // Fallback Esse3 diretto
    final fallbackResp = await http
        .get(
          Uri.parse(
            'https://esse3web.unisa.it/e3rest/api/tasse-service-v1/addebiti-studente?stuId=$stuId',
          ),
          headers: headers,
        )
        .timeout(_timeout);

    if (fallbackResp.statusCode < 200 || fallbackResp.statusCode >= 300) {
      throw CinecaRestException(
        'Tasse non disponibili (${overviewResp.statusCode}).',
      );
    }

    final fbDecoded = jsonDecode(fallbackResp.body);
    if (fbDecoded is! List) return [];
    return fbDecoded.whereType<Map<String, dynamic>>().map((e) {
      final pagata = e['pagatoFlg'] == 1 || e['pagatoFlg'] == true;
      final scadenza = _formatDateOrEmpty(e['scadFattura']?.toString());
      return TassaFattura(
        fattId: _primoNonVuoto([e['fattId']]),
        anno: _primoNonVuoto([e['aaId']]),
        importo: _primoNonVuoto([e['importoFattura'], e['importoVoce']], fallback: '0.00'),
        iuv: _primoNonVuoto([e['iuv']]),
        titolo: _primoNonVuoto([e['desMav2'], e['desMav1'], e['desTassa']], fallback: 'Contributo universitario'),
        scadenza: scadenza,
        dataPagamento: '',
        pagata: pagata,
        dettagli: [],
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // 3. BACHECA ESITI
  // ---------------------------------------------------------------------------

  /// Bacheca esiti degli appelli sostenuti.
  /// Campus: GET /students/{matID}/exams/board
  /// (con invio automatico presa visione 'V' per gli esiti con presaVisione == 'N')
  Future<List<EsitoBacheca>> getBachecaEsiti({
    required String authHeader,
    required String matId,
    required String stuId,
  }) async {
    final headers = _headers(authHeader);
    var targetId = matId.isNotEmpty ? matId : stuId;
    var resp = await http
        .get(
          Uri.parse('$apiBase/students/$targetId/exams/board'),
          headers: headers,
        )
        .timeout(_timeout);

    if ((resp.statusCode < 200 || resp.statusCode >= 300) &&
        stuId.isNotEmpty &&
        stuId != targetId) {
      targetId = stuId;
      resp = await http
          .get(
            Uri.parse('$apiBase/students/$targetId/exams/board'),
            headers: headers,
          )
          .timeout(_timeout);
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CinecaRestException(
        'Bacheca esiti non disponibile (${resp.statusCode}).',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! List) return [];

    final esiti = <EsitoBacheca>[];
    for (final raw in decoded.whereType<Map<String, dynamic>>()) {
      final esitoObj = raw['esito'] is Map<String, dynamic>
          ? raw['esito'] as Map<String, dynamic>
          : <String, dynamic>{};
      final pvObj = raw['presaVisione'] is Map<String, dynamic>
          ? raw['presaVisione'] as Map<String, dynamic>
          : <String, dynamic>{};

      final applistaId = _primoNonVuoto([raw['applistaId']]);
      var pvVal = _primoNonVuoto([pvObj['value']], fallback: 'S').toUpperCase();

      // Come in BachecaEsiti.java: se presaVisione == "N", invia automaticamente "V"
      if (pvVal == 'N' && applistaId.isNotEmpty) {
        try {
          await _inviaPresaVisione(
            authHeader: authHeader,
            targetId: targetId,
            applistaId: applistaId,
            valore: 'V',
          );
          pvVal = 'V';
        } catch (e) {
          debugPrint('[BACHECA] errore presa visione automatica: $e');
        }
      }

      esiti.add(_parseEsitoBacheca(raw, esitoObj, pvVal));
    }
    return esiti;
  }

  EsitoBacheca _parseEsitoBacheca(
    Map<String, dynamic> raw,
    Map<String, dynamic> esitoObj,
    String pvVal,
  ) {
    final dataRaw = _primoNonVuoto([raw['dataEsa']]);
    final dataPulita = dataRaw.contains(':')
        ? dataRaw.split(' ').first
        : _formatDateOrEmpty(dataRaw).isNotEmpty
            ? _formatDateOrEmpty(dataRaw)
            : dataRaw;

    final voto = int.tryParse(esitoObj['votoEsa']?.toString() ?? '') ?? 0;
    final lode = esitoObj['laude'] == 1 || esitoObj['laude'] == true;
    final superato = esitoObj['superatoFlg'] == 1 || esitoObj['superatoFlg'] == true;
    final assente = esitoObj['assenteFlg'] == 1 || esitoObj['assenteFlg'] == true;
    final ritirato = esitoObj['ritiratoFlg'] == 1 || esitoObj['ritiratoFlg'] == true;
    final accettaAbilitato =
        esitoObj['acceptEnabled'] == 1 || esitoObj['acceptEnabled'] == true;
    final rifiutaAbilitato =
        esitoObj['rejectEnabled'] == 1 || esitoObj['rejectEnabled'] == true;

    return EsitoBacheca(
      applistaId: _primoNonVuoto([raw['applistaId']]),
      insegnamento: _primoNonVuoto([raw['adStuDes']], fallback: 'Esame'),
      dataEsame: dataPulita,
      dataInserimento: _primoNonVuoto([raw['dataIns']]),
      presaVisione: pvVal,
      superato: superato,
      voto: voto,
      lode: lode,
      giudizioCod: _primoNonVuoto([esitoObj['tipoGiudCod']]),
      giudizioDes: _primoNonVuoto([esitoObj['tipoGiudizioDes']]),
      assente: assente,
      ritirato: ritirato,
      accettaAbilitato: accettaAbilitato,
      rifiutaAbilitato: rifiutaAbilitato,
    );
  }

  /// Accetta ('A') o rifiuta ('R') un voto nella bacheca esiti.
  /// Campus: PUT /students/{matID}/exams/board/{applistaId}/acknowledgement?presaVisione={A|R}
  Future<EsitoBacheca> modificaEsitoBacheca({
    required String authHeader,
    required String matId,
    required EsitoBacheca esitoCorrente,
    required bool accetta,
  }) async {
    final valore = accetta ? 'A' : 'R';
    final resp = await _inviaPresaVisione(
      authHeader: authHeader,
      targetId: matId,
      applistaId: esitoCorrente.applistaId,
      valore: valore,
    );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CinecaRestException(
        'Impossibile aggiornare l’esito (${resp.statusCode}).',
      );
    }
    try {
      final decoded = jsonDecode(resp.body);
      if (decoded is Map<String, dynamic>) {
        final esitoObj = decoded['esito'] is Map<String, dynamic>
            ? decoded['esito'] as Map<String, dynamic>
            : <String, dynamic>{};
        final pvObj = decoded['presaVisione'] is Map<String, dynamic>
            ? decoded['presaVisione'] as Map<String, dynamic>
            : <String, dynamic>{};
        final pvVal = _primoNonVuoto([pvObj['value']], fallback: valore).toUpperCase();
        final parsed = _parseEsitoBacheca(decoded, esitoObj, pvVal);
        return EsitoBacheca(
          applistaId: parsed.applistaId.isNotEmpty
              ? parsed.applistaId
              : esitoCorrente.applistaId,
          insegnamento: parsed.insegnamento != 'Esame' && parsed.insegnamento.isNotEmpty
              ? parsed.insegnamento
              : esitoCorrente.insegnamento,
          dataEsame: parsed.dataEsame.isNotEmpty
              ? parsed.dataEsame
              : esitoCorrente.dataEsame,
          dataInserimento: parsed.dataInserimento.isNotEmpty
              ? parsed.dataInserimento
              : esitoCorrente.dataInserimento,
          presaVisione: pvVal,
          superato: parsed.superato,
          voto: parsed.voto > 0 ? parsed.voto : esitoCorrente.voto,
          lode: parsed.lode || esitoCorrente.lode,
          giudizioCod: parsed.giudizioCod,
          giudizioDes: parsed.giudizioDes,
          assente: parsed.assente,
          ritirato: parsed.ritirato,
          accettaAbilitato: parsed.accettaAbilitato,
          rifiutaAbilitato: parsed.rifiutaAbilitato,
        );
      }
    } catch (_) {}
    return esitoCorrente.copyWith(presaVisione: valore);
  }

  Future<http.Response> _inviaPresaVisione({
    required String authHeader,
    required String targetId,
    required String applistaId,
    required String valore,
  }) {
    final uri = Uri.parse(
      '$apiBase/students/$targetId/exams/board/$applistaId/acknowledgement',
    ).replace(queryParameters: {'presaVisione': valore});
    return http
        .put(
          uri,
          headers: {
            ..._headers(authHeader),
            'Content-Type': 'application/json',
          },
          body: '{}',
        )
        .timeout(_timeout);
  }
}

class CinecaRestException implements Exception {
  final String message;
  CinecaRestException(this.message);

  @override
  String toString() => message;
}

class EsameLibretto {
  final String codice;
  final String annoCorso;
  final String descrizione;
  final String stato;
  final bool superato;
  final int cfu;
  final String cfuTesto;
  final bool lode;
  final String scoreDetail;
  final int? votoNumerico;
  final bool idoneita;
  final String votoDisplay;

  const EsameLibretto({
    required this.codice,
    required this.annoCorso,
    required this.descrizione,
    required this.stato,
    required this.superato,
    required this.cfu,
    required this.cfuTesto,
    required this.lode,
    required this.scoreDetail,
    required this.votoNumerico,
    required this.idoneita,
    required this.votoDisplay,
  });
}

class StatisticheLibretto {
  final int cfuAcquisiti;
  final int cfuTotali;
  final double mediaAritmetica;
  final double mediaPonderata;
  final double baseLaureaAritmetica;
  final double baseLaureaPonderata;

  const StatisticheLibretto({
    required this.cfuAcquisiti,
    required this.cfuTotali,
    required this.mediaAritmetica,
    required this.mediaPonderata,
    required this.baseLaureaAritmetica,
    required this.baseLaureaPonderata,
  });
}

class LibrettoDati {
  final List<EsameLibretto> esami;
  final StatisticheLibretto statistiche;

  const LibrettoDati({
    required this.esami,
    required this.statistiche,
  });
}

class TassaDettaglio {
  final String titolo;
  final String scadenza;
  final String dataPagamento;

  const TassaDettaglio({
    required this.titolo,
    required this.scadenza,
    required this.dataPagamento,
  });
}

class TassaFattura {
  final String fattId;
  final String anno;
  final String importo;
  final String iuv;
  final String titolo;
  final String scadenza;
  final String dataPagamento;
  final bool pagata;
  final List<TassaDettaglio> dettagli;

  const TassaFattura({
    required this.fattId,
    required this.anno,
    required this.importo,
    required this.iuv,
    required this.titolo,
    required this.scadenza,
    required this.dataPagamento,
    required this.pagata,
    required this.dettagli,
  });
}

class EsitoBacheca {
  final String applistaId;
  final String insegnamento;
  final String dataEsame;
  final String dataInserimento;
  final String presaVisione; // 'S', 'V', 'N', 'A' (Accettato), 'R' (Rifiutato)
  final bool superato;
  final int voto;
  final bool lode;
  final String giudizioCod;
  final String giudizioDes;
  final bool assente;
  final bool ritirato;
  final bool accettaAbilitato;
  final bool rifiutaAbilitato;

  const EsitoBacheca({
    required this.applistaId,
    required this.insegnamento,
    required this.dataEsame,
    required this.dataInserimento,
    required this.presaVisione,
    required this.superato,
    required this.voto,
    required this.lode,
    required this.giudizioCod,
    required this.giudizioDes,
    required this.assente,
    required this.ritirato,
    required this.accettaAbilitato,
    required this.rifiutaAbilitato,
  });

  String get votoDisplay {
    if (assente) return 'Assente';
    if (ritirato) return 'Ritirato';
    if (voto > 0) return '$voto${lode ? 'L' : ''}';
    if (giudizioDes.isNotEmpty) return giudizioDes;
    if (giudizioCod.isNotEmpty) return giudizioCod;
    return superato ? 'Idoneo' : 'Non superato';
  }

  EsitoBacheca copyWith({String? presaVisione}) {
    return EsitoBacheca(
      applistaId: applistaId,
      insegnamento: insegnamento,
      dataEsame: dataEsame,
      dataInserimento: dataInserimento,
      presaVisione: presaVisione ?? this.presaVisione,
      superato: superato,
      voto: voto,
      lode: lode,
      giudizioCod: giudizioCod,
      giudizioDes: giudizioDes,
      assente: assente,
      ritirato: ritirato,
      accettaAbilitato: accettaAbilitato,
      rifiutaAbilitato: rifiutaAbilitato,
    );
  }
}


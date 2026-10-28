import 'package:flutter/foundation.dart';
import '../models/lezione.dart';
import '../models/preferenze_corso.dart';
import '../models/presenza.dart';
import '../models/user.dart';
import 'adisurc_service.dart';
import 'cineca_rest_service.dart';
import 'easycourse_combo_service.dart';
import 'mensa_qr_service.dart';

/// Modalità dimostrativa per la verifica App Store (Guideline 2.1a).
///
/// Apple richiede di poter verificare TUTTE le funzioni, comprese quelle
/// dietro login SPID/CIE (orario, libretto, esami, presenze, saldo mensa).
/// Poiché l'accesso reale usa credenziali personali SPID/CIE non condivisibili
/// e l'app non ha un backend proprio, si fornisce — come esplicitamente
/// consentito da Apple — una modalità dimostrativa che popola le schermate con
/// dati di esempio, senza alcuna chiamata ai servizi dell'ateneo.
///
/// Si attiva dalla schermata d'ingresso con le credenziali comunicate nelle
/// "App Review Information". Non è pubblicizzata agli utenti reali.
class DemoMode {
  DemoMode._();

  /// Attiva/disattiva globale: i servizi dati vi fanno riferimento per
  /// restituire dati di esempio invece di interrogare la rete.
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static bool get isActive => active.value;

  // Credenziali per i recensori (comunicate nelle App Review Information).
  static const String reviewerUser = 'appstore.review';
  static const String reviewerPass = 'UnisaDemo2026';

  static bool matches(String user, String pass) =>
      user.trim().toLowerCase() == reviewerUser &&
      pass.trim() == reviewerPass;

  static void enable() => active.value = true;
  static void disable() => active.value = false;

  // ------------------------------------------------------------------ utente
  static AppUser utente() => AppUser(
        matricola: '0000000000',
        nome: 'Studente',
        cognome: 'Dimostrativo',
        email: 'demo@example.com',
        token: 'DEMO',
        userType: 'Studente',
        stuId: '100000',
        matId: '200000',
        corsoCodice: 'DEMO',
        classId: '2',
        classDes: 'Comune',
      );

  static PreferenzeCorso preferenze() => PreferenzeCorso(
        aa: EasyCourseComboService.annoAccademico(DateTime.now()),
        corsoValore: 'DEMO-CORSO',
        corsoLabel: 'Ingegneria Informatica',
        annoValore: 'PDS0-DEMO|2',
        annoLabel: '2° anno',
        facoltaCode: 'DEMO',
      );

  // ------------------------------------------------------------------ orario
  /// Mappe compatibili con `Lezione.fromJson`, ancorate a oggi così che una
  /// lezione risulti "in corso ora".
  static List<Map<String, dynamic>> orario() {
    final now = DateTime.now();
    final oggi = DateTime(now.year, now.month, now.day);
    String iso(DateTime d) => d.toIso8601String().split('.').first;
    final lun = oggi.subtract(Duration(days: oggi.weekday - 1));

    final list = <Map<String, dynamic>>[];
    void add(int id, DateTime ini, DateTime fin, String ins, String doc, String aula) {
      list.add({
        'id': id,
        'insegnamento': ins,
        'docente': doc,
        'corso': 'Ingegneria Informatica',
        'aula': aula,
        'inizio': iso(ini),
        'fine': iso(fin),
        'prenotabile': false,
        'prenotata': false,
      });
    }

    // Lezione in corso adesso (indipendente dall'ora della verifica).
    add(1, now.subtract(const Duration(minutes: 30)), now.add(const Duration(minutes: 60)),
        'Analisi Matematica II', 'Prof. M. Rossi', 'Aula F3');
    add(2, oggi.add(const Duration(hours: 14)), oggi.add(const Duration(hours: 16)),
        'Programmazione I', 'Prof. L. Verdi', 'Lab. Knuth');

    final mar = lun.add(const Duration(days: 1));
    add(3, mar.add(const Duration(hours: 9)), mar.add(const Duration(hours: 11)),
        'Fisica Generale', 'Prof. A. Bianchi', 'Aula F1');
    add(4, mar.add(const Duration(hours: 11, minutes: 15)), mar.add(const Duration(hours: 13, minutes: 15)),
        'Architettura degli Elaboratori', 'Prof. G. Esposito', 'Aula F2');

    final gio = lun.add(const Duration(days: 3));
    add(5, gio.add(const Duration(hours: 9)), gio.add(const Duration(hours: 12)),
        'Basi di Dati', 'Prof.ssa C. Romano', 'Aula P2');
    add(6, gio.add(const Duration(hours: 14)), gio.add(const Duration(hours: 16)),
        'Analisi Matematica II', 'Prof. M. Rossi', 'Aula F3');
    return list;
  }

  // ------------------------------------------------------------------ esami
  static List<EsameAgenda> esami() {
    final now = DateTime.now();
    EsameAgenda e(int id, int giorni, String ins, String aula, String doc,
        {bool prenotato = false, bool prenotabile = true, String tipo = 'Scritto', String part = ''}) {
      return EsameAgenda(
        id: '$id',
        insegnamento: ins,
        data: DateTime(now.year, now.month, now.day).add(Duration(days: giorni, hours: 9)),
        haOrario: true,
        aula: aula,
        docente: doc,
        tipoProva: tipo,
        partizione: part,
        prenotato: prenotato,
        prenotabile: prenotabile,
      );
    }

    return [
      e(1, 12, 'Analisi Matematica II', 'Aula F3', 'Prof. M. Rossi', prenotato: true, prenotabile: false, tipo: 'Scritto e orale'),
      e(2, 18, 'Fisica Generale', 'Aula F1', 'Prof. A. Bianchi', prenotato: true, prenotabile: false),
      e(3, 25, 'Programmazione I', 'Lab. Knuth', 'Prof. L. Verdi', tipo: 'Scritto', part: 'A-L'),
      e(4, 26, 'Programmazione I', 'Lab. Turing', 'Prof. L. Verdi', tipo: 'Scritto', part: 'M-Z'),
      e(5, 31, 'Basi di Dati', 'Aula P2', 'Prof.ssa C. Romano', tipo: 'Orale'),
    ];
  }

  // ------------------------------------------------------------------ libretto
  static LibrettoDati libretto() {
    EsameLibretto es(String cod, String anno, String desc, int cfu, {int? voto, bool lode = false}) {
      final sup = voto != null;
      return EsameLibretto(
        codice: cod,
        annoCorso: anno,
        descrizione: desc,
        stato: sup ? 'Superato' : 'Da sostenere',
        superato: sup,
        cfu: cfu,
        cfuTesto: '$cfu CFU',
        lode: lode,
        scoreDetail: sup ? '$voto${lode ? 'L' : ''}/30' : '',
        votoNumerico: voto,
        idoneita: false,
        votoDisplay: sup ? '$voto${lode ? 'L' : ''}' : 'Da sostenere',
      );
    }

    return LibrettoDati(
      statistiche: const StatisticheLibretto(
        cfuAcquisiti: 96,
        cfuTotali: 180,
        mediaAritmetica: 27.10,
        mediaPonderata: 27.84,
        baseLaureaAritmetica: 99.37,
        baseLaureaPonderata: 102.08,
      ),
      esami: [
        es('MAT01', '1', 'Analisi Matematica I', 9, voto: 30, lode: true),
        es('INF01', '1', 'Programmazione I', 12, voto: 28),
        es('FIS01', '1', 'Fisica Generale', 9, voto: 27),
        es('INF02', '1', 'Architettura degli Elaboratori', 9, voto: 30),
        es('MAT02', '2', 'Analisi Matematica II', 9),
        es('INF03', '2', 'Basi di Dati', 9),
        es('INF04', '2', 'Algoritmi e Strutture Dati', 12),
      ],
    );
  }

  // ------------------------------------------------------------------ presenze
  static List<CorsoPresenza> corsiPresenza() => const [
        CorsoPresenza(codice: 'MAT02', nome: 'Analisi Matematica II', percentuale: 92, frequentateMinuti: 1980, svolteMinuti: 2160, percentualeConseguimento: 75, stato: 'frequentante'),
        CorsoPresenza(codice: 'FIS01', nome: 'Fisica Generale', percentuale: 78, frequentateMinuti: 1680, svolteMinuti: 2160, percentualeConseguimento: 64, stato: 'frequentante'),
        CorsoPresenza(codice: 'INF01', nome: 'Programmazione I', percentuale: 64, frequentateMinuti: 1380, svolteMinuti: 2160, percentualeConseguimento: 53, stato: 'in_frequenza'),
        CorsoPresenza(codice: 'INF02', nome: 'Architettura degli Elaboratori', percentuale: 100, frequentateMinuti: 1440, svolteMinuti: 1440, percentualeConseguimento: 60, stato: 'frequentante'),
      ];

  static List<LezionePresenza> lezioniPresenza() {
    final now = DateTime.now();
    final base = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 28));
    final out = <LezionePresenza>[];
    for (var i = 0; i < 8; i++) {
      final g = base.add(Duration(days: i * 3));
      out.add(LezionePresenza(
        modulo: 'Analisi Matematica II',
        inizio: g.add(const Duration(hours: 9)),
        fine: g.add(const Duration(hours: 11)),
        svolta: true,
        presente: i % 4 != 3, // qualche assenza realistica
      ));
    }
    return out.reversed.toList();
  }

  // ------------------------------------------------------------------ mensa
  static WalletAdisurc wallet() => WalletAdisurc(
        saldo: 42.50,
        valuta: 'EUR',
        updatedAt: DateTime.now(),
      );

  /// Carta FITTIZIA per la demo (nessun dato reale): numero segnaposto e
  /// segreto base32 di esempio pubblico. Serve solo a generare un QR TOTP
  /// dimostrativo, non associato ad alcun tesserino reale.
  static MensaCard carta() => MensaCard(
        cardId: 'DEMO0000:0000000|0:991231|D000',
        cardSecret: 'JBSWY3DPEHPK3PXP',
        cardInterval: 30,
        scadenza: DateTime.now().add(const Duration(days: 365)),
      );

  // ------------------------------------------------------------------ tasse
  static List<TassaFattura> tasse() => const [
        TassaFattura(fattId: '1', anno: '2025/2026', importo: '156,00', iuv: '000000000000001', titolo: 'I rata - Contributo onnicomprensivo', scadenza: '31/10/2025', dataPagamento: '12/10/2025', pagata: true, dettagli: []),
        TassaFattura(fattId: '2', anno: '2025/2026', importo: '140,00', iuv: '000000000000002', titolo: 'Tassa regionale per il diritto allo studio', scadenza: '31/10/2025', dataPagamento: '', pagata: false, dettagli: []),
      ];

  // ------------------------------------------------------------------ bacheca
  static List<EsitoBacheca> bacheca() => const [
        EsitoBacheca(applistaId: '1', insegnamento: 'Architettura degli Elaboratori', dataEsame: '18/09/2025', dataInserimento: '22/09/2025', presaVisione: 'N', superato: true, voto: 30, lode: true, giudizioCod: '', giudizioDes: '', assente: false, ritirato: false, accettaAbilitato: true, rifiutaAbilitato: true),
        EsitoBacheca(applistaId: '2', insegnamento: 'Fisica Generale', dataEsame: '10/07/2025', dataInserimento: '14/07/2025', presaVisione: 'A', superato: true, voto: 27, lode: false, giudizioCod: '', giudizioDes: '', assente: false, ritirato: false, accettaAbilitato: false, rifiutaAbilitato: false),
      ];
}

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Lettura del combo pubblico di EasyCourse con tutti i corsi e gli anni
/// (`AgendaStudenti/combo.php?sw=ec_&aa=…&page=corsi`). È lo stesso elenco
/// che usa il sito AgendaStudenti per i menu a tendina.
class EasyCourseComboService {
  EasyCourseComboService({
    this.baseUrl = 'https://easycourse.unisa.it/AgendaStudenti',
  });

  final String baseUrl;
  static const _timeout = Duration(seconds: 15);

  /// Anno accademico di una data: da agosto in poi è l'anno che inizia.
  static int annoAccademico(DateTime date) =>
      date.month >= 8 ? date.year : date.year - 1;

  final Map<int, List<CorsoCombo>> _cache = {};

  Future<List<CorsoCombo>> getCorsi(int aa) async {
    final cached = _cache[aa];
    if (cached != null) return cached;
    final resp = await http
        .get(Uri.parse('$baseUrl/combo.php?sw=ec_&aa=$aa&page=corsi'))
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw ComboException('Elenco corsi non disponibile (${resp.statusCode}).');
    }
    // La risposta è JS: `var elenco_corsi = [ ... ];` seguita a volte da
    // altre variabili. Si estrae solo l'array di elenco_corsi.
    final raw = resp.body;
    final marker = raw.indexOf('elenco_corsi');
    final start = raw.indexOf('[', marker < 0 ? 0 : marker);
    final end = raw.indexOf('];', start);
    final stop = end > start ? end : raw.lastIndexOf(']');
    if (start < 0 || stop <= start) {
      throw ComboException('Elenco corsi non valido.');
    }
    final arr = jsonDecode(raw.substring(start, stop + 1));
    if (arr is! List) throw ComboException('Elenco corsi non valido.');
    final corsi = arr
        .whereType<Map>()
        .map(CorsoCombo.fromJson)
        .where((c) => c.valore.isNotEmpty && c.anni.isNotEmpty)
        .toList()
      ..sort((a, b) => a.label.compareTo(b.label));
    _cache[aa] = corsi;
    return corsi;
  }

  /// Suggerimento: il corso il cui codice coincide con le prime 5 cifre
  /// della matricola (vale per i codici numerici storici, es. `05121`).
  static CorsoCombo? suggerisciCorso(List<CorsoCombo> corsi, String matricola) {
    final m = matricola.trim();
    if (m.length < 5) return null;
    final prefisso = m.substring(0, 5);
    for (final c in corsi) {
      if (c.valore == prefisso) return c;
    }
    return null;
  }

  /// Suggerimento: fra gli anni del corso, la partizione (A-C, D-G…) che
  /// contiene l'iniziale del cognome, preferendo [annoDiCorso] se noto.
  static AnnoCombo? suggerisciAnno(
    CorsoCombo corso, {
    String cognome = '',
    String annoDiCorso = '',
  }) {
    final pool = annoDiCorso.isEmpty
        ? corso.anni
        : corso.anni.where((a) => a.annoDiCorso == annoDiCorso).toList();
    if (pool.isEmpty) return null;
    for (final a in pool) {
      if (cognomeInPartizione(cognome, a.partizione)) return a;
    }
    return pool.length == 1 ? pool.first : null;
  }

  /// true se il cognome rientra nel range di partizione tipo "A-C",
  /// "H-PET", "PEU-Z".
  static bool cognomeInPartizione(String cognome, String range) {
    final c = cognome.trim().toUpperCase();
    if (c.isEmpty || !range.contains('-')) return false;
    final parti = range.split('-');
    if (parti.length != 2) return false;
    final inizio = parti[0].trim().toUpperCase();
    final fine = parti[1].trim().toUpperCase();
    if (inizio.isEmpty || fine.isEmpty) return false;
    return c.compareTo(inizio) >= 0 && c.compareTo('$fine\uFFFF') <= 0;
  }
}

class CorsoCombo {
  const CorsoCombo({
    required this.valore,
    required this.label,
    required this.tipo,
    required this.anni,
    this.facoltaCode = '',
  });

  final String valore;
  final String label;
  final String tipo;
  final List<AnnoCombo> anni;
  final String facoltaCode;

  factory CorsoCombo.fromJson(Map json) {
    final anni = json['elenco_anni'];
    return CorsoCombo(
      valore: json['valore']?.toString().trim() ?? '',
      label: json['label']?.toString().trim() ?? '',
      tipo: json['tipo']?.toString().trim() ?? '',
      facoltaCode: json['facolta_code']?.toString().trim() ?? '',
      anni: anni is List
          ? anni
              .whereType<Map>()
              .map(AnnoCombo.fromJson)
              .where((a) => a.valore.isNotEmpty)
              .toList()
          : const [],
    );
  }
}

class AnnoCombo {
  const AnnoCombo({required this.valore, required this.label});

  /// Es. `PDS0-2026-A-C|1`: da passare come `anno2` a grid_call.php.
  final String valore;

  /// Es. `1 - A-C`, `2 - COMUNE`, `1 - BIOINFORMATICO`.
  final String label;

  String get annoDiCorso =>
      valore.contains('|') ? valore.split('|').last.trim() : '';

  /// Parte dopo "N - " nella label: partizione o curriculum.
  String get partizione {
    final i = label.indexOf(' - ');
    return i >= 0 ? label.substring(i + 3).trim() : '';
  }

  factory AnnoCombo.fromJson(Map json) => AnnoCombo(
    valore: json['valore']?.toString().trim() ?? '',
    label: json['label']?.toString().trim() ?? '',
  );
}

class ComboException implements Exception {
  final String message;
  ComboException(this.message);

  @override
  String toString() => message;
}


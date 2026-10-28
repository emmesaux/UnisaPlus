import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../models/presenza.dart';
import 'demo_mode.dart';

/// Servizio EasyBadge dell'ateneo UNISA (`it.easystaff.unisa`):
///  - `TimbratureApi.php`  : registrazione presenza in aula (`action: CreateFromJSON`)
///  - `corso_iscritti.php` : elenco corsi con ore frequentate/svolte e %
///  - `timbrature.php`     : dettaglio lezioni (tenuta / presente)
///
/// L'`Authorization: Basic EasyBadgeAPI:Easy2019!` è la credenziale a livello
/// di APP del servizio EasyBadge UNISA (usata identicamente sia per la
/// rilevazione presenza con o senza login, sia per la consultazione).
class EasyBadgeService {
  EasyBadgeService({
    this.baseTimbrature =
        'https://easycourse.unisa.it/EasyBadgeNew/api/TimbratureApi.php',
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String baseTimbrature;
  final FlutterSecureStorage _storage;

  static const _timeout = Duration(seconds: 12);
  static const _appCredential = 'EasyBadgeAPI:Easy2019!';
  static const _deviceIdStorageKey = 'easybadge_device_uuid';
  static const _lastMatricolaStorageKey = 'easybadge_ultima_matricola';
  static String? _cachedDeviceId;

  Map<String, String> get _headers => {
        'Authorization': 'Basic ${base64Encode(utf8.encode(_appCredential))}',
        'Content-Type': 'application/json; charset=UTF-8',
      };

  String _url(String endpoint) =>
      baseTimbrature.replaceFirst('TimbratureApi', endpoint);

  /// Restituisce l'UUID persistente del dispositivo richiesto da `TimbratureApi.php`
  /// nel campo `device_token` (come `AppPreferences.getUUID()` nell'app ufficiale).
  Future<String> getOrCreateDeviceToken() async {
    if (_cachedDeviceId != null && _cachedDeviceId!.isNotEmpty) {
      return _cachedDeviceId!;
    }
    try {
      final existing = await _storage.read(key: _deviceIdStorageKey);
      if (existing != null && existing.trim().isNotEmpty) {
        _cachedDeviceId = existing.trim();
        return _cachedDeviceId!;
      }
    } catch (_) {}

    final generated = _generateUuidV4();
    _cachedDeviceId = generated;
    try {
      await _storage.write(key: _deviceIdStorageKey, value: generated);
    } catch (_) {}
    return generated;
  }

  /// Legge l'ultima matricola usata nella rilevazione senza accesso.
  Future<String?> getUltimaMatricola() async {
    try {
      final v = await _storage.read(key: _lastMatricolaStorageKey);
      return (v != null && v.trim().isNotEmpty) ? v.trim().toUpperCase() : null;
    } catch (_) {
      return null;
    }
  }

  /// Salva l'ultima matricola usata nella rilevazione senza accesso.
  Future<void> saveUltimaMatricola(String matricola) async {
    final clean = matricola.trim().toUpperCase();
    if (clean.isEmpty) return;
    try {
      await _storage.write(key: _lastMatricolaStorageKey, value: clean);
    } catch (_) {}
  }

  /// Decodifica il codice lezione dal QR proiettato in aula o dal testo inserito.
  ///
  /// Nell'app ufficiale UNISA (`FragmentRilevaLoggato` / `ActivityFormRegistrazioneOld`),
  /// il QR code contiene una stringa Base64 del tipo `"{codice_lezione}-{extra}"`,
  /// decodificata tramite `new String(Base64.decode(raw, 0)).split("-")[0]`.
  /// Se invece l'utente digita manualmente il codice in chiaro, viene usato direttamente.
  static String estraiCodiceLezione(String raw, {bool fromQr = false}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';

    // Tentiamo la decodifica Base64 se proviene da QR o se ha il formato Base64
    if (fromQr || _looksLikeBase64(trimmed)) {
      try {
        final normalized = base64.normalize(trimmed.replaceAll(RegExp(r'\s+'), ''));
        final decodedBytes = base64.decode(normalized);
        final decodedStr = utf8.decode(decodedBytes, allowMalformed: false).trim();
        if (decodedStr.isNotEmpty && _isPrintableAscii(decodedStr)) {
          // Nel QR EasyBadge il formato decodificato è "<codice_lezione>-<timestamp/extra>"
          if (fromQr || decodedStr.contains('-')) {
            return decodedStr.split('-').first.trim();
          }
        }
      } catch (_) {
        // Non è Base64 valido: prosegui con il valore in chiaro
      }
    }

    return trimmed.split('-').first.trim();
  }

  static bool _looksLikeBase64(String s) {
    if (s.length < 8) return false;
    return RegExp(r'^[A-Za-z0-9+/=_-]+$').hasMatch(s);
  }

  static bool _isPrintableAscii(String s) {
    for (final codeUnit in s.codeUnits) {
      if (codeUnit < 32 || codeUnit > 126) return false;
    }
    return true;
  }

  /// Registra la presenza presso `TimbratureApi.php` (`action: CreateFromJSON`),
  /// replicando fedelmente `ThreadFeedbackRegistration` dell'app ufficiale UNISA.
  ///
  /// - [matricola]: matricola dello studente.
  /// - [codiceLezioneRaw]: valore letto dal QR code (anche Base64) o digitato a mano.
  /// - [autenticazione]: `true` se lo studente è autenticato, `false` se da accesso rapido.
  /// - [fromQr]: `true` se il codice proviene dalla scansione del QR code.
  ///
  /// Restituisce il messaggio di conferma del server se `result == "ok"`,
  /// altrimenti solleva [EasyBadgeException] con il messaggio restituito da EasyBadge.
  Future<String> rilevaPresenza({
    required String matricola,
    required String codiceLezioneRaw,
    required bool autenticazione,
    bool fromQr = false,
  }) async {
    final cleanMatricola = matricola.trim().toUpperCase();
    if (cleanMatricola.isEmpty) {
      throw EasyBadgeException('Matricola studente mancante.');
    }

    final codiceLezione = estraiCodiceLezione(codiceLezioneRaw, fromQr: fromQr);
    if (codiceLezione.isEmpty) {
      throw EasyBadgeException('Codice lezione non valido.');
    }

    final deviceToken = await getOrCreateDeviceToken();
    final payload = {
      'matricola_studente': cleanMatricola,
      'codice_lezione': codiceLezione,
      'device_token': deviceToken,
      'posto': '',
      'lingua': 'it',
      'autenticazione': autenticazione,
      'action': 'CreateFromJSON',
      'dati_addizionali': {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'longitudine': 0.0,
        'latitudine': 0.0,
      },
    };

    final http.Response resp;
    try {
      resp = await http
          .post(
            Uri.parse(baseTimbrature),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } catch (_) {
      throw EasyBadgeException(
        'Impossibile contattare il servizio EasyBadge UNISA. Verifica la connessione.',
      );
    }

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EasyBadgeException(
        'Il servizio EasyBadge ha risposto con errore (${resp.statusCode}).',
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    } catch (_) {
      throw EasyBadgeException('Risposta non valida dal servizio EasyBadge.');
    }

    if (decoded is! Map) {
      throw EasyBadgeException('Formato risposta non riconosciuto.');
    }

    final result = decoded['result']?.toString().trim().toLowerCase() ?? '';
    final rawMessage = decoded['message']?.toString() ?? '';
    final message = _cleanHtmlMessage(rawMessage);

    if (result == 'ok') {
      return message.isNotEmpty
          ? message
          : 'Presenza registrata correttamente per la matricola $cleanMatricola.';
    }

    throw EasyBadgeException(
      message.isNotEmpty
          ? message
          : 'Impossibile registrare la presenza per il codice "$codiceLezione".',
    );
  }

  /// Elenco dei corsi con il riepilogo di frequenza (`corso_iscritti.php`).
  Future<List<CorsoPresenza>> getCorsi(String matricola) async {
    if (DemoMode.isActive) return DemoMode.corsiPresenza();
    final cleanMatricola = matricola.trim();
    if (cleanMatricola.isEmpty) return [];

    final resp = await http
        .post(
          Uri.parse(_url('corso_iscritti')),
          headers: _headers,
          body: jsonEncode({'Matricola': cleanMatricola}),
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EasyBadgeException('Presenze non disponibili (${resp.statusCode}).');
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    if (decoded is! Map) return [];
    final perMatricola = _lookupByMatricola(decoded, cleanMatricola);
    if (perMatricola is! Map) return [];
    final result = <CorsoPresenza>[];
    for (final entry in perMatricola.entries) {
      final lista = entry.value;
      if (lista is! List) continue;
      for (final c in lista.whereType<Map>()) {
        final rawPerc = _toDouble(c['Percentuale']);
        final rawConseg = _toDouble(c['percentuale_conseguimento']);
        result.add(CorsoPresenza(
          codice: c['codice']?.toString() ?? '',
          nome: c['nome']?.toString() ?? entry.key.toString(),
          percentuale: (rawPerc > 0 && rawPerc <= 1.0) ? rawPerc * 100 : rawPerc,
          frequentateMinuti: _toInt(c['Frequentate']),
          svolteMinuti: _toInt(c['OreFatte']),
          percentualeConseguimento:
              (rawConseg > 0 && rawConseg <= 1.0) ? rawConseg * 100 : rawConseg,
          stato: c['Stato']?.toString() ?? '',
        ));
      }
    }
    result.sort((a, b) => a.nome.compareTo(b.nome));
    return result;
  }

  /// Dettaglio lezioni per i corsi indicati (`timbrature.php`).
  Future<List<LezionePresenza>> getLezioni(
    String matricola,
    List<String> codiciCorso,
  ) async {
    if (DemoMode.isActive) return DemoMode.lezioniPresenza();
    final cleanMatricola = matricola.trim();
    if (cleanMatricola.isEmpty || codiciCorso.isEmpty) return [];

    final resp = await http
        .post(
          Uri.parse(_url('timbrature')),
          headers: _headers,
          body: jsonEncode({
            'Matricola': cleanMatricola,
            'Corsi': codiciCorso.map((c) => {'codice': c}).toList(),
          }),
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw EasyBadgeException(
        'Dettaglio presenze non disponibile (${resp.statusCode}).',
      );
    }
    final decoded = jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    final raw = decoded is Map
        ? _lookupByMatricola(decoded, cleanMatricola)
        : decoded;
    if (raw is! List) return [];
    final lezioni = raw.whereType<Map>().map((l) {
      return LezionePresenza(
        modulo: l['Modulo']?.toString() ?? '',
        inizio: _parseDate(l['inizio']?.toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        fine: _parseDate(l['fine']?.toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0),
        svolta: l['svolta']?.toString() == '1',
        presente: l['Presenza']?.toString() == '1',
        timestamp: _parseDate(l['Timestamp']?.toString()),
      );
    }).toList();
    lezioni.sort((a, b) => a.inizio.compareTo(b.inizio));
    return lezioni;
  }

  static dynamic _lookupByMatricola(Map decoded, String matricola) {
    if (decoded.containsKey(matricola)) return decoded[matricola];
    final upper = matricola.toUpperCase();
    if (decoded.containsKey(upper)) return decoded[upper];
    final lower = matricola.toLowerCase();
    if (decoded.containsKey(lower)) return decoded[lower];
    for (final entry in decoded.entries) {
      if (entry.key.toString().toUpperCase() == upper) {
        return entry.value;
      }
    }
    if (decoded.length == 1) return decoded.values.first;
    return null;
  }

  static String _cleanHtmlMessage(String raw) {
    if (raw.isEmpty) return '';
    return raw
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&agrave;', 'à')
        .replaceAll('&egrave;', 'è')
        .replaceAll('&eacute;', 'é')
        .replaceAll('&igrave;', 'ì')
        .replaceAll('&ograve;', 'ò')
        .replaceAll('&ugrave;', 'ù')
        .replaceAll('&Agrave;', 'À')
        .replaceAll('&Egrave;', 'È')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .trim();
  }

  static String _generateUuidV4() {
    final rnd = Random.secure();
    final bytes = List<int>.generate(16, (_) => rnd.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    String hex(int b) => b.toRadixString(16).padLeft(2, '0');
    final h = bytes.map(hex).join();
    return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20, 32)}';
  }

  static int _toInt(Object? v) =>
      int.tryParse(v?.toString() ?? '') ??
      double.tryParse(v?.toString() ?? '')?.round() ??
      0;
  static double _toDouble(Object? v) => double.tryParse(v?.toString() ?? '') ?? 0;
  static DateTime? _parseDate(String? v) =>
      v == null || v.isEmpty ? null : DateTime.tryParse(v);
}

class EasyBadgeException implements Exception {
  final String message;
  EasyBadgeException(this.message);

  @override
  String toString() => message;
}

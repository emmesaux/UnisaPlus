import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Login federato reale di UNISA: l'Identity Provider OIDC gestito da
/// CINECA (`unisa.idp.cineca.it`), lo stesso usato dalle app ufficiali
/// dell'ateneo. SPID, CIE e le credenziali UNISA sono scelte DENTRO questa
/// pagina dall'IdP stesso: non servono due URL diversi per SPID e CIE.
///
/// Il client_id e lo scope OAuth non sono segreti: sono parametri di un
/// client OAuth pubblico (senza client secret, come da specifica OAuth2
/// per le app native), ottenuti dallo stesso endpoint pubblico che usa
/// l'app ufficiale (`/app/init`), non incorporati nel codice.
///
/// A login completato, l'IdP non restituisce un token nel senso comune:
/// restituisce username e password derivati per autenticarsi presso le
/// API legacy dell'ateneo (Basic Auth). Non è una scorciatoia nostra: è
/// il meccanismo reale con cui CINECA fa da ponte tra la verifica SPID/CIE
/// esterna e i sistemi più vecchi dell'ateneo che parlano ancora solo
/// Basic Auth. L'utente non digita né vede mai questa password: viene
/// generata e restituita dall'Identity Provider dopo la verifica.
class CinecaLoginService {
  CinecaLoginService({
    this.apiBase = 'https://unisa.app.cineca.it/',
    this.idpAuthorizeUrl =
        'https://unisa.idp.cineca.it/idp/profile/oidc/authorize',
  });

  final String apiBase;
  final String idpAuthorizeUrl;

  static const _timeout = Duration(seconds: 8);

  Future<_CinecaOAuthConfig> _fetchOAuthConfig() async {
    final resp = await http
        .get(
          Uri.parse('${apiBase}app/init?os=android'),
          headers: const {'Authorization': ''},
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CinecaLoginException(
        'Configurazione OAuth non disponibile (${resp.statusCode}).',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final configs = (json['configs'] as List?) ?? [];
    String? trova(String chiave) {
      for (final c in configs) {
        if (c is Map && c['key'] == chiave) return c['value']?.toString();
      }
      return null;
    }

    final clientId = trova('OAuthClientId');
    final scope = trova('OAuthScope');
    if (clientId == null || scope == null) {
      throw CinecaLoginException(
        'OAuthClientId/OAuthScope non trovati nella risposta.',
      );
    }
    return _CinecaOAuthConfig(clientId: clientId, scope: scope);
  }

  /// Callback HTTPS già autorizzato dal client CINECA. Il callback applicativo
  /// `unisa-prod://` viene intercettato dalla WebView prima del redirect.
  String get redirectUri => '${apiBase}oauth/app-auth-code/unisa-prod';

  /// Costruisce l'URL di login da caricare nella WebView, interrogando
  /// prima il client_id/scope pubblici reali.
  Future<String> buildAuthorizeUrl() async {
    final config = await _fetchOAuthConfig();
    final state = _randomState();
    return '$idpAuthorizeUrl?response_type=code'
        '&client_id=${config.clientId}'
        '&redirect_uri=$redirectUri'
        '&scope=${Uri.encodeQueryComponent(config.scope)}'
        '&state=$state';
  }

  String _randomState([int length = 40]) {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(
      length,
      (_) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  /// L'IdP a volte risponde 404 a meta' del percorso su questo host
  /// esatto: non e' un errore, va solo ricaricata la pagina di partenza.
  bool isTransientBounce(Uri uri) =>
      uri.host.toLowerCase() == 'unisa.openid.cineca.it';

  /// Il callback HTTPS CINECA usato dal client UNISA termina nello schema
  /// dell'app ufficiale. Registriamo entrambi gli schemi perché alcune
  /// configurazioni restituiscono il nome storico `myunisalerno`, mentre
  /// altre usano `unisa-prod`.
  bool isAppHandback(String url) {
    final uri = Uri.tryParse(url);
    final normalized = url.toLowerCase();
    return (uri != null &&
            (uri.scheme == 'myunisalerno' ||
                uri.scheme == 'unisa-prod' ||
                uri.scheme == 'it.unisaplus.app' ||
                uri.scheme == 'it.studenti.uniapp')) ||
        normalized.startsWith('unisa-prod://') ||
        normalized.startsWith('myunisalerno://');
  }

  /// Estrae username e password dal rientro e li converte nell'header
  /// Basic richiesto dalle API legacy. Restituisce null se il formato non
  /// e' quello atteso.
  String? extractBasicAuthHeader(String url) {
    final uri = Uri.tryParse(url);
    if (!isAppHandback(url)) return null;
    final raw = url.replaceFirst(RegExp(r'^[^:]+://\??'), '');
    final params = <String, String>{
      if (uri != null) ...uri.queryParameters,
      ..._fragmentParameters(uri?.fragment ?? ''),
      ..._queryParameters(raw),
    };
    final username = (params['username'] ?? params['user'])?.trim();
    final password = (params['password'] ?? params['pass'])?.trim();
    if (username == null ||
        password == null ||
        username.isEmpty ||
        password.isEmpty) {
      return null;
    }

    return 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
  }

  Map<String, String> _queryParameters(String value) {
    try {
      return value.isEmpty ? const {} : Uri.splitQueryString(value);
    } on FormatException {
      return const {};
    }
  }

  Map<String, String> _fragmentParameters(String fragment) {
    if (fragment.isEmpty) return const {};
    return Uri.splitQueryString(fragment);
  }

  /// Recupera il profilo dello studente appena autenticato, con lo stesso
  /// endpoint pubblico di prima ma stavolta con l'header Basic ottenuto.
  Future<Map<String, dynamic>> fetchProfilo(String basicAuthHeader) async {
    final resp = await http
        .get(
          Uri.parse('${apiBase}app/init?os=android'),
          headers: {'Authorization': basicAuthHeader},
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw CinecaLoginException(
        'Recupero profilo non riuscito (${resp.statusCode}).',
      );
    }
    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final profilo = json['auth_session'];
    if (profilo is! Map<String, dynamic>) {
      throw CinecaLoginException('Profilo non presente nella risposta.');
    }
    // Identificativi di carriera per le API REST dell'ateneo. Il profilo
    // puo' contenere piu' carriere (es. triennale + magistrale): si prende
    // la prima, come fa campus all'avvio. Campi CINECA: id=stuID,
    // registrationId=matID.
    String stuId = '';
    String matId = '';
    String corsoCodice = '';
    String matricolaCarriera = '';
    String annoCorso = '';
    String percorso = '';
    Map career0 = const {};
    final careers = profilo['careers'];
    if (careers is List && careers.isNotEmpty) {
      final primaCarriera = careers.first;
      if (primaCarriera is Map) {
        career0 = primaCarriera;
        stuId = primaCarriera['id']?.toString() ?? '';
        matId = primaCarriera['registrationId']?.toString() ?? '';
        // La matricola vera è qui (CareerInfo.registration_number): il
        // campo auth_session.matricola di solito è vuoto.
        matricolaCarriera = (primaCarriera['registration_number'] ??
                primaCarriera['matricola'] ??
                '')
            .toString()
            .trim();
        // Per l'orario (grid_call): anno2 = anno di corso, txtcurr =
        // curriculum/percorso. Il profilo UNISA non ha classID/classDes:
        // i valori equivalenti sono nella carriera.
        annoCorso = (primaCarriera['annoCorso'] ?? '').toString().trim();
        for (final key in ['percorsoDes', 'classe', 'iscrDes']) {
          final v = primaCarriera[key]?.toString().trim();
          if (v != null && v.isNotEmpty && v.toLowerCase() != 'comune') {
            percorso = v;
            break;
          }
        }
        // Se l'unico percorso è "COMUNE" lo si usa comunque.
        if (percorso.isEmpty) {
          percorso = (primaCarriera['percorsoDes'] ?? primaCarriera['classe'] ?? '').toString().trim();
        }
        for (final key in ['cdsCod', 'cdl', 'courseCode', 'degreeCourseCode']) {
          final value = primaCarriera[key]?.toString().trim();
          if (value != null && value.isNotEmpty) {
            corsoCodice = value;
            break;
          }
        }
        if (corsoCodice.isEmpty) {
          corsoCodice = primaCarriera['notes']?.toString().trim() ?? '';
        }
      }
    }
    final matricola = (profilo['matricola']?.toString().trim().isNotEmpty ?? false)
        ? profilo['matricola'].toString().trim()
        : matricolaCarriera;
    debugPrint('[LOGIN] matricola="$matricola" annoCorso="$annoCorso" percorso="$percorso" stuId="$stuId" matId="$matId"');
    debugPrint('[LOGIN] career.annoCorso=${career0['annoCorso']} classe=${career0['classe']} '
        'percorsoDes=${career0['percorsoDes']} coorte=${career0['coorte']} '
        'ordinamento=${career0['ordinamento']} title=${career0['title']}');
    return {
      'matricola': matricola,
      'nome': profilo['firstname']?.toString() ?? '',
      'cognome': profilo['lastname']?.toString() ?? '',
      'email': profilo['username']?.toString() ?? '',
      'token': basicAuthHeader,
      'userType': 'Studente',
      'stuId': stuId,
      'matId': matId,
      'corsoCodice': corsoCodice,
      // Per l'orario pubblico AgendaStudenti (grid_call.php): anno2 =
      // annoCorso, txtcurr = percorso/curriculum.
      'classId': annoCorso.isNotEmpty ? annoCorso : (profilo['classID']?.toString() ?? ''),
      'classDes': percorso.isNotEmpty ? percorso : (profilo['classDes']?.toString() ?? ''),
    };
  }
}

class _CinecaOAuthConfig {
  final String clientId;
  final String scope;
  _CinecaOAuthConfig({required this.clientId, required this.scope});
}

class CinecaLoginException implements Exception {
  final String message;
  CinecaLoginException(this.message);

  @override
  String toString() => message;
}

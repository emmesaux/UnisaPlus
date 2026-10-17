import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'mensa_qr_service.dart';

/// Saldo del borsellino mensa ADiSURC e gestione del tesserino QR TOTP.
class WalletAdisurc {
  final double saldo;
  final String valuta;
  WalletAdisurc({required this.saldo, this.valuta = 'EUR'});
}

class AdisurcLoginSession {
  const AdisurcLoginSession({
    required this.accessToken,
    required this.flag0,
    required this.customAuthorization,
    this.qrAttivato = false,
  });

  final String accessToken;
  final String flag0;
  final String customAuthorization;
  final bool qrAttivato;
}

class AdisurcService {
  AdisurcService({
    this.apiBase = 'https://in4ceptor-proxy.dirittoallostudio.it',
  });

  final String apiBase;
  static const _timeout = Duration(seconds: 12);
  final _storage = const FlutterSecureStorage();

  static const _kAccessToken = 'adisurc_access_token';
  static const _kFlag0 = 'adisurc_flag0';
  static const _kAccessTokenSrm = 'adisurc_access_token_srm';
  static const _kSidSrm = 'adisurc_sid_srm';
  static const _kMensaKey = 'adisurc_mensa_key';
  static const _kCustomAuth = 'adisurc_custom_auth';

  final ValueNotifier<bool> isDemo = ValueNotifier(false);

  bool _restored = false;

  /// Sessione `Custom-App-Authorization` ottenuta da `DEVICE-MENSA/user/init`
  /// o dall'associazione QR.
  String? _sessionToken;
  bool get associato => (_mensaKey != null && _mensaKey!.isNotEmpty) || _sessionToken != null;

  /// Credenziali della sessione web ADiSURC (dal login SPID/CIE).
  String? _accessToken;
  String? _flag0;
  String? _accessTokenSRM;
  String? _sidSRM;
  bool get loggato => _accessToken != null && _flag0 != null;

  /// Chiave carta mensa (`KEY` del QR di associazione): serve a richiedere
  /// il JWT della carta per generare il QR mensa reale (TOTP).
  String? _mensaKey;

  /// Dati carta mensa correnti (null finché non ottenuti dal server).
  MensaCard? cartaMensa;

  /// Saldo eventualmente estratto dal payload JWT della carta.
  double? _saldoDaJwt;

  // Endpoint reali del gateway mensa ADiSURC (usati dall'app Campus / ADISURC.EAT).
  static const _mensaGatewayBase =
      'https://mensa-agw-02.dirittoallostudio.it/7b132cc348f9f803350d65f6739561a1/rest/V4.0.2';
  static const _mensaActivateUrl =
      '$_mensaGatewayBase/api/app/activate/EBADGE-QRCARD';
  static const _mensaLoginUrl =
      '$_mensaGatewayBase/api/app/login/EBADGE-QRCARD';
  static const _mensaDeactivateUrl =
      '$_mensaGatewayBase/api/app/deactivate/EBADGE-QRCARD';
  static const _mensaClientBearer =
      'Bearer 74e056bf-ab28-48b0-8436-5551df72a3db';

  static const _serverBase =
      'https://adisurc-ol.dirittoallostudio.it/apps/V3.1';

  /// Ripristina le credenziali e la chiave QR salvate nello storage sicuro.
  Future<void> restoreSession() async {
    if (_restored) return;
    _restored = true;
    try {
      _accessToken = await _storage
          .read(key: _kAccessToken)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      _flag0 = await _storage
          .read(key: _kFlag0)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      _accessTokenSRM = await _storage
          .read(key: _kAccessTokenSrm)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      _sidSRM = await _storage
          .read(key: _kSidSrm)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      _mensaKey = await _storage
          .read(key: _kMensaKey)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      _sessionToken = await _storage
          .read(key: _kCustomAuth)
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
    } catch (_) {}
  }

  Future<void> _salvaSessioneStorage() async {
    try {
      if (_accessToken != null) {
        await _storage.write(key: _kAccessToken, value: _accessToken);
      }
      if (_flag0 != null) {
        await _storage.write(key: _kFlag0, value: _flag0);
      }
      if (_accessTokenSRM != null && _accessTokenSRM!.isNotEmpty) {
        await _storage.write(key: _kAccessTokenSrm, value: _accessTokenSRM);
      }
      if (_sidSRM != null && _sidSRM!.isNotEmpty) {
        await _storage.write(key: _kSidSrm, value: _sidSRM);
      }
      if (_mensaKey != null && _mensaKey!.isNotEmpty) {
        await _storage.write(key: _kMensaKey, value: _mensaKey);
      }
      if (_sessionToken != null && _sessionToken!.isNotEmpty) {
        await _storage.write(key: _kCustomAuth, value: _sessionToken);
      }
    } catch (_) {}
  }

  /// Body JSON standard `appPOSTRequest` richiesto dal gateway `mensa-agw-02`.
  String _appPostBody(String key) => jsonEncode({
    'KEY': key,
    'DEVICE_UID': 'N/A',
    'DEVICE_NAME': '[CampusUnisaApp] Android',
    'DEVICE_OS': 'Android',
    'DEVICE_VERSION': 34,
    'APP_NAME': 'ADISURC.EAT',
    'APP_VER': '2.1.9',
  });

  Map<String, String> _adisurcWebHeaders(
    String accessToken, {
    String? customAppAuth,
    bool jsonContent = false,
  }) {
    return {
      'Authorization': accessToken,
      if (_accessTokenSRM != null && _accessTokenSRM!.isNotEmpty)
        'Custom-Authorization': _accessTokenSRM!,
      if (_sidSRM != null && _sidSRM!.isNotEmpty) 'Custom-Sid-Srm': _sidSRM!,
      if (customAppAuth != null && customAppAuth.isNotEmpty)
        'Custom-App-Authorization': customAppAuth,
      if (jsonContent) 'Content-Type': 'application/json',
    };
  }

  /// Anni accademici candidati (in ordine di priorità). Su ADiSURC i moduli
  /// `INFO-RISTORAZIONE` e `DEVICE-MENSA` sono pubblicati su `dol-100/25`
  /// (`p_idanac=2025`), con fallback su `2026` e `2024`.
  List<int> _anniCandidati() => const [2025, 2026, 2024];

  /// Richiede al gateway `mensa-agw-02` i dati carta (`cardid`, `cardsecret`,
  /// `cardinterval`) dentro un JWT usando la `KEY` di associazione.
  /// Se l'utente ha già effettuato il login web ADiSURC ma non ha ancora
  /// `_mensaKey`, esegue automaticamente il provisioning da `DEVICE-MENSA`
  /// (come Campus, senza bisogno di scansionare il QR con la fotocamera).
  Future<MensaCard?> caricaCartaMensa() async {
    await restoreSession();
    var key = _mensaKey;
    if ((key == null || key.isEmpty) && loggato) {
      await _procuratiKeyDaSessioneWeb();
      key = _mensaKey;
    }
    if (key == null || key.isEmpty) return null;
    try {
      final resp = await http
          .post(
            Uri.parse(_mensaLoginUrl),
            headers: const {
              'Authorization': _mensaClientBearer,
              'Content-Type': 'application/json',
            },
            body: _appPostBody(key),
          )
          .timeout(_timeout);
      debugPrint('[ADISURC] loginQR status=${resp.statusCode}');
      if (resp.statusCode < 200 || resp.statusCode >= 300) return null;
      final json = jsonDecode(resp.body);
      if (json is! Map ||
          json['status']?.toString().toUpperCase() != 'OK') {
        debugPrint('[ADISURC] loginQR body=${resp.body}');
        return null;
      }
      final data = json['data'];
      final jwt = data is Map ? data['jwt']?.toString() : null;
      if (jwt == null || jwt.isEmpty) return null;
      final payload = _decodeJwtPayload(jwt);
      if (payload == null) return null;
      final saldoJwt = _estraiSaldoDaMappa(payload);
      if (saldoJwt != null) _saldoDaJwt = saldoJwt;
      final carta = MensaCard.fromPayload(payload);
      cartaMensa = carta.valida ? carta : null;
      return cartaMensa;
    } catch (e) {
      debugPrint('[ADISURC] caricaCartaMensa err=$e');
      return null;
    }
  }

  /// Attiva una `KEY` sul gateway `mensa-agw-02` (`activate/EBADGE-QRCARD`).
  Future<bool> _attivaKeySulGateway(String key, {Uri? customUrl}) async {
    final urls = <Uri>[
      ?customUrl,
      if (customUrl == null || customUrl.toString() != _mensaActivateUrl)
        Uri.parse(_mensaActivateUrl),
    ];
    for (final url in urls) {
      try {
        final resp = await http
            .post(
              url,
              headers: const {
                'Authorization': _mensaClientBearer,
                'Content-Type': 'application/json',
              },
              body: _appPostBody(key),
            )
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] activateQR ($url) status=${resp.statusCode} body=${resp.body}',
        );
        if (resp.statusCode >= 200 && resp.statusCode < 300) {
          final decoded = jsonDecode(resp.body);
          if (decoded is Map &&
              decoded['status']?.toString().toUpperCase() == 'OK') {
            return true;
          }
        }
      } catch (e) {
        debugPrint('[ADISURC] activateQR err=$e');
      }
    }
    return false;
  }

  /// Disattiva la carta corrente sul gateway `mensa-agw-02`.
  Future<void> disattivaQr() async {
    await restoreSession();
    final key = _mensaKey;
    if (key != null && key.isNotEmpty) {
      try {
        await http
            .post(
              Uri.parse(_mensaDeactivateUrl),
              headers: const {
                'Authorization': _mensaClientBearer,
                'Content-Type': 'application/json',
              },
              body: _appPostBody(key),
            )
            .timeout(_timeout);
      } catch (_) {}
    }
    _mensaKey = null;
    cartaMensa = null;
    await _storage.delete(key: _kMensaKey);
  }

  /// Decodifica il payload (segmento centrale) di un JWT, come fa Campus.
  Map<String, dynamic>? _decodeJwtPayload(String jwt) {
    final parti = jwt.split('.');
    if (parti.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parti[1])),
      );
      final json = jsonDecode(payload);
      return json is Map<String, dynamic> ? json : null;
    } catch (_) {
      return null;
    }
  }

  /// Completa il login ADiSURC effettuato nella WebView (SPID/CIE) seguendo
  /// l'esatto flusso di `MensaQrManager` dell'app Campus:
  /// 1. `util/accreditato`
  /// 2. `DEVICE-MENSA/public/index.php/user/init` -> `Custom-App-Authorization`
  /// 3. `GET user/device/qrcode` -> se già associato ad altro telefono
  ///    (`APP gia' attivata`), chiama `POST user/device/delete` per
  ///    dissociare il vecchio telefono
  /// 4. `POST user/device/qrcode` -> genera il QR di associazione (`based`)
  /// 5. `POST activate/EBADGE-QRCARD` -> attiva la `key` e salva `_mensaKey`
  /// 6. `caricaCartaMensa()` -> ottiene subito il JWT per il QR TOTP.
  Future<AdisurcLoginSession> completaLoginWeb({
    required String accessToken,
    required String flag0,
    String? accessTokenSRM,
    String? sidSRM,
  }) async {
    _restored = true;
    _accessToken = accessToken;
    _flag0 = flag0;
    if (accessTokenSRM != null && accessTokenSRM.isNotEmpty) {
      _accessTokenSRM = accessTokenSRM;
    }
    if (sidSRM != null && sidSRM.isNotEmpty) {
      _sidSRM = sidSRM;
    }
    await _salvaSessioneStorage();

    // Step 1: checkAccredito (best-effort, inizializza la sessione lato sol).
    try {
      final accUri = Uri.parse(
        '$_serverBase/sol/public/index.php/util/accreditato',
      ).replace(queryParameters: {'p_flag0': flag0, 'p_lang': 'it'});
      await http
          .get(accUri, headers: _adisurcWebHeaders(accessToken))
          .timeout(_timeout);
    } catch (_) {}

    // Step 2..5: ottiene Custom-App-Authorization, genera e attiva la KEY QR.
    final qrAttivato = await _procuratiKeyDaSessioneWeb();

    if (_mensaKey != null && _mensaKey!.isNotEmpty) {
      await caricaCartaMensa();
    }

    return AdisurcLoginSession(
      accessToken: accessToken,
      flag0: flag0,
      customAuthorization: _sessionToken ?? '',
      qrAttivato: qrAttivato,
    );
  }

  /// Usa `_accessToken` e `_flag0` per eseguire `user/init` su `DEVICE-MENSA`,
  /// generare il QR (`based`) e attivare la `key` su `mensa-agw-02`.
  Future<bool> _procuratiKeyDaSessioneWeb() async {
    final accessToken = _accessToken;
    final flag0 = _flag0;
    if (accessToken == null || flag0 == null) return false;

    String customAuthorization = '';
    int? activeYear;
    String? activeSmallYear;

    for (final year in _anniCandidati()) {
      final smallYear = (year % 100).toString().padLeft(2, '0');
      try {
        final response = await http
            .get(
              Uri.parse(
                '$_serverBase/dol-100/$smallYear/DEVICE-MENSA/public/index.php/user/init',
              ).replace(
                queryParameters: {
                  'p_idanac': year.toString(),
                  'p_codappl': 'DEVICE-MENSA',
                  'p_flag0': flag0,
                },
              ),
              headers: _adisurcWebHeaders(accessToken),
            )
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] DEVICE-MENSA init ($year) status=${response.statusCode}',
        );
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final token = _responseDataString(jsonDecode(response.body)) ?? '';
          if (token.isNotEmpty) {
            customAuthorization = token;
            activeYear = year;
            activeSmallYear = smallYear;
            _sessionToken = customAuthorization;
            break;
          }
        }
      } catch (e) {
        debugPrint('[ADISURC] DEVICE-MENSA init ($year) err=$e');
      }
    }

    if (customAuthorization.isEmpty ||
        activeYear == null ||
        activeSmallYear == null) {
      return false;
    }

    final attivato = await _generaEAttivaQrAutomatico(
      accessToken: accessToken,
      flag0: flag0,
      customAuth: customAuthorization,
      year: activeYear,
      smallYear: activeSmallYear,
    );
    await _salvaSessioneStorage();
    return attivato;
  }

  /// Esegue il provisioning automatico del QR su `DEVICE-MENSA` come Campus.
  Future<bool> _generaEAttivaQrAutomatico({
    required String accessToken,
    required String flag0,
    required String customAuth,
    required int year,
    required String smallYear,
  }) async {
    final baseDeviceUrl =
        '$_serverBase/dol-100/$smallYear/DEVICE-MENSA/public/index.php/user/device';
    try {
      // 3a) Controlla lo stato attuale del dispositivo/QR (GET qrcode).
      final checkUri = Uri.parse('$baseDeviceUrl/qrcode').replace(
        queryParameters: {
          'p_flag0': flag0,
          'idanac': year.toString(),
          't': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      final checkResp = await http
          .get(
            checkUri,
            headers: _adisurcWebHeaders(
              accessToken,
              customAppAuth: customAuth,
            ),
          )
          .timeout(_timeout);
      debugPrint(
        '[ADISURC] GET device/qrcode status=${checkResp.statusCode} body=${checkResp.body}',
      );

      _AdisurcActivation? attivazione;
      bool giaAttivata = false;

      if (checkResp.statusCode >= 200 && checkResp.statusCode < 300) {
        final checkJson = jsonDecode(checkResp.body);
        if (checkJson is Map) {
          final status = checkJson['status']?.toString().toUpperCase();
          final errText = [
            checkJson['error']?.toString() ?? '',
            if (checkJson['messages'] is Map)
              (checkJson['messages'] as Map)['error']?.toString() ?? '',
          ].join(' ').toLowerCase();

          if (status == 'KO' && errText.contains('attivat')) {
            giaAttivata = true;
          } else if (status == 'OK') {
            attivazione = _estraiAttivazioneDaRispostaQrCode(checkJson);
          }
        }
      }

      // 3b) Se l'app risulta già attivata, dissocia il dispositivo precedente
      // (esattamente come `dissociaSmartphone` in Campus).
      if (giaAttivata) {
        final delResp = await http
            .post(
              Uri.parse('$baseDeviceUrl/delete'),
              headers: _adisurcWebHeaders(
                accessToken,
                customAppAuth: customAuth,
                jsonContent: true,
              ),
              body: jsonEncode({'p_flag0': flag0}),
            )
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] POST device/delete status=${delResp.statusCode} body=${delResp.body}',
        );
      }

      // 4) Se non abbiamo ancora un QR di attivazione valido, generalo con POST qrcode.
      if (attivazione == null) {
        final postResp = await http
            .post(
              Uri.parse('$baseDeviceUrl/qrcode'),
              headers: _adisurcWebHeaders(
                accessToken,
                customAppAuth: customAuth,
                jsonContent: true,
              ),
              body: jsonEncode({
                'p_flag0': flag0,
                'idanac': year,
                't': DateTime.now().millisecondsSinceEpoch,
              }),
            )
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] POST device/qrcode status=${postResp.statusCode} body=${postResp.body}',
        );
        if (postResp.statusCode >= 200 && postResp.statusCode < 300) {
          final postJson = jsonDecode(postResp.body);
          if (postJson is Map) {
            attivazione = _estraiAttivazioneDaRispostaQrCode(postJson);
          }
        }
      }

      if (attivazione == null) {
        debugPrint('[ADISURC] Nessuna attivazione estratta dal QR');
        return false;
      }

      // 5) Attiva la KEY sul gateway mensa-agw-02 e salvala.
      await _attivaKeySulGateway(attivazione.key, customUrl: attivazione.url);
      _mensaKey = attivazione.key;
      return true;
    } catch (e) {
      debugPrint('[ADISURC] _generaEAttivaQrAutomatico err=$e');
      return false;
    }
  }

  /// Estrae `_AdisurcActivation` dalla risposta di `user/device/qrcode`.
  /// In `MensaData` (e nella risposta reale di ADiSURC), `"based"` è una
  /// proprietà di primo livello del JSON (`json['based']`), oltre a poter
  /// comparire dentro `json['data']`.
  _AdisurcActivation? _estraiAttivazioneDaRispostaQrCode(Map json) {
    final topBased = json['based']?.toString();
    if (topBased != null && topBased.isNotEmpty) {
      final act = _estraiAttivazione(topBased);
      if (act != null) return act;
    }
    final data = json['data'];
    if (data is String && data.isNotEmpty) {
      final act = _estraiAttivazione(data);
      if (act != null) return act;
    } else if (data is Map) {
      final based = data['based']?.toString();
      if (based != null && based.isNotEmpty) {
        final act = _estraiAttivazione(based);
        if (act != null) return act;
      }
      final innerData = data['data'];
      if (innerData is String && innerData.isNotEmpty) {
        final act = _estraiAttivazione(innerData);
        if (act != null) return act;
      } else if (innerData is Map) {
        final act = _activationFromJson(innerData);
        if (act != null) return act;
      }
      final direct = _activationFromJson(data);
      if (direct != null) return direct;
    }
    return _activationFromJson(json);
  }

  String? _responseDataString(dynamic response) {
    if (response is! Map) return null;
    final status = response['status']?.toString().toUpperCase();
    if (status != null && status != 'OK' && status != 'SUCCESS') return null;
    final data = response['data'];
    if (data is String) return data;
    if (data is Map) {
      for (final key in [
        'token',
        'access_token',
        'custom_app_authorization',
        'customAuthorization',
      ]) {
        final value = data[key]?.toString();
        if (value != null && value.isNotEmpty) return value;
      }
    }
    return null;
  }

  /// Associa il dispositivo scansionando il QR generato sul portale web ADiSURC.
  /// Usa il vero endpoint `activate/EBADGE-QRCARD` del gateway `mensa-agw-02`.
  Future<void> associaConQr(String datiQr) async {
    await restoreSession();
    final attivazione = _estraiAttivazione(datiQr);
    if (attivazione == null) {
      throw AdisurcException(
        'Codice QR non riconosciuto. Generane uno nuovo dal portale ADiSURC.',
      );
    }

    final attivato = await _attivaKeySulGateway(
      attivazione.key,
      customUrl: attivazione.url,
    );
    _mensaKey = attivazione.key;
    _sessionToken = attivazione.token;
    await _salvaSessioneStorage();

    final carta = await caricaCartaMensa();
    if (!attivato && carta == null) {
      throw AdisurcException(
        'Associazione non riuscita. Il codice QR potrebbe essere già stato utilizzato: rigeneralo dal portale ADiSURC o accedi con SPID/CIE.',
      );
    }
  }

  _AdisurcActivation? _estraiAttivazione(String datiQr) {
    final contenuto = datiQr.trim();
    if (contenuto.isEmpty) return null;

    // 1) JSON diretto `{"url": "...", "key": "...", "token": "..."}`.
    try {
      final json = jsonDecode(contenuto);
      if (json is Map) {
        final activation = _activationFromJson(json);
        if (activation != null) return activation;
      }
    } catch (_) {}

    // 2) Formato `data:...,<base64>`.
    if (contenuto.contains(',')) {
      final afterComma = contenuto.split(',').last.trim();
      try {
        final decoded = utf8.decode(
          base64.decode(base64.normalize(afterComma)),
        );
        final json = jsonDecode(decoded);
        if (json is Map) {
          final activation = _activationFromJson(json);
          if (activation != null) return activation;
        }
      } catch (_) {}
    }

    // 3) URI `attivazione://...` con payload base64.
    final activationUri = Uri.tryParse(contenuto);
    if (activationUri?.scheme == 'attivazione' &&
        activationUri!.pathSegments.isNotEmpty) {
      try {
        final encoded = activationUri.pathSegments.last;
        final decoded = utf8.decode(
          base64Url.decode(base64Url.normalize(encoded)),
        );
        final json = jsonDecode(decoded);
        if (json is Map) return _activationFromJson(json);
      } catch (_) {}
    }

    // 4) Base64 standard o Base64Url puro di un JSON (es. `based` = `eyJ1cmwiOi...`).
    for (final codec in [base64, base64Url]) {
      try {
        final decoded = utf8.decode(
          codec.decode(codec.normalize(contenuto)),
        );
        final json = jsonDecode(decoded);
        if (json is Map) {
          final act = _activationFromJson(json);
          if (act != null) return act;
        }
      } catch (_) {}
    }

    return null;
  }

  _AdisurcActivation? _activationFromJson(Map<dynamic, dynamic> json) {
    final rawUrl =
        json['url']?.toString().replaceAll(r'\/', '/') ?? _mensaActivateUrl;
    final token =
        json['token']?.toString() ?? json['info']?.toString() ?? '';
    final key = json['key']?.toString() ?? json['KEY']?.toString();
    if (key == null || key.isEmpty) {
      return null;
    }
    final url = Uri.tryParse(rawUrl) ?? Uri.parse(_mensaActivateUrl);
    final method = (json['method']?.toString() ?? 'POST').toUpperCase();
    return _AdisurcActivation(
      url: url,
      method: method,
      token: token,
      key: key,
    );
  }

  /// Saldo del borsellino mensa ADiSURC dall'endpoint `badgeinfo`:
  /// `https://adisurc-ol.dirittoallostudio.it/apps/V3.1/dol-100/25/INFO-RISTORAZIONE/public/index.php/badgeinfo?p_idanac=2025&p_codappl=INFO-RISTORAZIONE&p_flag0={flag0}`
  Future<WalletAdisurc?> getSaldo() async {
    await restoreSession();
    final token = _accessToken;
    final flag0 = _flag0;
    if (token == null || flag0 == null) {
      if (_saldoDaJwt != null) {
        isDemo.value = false;
        return WalletAdisurc(saldo: _saldoDaJwt!);
      }
      isDemo.value = true;
      return null;
    }

    for (final year in _anniCandidati()) {
      final smallYear = (year % 100).toString().padLeft(2, '0');
      final badgeUri = Uri.parse(
        '$_serverBase/dol-100/$smallYear/INFO-RISTORAZIONE/public/index.php/badgeinfo',
      ).replace(
        queryParameters: {
          'p_idanac': year.toString(),
          'p_codappl': 'INFO-RISTORAZIONE',
          'p_flag0': flag0,
        },
      );

      // 1) Tentativo diretto su badgeinfo con Authorization (e token SRM se presenti).
      try {
        final directResp = await http
            .get(
              badgeUri,
              headers: _adisurcWebHeaders(
                token,
                customAppAuth: _sessionToken,
              ),
            )
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] GET badgeinfo diretto ($year) status=${directResp.statusCode} body=${directResp.body}',
        );
        if (directResp.statusCode >= 200 &&
            directResp.statusCode < 300 &&
            directResp.body.trim() != 'Invalid token') {
          final saldo = _estraiSaldo(directResp.body);
          if (saldo != null) {
            isDemo.value = false;
            return WalletAdisurc(saldo: saldo);
          }
        }
      } catch (e) {
        debugPrint('[ADISURC] GET badgeinfo diretto ($year) err=$e');
      }

      // 2) Tentativo con user/init su INFO-RISTORAZIONE per ottenere Custom-App-Authorization
      // e successiva GET su badgeinfo.
      try {
        final initUri = Uri.parse(
          '$_serverBase/dol-100/$smallYear/INFO-RISTORAZIONE/public/index.php/user/init',
        ).replace(
          queryParameters: {
            'p_idanac': year.toString(),
            'p_codappl': 'INFO-RISTORAZIONE',
            'p_flag0': flag0,
          },
        );
        final initResp = await http
            .get(initUri, headers: _adisurcWebHeaders(token))
            .timeout(_timeout);
        debugPrint(
          '[ADISURC] INFO-RISTORAZIONE init ($year) status=${initResp.statusCode} body=${initResp.body}',
        );
        if (initResp.statusCode >= 200 && initResp.statusCode < 300) {
          final saldoInit = _estraiSaldo(initResp.body);
          if (saldoInit != null) {
            isDemo.value = false;
            return WalletAdisurc(saldo: saldoInit);
          }
          final customAppAuth = _responseDataString(jsonDecode(initResp.body));
          if (customAppAuth != null && customAppAuth.isNotEmpty) {
            final resp = await http
                .get(
                  badgeUri,
                  headers: _adisurcWebHeaders(
                    token,
                    customAppAuth: customAppAuth,
                  ),
                )
                .timeout(_timeout);
            debugPrint(
              '[ADISURC] GET badgeinfo+init ($year) status=${resp.statusCode} body=${resp.body}',
            );
            if (resp.statusCode >= 200 && resp.statusCode < 300) {
              final saldo = _estraiSaldo(resp.body);
              if (saldo != null) {
                isDemo.value = false;
                return WalletAdisurc(saldo: saldo);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[ADISURC] INFO-RISTORAZIONE init+badgeinfo ($year) err=$e');
      }
    }

    if (_saldoDaJwt != null) {
      isDemo.value = false;
      return WalletAdisurc(saldo: _saldoDaJwt!);
    }

    isDemo.value = true;
    return null;
  }

  double? _daStringaImporto(String? s) {
    if (s == null) return null;
    final pulita = s
        .replaceAll('€', '')
        .replaceAll('EUR', '')
        .replaceAll(RegExp(r'[^0-9,.\-]'), '')
        .trim();
    if (pulita.isEmpty || pulita == '-' || pulita == '.' || pulita == ',') {
      return null;
    }
    final norm = pulita.contains(',') && !pulita.contains('.')
        ? pulita.replaceAll('.', '').replaceAll(',', '.')
        : pulita.replaceAll(',', '');
    return double.tryParse(norm);
  }

  double? _estraiSaldoDaMappa(Map map) {
    const chiaviSaldo = [
      'saldo',
      'borsellino',
      'importo',
      'credito',
      'disponibilita',
      'balance',
      'residuo',
      'credit',
      'wallet',
      'valore_saldo',
      'imp_saldo',
    ];
    for (final entry in map.entries) {
      final k = entry.key.toString().toLowerCase();
      final val = entry.value;
      if (chiaviSaldo.any((c) => k == c || k.contains(c))) {
        if (val is num) return val.toDouble();
        if (val is String) {
          final parsed = _daStringaImporto(val);
          if (parsed != null) return parsed;
        }
      }
    }
    for (final val in map.values) {
      if (val is Map) {
        final nested = _estraiSaldoDaMappa(val);
        if (nested != null) return nested;
      } else if (val is List) {
        for (final item in val) {
          if (item is Map) {
            final nested = _estraiSaldoDaMappa(item);
            if (nested != null) return nested;
          }
        }
      }
    }
    return null;
  }

  /// Estrae l'importo del saldo dalla risposta JSON o HTML di `badgeinfo`.
  double? _estraiSaldo(String body) {
    try {
      final json = jsonDecode(body);
      if (json is num) return json.toDouble();
      if (json is Map) {
        final daMappa = _estraiSaldoDaMappa(json);
        if (daMappa != null) return daMappa;

        final data = json['data'];
        if (data is num) return data.toDouble();
        if (data is String) {
          final diretto = _daStringaImporto(data);
          if (diretto != null &&
              RegExp(r'^\s*€?\s*[0-9]+[.,]?[0-9]*\s*€?\s*$').hasMatch(data)) {
            return diretto;
          }
          final daTesto = _estraiSaldoDaTesto(data);
          if (daTesto != null) return daTesto;
        } else if (data is Map) {
          for (final v in data.values) {
            if (v is String) {
              final daTesto = _estraiSaldoDaTesto(v);
              if (daTesto != null) return daTesto;
            }
          }
        }
      }
    } catch (_) {}
    return _estraiSaldoDaTesto(body);
  }

  double? _estraiSaldoDaTesto(String text) {
    final m =
        RegExp(
          r'(?:saldo|borsellino|credito|disponibilit[aà]|residuo)[^0-9€\-]{0,60}(?:€|EUR)?\s*([\-]?[0-9]+[.,][0-9]{1,2})',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'(?:€|EUR)\s*([\-]?[0-9]+[.,][0-9]{1,2})',
          caseSensitive: false,
        ).firstMatch(text) ??
        RegExp(
          r'([\-]?[0-9]+[.,][0-9]{2})\s*(?:€|EUR)',
          caseSensitive: false,
        ).firstMatch(text);
    return _daStringaImporto(m?.group(1));
  }

  static const String mensaMenuPageUrl =
      'https://www.adisurcampania.it/ristorazione/mense-ed-esercizi-convenzionati/mensa-di-fisciano-e-baronissi#toc-il-men-';
  static const String _adisurcSiteOrigin = 'https://www.adisurcampania.it';

  /// Scarica l'elenco aggiornato dei menù giornalieri (Pranzo e Cena) della
  /// settimana dalla pagina ufficiale ADiSURC di Fisciano e Baronissi.
  Future<List<MensaMenuGiorno>> getMenuSettimana() async {
    final resp = await http
        .get(
          Uri.parse(
            '$_adisurcSiteOrigin/ristorazione/mense-ed-esercizi-convenzionati/mensa-di-fisciano-e-baronissi',
          ),
        )
        .timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw AdisurcException(
        'Impossibile caricare il menù della mensa (${resp.statusCode}).',
      );
    }

    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    return _parseMenuHtml(html);
  }

  List<MensaMenuGiorno> _parseMenuHtml(String html) {
    // Divide la pagina nei blocchi "Menu pranzo" e "Menu cena"
    final sectionRegex = RegExp(
      r'field--name-field-titolo[^>]*>\s*([^<]+?)\s*</div>([\s\S]*?)(?=field--name-field-titolo|<h2>Come pagare</h2>|$)',
      caseSensitive: false,
    );

    final pranzoItems = <_ParsedMenuLink>[];
    final cenaItems = <_ParsedMenuLink>[];

    for (final secMatch in sectionRegex.allMatches(html)) {
      final titolo = (secMatch.group(1) ?? '').trim().toLowerCase();
      final content = secMatch.group(2) ?? '';
      final isCena = titolo.contains('cena');
      final isPranzo = titolo.contains('pranzo') || !isCena;

      final itemRegex = RegExp(
        r'<div\s+class="block-scadenze">\s*<a\s+href="([^"]+)"[^>]*>\s*'
        r'<div\s+class="block-scadenze-day">\s*([^<]*?)\s*</div>\s*'
        r'<div\s+class="block-scadenze-month">\s*([^<]*?)\s*</div>\s*'
        r'<div\s+class="block-scadenze-year">\s*([^<]*?)\s*</div>',
        caseSensitive: false,
      );

      var idx = 0;
      for (final m in itemRegex.allMatches(content)) {
        final rawHref = (m.group(1) ?? '').trim();
        if (rawHref.isEmpty) continue;
        final fullUrl = rawHref.startsWith('http')
            ? rawHref
            : '$_adisurcSiteOrigin${rawHref.startsWith('/') ? '' : '/'}$rawHref';
        final day = (m.group(2) ?? '').trim();
        final month = (m.group(3) ?? '').trim();
        final year = (m.group(4) ?? '').trim();
        final weekday = _inferWeekday(fullUrl, idx);
        final settimana = _inferSettimana(fullUrl);
        final link = _ParsedMenuLink(
          url: fullUrl,
          day: day,
          month: month,
          year: year,
          weekday: weekday,
          settimanaLabel: settimana,
        );
        if (isCena) {
          cenaItems.add(link);
        } else if (isPranzo) {
          pranzoItems.add(link);
        }
        idx++;
      }
    }

    // Combina pranzo e cena per giorno della settimana / data
    final byKey = <String, MensaMenuGiorno>{};
    for (var i = 0; i < pranzoItems.length; i++) {
      final p = pranzoItems[i];
      final key = '${p.weekday}_${p.day}_${p.month}';
      byKey[key] = MensaMenuGiorno(
        weekday: p.weekday,
        nomeGiorno: _nomeGiorno(p.weekday),
        nomeGiornoBreve: _nomeGiornoBreve(p.weekday),
        giornoNumero: p.day,
        meseNome: p.month,
        anno: p.year,
        settimanaLabel: p.settimanaLabel,
        pranzoPdfUrl: p.url,
        cenaPdfUrl: null,
      );
    }

    for (var i = 0; i < cenaItems.length; i++) {
      final c = cenaItems[i];
      final key = '${c.weekday}_${c.day}_${c.month}';
      final existing = byKey[key];
      if (existing != null) {
        byKey[key] = existing.copyWith(cenaPdfUrl: c.url);
      } else {
        byKey[key] = MensaMenuGiorno(
          weekday: c.weekday,
          nomeGiorno: _nomeGiorno(c.weekday),
          nomeGiornoBreve: _nomeGiornoBreve(c.weekday),
          giornoNumero: c.day,
          meseNome: c.month,
          anno: c.year,
          settimanaLabel: c.settimanaLabel,
          pranzoPdfUrl: null,
          cenaPdfUrl: c.url,
        );
      }
    }

    final result = byKey.values.toList()
      ..sort((a, b) => a.weekday.compareTo(b.weekday));
    return result;
  }

  static int _inferWeekday(String url, int fallbackIndex) {
    final file = url.split('/').last.toLowerCase();
    if (file.contains('lun')) return DateTime.monday;
    if (file.contains('mar')) return DateTime.tuesday;
    if (file.contains('mer')) return DateTime.wednesday;
    if (file.contains('gio')) return DateTime.thursday;
    if (file.contains('ven')) return DateTime.friday;
    if (file.contains('sab')) return DateTime.saturday;
    if (file.contains('dom')) return DateTime.sunday;
    return (fallbackIndex + 1).clamp(1, 7);
  }

  static String _inferSettimana(String url) {
    final file = url.split('/').last;
    final m = RegExp(r'^([1-5])a', caseSensitive: false).firstMatch(file);
    final stag = file.toLowerCase().contains('inv')
        ? 'Invernale'
        : (file.toLowerCase().contains('est') ? 'Estivo' : '');
    if (m != null) {
      final numSett = m.group(1);
      return stag.isNotEmpty
          ? '$numSettª settimana · Menù $stag'
          : '$numSettª settimana';
    }
    return stag.isNotEmpty ? 'Menù $stag' : 'Menù settimanale';
  }

  static String _nomeGiorno(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'Lunedì';
      case DateTime.tuesday:
        return 'Martedì';
      case DateTime.wednesday:
        return 'Mercoledì';
      case DateTime.thursday:
        return 'Giovedì';
      case DateTime.friday:
        return 'Venerdì';
      case DateTime.saturday:
        return 'Sabato';
      case DateTime.sunday:
        return 'Domenica';
      default:
        return 'Giorno $weekday';
    }
  }

  static String _nomeGiornoBreve(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'LUN';
      case DateTime.tuesday:
        return 'MAR';
      case DateTime.wednesday:
        return 'MER';
      case DateTime.thursday:
        return 'GIO';
      case DateTime.friday:
        return 'VEN';
      case DateTime.saturday:
        return 'SAB';
      case DateTime.sunday:
        return 'DOM';
      default:
        return 'GG';
    }
  }
}

class _ParsedMenuLink {
  const _ParsedMenuLink({
    required this.url,
    required this.day,
    required this.month,
    required this.year,
    required this.weekday,
    required this.settimanaLabel,
  });

  final String url;
  final String day;
  final String month;
  final String year;
  final int weekday;
  final String settimanaLabel;
}

class MensaMenuGiorno {
  const MensaMenuGiorno({
    required this.weekday,
    required this.nomeGiorno,
    required this.nomeGiornoBreve,
    required this.giornoNumero,
    required this.meseNome,
    required this.anno,
    required this.settimanaLabel,
    this.pranzoPdfUrl,
    this.cenaPdfUrl,
  });

  final int weekday;
  final String nomeGiorno;
  final String nomeGiornoBreve;
  final String giornoNumero;
  final String meseNome;
  final String anno;
  final String settimanaLabel;
  final String? pranzoPdfUrl;
  final String? cenaPdfUrl;

  String get dataLabel => '$giornoNumero $meseNome $anno'.trim();
  String get dataBreve =>
      '$giornoNumero ${meseNome.length > 3 ? meseNome.substring(0, 3) : meseNome}'
          .trim();

  MensaMenuGiorno copyWith({String? pranzoPdfUrl, String? cenaPdfUrl}) {
    return MensaMenuGiorno(
      weekday: weekday,
      nomeGiorno: nomeGiorno,
      nomeGiornoBreve: nomeGiornoBreve,
      giornoNumero: giornoNumero,
      meseNome: meseNome,
      anno: anno,
      settimanaLabel: settimanaLabel,
      pranzoPdfUrl: pranzoPdfUrl ?? this.pranzoPdfUrl,
      cenaPdfUrl: cenaPdfUrl ?? this.cenaPdfUrl,
    );
  }
}

class _AdisurcActivation {
  const _AdisurcActivation({
    required this.url,
    required this.method,
    required this.token,
    required this.key,
  });

  final Uri url;
  final String method;
  final String token;
  final String key;
}

class AdisurcException implements Exception {
  final String message;
  AdisurcException(this.message);

  @override
  String toString() => message;
}


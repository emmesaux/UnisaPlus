import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/lezione.dart';
import '../models/preferenze_corso.dart';
import '../models/user.dart';
import 'api_service.dart';
import 'cineca_rest_service.dart';
import 'easycourse_combo_service.dart';

/// Gestisce login, logout e sessione corrente.
///
/// Ogni dispositivo può avere UNA sola sessione attiva alla volta. Se due
/// persone condividono il telefono, la seconda deve effettuare `logout()`
/// e poi `login()` con le proprie credenziali prima di poter firmare la
/// propria presenza o vedere il proprio orario: l'app non mantiene due
/// identità attive in parallelo.
class AuthService {
  AuthService(this.api);

  final ApiService api;
  final rest = CinecaRestService();
  final _storage = const FlutterSecureStorage();
  static const _kUserKey = 'current_user';

  AppUser? currentUser;

  /// Appelli d'esame reali per l'utente corrente. Richiede un login con
  /// carriera valida; in assenza propaga un errore invece di inventare.
  Future<List<EsameAgenda>> getAppelliReali() async {
    final user = currentUser;
    if (user == null || !user.haCarriera) {
      throw CinecaRestException('Carriera non disponibile per questo account.');
    }
    return rest.getAppelli(
      authHeader: user.token,
      stuId: user.stuId,
      matId: user.matId,
    );
  }

  /// Libretto e statistiche reali per l'utente corrente.
  Future<LibrettoDati> getLibrettoReale() async {
    final user = currentUser;
    if (user == null || !user.haCarriera) {
      throw CinecaRestException('Carriera non disponibile per questo account.');
    }
    return rest.getLibretto(
      authHeader: user.token,
      stuId: user.stuId,
      matId: user.matId,
    );
  }

  /// Tasse universitarie reali per l'utente corrente.
  Future<List<TassaFattura>> getTasseReali() async {
    final user = currentUser;
    if (user == null || user.stuId.isEmpty) {
      throw CinecaRestException('Profilo studente non disponibile.');
    }
    return rest.getTasse(
      authHeader: user.token,
      stuId: user.stuId,
    );
  }

  /// Bacheca esiti reale per l'utente corrente.
  Future<List<EsitoBacheca>> getBachecaEsitiReali() async {
    final user = currentUser;
    if (user == null || (!user.haCarriera && user.stuId.isEmpty)) {
      throw CinecaRestException('Carriera non disponibile per questo account.');
    }
    return rest.getBachecaEsiti(
      authHeader: user.token,
      matId: user.matId,
      stuId: user.stuId,
    );
  }

  /// Accetta o rifiuta un esito in bacheca per l'utente corrente.
  Future<EsitoBacheca> modificaEsitoBachecaReale({
    required EsitoBacheca esito,
    required bool accetta,
  }) async {
    final user = currentUser;
    if (user == null || (!user.haCarriera && user.stuId.isEmpty)) {
      throw CinecaRestException('Carriera non disponibile per questo account.');
    }
    return rest.modificaEsitoBacheca(
      authHeader: user.token,
      matId: user.matId.isNotEmpty ? user.matId : user.stuId,
      esitoCorrente: esito,
      accetta: accetta,
    );
  }

  /// Completa il login dopo che l'Identity Provider CINECA (SPID, CIE o
  /// credenziali UNISA, scelte dentro la sua pagina) ha verificato
  /// l'utente e restituito il profilo. L'app non mostra mai un form di
  /// password: [profiloJson] arriva già pronto da
  /// `CinecaLoginService.fetchProfilo`.
  Future<AppUser> completaLoginCineca(Map<String, dynamic> profiloJson) async {
    final user = AppUser.fromJson(profiloJson);
    _applicaAllaApi(user);
    currentUser = user;
    await _storage.write(key: _kUserKey, value: jsonEncode(user.toJson()));
    await _caricaPreferenzeCorso(user);
    return user;
  }

  void _applicaAllaApi(AppUser user) {
    api.token = user.token;
    api.corsoCodice = user.corsoCodice;
    api.matricola = user.matricola;
    api.classId = user.classId;
    api.classDes = user.classDes;
    api.cognome = user.cognome;
  }

  Future<AppUser?> restoreSession() async {
    // Timeout di sicurezza: su alcune piattaforme/ambienti (es. test senza
    // canale nativo) la lettura dello storage sicuro può non rispondere
    // mai. In quel caso si ricomincia dalla schermata di accesso invece
    // di restare bloccati sulla schermata di avvio per sempre.
    final raw = await _storage
        .read(key: _kUserKey)
        .timeout(const Duration(seconds: 5), onTimeout: () => null);
    if (raw == null) return null;
    final user = AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    _applicaAllaApi(user);
    currentUser = user;
    await _caricaPreferenzeCorso(user);
    return user;
  }

  // --- Corso e anno per l'orario -------------------------------------
  //
  // Come nell'app campus, si chiedono al primo accesso e si cambiano dalle
  // impostazioni. Salvati per utente (chiave con la matricola), così un
  // nuovo login dello stesso studente non li richiede.

  /// Scelta corrente; le schermate (es. orario) la ascoltano per ricaricare.
  final preferenzeCorso = ValueNotifier<PreferenzeCorso?>(null);

  String _kPrefKey(AppUser user) {
    final id = user.matricola.isNotEmpty ? user.matricola : user.stuId;
    return 'preferenze_corso_$id';
  }

  /// true se va mostrata la scelta di corso/anno: mai fatta, oppure fatta
  /// per un anno accademico precedente (i valori del combo cambiano).
  bool get serveSceltaCorso {
    final p = preferenzeCorso.value;
    if (p == null) return true;
    return p.aa != EasyCourseComboService.annoAccademico(DateTime.now());
  }

  Future<void> _caricaPreferenzeCorso(AppUser user) async {
    PreferenzeCorso? p;
    try {
      final raw = await _storage
          .read(key: _kPrefKey(user))
          .timeout(const Duration(seconds: 5), onTimeout: () => null);
      if (raw != null) {
        p = PreferenzeCorso.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      p = null;
    }
    _applicaPreferenze(p);
  }

  Future<void> salvaPreferenzeCorso(PreferenzeCorso p) async {
    final user = currentUser;
    if (user != null) {
      await _storage.write(key: _kPrefKey(user), value: jsonEncode(p.toJson()));
    }
    _applicaPreferenze(p);
  }

  void _applicaPreferenze(PreferenzeCorso? p) {
    api.corsoOrario = p?.corsoValore ?? '';
    api.anno2Orario = p?.annoValore ?? '';
    api.aaOrario = p?.aa;
    preferenzeCorso.value = p;
  }

  Future<void> logout() async {
    currentUser = null;
    api.token = null;
    api.corsoCodice = '';
    api.matricola = '';
    api.classId = '';
    api.classDes = '';
    api.cognome = '';
    // Le preferenze restano salvate per utente: si azzera solo lo stato
    // in memoria.
    _applicaPreferenze(null);
    await _storage.delete(key: _kUserKey);
  }
}

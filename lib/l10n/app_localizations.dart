import 'package:flutter/material.dart';
import '../services/settings_service.dart';

/// Sistema di localizzazione bilingue (Italiano / Inglese).
///
/// Permette il cambio dinamico della lingua nell'intera app e rispetta sia
/// la lingua di sistema sia la scelta manuale dell'utente.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  bool get isEnglish => locale.languageCode == 'en';

  static AppLocalizations of(BuildContext context) {
    final forced = SettingsService.instance.locale;
    if (forced != null) {
      return AppLocalizations(forced);
    }
    final deviceLocale = Localizations.maybeLocaleOf(context);
    final code = deviceLocale?.languageCode ?? 'it';
    return AppLocalizations(code == 'en' ? const Locale('en') : const Locale('it'));
  }

  // --- Navigazione & Titoli principali ---
  String get navOrario => isEnglish ? 'Timetable' : 'Orario';
  String get navAule => isEnglish ? 'Rooms' : 'Aule';
  String get navBadge => 'Badge';
  String get navAltro => isEnglish ? 'More' : 'Altro';

  String get titleOrario => isEnglish ? 'My Schedule' : 'Il mio orario';
  String get titleAule => isEnglish ? 'Available Rooms' : 'Aule libere';
  String get titleBadge => isEnglish ? 'Badge & Attendance' : 'Badge e presenze';
  String get titleAltro => isEnglish ? 'More' : 'Altro';

  String get logout => isEnglish ? 'Log out' : 'Esci';

  // --- Schermata Altro: Sezioni ---
  String get secCarriera => isEnglish ? 'Career & Studies' : 'Carriera & Didattica';
  String get secCampus => isEnglish ? 'Campus & Services' : 'Campus & Servizi';
  String get secImpostazioni => isEnglish ? 'Settings' : 'Impostazioni';

  // --- Voci Carriera ---
  String get librettoTitolo => isEnglish ? 'Transcript & Degree projection' : 'Libretto e previsione laurea';
  String get librettoSub => isEnglish
      ? 'Passed exams, GPA, ECTS and degree grade simulator'
      : 'Esami sostenuti, medie, CFU e simulatore voto di laurea';
  String get librettoAppBar => isEnglish ? 'Transcript & Degree' : 'Libretto e laurea';

  String get pianoStudiTitolo => isEnglish ? 'Study plan' : 'Piano di studi';
  String get pianoStudiSub => isEnglish
      ? 'Courses by year, completed and remaining credits'
      : 'Insegnamenti per anno di corso, CFU conseguiti e da sostenere';

  String get bachecaEsitiTitolo => isEnglish ? 'Exam results noticeboard' : 'Bacheca esiti';
  String get bachecaEsitiSub => isEnglish
      ? 'Published grades, review, accept or reject results'
      : 'Esiti pubblicati, presa visione, accetta o rifiuta voto';

  String get agendaEsamiTitolo => isEnglish ? 'Exam sessions' : 'Agenda esami';
  String get agendaEsamiSub => isEnglish
      ? 'Booked exams and available sessions'
      : 'Esami prenotati e appelli disponibili';

  String get tasseTitolo => isEnglish ? 'Tuition fees' : 'Tasse';
  String get tasseSub => isEnglish
      ? 'University fees, deadlines, payment status and PagoPA'
      : 'Contributi universitari, scadenze, stato pagamenti e IUV';
  String get tasseAppBar => isEnglish ? 'Tuition fees' : 'Tasse universitarie';

  // --- Voci Campus ---
  String get mappaTitolo => isEnglish ? 'Campus Map' : 'Mappa dei Campus';
  String get mappaSub => isEnglish
      ? 'Fisciano & Baronissi: buildings, rooms, libraries and buses'
      : 'Fisciano e Baronissi: edifici, aule, biblioteche, CUS e bus';

  String get serviziTitolo => isEnglish ? 'Useful services & links' : 'Servizi e collegamenti utili';
  String get serviziSub => isEnglish
      ? 'University libraries, ADISURC, CUS Salerno, Esse3 and CLA'
      : 'Biblioteche di Ateneo, ADISURC, CUS Salerno, Esse3 e CLA';

  String get mensaTitolo => isEnglish ? 'ADISURC Canteen' : 'Mensa ADISURC';
  String get mensaSub => isEnglish
      ? 'Dynamic QR access code and wallet balance'
      : 'QR dinamico di accesso e saldo borsellino';

  String get messaggiTitolo => isEnglish ? 'Messages' : 'Messaggi';
  String get messaggiSub => isEnglish
      ? 'University and Department announcements'
      : 'Avvisi di Ateneo e del tuo Dipartimento';

  // --- Voci Impostazioni ---
  String get corsoAnnoTitolo => isEnglish ? 'Course & year' : 'Corso e anno';
  String get corsoAnnoNonImpostato => isEnglish
      ? 'Not set: choose to see timetable'
      : 'Non impostati: scegli per vedere l’orario';

  String get temaTitolo => isEnglish ? 'App theme' : 'Tema dell’app';
  String get temaSubSistema => isEnglish ? 'Follow system settings' : 'Segui impostazioni di sistema';
  String get temaSubChiaro => isEnglish ? 'Light theme' : 'Tema chiaro';
  String get temaSubScuro => isEnglish ? 'Dark theme' : 'Tema scuro';
  String get temaDialogTitle => isEnglish ? 'Choose theme' : 'Scegli il tema';
  String get temaOpzioneSistema => isEnglish ? 'System' : 'Sistema';
  String get temaOpzioneChiaro => isEnglish ? 'Light' : 'Chiaro';
  String get temaOpzioneScuro => isEnglish ? 'Dark' : 'Scuro';

  String get linguaTitolo => isEnglish ? 'Language' : 'Lingua';
  String get linguaSubSistema => isEnglish ? 'System default' : 'Predefinita di sistema';
  String get linguaSubIt => 'Italiano';
  String get linguaSubEn => 'English';
  String get linguaDialogTitle => isEnglish ? 'Choose language' : 'Scegli la lingua';
  String get linguaOpzioneSistema => isEnglish ? 'System default' : 'Predefinita di sistema';
  String get linguaOpzioneIt => 'Italiano';
  String get linguaOpzioneEn => 'English';

  // --- Schermata Iniziale / SPID CIE Entry ---
  String get welcomeTo => isEnglish ? 'Welcome to' : 'Bentornato in';
  String get loginSubtitle => isEnglish
      ? 'Log in with SPID or CIE to see your timetable, exams, fees, canteen and attendance.'
      : 'Accedi con SPID o CIE per vedere orario, libretto, esami, tasse, mensa e la tua presenza.';
  String get loginWithSpid => isEnglish ? 'Log in with SPID' : 'Accedi con SPID';
  String get loginWithCie => isEnglish ? 'Log in with CIE' : 'Accedi con CIE';
  String get orBrowseFreely => isEnglish ? 'Or browse freely' : 'Oppure consulta liberamente';
  String get freeRoomsNow => isEnglish ? 'Available rooms right now' : 'Aule libere adesso';
  String get freeRoomsNowSub => isEnglish
      ? 'Quickly find a study space or empty classroom in Fisciano or Baronissi'
      : 'Trova subito un posto studio o un’aula libera a Fisciano o Baronissi';
  String get campusMap => isEnglish ? 'Campus map' : 'Mappa del campus';
  String get campusMapSub => isEnglish
      ? 'Buildings, classrooms, libraries and services at Fisciano & Baronissi'
      : 'Edifici, aule, biblioteche e servizi di Fisciano e Baronissi';
  String get checkInWithoutLogin => isEnglish ? 'Attendance check-in without login' : 'Rileva presenza senza login';
  String get checkInWithoutLoginSub => isEnglish
      ? 'Enter your student ID and scan the lecture QR code'
      : 'Inserisci la tua matricola e inquadra il QR lezione proiettato in aula';
  String get usefulServices => isEnglish ? 'Useful services & links' : 'Servizi e collegamenti utili';
  String get usefulServicesSub => isEnglish
      ? 'Libraries, Esse3, CUS, ADISURC and university contacts'
      : 'Biblioteche, Esse3, CUS, ADISURC e contatti di Ateneo';
  String get demoMode => isEnglish ? 'Demo mode (App Store review)' : 'Modalità demo (per revisione Store)';
  String get demoModeSub => isEnglish
      ? 'Simulate a full session with sample student data'
      : 'Simula una sessione completa con dati di test';

  // --- Tooltips & Pulsanti generici ---
  String get toggleThemeTooltip => isEnglish ? 'Toggle light / dark mode' : 'Cambia tema (chiaro/scuro)';
  String get toggleLanguageTooltip => isEnglish ? 'Change language' : 'Cambia lingua';
  String get annulla => isEnglish ? 'Cancel' : 'Annulla';
  String get chiudi => isEnglish ? 'Close' : 'Chiudi';
  String get salva => isEnglish ? 'Save' : 'Salva';
  String get nuovoBadge => isEnglish ? 'New' : 'Nuovo';
}

extension LocalizationExtension on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}


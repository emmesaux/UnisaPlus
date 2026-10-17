/// Rappresenta l'utente autenticato con le proprie credenziali personali.
/// Ogni utente ha il proprio account: non esiste un "account condiviso"
/// usato da più persone sullo stesso dispositivo.
///
/// `stuId`/`matId` sono gli identificativi di carriera restituiti dal
/// profilo CINECA (`/app/init`, campo `careers`): servono per comporre i
/// percorsi REST reali dell'ateneo (es. libretto, appelli), esattamente
/// come fa l'app campus. `token` è l'header `Basic ...` ottenuto al login.
class AppUser {
  final String matricola;
  final String nome;
  final String cognome;
  final String email;
  final String token;
  final String userType; // "Studente" oppure "Docente"
  final String stuId;
  final String matId;
  final String corsoCodice;
  final String classId;
  final String classDes;

  AppUser({
    required this.matricola,
    required this.nome,
    required this.cognome,
    required this.email,
    required this.token,
    required this.userType,
    this.stuId = '',
    this.matId = '',
    this.corsoCodice = '',
    this.classId = '',
    this.classDes = '',
  });

  String get nomeCompleto => '$nome $cognome';

  /// true quando abbiamo gli identificativi di carriera per interrogare le
  /// API REST dell'ateneo.
  bool get haCarriera => stuId.isNotEmpty && matId.isNotEmpty;

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      matricola: json['matricola'] as String? ?? '',
      nome: json['nome'] as String? ?? '',
      cognome: json['cognome'] as String? ?? '',
      email: json['email'] as String? ?? '',
      token: json['token'] as String? ?? '',
      userType: json['userType'] as String? ?? 'Studente',
      stuId: json['stuId'] as String? ?? '',
      matId: json['matId'] as String? ?? '',
      corsoCodice: json['corsoCodice'] as String? ?? '',
      classId: json['classId'] as String? ?? '',
      classDes: json['classDes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'matricola': matricola,
    'nome': nome,
    'cognome': cognome,
    'email': email,
    'token': token,
    'userType': userType,
    'stuId': stuId,
    'matId': matId,
    'corsoCodice': corsoCodice,
    'classId': classId,
    'classDes': classDes,
  };
}

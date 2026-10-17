/// Corso e anno scelti dallo studente nel combo pubblico di EasyCourse
/// (`AgendaStudenti/combo.php`). Come fa l'app campus, si chiedono al
/// primo accesso e si modificano dalle impostazioni: il profilo CINECA non
/// li espone in modo affidabile.
///
/// I valori sono quelli del combo, da passare così come sono a
/// `grid_call.php`: [corsoValore] → `corso`, [annoValore] → `anno2`
/// (es. `PDS0-2026-A-C|1`, che contiene anche coorte e partizione).
/// Il combo cambia a ogni anno accademico ([aa]): quando l'anno cambia la
/// scelta va rifatta, perché i `valore` degli anni non sono più validi.
class PreferenzeCorso {
  const PreferenzeCorso({
    required this.aa,
    required this.corsoValore,
    required this.corsoLabel,
    required this.annoValore,
    required this.annoLabel,
    this.facoltaCode = '',
  });

  final int aa;
  final String corsoValore;
  final String corsoLabel;
  final String annoValore;
  final String annoLabel;
  final String facoltaCode;

  /// Anno di corso (1, 2, 3…), il numero dopo `|` nel valore del combo.
  String get annoDiCorso =>
      annoValore.contains('|') ? annoValore.split('|').last : '';

  factory PreferenzeCorso.fromJson(Map<String, dynamic> json) =>
      PreferenzeCorso(
        aa: (json['aa'] as num?)?.toInt() ?? 0,
        corsoValore: json['corsoValore'] as String? ?? '',
        corsoLabel: json['corsoLabel'] as String? ?? '',
        annoValore: json['annoValore'] as String? ?? '',
        annoLabel: json['annoLabel'] as String? ?? '',
        facoltaCode: json['facoltaCode'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
    'aa': aa,
    'corsoValore': corsoValore,
    'corsoLabel': corsoLabel,
    'annoValore': annoValore,
    'annoLabel': annoLabel,
    'facoltaCode': facoltaCode,
  };
}


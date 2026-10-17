/// ESERCIZIO: selettore di carriera multi-matricola.
///
/// Contesto reale: alcuni studenti hanno PIÙ matricole sotto lo STESSO
/// account personale (es. doppia iscrizione, cambio corso, laurea +
/// magistrale in contemporanea). Nell'app originale questo arriva dal
/// campo `multiple_matricole` del JWT di login. Qui lo riproduciamo in
/// forma isolata e testabile.
///
/// Importante — questo esercizio NON riguarda l'uso dell'app da parte di
/// più persone: `Carriera` appartiene sempre a un solo `AppUser` già
/// autenticato con le sue credenziali. Non aggiungere qui nulla che
/// permetta di agire per conto di un altro account.
///
/// COSA DEVI FARE
/// Implementa `CarrieraSwitcher` sotto, senza cambiare le firme pubbliche
/// (i test in test/carriera_switcher_exercise_test.dart si aspettano
/// esattamente questi nomi e comportamenti). Rimuovi i `throw
/// UnimplementedError(...)` sostituendoli con codice funzionante.
///
/// REGOLE DA RISPETTARE
/// 1. Se la lista `carriere` è vuota, il costruttore deve lanciare
///    `ArgumentError`.
/// 2. All'avvio la carriera attiva è la prima della lista.
/// 3. `selezionaCarriera(matricola)` cambia la carriera attiva SOLO se
///    quella matricola esiste nella lista; altrimenti lancia
///    `ArgumentError` e NON cambia nulla.
/// 4. `carriereAltre` restituisce tutte le carriere tranne quella attiva,
///    nello stesso ordine della lista originale.
/// 5. Non è ammessa logica che fonde o mescola dati di due matricole in
///    un'unica richiesta: ogni operazione successiva (orario, esami,
///    prenotazioni) deve riferirsi a UNA sola matricola per volta — quella
///    attiva. (Non serve codice qui per questa regola: è un vincolo di
///    design da tenere a mente se poi collegherai questa classe alle
///    schermate esistenti.)
library;

class Carriera {
  final String matricola;
  final String corsoDiStudio;

  const Carriera({required this.matricola, required this.corsoDiStudio});

  @override
  String toString() => 'Carriera($matricola, $corsoDiStudio)';

  @override
  bool operator ==(Object other) =>
      other is Carriera && other.matricola == matricola && other.corsoDiStudio == corsoDiStudio;

  @override
  int get hashCode => Object.hash(matricola, corsoDiStudio);
}

class CarrieraSwitcher {
  CarrieraSwitcher(List<Carriera> carriere) {
    throw UnimplementedError('TODO: valida e memorizza `carriere`, imposta la carriera attiva iniziale');
  }

  /// Tutte le carriere, nell'ordine originale passato al costruttore.
  List<Carriera> get carriere => throw UnimplementedError('TODO');

  /// La carriera attualmente selezionata.
  Carriera get carrieraAttiva => throw UnimplementedError('TODO');

  /// Tutte le carriere tranne quella attiva, stesso ordine originale.
  List<Carriera> get carriereAltre => throw UnimplementedError('TODO');

  /// Cambia la carriera attiva. Lancia `ArgumentError` se `matricola`
  /// non corrisponde a nessuna carriera nella lista.
  void selezionaCarriera(String matricola) {
    throw UnimplementedError('TODO');
  }
}

import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Dati carta mensa restituiti dal server ADiSURC (dentro il payload JWT
/// di `loginQR`): id carta, segreto base32 e intervallo di rotazione del
/// codice. Sono gli stessi campi che usa l'app campus
/// (`public.cardid`, `public.cardsecret`, `public.cardinterval`).
class MensaCard {
  final String cardId;
  final String cardSecret;
  final int cardInterval;
  final DateTime? scadenza;

  MensaCard({
    required this.cardId,
    required this.cardSecret,
    required this.cardInterval,
    this.scadenza,
  });

  factory MensaCard.fromPayload(Map<String, dynamic> payload) {
    final pub = payload['public'];
    final map = pub is Map ? pub : payload;
    final interval = int.tryParse(map['cardinterval']?.toString() ?? '') ?? 30;
    DateTime? exp;
    final expRaw = payload['exp']?.toString();
    if (expRaw != null) {
      final secs = int.tryParse(expRaw);
      if (secs != null) exp = DateTime.fromMillisecondsSinceEpoch(secs * 1000);
    }
    return MensaCard(
      cardId: map['cardid']?.toString() ?? '',
      cardSecret: map['cardsecret']?.toString() ?? '',
      cardInterval: interval <= 0 ? 30 : interval,
      scadenza: exp,
    );
  }

  bool get valida => cardId.isNotEmpty && cardSecret.isNotEmpty;
}

/// Genera il QR mensa reale: un codice TOTP a tempo derivato dal segreto
/// della carta, con lo stesso algoritmo dell'app campus (base32 + HMAC
/// SHA-1, 6 cifre, periodo = cardinterval). Il contenuto del QR NON è
/// `MENSA:matricola` (una stringa inventata che nessun lettore accetta):
/// e' il codice rotante che il tornello della mensa verifica.
///
/// Nota: la carta (segreto incluso) arriva solo dopo l'associazione
/// ADiSURC. Senza quella non si genera alcun QR, invece di mostrarne uno
/// falso.
class MensaQrService {
  static const _base32Alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';

  /// Codice TOTP corrente (6 cifre) per la carta data.
  String codiceTotp(MensaCard card, {DateTime? ora}) {
    final now = ora ?? DateTime.now();
    final counter = now.millisecondsSinceEpoch ~/ 1000 ~/ card.cardInterval;
    final key = _base32Decode(card.cardSecret);
    return _totp(key, counter);
  }

  /// Contenuto da codificare nel QR: id carta e codice corrente. Il
  /// tornello identifica la carta da `cardId` e verifica il TOTP.
  String contenutoQr(MensaCard card, {DateTime? ora}) {
    final code = codiceTotp(card, ora: ora);
    return '${card.cardId}:$code';
  }

  /// Secondi mancanti alla prossima rotazione del codice: utile per il
  /// contatore visivo.
  int secondiAllaRotazione(MensaCard card, {DateTime? ora}) {
    final now = ora ?? DateTime.now();
    final sec = now.millisecondsSinceEpoch ~/ 1000;
    return card.cardInterval - (sec % card.cardInterval);
  }

  String _totp(Uint8List key, int counter) {
    final msg = Uint8List(8);
    var c = counter;
    for (var i = 7; i >= 0; i--) {
      msg[i] = c & 0xff;
      c >>= 8;
    }
    final hmac = Hmac(sha1, key).convert(msg).bytes;
    final offset = hmac[hmac.length - 1] & 0x0f;
    final binary = ((hmac[offset] & 0x7f) << 24) |
        ((hmac[offset + 1] & 0xff) << 16) |
        ((hmac[offset + 2] & 0xff) << 8) |
        (hmac[offset + 3] & 0xff);
    final otp = binary % 1000000;
    return otp.toString().padLeft(6, '0');
  }

  /// Decodifica base32 (RFC 4648), stesso alfabeto di campus. Ignora il
  /// padding '=' finale.
  Uint8List _base32Decode(String input) {
    final clean = input.replaceAll('=', '').toUpperCase();
    final out = <int>[];
    var buffer = 0;
    var bits = 0;
    for (final ch in clean.split('')) {
      final val = _base32Alphabet.indexOf(ch);
      if (val < 0) continue;
      buffer = (buffer << 5) | val;
      bits += 5;
      if (bits >= 8) {
        bits -= 8;
        out.add((buffer >> bits) & 0xff);
      }
    }
    return Uint8List.fromList(out);
  }
}

import 'package:http/http.dart' as http;

/// Avviso / notizia estratta dal portale di Ateneo (`web.unisa.it`) o dal
/// sito del Dipartimento UNISA dello studente.
class AvvisoUnisa {
  const AvvisoUnisa({
    required this.titolo,
    required this.categoria,
    required this.sottotitolo,
    required this.url,
    this.dataLabel = '',
  });

  final String titolo;
  final String categoria;
  final String sottotitolo;
  final String url;
  final String dataLabel;
}

/// Dipartimento dell'Università degli Studi di Salerno, associato al
/// `facolta_code` di EasyCourse (`combo.php`).
class DipartimentoUnisa {
  const DipartimentoUnisa({
    required this.codice,
    required this.sigla,
    required this.nome,
    required this.baseUrl,
  });

  /// `facolta_code` usato in `combo.php` (es. `DI`, `ING_INF`, `DIPMEDCHI`).
  final String codice;
  final String sigla;
  final String nome;
  final String baseUrl;
}

class UnisaNewsService {
  static const _timeout = Duration(seconds: 12);
  static const ateneoUrl = 'https://web.unisa.it';

  /// Tutti i 17 Dipartimenti UNISA con i rispettivi codici `facolta_code`
  /// di EasyCourse e gli URL ufficiali di dipartimento.
  static const List<DipartimentoUnisa> dipartimenti = [
    DipartimentoUnisa(
      codice: 'DI',
      sigla: 'DI',
      nome: 'Informatica',
      baseUrl: 'https://www.di.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'ING_INF',
      sigla: 'DIEM',
      nome: 'Ingegneria dell’Informazione ed Elettrica e Matematica Applicata',
      baseUrl: 'https://www.diem.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'ING_IND',
      sigla: 'DIIN',
      nome: 'Ingegneria Industriale',
      baseUrl: 'https://www.diin.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'ING_CIV',
      sigla: 'DICIV',
      nome: 'Ingegneria Civile',
      baseUrl: 'https://www.diciv.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DCB',
      sigla: 'DCB',
      nome: 'Chimica e Biologia "A. Zambelli"',
      baseUrl: 'https://www.dcb.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'FA_FAR',
      sigla: 'DIFARMA',
      nome: 'Farmacia',
      baseUrl: 'https://www.difarma.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DF',
      sigla: 'DF',
      nome: 'Fisica "E. R. Caianiello"',
      baseUrl: 'https://www.df.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DIPMAT',
      sigla: 'DIPMAT',
      nome: 'Matematica',
      baseUrl: 'https://www.dipmat.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DIPMEDCHI',
      sigla: 'DIPMED',
      nome: 'Medicina, Chirurgia e Odontoiatria "Scuola Medica Salernitana"',
      baseUrl: 'https://www.dipmed.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISA-MIS',
      sigla: 'DISA-MIS',
      nome: 'Scienze Aziendali - Management & Innovation Systems',
      baseUrl: 'https://www.disa.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISES',
      sigla: 'DISES',
      nome: 'Scienze Economiche e Statistiche',
      baseUrl: 'https://www.dises.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'FA_GIU',
      sigla: 'DSG',
      nome: 'Scienze Giuridiche (Scuola di Giurisprudenza)',
      baseUrl: 'https://www.dsg.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISPAC',
      sigla: 'DISPAC',
      nome: 'Scienze del Patrimonio Culturale',
      baseUrl: 'https://www.dispac.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISPC',
      sigla: 'DISPC',
      nome: 'Scienze Politiche e della Comunicazione',
      baseUrl: 'https://www.dispc.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISPS',
      sigla: 'DISPS',
      nome: 'Studi Politici e Sociali',
      baseUrl: 'https://www.disps.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'DISUFF',
      sigla: 'DISUFF',
      nome: 'Scienze Umane, Filosofiche e della Formazione',
      baseUrl: 'https://www.disuff.unisa.it',
    ),
    DipartimentoUnisa(
      codice: 'FA_UMA',
      sigla: 'DIPSUM',
      nome: 'Studi Umanistici',
      baseUrl: 'https://www.dipsum.unisa.it',
    ),
  ];

  /// Individua il dipartimento a partire dal `facoltaCode` del corso scelto,
  /// dal codice corso (`05121`...) o dal nome del corso.
  static DipartimentoUnisa? trovaDipartimento({
    String facoltaCode = '',
    String corsoValore = '',
    String corsoLabel = '',
  }) {
    final code = facoltaCode.trim().toUpperCase();
    if (code.isNotEmpty) {
      for (final d in dipartimenti) {
        if (d.codice == code || d.sigla == code) return d;
      }
    }

    // Fallback dai prefissi storici dei codici corso UNISA / parole chiave.
    final val = corsoValore.trim();
    if (val.startsWith('05121') || val.startsWith('05225')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DI');
    }
    final lbl = corsoLabel.toUpperCase();
    if (lbl.contains('INFORMATICA') && !lbl.contains('INGEGNERIA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DI');
    }
    if (lbl.contains('INGEGNERIA INFORMATICA') ||
        lbl.contains('INGEGNERIA ELETTRONICA') ||
        lbl.contains('INGEGNERIA DELL\'INFORMAZIONE')) {
      return dipartimenti.firstWhere((d) => d.codice == 'ING_INF');
    }
    if (lbl.contains('INGEGNERIA MECCANICA') ||
        lbl.contains('INGEGNERIA GESTIONALE') ||
        lbl.contains('INGEGNERIA CHIMICA') ||
        lbl.contains('INGEGNERIA INDUSTRIALE')) {
      return dipartimenti.firstWhere((d) => d.codice == 'ING_IND');
    }
    if (lbl.contains('INGEGNERIA CIVILE') || lbl.contains('EDIL')) {
      return dipartimenti.firstWhere((d) => d.codice == 'ING_CIV');
    }
    if (lbl.contains('FARMACIA') ||
        lbl.contains('CHIMICA E TECNOLOGIA FARMACEUTICHE') ||
        lbl.contains('ERBORIST')) {
      return dipartimenti.firstWhere((d) => d.codice == 'FA_FAR');
    }
    if (lbl.contains('MEDICINA') ||
        lbl.contains('ODONTOIATRIA') ||
        lbl.contains('INFERMIERISTICA') ||
        lbl.contains('OSTETRICIA') ||
        lbl.contains('FISIOTERAPIA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DIPMEDCHI');
    }
    if (lbl.contains('BIOLOGIA') || lbl.contains('CHIMICA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DCB');
    }
    if (lbl.contains('FISICA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DF');
    }
    if (lbl.contains('MATEMATICA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DIPMAT');
    }
    if (lbl.contains('GIURISPRUDENZA') || lbl.contains('GIURIDIC')) {
      return dipartimenti.firstWhere((d) => d.codice == 'FA_GIU');
    }
    if (lbl.contains('ECONOMIA') && lbl.contains('MANAGEMENT') ||
        lbl.contains('AZIENDAL')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DISA-MIS');
    }
    if (lbl.contains('ECONOMIA') || lbl.contains('STATISTIC')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DISES');
    }
    if (lbl.contains('COMUNICAZIONE') || lbl.contains('SCIENZE POLITICHE')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DISPC');
    }
    if (lbl.contains('BENI CULTURALI') || lbl.contains('ARCHEOLOGIA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DISPAC');
    }
    if (lbl.contains('FILOSOFIA') ||
        lbl.contains('FORMAZIONE') ||
        lbl.contains('EDUCAZIONE') ||
        lbl.contains('PEDAGOGIA')) {
      return dipartimenti.firstWhere((d) => d.codice == 'DISUFF');
    }
    if (lbl.contains('LETTERE') || lbl.contains('LINGUE')) {
      return dipartimenti.firstWhere((d) => d.codice == 'FA_UMA');
    }
    return null;
  }

  /// Scarica gli avvisi di Ateneo da `https://web.unisa.it/` (come fa Campus).
  Future<List<AvvisoUnisa>> getNewsAteneo() =>
      _fetchNewsFromSite(ateneoUrl, linkBase: 'https://www.unisa.it');

  /// Scarica gli avvisi dal sito del Dipartimento selezionato.
  Future<List<AvvisoUnisa>> getNewsDipartimento(DipartimentoUnisa dip) =>
      _fetchNewsFromSite(dip.baseUrl, linkBase: dip.baseUrl);

  Future<List<AvvisoUnisa>> _fetchNewsFromSite(
    String pageUrl, {
    required String linkBase,
  }) async {
    final resp = await http.get(Uri.parse(pageUrl)).timeout(_timeout);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('Impossibile caricare gli avvisi (${resp.statusCode}).');
    }
    return _parseHtmlNews(resp.body, linkBase: linkBase);
  }

  List<AvvisoUnisa> _parseHtmlNews(String html, {required String linkBase}) {
    final out = <AvvisoUnisa>[];
    final visti = <String>{};

    // Ogni avviso in UNISA Rescue CMS si trova in un `<li>...<div class="info">...</div></li>`.
    final liPattern = RegExp(
      r'<li[^>]*>(.*?)</li>',
      caseSensitive: false,
      dotAll: true,
    );

    for (final match in liPattern.allMatches(html)) {
      final liHtml = match.group(1) ?? '';
      if (!liHtml.contains('class="info"') &&
          !liHtml.contains("class='info'")) {
        continue;
      }

      final infoIndex = liHtml.indexOf('class="info"');
      final infoHtml = infoIndex >= 0 ? liHtml.substring(infoIndex) : liHtml;

      // Titolo + link (dentro <h3><a ...> o <h4><a ...>).
      final titleMatch = RegExp(
        r'<h[34][^>]*>\s*<a[^>]*href=["\x27]([^"\x27]+)["\x27][^>]*>(.*?)</a>\s*</h[34]>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(infoHtml);
      if (titleMatch == null) continue;

      final rawHref = _cleanHtmlText(titleMatch.group(1) ?? '');
      final titolo = _cleanHtmlText(titleMatch.group(2) ?? '');
      if (titolo.isEmpty || rawHref.isEmpty) continue;

      final fullUrl = rawHref.startsWith('http')
          ? rawHref
          : '$linkBase${rawHref.startsWith('/') ? '' : '/'}$rawHref';
      if (!visti.add(fullUrl)) continue;

      // Categoria (es. "Didattica", "Ateneo", "Seminari e Convegni").
      final catMatch =
          RegExp(
            r'<p[^>]*categoria[^>]*>.*?<small>(.*?)</small>',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(infoHtml) ??
          RegExp(
            r'<span[^>]*categoryover[^>]*>(.*?)</span>',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(liHtml);
      final categoria = _cleanHtmlText(catMatch?.group(1) ?? 'Avviso');

      // Sottotitolo / descrizione (l'ultimo <p> dentro .info che non sia .categoria).
      String sottotitolo = '';
      final afterHeading = infoHtml.substring(titleMatch.end);
      final pMatch = RegExp(
        r'<p[^>]*>(.*?)</p>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(afterHeading);
      if (pMatch != null) {
        sottotitolo = _cleanHtmlText(pMatch.group(1) ?? '');
      }

      // Eventuale data (<time ...><span class="day">21</span><span class="month">Ottobre</span>)
      String dataLabel = '';
      final dayMatch = RegExp(
        r'<span[^>]*class=["\x27]day["\x27][^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(liHtml);
      final monthMatch = RegExp(
        r'<span[^>]*class=["\x27]month["\x27][^>]*>(.*?)</span>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(liHtml);
      if (dayMatch != null && monthMatch != null) {
        final d = _cleanHtmlText(dayMatch.group(1) ?? '');
        final m = _cleanHtmlText(monthMatch.group(1) ?? '');
        if (d.isNotEmpty && m.isNotEmpty) {
          final mShort = m.length > 3 ? m.substring(0, 3) : m;
          dataLabel = '$d $mShort';
        }
      }

      out.add(
        AvvisoUnisa(
          titolo: titolo,
          categoria: categoria.isEmpty ? 'Avviso' : categoria,
          sottotitolo: sottotitolo,
          url: fullUrl,
          dataLabel: dataLabel,
        ),
      );
    }

    return out;
  }

  /// Scarica il testo completo dell'avviso dalla pagina di dettaglio UNISA.
  Future<String> getDettaglioAvviso(String url) async {
    try {
      final resp = await http.get(Uri.parse(url)).timeout(_timeout);
      if (resp.statusCode < 200 || resp.statusCode >= 300) return '';
      final html = resp.body;

      // Il corpo dell'avviso su UNISA Rescue è dentro `#rescue-main` o `.panel-body` o `#unisa-content`.
      final bodyMatch =
          RegExp(
            r'<div[^>]*id=["\x27]rescue-main["\x27][^>]*>(.*?)<div[^>]*id=["\x27]unisa-left-menu["\x27]',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(html) ??
          RegExp(
            r'<div[^>]*class=["\x27][^"\x27]*panel-body[^"\x27]*["\x27][^>]*>(.*?)</div>',
            caseSensitive: false,
            dotAll: true,
          ).firstMatch(html);

      final snippet = bodyMatch?.group(1) ?? '';
      if (snippet.isEmpty) return '';

      final paragrafi = <String>[];
      for (final p in RegExp(
        r'<(?:p|li)[^>]*>(.*?)</(?:p|li)>',
        caseSensitive: false,
        dotAll: true,
      ).allMatches(snippet)) {
        final txt = _cleanHtmlText(p.group(1) ?? '');
        if (txt.length > 3 &&
            !txt.toLowerCase().startsWith('condividi') &&
            !txt.toLowerCase().startsWith('pubblicato il')) {
          paragrafi.add(txt);
        }
      }
      return paragrafi.join('\n\n');
    } catch (_) {
      return '';
    }
  }

  String _cleanHtmlText(String input) {
    if (input.isEmpty) return '';
    var s = input
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), ' ');
    const entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&quot;': '"',
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&lsquo;': '‘',
      '&rsquo;': '’',
      '&#039;': "'",
      '&#39;': "'",
      '&apos;': "'",
      '&ndash;': '–',
      '&mdash;': '—',
      '&agrave;': 'à',
      '&egrave;': 'è',
      '&eacute;': 'é',
      '&igrave;': 'ì',
      '&ograve;': 'ò',
      '&ugrave;': 'ù',
      '&Agrave;': 'À',
      '&Egrave;': 'È',
      '&Eacute;': 'É',
      '&Igrave;': 'Ì',
      '&Ograve;': 'Ò',
      '&Ugrave;': 'Ù',
      '&deg;': '°',
      '&euro;': '€',
      '&laquo;': '«',
      '&raquo;': '»',
    };
    entities.forEach((k, v) {
      s = s.replaceAll(k, v);
    });
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      return code != null ? String.fromCharCode(code) : '';
    });
    return s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
  }
}

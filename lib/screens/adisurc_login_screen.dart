import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';
import '../services/adisurc_service.dart';
import '../theme/app_theme.dart';

/// Login mensa ADiSURC. La pagina ufficiale è una SPA Vue: il suo HTML è
/// un template (`v-if=...`) che da solo mostra una pagina bianca. Per
/// questo si estraggono i link dei provider SPID/CIE dal contenuto e si
/// mostrano come pulsanti nativi; al tocco, la WebView apre l'SSO reale
/// del provider (pagina che si renderizza normalmente). A login completato
/// si legge la sessione dal sessionStorage, come fa l'app campus.
class AdisurcLoginScreen extends StatefulWidget {
  const AdisurcLoginScreen({super.key, required this.service, required this.onLoggedIn});

  final AdisurcService service;
  final ValueChanged<AdisurcLoginSession> onLoggedIn;

  @override
  State<AdisurcLoginScreen> createState() => _AdisurcLoginScreenState();
}

class _ProviderSpid {
  final String nome;
  final String url;
  _ProviderSpid(this.nome, this.url);
}

class _AdisurcLoginScreenState extends State<AdisurcLoginScreen> {
  static const _homeUrl =
      'https://adisurc-ol.dirittoallostudio.it/apps/V3.1/sol/public/index.php/load-page?p_code=Homepage&p_folder=homepage';

  WebViewController? _controller;
  List<_ProviderSpid> _providers = [];
  bool _loading = true;
  bool _mostraWebView = false;
  bool _completing = false;
  bool _checkingSession = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _caricaProviders();
  }

  Future<void> _caricaProviders() async {
    try {
      final resp = await http.get(Uri.parse(_homeUrl)).timeout(const Duration(seconds: 12));
      final json = jsonDecode(resp.body);
      final content = (json is Map && json['data'] is Map) ? (json['data'] as Map)['content']?.toString() : null;
      if (content == null || content.isEmpty) throw Exception('contenuto assente');
      final providers = _estraiProviders(content);
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _loading = false;
        if (providers.isEmpty) {
          _error = 'Nessun provider di accesso trovato. Riprova piu tardi.';
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossibile caricare l’accesso ADiSURC. Riprova.';
        });
      }
    }
  }

  /// Estrae i link SSO (cerbero) dei provider SPID/CIE dal contenuto HTML.
  List<_ProviderSpid> _estraiProviders(String html) {
    final out = <_ProviderSpid>[];
    final visti = <String>{};
    final re = RegExp(r'href="(https://cerbero\.dirittoallostudio\.it[^"]*?(?:initsso|sso)[^"]*)"', caseSensitive: false);
    for (final m in re.allMatches(html)) {
      final url = m.group(1)!.replaceAll('&amp;', '&');
      if (!visti.add(url)) continue;
      final idp = RegExp(r'IDP=([^"&]+)', caseSensitive: false).firstMatch(url)?.group(1) ?? '';
      out.add(_ProviderSpid(_nomeProvider(idp, url), url));
    }
    return out;
  }

  String _nomeProvider(String idp, String url) {
    final i = idp.toLowerCase();
    if (i.contains('cie')) return 'CIE - Carta d’Identita Elettronica';
    const nomi = {
      'arubaid': 'Aruba ID',
      'posteid': 'Poste ID',
      'infocertid': 'InfoCert ID',
      'sielteid': 'Sielte ID',
      'tim': 'TIM id',
      'namirialid': 'Namirial ID',
      'spiditalia': 'SpidItalia',
      'lepidaid': 'Lepida ID',
      'teamsystemid': 'TeamSystem ID',
      'intesaid': 'Intesa ID',
      'ehealthid': 'etnaHitech',
    };
    for (final e in nomi.entries) {
      if (i.contains(e.key)) return e.value;
    }
    if (url.toLowerCase().contains('/cie/')) return 'CIE - Carta d’Identita Elettronica';
    return idp.isEmpty ? 'Accedi' : idp;
  }

  void _apriProvider(_ProviderSpid p) {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _loading = false);
            await _readWebSession();
          },
        ),
      )
      ..loadRequest(Uri.parse(p.url));
    setState(() => _mostraWebView = true);
  }

  Future<void> _readWebSession() async {
    if (_completing || _checkingSession || _controller == null) return;
    _checkingSession = true;
    try {
      final tokens = await _estraiTokenDallaPagina();
      final accessToken = tokens['accessToken'];
      final flag0 = tokens['p_flag0'];
      if (accessToken == null ||
          accessToken.isEmpty ||
          flag0 == null ||
          flag0.isEmpty) {
        _checkingSession = false;
        // La pagina coi token è intermedia e può comparire dopo un
        // redirect: si riprova finché la schermata resta aperta.
        if (mounted && !_completing) {
          Future<void>.delayed(
            const Duration(milliseconds: 800),
            _readWebSession,
          );
        }
        return;
      }
      _completing = true;
      if (mounted) setState(() => _loading = true);
      final session = await widget.service.completaLoginWeb(
        accessToken: accessToken,
        flag0: flag0,
        accessTokenSRM: tokens['accessTokenSRM'],
        sidSRM: tokens['sidSRM'],
      );
      if (mounted) widget.onLoggedIn(session);
    } catch (_) {
      _completing = false;
      _checkingSession = false;
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Login ADiSURC non riuscito. Riprova.';
        });
      }
    }
  }

  void _estraiSetItemDaHtml(String html, Map<String, String> mappa) {
    final patterns = [
      RegExp(
        r'''sessionStorage\.setItem\(\s*['"](.*?)['"]\s*,\s*"(.*?)"\s*\)''',
        dotAll: true,
      ),
      RegExp(
        r"""sessionStorage\.setItem\(\s*['"](.*?)['"]\s*,\s*'(.*?)'\s*\)""",
        dotAll: true,
      ),
    ];
    for (final p in patterns) {
      for (final m in p.allMatches(html)) {
        final k = m.group(1);
        final v = m.group(2);
        if (k != null && v != null && v.isNotEmpty) mappa[k] = v;
      }
    }
  }

  /// Estrae i token esattamente come fa Campus (`SelectSpidFragment`):
  /// 1) legge il `sessionStorage` vivo della WebView;
  /// 2) legge l'HTML della pagina e cerca `sessionStorage.setItem('...', '...')`;
  /// 3) se la WebView si trova sulla pagina intermedia SAML
  ///    `cerbero.dirittoallostudio.it/.../assertion/index.php`, intercetta
  ///    il `<form>` con `DATA` e `CHK` e invia la POST per ottenere i token.
  Future<Map<String, String>> _estraiTokenDallaPagina() async {
    final mappa = <String, String>{};

    // 1) sessionStorage vivo.
    try {
      final raw = await _controller!.runJavaScriptReturningResult('''
        (function() {
          var v = {};
          try { for (var i=0;i<sessionStorage.length;i++){var k=sessionStorage.key(i);v[k]=sessionStorage.getItem(k);} } catch(e){}
          return JSON.stringify(v);
        })()
      ''');
      var decoded = raw is String ? jsonDecode(raw) : null;
      if (decoded is String) decoded = jsonDecode(decoded);
      if (decoded is Map) {
        decoded.forEach((k, val) {
          if (val != null && val.toString().isNotEmpty) {
            mappa[k.toString()] = val.toString();
          }
        });
      }
    } catch (_) {}

    // 2) HTML della pagina → regex sulle setItem inline + eventuale form SAML DATA/CHK.
    try {
      final rawHtml = await _controller!.runJavaScriptReturningResult(
        'document.documentElement.outerHTML',
      );
      var html = rawHtml is String ? rawHtml : rawHtml.toString();
      if (html.startsWith('"')) {
        try {
          html = jsonDecode(html) as String;
        } catch (_) {}
      }
      _estraiSetItemDaHtml(html, mappa);

      // 3) Se siamo su assertion/index.php e non abbiamo ancora i token,
      // estraiamo action + DATA + CHK come fa SelectSpidFragment in Campus.
      final currentUrl = await _controller!.currentUrl() ?? '';
      if (mappa['accessToken'] == null &&
          currentUrl.contains('/assertion/index.php')) {
        final actionMatch = RegExp(
          r'<form[^>]*action=["\x27]([^"\x27]+)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        final dataMatch = RegExp(
          r'name=["\x27]DATA["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        final chkMatch = RegExp(
          r'name=["\x27]CHK["\x27][^>]*value=["\x27]([^"\x27]*)["\x27]',
          caseSensitive: false,
        ).firstMatch(html);
        final actionUrl = actionMatch?.group(1)?.replaceAll('&amp;', '&');
        final dataVal = dataMatch?.group(1);
        final chkVal = chkMatch?.group(1);
        if (actionUrl != null &&
            actionUrl.isNotEmpty &&
            dataVal != null &&
            chkVal != null) {
          final resp = await http
              .post(
                Uri.parse(actionUrl),
                headers: const {
                  'Content-Type': 'application/x-www-form-urlencoded',
                },
                body: {'DATA': dataVal, 'CHK': chkVal},
              )
              .timeout(const Duration(seconds: 12));
          if (resp.statusCode >= 200 && resp.statusCode < 300) {
            _estraiSetItemDaHtml(resp.body, mappa);
          }
        }
      }
    } catch (_) {}

    // Normalizza: trova le chiavi attese anche se con nome leggermente diverso.
    String? trova(List<String> candidati) {
      for (final c in candidati) {
        if (mappa[c] != null && mappa[c]!.isNotEmpty) return mappa[c];
      }
      for (final e in mappa.entries) {
        final key = e.key.toLowerCase();
        if (candidati.any((c) => key == c.toLowerCase()) &&
            e.value.isNotEmpty) {
          return e.value;
        }
      }
      return null;
    }

    final access = trova(['accessToken', 'access_token']);
    final flag = trova(['flag0', 'p_flag0']);
    final accessSrm = trova(['accessTokenSRM']);
    final sidSrm = trova(['sidSRM']);
    debugPrint('[ADISURC] url=${await _controller!.currentUrl()}');
    debugPrint(
      '[ADISURC] chiavi trovate=${mappa.keys.toList()} access=${access != null} flag=${flag != null}',
    );
    return {
      'accessToken': ?access,
      'p_flag0': ?flag,
      'accessTokenSRM': ?accessSrm,
      'sidSRM': ?sidSrm,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Login mensa ADiSURC')),
      body: Stack(
        children: [
          if (_mostraWebView && _controller != null)
            WebViewWidget(controller: _controller!)
          else
            _pickerProviders(context),
          if (_loading)
            LinearProgressIndicator(color: scheme.secondary, backgroundColor: scheme.surfaceContainerHighest),
          if (_error != null && !_mostraWebView)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_error!, style: TextStyle(color: scheme.error), textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pickerProviders(BuildContext context) {
    if (_loading && _providers.isEmpty) {
      return const SizedBox.shrink();
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('Accedi al servizio mensa', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          'Scegli il tuo gestore di identita SPID o la CIE. L’accesso avviene sul sito ufficiale ADiSURC.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        for (final p in _providers)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: () => _apriProvider(p),
              style: OutlinedButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.all(16)),
              child: Row(
                children: [
                  Icon(
                    p.nome.startsWith('CIE') ? Icons.credit_card : Icons.badge_outlined,
                    size: 20,
                    color: AppColors.mare,
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.nome)),
                  const Icon(Icons.chevron_right, size: 18),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

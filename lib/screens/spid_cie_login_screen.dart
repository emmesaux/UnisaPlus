import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/auth_service.dart';
import '../services/cineca_login_service.dart';
import '../theme/app_theme.dart';

/// Mantiene il login CINECA nella WebView come Campus. Gli schemi non web
/// richiesti dal provider, come quello dell'app CieID, vengono aperti fuori.
class SpidCieLoginScreen extends StatefulWidget {
  const SpidCieLoginScreen({
    super.key,
    required this.authService,
    required this.onLoggedIn,
  });

  final AuthService authService;
  final VoidCallback onLoggedIn;

  @override
  State<SpidCieLoginScreen> createState() => _SpidCieLoginScreenState();
}

class _SpidCieLoginScreenState extends State<SpidCieLoginScreen> {
  final _cineca = CinecaLoginService();
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _avvia();
  }

  Future<void> _avvia() async {
    try {
      final url = await _cineca.buildAuthorizeUrl();
      if (!mounted) return;
      setState(() {
        _controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            NavigationDelegate(
              onPageStarted: (_) {
                if (mounted) setState(() => _loading = true);
              },
              onPageFinished: (_) {
                if (mounted) setState(() => _loading = false);
              },
              onNavigationRequest: _onNavigationRequest,
            ),
          )
          ..loadRequest(Uri.parse(url));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            'Impossibile contattare il servizio di accesso dell’ateneo. Riprova.';
      });
    }
  }

  NavigationDecision _onNavigationRequest(NavigationRequest request) {
    if (_cineca.isAppHandback(request.url)) {
      _completaAccesso(request.url);
      return NavigationDecision.prevent;
    }
    final uri = Uri.tryParse(request.url);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
      return NavigationDecision.navigate;
    }
    if (uri != null) _apriAppCie(uri);
    return NavigationDecision.prevent;
  }

  Future<void> _apriAppCie(Uri uri) async {
    try {
      final aperto = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!aperto && mounted) {
        setState(() => _error = 'App richiesta dal login CIE non disponibile.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'App richiesta dal login CIE non disponibile.');
      }
    }
  }

  Future<void> _completaAccesso(String url) async {
    if (!mounted) return;
    setState(() => _loading = true);
    final header = _cineca.extractBasicAuthHeader(url);
    if (header == null) {
      setState(() {
        _loading = false;
        _error = 'Risposta di accesso non valida.';
      });
      return;
    }
    try {
      final profilo = await _cineca.fetchProfilo(header);
      await widget.authService.completaLoginCineca(profilo);
      if (mounted) widget.onLoggedIn();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Accesso non riuscito. Riprova.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accedi con SPID, CIE o credenziali UNISA'),
      ),
      body: Stack(
        children: [
          if (_controller != null) WebViewWidget(controller: _controller!),
          if (_loading)
            Center(child: CircularProgressIndicator(color: scheme.secondary)),
          if (!_loading && _error == null)
            Center(
              child: Text(
                'Completa l’accesso nel browser e torna qui.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.inchiostro,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppColors.zolfo,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(color: AppColors.pietra),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.zolfo,
                            foregroundColor: AppColors.inchiostro,
                          ),
                          onPressed: () {
                            setState(() => _error = null);
                            _avvia();
                          },
                          child: const Text('Riprova'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

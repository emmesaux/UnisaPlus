import 'package:flutter/material.dart';
import '../models/preferenze_corso.dart';
import '../services/auth_service.dart';
import '../services/easycourse_combo_service.dart';

/// Scelta di corso e anno (con partizione o curriculum) dal combo pubblico
/// di AgendaStudenti. Come nell'app campus: si mostra al primo accesso e
/// si riapre dalle impostazioni. I suggerimenti (corso dalla matricola,
/// partizione dal cognome) sono solo una preselezione: decide lo studente.
class SelezioneCorsoScreen extends StatefulWidget {
  const SelezioneCorsoScreen({
    super.key,
    required this.authService,
    this.primoAccesso = false,
    this.onSalvato,
  });

  final AuthService authService;

  /// Al primo accesso non c'è "indietro": la scelta è necessaria per
  /// l'orario (si può comunque rimandare).
  final bool primoAccesso;

  /// Chiamato dopo il salvataggio. Se nullo, la schermata fa `pop`.
  final VoidCallback? onSalvato;

  @override
  State<SelezioneCorsoScreen> createState() => _SelezioneCorsoScreenState();
}

class _SelezioneCorsoScreenState extends State<SelezioneCorsoScreen> {
  final _combo = EasyCourseComboService();
  final _cercaController = TextEditingController();
  final int _aa = EasyCourseComboService.annoAccademico(DateTime.now());

  late Future<List<CorsoCombo>> _future;
  CorsoCombo? _corso;
  AnnoCombo? _anno;
  CorsoCombo? _suggerito;
  String _query = '';
  bool _inizializzato = false;
  bool _salvataggio = false;

  @override
  void initState() {
    super.initState();
    _future = _carica();
  }

  @override
  void dispose() {
    _cercaController.dispose();
    super.dispose();
  }

  Future<List<CorsoCombo>> _carica() async {
    final corsi = await _combo.getCorsi(_aa);
    if (!_inizializzato) {
      _inizializzato = true;
      _preseleziona(corsi);
    }
    return corsi;
  }

  /// Preselezione: la scelta già salvata se ancora valida, altrimenti il
  /// corso suggerito dalla matricola e la partizione dal cognome.
  void _preseleziona(List<CorsoCombo> corsi) {
    final user = widget.authService.currentUser;
    final attuale = widget.authService.preferenzeCorso.value;
    _suggerito = EasyCourseComboService.suggerisciCorso(corsi, user?.matricola ?? '');

    CorsoCombo? corso;
    if (attuale != null) {
      corso = corsi.where((c) => c.valore == attuale.corsoValore).firstOrNull;
    }
    corso ??= _suggerito;
    if (corso == null) return;

    AnnoCombo? anno;
    if (attuale != null && attuale.aa == _aa) {
      anno = corso.anni.where((a) => a.valore == attuale.annoValore).firstOrNull;
    }
    if (anno == null) {
      // Scelta di un anno accademico precedente: si avanza di anno.
      var annoDiCorso = '';
      if (attuale != null && attuale.annoDiCorso.isNotEmpty) {
        final n = int.tryParse(attuale.annoDiCorso);
        if (n != null) annoDiCorso = '${n + (_aa - attuale.aa)}';
      } else {
        annoDiCorso = user?.classId ?? '';
      }
      anno = EasyCourseComboService.suggerisciAnno(
        corso,
        cognome: user?.cognome ?? '',
        annoDiCorso: annoDiCorso,
      );
    }
    _corso = corso;
    _anno = anno;
  }

  Future<void> _salva() async {
    final corso = _corso;
    final anno = _anno;
    if (corso == null || anno == null) return;
    setState(() => _salvataggio = true);
    await widget.authService.salvaPreferenzeCorso(
      PreferenzeCorso(
        aa: _aa,
        corsoValore: corso.valore,
        corsoLabel: corso.label,
        annoValore: anno.valore,
        annoLabel: anno.label,
        facoltaCode: corso.facoltaCode,
      ),
    );
    if (!mounted) return;
    setState(() => _salvataggio = false);
    if (widget.onSalvato != null) {
      widget.onSalvato!();
    } else {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.primoAccesso || _corso != null,
        leading: _corso != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Cambia corso',
                onPressed: () => setState(() {
                  _corso = null;
                  _anno = null;
                }),
              )
            : null,
        title: Text(_corso == null ? 'Il tuo corso' : 'Anno e gruppo'),
        actions: [
          if (widget.primoAccesso && widget.onSalvato != null)
            TextButton(onPressed: widget.onSalvato, child: const Text('Dopo')),
        ],
      ),
      body: FutureBuilder<List<CorsoCombo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _Errore(
              messaggio: snapshot.error.toString(),
              onRetry: () => setState(() => _future = _carica()),
            );
          }
          final corsi = snapshot.data ?? const [];
          return _corso == null ? _elencoCorsi(corsi) : _elencoAnni(_corso!);
        },
      ),
      bottomNavigationBar: _corso == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: FilledButton(
                  onPressed: _anno == null || _salvataggio ? null : _salva,
                  child: _salvataggio
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salva'),
                ),
              ),
            ),
    );
  }

  Widget _elencoCorsi(List<CorsoCombo> corsi) {
    final q = _query.trim().toUpperCase();
    final filtrati = q.isEmpty
        ? corsi
        : corsi
            .where((c) =>
                c.label.toUpperCase().contains(q) ||
                c.valore.toUpperCase().contains(q) ||
                c.tipo.toUpperCase().contains(q))
            .toList();
    final suggerito = _suggerito;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            'Scegli il corso di laurea per vedere il tuo orario. '
            'Potrai cambiarlo in Altro → Corso e anno.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _cercaController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cerca corso o codice',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: [
              if (suggerito != null && q.isEmpty) ...[
                const _Intestazione('Suggerito dalla tua matricola'),
                _tileCorso(suggerito),
                const _Intestazione('Tutti i corsi'),
              ],
              for (final c in filtrati) _tileCorso(c),
              if (filtrati.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Nessun corso trovato')),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tileCorso(CorsoCombo c) => ListTile(
    title: Text(c.label),
    subtitle: Text([c.tipo, c.valore].where((s) => s.isNotEmpty).join(' · ')),
    trailing: const Icon(Icons.chevron_right),
    onTap: () {
      final user = widget.authService.currentUser;
      setState(() {
        _corso = c;
        _anno = EasyCourseComboService.suggerisciAnno(
          c,
          cognome: user?.cognome ?? '',
          annoDiCorso: user?.classId ?? '',
        );
      });
    },
  );

  Widget _elencoAnni(CorsoCombo corso) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        ListTile(
          title: Text(corso.label, style: const TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text([corso.tipo, corso.valore].where((s) => s.isNotEmpty).join(' · ')),
        ),
        Divider(color: scheme.outlineVariant),
        const _Intestazione('Anno di corso e gruppo (partizione o curriculum)'),
        RadioGroup<String>(
          groupValue: _anno?.valore,
          onChanged: (v) => setState(() {
            _anno = corso.anni.where((a) => a.valore == v).firstOrNull;
          }),
          child: Column(
            children: [
              for (final a in corso.anni)
                RadioListTile<String>(
                  value: a.valore,
                  title: Text(a.annoDiCorso.isNotEmpty ? '${a.annoDiCorso}° anno' : a.label),
                  subtitle: a.partizione.isNotEmpty ? Text(a.partizione) : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Intestazione extends StatelessWidget {
  const _Intestazione(this.testo);
  final String testo;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
    child: Text(
      testo.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _Errore extends StatelessWidget {
  const _Errore({required this.messaggio, required this.onRetry});
  final String messaggio;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48),
          const SizedBox(height: 12),
          Text('Elenco corsi non disponibile', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(messaggio, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
        ],
      ),
    ),
  );
}


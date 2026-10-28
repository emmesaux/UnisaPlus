import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/presenza.dart';
import '../services/auth_service.dart';
import '../services/easybadge_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_state.dart';

/// "Le mie presenze": consultazione dei propri dati di frequenza EasyBadge.
/// Elenco corsi con la percentuale di presenza; toccando un corso si
/// vedono le singole lezioni (tenute e dove si risulta presenti).
class PresenzeScreen extends StatefulWidget {
  const PresenzeScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<PresenzeScreen> createState() => _PresenzeScreenState();
}

class _PresenzeScreenState extends State<PresenzeScreen> {
  final _badge = EasyBadgeService();
  late Future<List<CorsoPresenza>> _corsi;

  @override
  void initState() {
    super.initState();
    _corsi = _carica();
  }

  Future<List<CorsoPresenza>> _carica() {
    final matricola = widget.authService.currentUser?.matricola ?? '';
    if (matricola.isEmpty) return Future.value([]);
    return _badge.getCorsi(matricola);
  }

  void _ricarica() => setState(() => _corsi = _carica());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CorsoPresenza>>(
      future: _corsi,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Presenze non disponibili',
            message: 'Il servizio presenze non ha risposto. Riprova tra poco.',
            upstream: true,
            onRetry: _ricarica,
          );
        }
        final corsi = snapshot.data ?? [];
        if (corsi.isEmpty) {
          return EmptyState(
            icon: Icons.fact_check_outlined,
            title: 'Nessun corso con presenze',
            message: 'Quando le tue presenze saranno registrate le vedrai qui, corso per corso.',
            onRetry: _ricarica,
          );
        }
        return RefreshIndicator(
          onRefresh: () async => _ricarica(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: corsi.length,
            itemBuilder: (context, i) => _CorsoRow(
              corso: corsi[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PresenzeCorsoScreen(
                    badge: _badge,
                    matricola: widget.authService.currentUser?.matricola ?? '',
                    corso: corsi[i],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Color _coloreStato(String stato, ColorScheme scheme) {
  switch (stato) {
    case 'frequentante':
      return const Color(0xFF2E7D5B);
    case 'in_frequenza':
      return AppColors.zolfo;
    default:
      return scheme.onSurfaceVariant;
  }
}

String _ore(int minuti) {
  if (minuti <= 0) return '0 h';
  if (minuti % 60 == 0) return '${minuti ~/ 60} h';
  return '${minuti ~/ 60}h ${minuti % 60}m';
}

class _CorsoRow extends StatelessWidget {
  const _CorsoRow({required this.corso, required this.onTap});
  final CorsoPresenza corso;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colore = _coloreStato(corso.stato, scheme);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${corso.percentuale.toStringAsFixed(0)}%',
                    style: AppTheme.numerico(size: 20, color: colore),
                  ),
                  Text('presenza', style: AppTheme.codice(size: 10, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
            Container(width: 1, height: 36, color: scheme.outlineVariant, margin: const EdgeInsets.symmetric(horizontal: 12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(corso.nome, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    '${_ore(corso.frequentateMinuti)} frequentate su ${_ore(corso.svolteMinuti)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class PresenzeCorsoScreen extends StatefulWidget {
  const PresenzeCorsoScreen({super.key, required this.badge, required this.matricola, required this.corso});
  final EasyBadgeService badge;
  final String matricola;
  final CorsoPresenza corso;

  @override
  State<PresenzeCorsoScreen> createState() => _PresenzeCorsoScreenState();
}

class _PresenzeCorsoScreenState extends State<PresenzeCorsoScreen> {
  late Future<List<LezionePresenza>> _lezioni;

  @override
  void initState() {
    super.initState();
    _lezioni = widget.badge.getLezioni(widget.matricola, [widget.corso.codice]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.corso.nome)),
      body: FutureBuilder<List<LezionePresenza>>(
        future: _lezioni,
        builder: (context, snapshot) {
          final lezioni = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _Riepilogo(corso: widget.corso),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: Text('Lezioni', style: Theme.of(context).textTheme.titleSmall)),
                  _Legenda(),
                ],
              ),
              const SizedBox(height: 8),
              if (snapshot.connectionState != ConnectionState.done)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (lezioni.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nessuna lezione registrata per questo corso.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                )
              else
                for (final l in lezioni) _LezioneRow(lezione: l),
            ],
          );
        },
      ),
    );
  }
}

class _Riepilogo extends StatelessWidget {
  const _Riepilogo({required this.corso});
  final CorsoPresenza corso;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(color: AppColors.inchiostro, borderRadius: BorderRadius.circular(6)),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${corso.percentuale.toStringAsFixed(1)}%', style: AppTheme.numerico(size: 40, color: AppColors.zolfo)),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('di presenza', style: TextStyle(color: AppColors.nebbiaChiara)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _rigaRiepilogo('Ore frequentate', _ore(corso.frequentateMinuti), scheme),
          _rigaRiepilogo('Ore svolte dal docente', _ore(corso.svolteMinuti), scheme),
          _rigaRiepilogo('Conseguimento', '${corso.percentualeConseguimento.toStringAsFixed(1)}%', scheme),
        ],
      ),
    );
  }

  Widget _rigaRiepilogo(String label, String valore, ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.nebbiaChiara, fontSize: 13)),
          Text(valore, style: AppTheme.codice(size: 13, color: AppColors.pietra)),
        ],
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    return Row(
      children: [
        Icon(Icons.school_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text('tenuta', style: style),
        const SizedBox(width: 10),
        Icon(Icons.how_to_reg_outlined, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 2),
        Text('presente', style: style),
      ],
    );
  }
}

class _LezioneRow extends StatelessWidget {
  const _LezioneRow({required this.lezione});
  final LezionePresenza lezione;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final data = DateFormat('EEE d MMM yyyy', 'it_IT').format(lezione.inizio);
    final orario = '${DateFormat('HH:mm').format(lezione.inizio)} – ${DateFormat('HH:mm').format(lezione.fine)}';
    return Container(
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data[0].toUpperCase() + data.substring(1), style: Theme.of(context).textTheme.bodyMedium),
                Text(orario, style: AppTheme.codice(size: 12, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          _segno(lezione.svolta),
          const SizedBox(width: 24),
          _segno(lezione.presente),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _segno(bool ok) => Icon(
        ok ? Icons.check : Icons.close,
        color: ok ? const Color(0xFF2E7D5B) : AppColors.corallo,
        size: 20,
      );
}

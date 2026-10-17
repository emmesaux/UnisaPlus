import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/lezione.dart';
import '../models/preferenze_corso.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/board_row.dart';
import '../widgets/empty_state.dart';
import 'selezione_corso_screen.dart';

class OrarioScreen extends StatefulWidget {
  const OrarioScreen({super.key, required this.authService});
  final AuthService authService;

  @override
  State<OrarioScreen> createState() => _OrarioScreenState();
}

class _OrarioScreenState extends State<OrarioScreen> {
  DateTime _weekStart = _mondayOf(DateTime.now());
  late Future<List<Lezione>> _future;
  final _scrollController = ScrollController();
  final _sectionKeys = <int, GlobalKey>{};

  static DateTime _mondayOf(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  @override
  void initState() {
    super.initState();
    _future = _load();
    widget.authService.preferenzeCorso.addListener(_ricarica);
  }

  @override
  void dispose() {
    widget.authService.preferenzeCorso.removeListener(_ricarica);
    _scrollController.dispose();
    super.dispose();
  }

  /// Corso/anno cambiati dalle impostazioni: si ricarica la settimana.
  void _ricarica() {
    if (!mounted) return;
    setState(() => _future = _load());
  }

  void _apriSceltaCorso() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SelezioneCorsoScreen(authService: widget.authService),
      ),
    );
  }

  Future<List<Lezione>> _load() async {
    final data = await widget.authService.api.getOrarioReale(
      _weekStart,
      _weekStart.add(const Duration(days: 7)),
    );
    return data.map((e) => Lezione.fromJson(e as Map<String, dynamic>)).toList()
      ..sort((a, b) => a.inizio.compareTo(b.inizio));
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _future = _load();
    });
  }

  void _tornaAOggi() {
    final lunediOggi = _mondayOf(DateTime.now());
    if (DateUtils.isSameDay(_weekStart, lunediOggi)) return;
    setState(() {
      _weekStart = lunediOggi;
      _future = _load();
    });
  }

  void _vaiAlGiorno(int weekday) {
    final key = _sectionKeys[weekday];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSettimanaCorrente = DateUtils.isSameDay(
      _weekStart,
      _mondayOf(DateTime.now()),
    );
    return Column(
      children: [
        _BarraCorsoEAnno(
          authService: widget.authService,
          onTap: _apriSceltaCorso,
        ),
        _SelettoreSettimana(
          weekStart: _weekStart,
          isSettimanaCorrente: isSettimanaCorrente,
          onChange: _changeWeek,
          onToday: _tornaAOggi,
        ),
        Expanded(
          child: FutureBuilder<List<Lezione>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.error is CorsoNonImpostatoException) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.school_outlined, size: 56),
                        const SizedBox(height: 16),
                        Text(
                          'Scegli corso e anno',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Servono per mostrarti l’orario delle tue lezioni.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _apriSceltaCorso,
                          child: const Text('Scegli'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final lezioni = snapshot.data ?? [];
              if (lezioni.isEmpty) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _StripGiorni(
                        weekStart: _weekStart,
                        lezioniPerGiorno: const {},
                        onTapGiorno: _vaiAlGiorno,
                      ),
                    ),
                    Expanded(
                      child: EmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: 'Nessuna lezione questa settimana',
                        message:
                            'Quando il tuo orario sarà disponibile lo vedrai qui, giorno per giorno.',
                        onRetry: () => setState(() {
                          _future = _load();
                        }),
                      ),
                    ),
                  ],
                );
              }
              final byDay = <int, List<Lezione>>{};
              for (final l in lezioni) {
                byDay.putIfAbsent(l.inizio.weekday, () => []).add(l);
              }
              _sectionKeys.clear();
              for (final wd in byDay.keys) {
                _sectionKeys[wd] = GlobalKey();
              }
              final inCorsoOProssima = _trovaInCorsoOProssima(lezioni);
              return RefreshIndicator(
                onRefresh: () async => _ricarica(),
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    _StripGiorni(
                      weekStart: _weekStart,
                      lezioniPerGiorno: byDay,
                      onTapGiorno: _vaiAlGiorno,
                    ),
                    const SizedBox(height: 16),
                    if (inCorsoOProssima != null) ...[
                      _CardOraProssima(info: inCorsoOProssima),
                      const SizedBox(height: 20),
                    ],
                    for (var wd = 1; wd <= 7; wd++)
                      if (byDay.containsKey(wd))
                        _DaySection(
                          key: _sectionKeys[wd],
                          day: _weekStart.add(Duration(days: wd - 1)),
                          lezioni: byDay[wd]!,
                          ritardo: (wd - 1) * 50,
                        ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  _InfoLezione? _trovaInCorsoOProssima(List<Lezione> lezioni) {
    final ora = DateTime.now();
    for (final l in lezioni) {
      if (ora.isAfter(l.inizio) && ora.isBefore(l.fine)) {
        return _InfoLezione(lezione: l, inCorso: true);
      }
    }
    Lezione? prossima;
    for (final l in lezioni) {
      if (l.inizio.isAfter(ora)) {
        if (prossima == null || l.inizio.isBefore(prossima.inizio)) {
          prossima = l;
        }
      }
    }
    return prossima == null
        ? null
        : _InfoLezione(lezione: prossima, inCorso: false);
  }
}

class _InfoLezione {
  final Lezione lezione;
  final bool inCorso;
  _InfoLezione({required this.lezione, required this.inCorso});
}

/// Barra superiore compatta che mostra il corso e l'anno scelti e permette
/// di cambiarli al volo con un tocco.
class _BarraCorsoEAnno extends StatelessWidget {
  const _BarraCorsoEAnno({required this.authService, required this.onTap});
  final AuthService authService;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<PreferenzeCorso?>(
      valueListenable: authService.preferenzeCorso,
      builder: (context, pref, _) {
        if (pref == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.school_outlined, size: 16, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pref.corsoLabel} · ${pref.annoLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Cambia',
                    style: AppTheme.codice(size: 11, color: scheme.primary),
                  ),
                  Icon(Icons.chevron_right, size: 16, color: scheme.primary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Selettore di settimana in stile tabellone: frecce ai lati, intervallo
/// al centro e pulsante rapido "Oggi" quando si esplora un'altra settimana.
class _SelettoreSettimana extends StatelessWidget {
  const _SelettoreSettimana({
    required this.weekStart,
    required this.isSettimanaCorrente,
    required this.onChange,
    required this.onToday,
  });
  final DateTime weekStart;
  final bool isSettimanaCorrente;
  final void Function(int deltaSettimane) onChange;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM', 'it_IT');
    final fine = weekStart.add(const Duration(days: 6));
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChange(-1),
            tooltip: 'Settimana precedente',
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.date_range_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${fmt.format(weekStart).toUpperCase()} – ${fmt.format(fine).toUpperCase()}',
                    style: AppTheme.numerico(
                      size: 15,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (!isSettimanaCorrente) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onToday,
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: scheme.primary.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'OGGI',
                          style: AppTheme.codice(
                            size: 10,
                            color: scheme.primary,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChange(1),
            tooltip: 'Settimana successiva',
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Striscia dei 7 giorni della settimana: mostra i pallini colorati delle
/// materie previste in quel giorno e permette di saltare subito alla sezione.
class _StripGiorni extends StatelessWidget {
  const _StripGiorni({
    required this.weekStart,
    required this.lezioniPerGiorno,
    required this.onTapGiorno,
  });
  final DateTime weekStart;
  final Map<int, List<Lezione>> lezioniPerGiorno;
  final void Function(int weekday) onTapGiorno;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final oggi = DateTime.now();
    return SizedBox(
      height: 70,
      child: Row(
        children: [
          for (var wd = 1; wd <= 7; wd++)
            Expanded(
              child: Builder(
                builder: (context) {
                  final giorno = weekStart.add(Duration(days: wd - 1));
                  final isOggi = DateUtils.isSameDay(giorno, oggi);
                  final lezioniGiorno = lezioniPerGiorno[wd] ?? const [];
                  final haLezioni = lezioniGiorno.isNotEmpty;
                  return GestureDetector(
                    onTap: haLezioni ? () => onTapGiorno(wd) : null,
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2.5),
                      decoration: BoxDecoration(
                        color: isOggi
                            ? AppColors.mare
                            : haLezioni
                            ? scheme.surfaceContainerHigh
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: isOggi
                              ? AppColors.mare
                              : haLezioni
                              ? scheme.outlineVariant
                              : scheme.outlineVariant.withValues(alpha: 0.45),
                          width: isOggi ? 1.5 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('E', 'it_IT')
                                .format(giorno)
                                .substring(0, 3)
                                .toUpperCase(),
                            style: AppTheme.codice(
                              size: 10,
                              color: isOggi
                                  ? AppColors.zolfo
                                  : haLezioni
                                  ? scheme.onSurfaceVariant
                                  : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${giorno.day}',
                            style: AppTheme.numerico(
                              size: 17,
                              color: isOggi
                                  ? AppColors.pietra
                                  : haLezioni
                                  ? scheme.onSurface
                                  : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (haLezioni)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final l in lezioniGiorno.take(3))
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isOggi
                                          ? AppColors.zolfo
                                          : coloreMateria(l.insegnamento),
                                    ),
                                  ),
                              ],
                            )
                          else
                            const SizedBox(height: 5),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Riquadro in evidenza con la lezione in corso o la prossima, come
/// l'annuncio in testa a un vero tabellone delle partenze.
class _CardOraProssima extends StatelessWidget {
  const _CardOraProssima({required this.info});
  final _InfoLezione info;

  @override
  Widget build(BuildContext context) {
    final l = info.lezione;
    final fmt = DateFormat('HH:mm');
    final colore = coloreMateria(l.insegnamento);
    double? progresso;
    String sottotesto;
    if (info.inCorso) {
      final totale = l.fine.difference(l.inizio).inSeconds;
      final trascorso = DateTime.now().difference(l.inizio).inSeconds;
      progresso = totale == 0 ? 0 : (trascorso / totale).clamp(0, 1).toDouble();
      final restanti = l.fine.difference(DateTime.now()).inMinutes.clamp(0, 999);
      sottotesto = 'Termina alle ${fmt.format(l.fine)} · ancora $restanti min';
    } else {
      final attesa = l.inizio.difference(DateTime.now());
      final minuti = attesa.inMinutes;
      final giornoFmt = DateUtils.isSameDay(l.inizio, DateTime.now())
          ? 'Oggi'
          : DateFormat('EEE d MMM', 'it_IT').format(l.inizio);
      sottotesto = minuti >= 0 && minuti < 60
          ? 'Inizia tra $minuti min · ${fmt.format(l.inizio)}–${fmt.format(l.fine)}'
          : '$giornoFmt · ${fmt.format(l.inizio)}–${fmt.format(l.fine)}';
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inchiostro,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: info.inCorso
              ? AppColors.zolfo.withValues(alpha: 0.7)
              : AppColors.inchiostro,
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 5, color: info.inCorso ? AppColors.zolfo : colore),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: info.inCorso
                                ? AppColors.zolfo
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            info.inCorso ? 'IN CORSO ORA' : 'PROSSIMA LEZIONE',
                            style: AppTheme.codice(
                              size: 10,
                              color: info.inCorso
                                  ? AppColors.inchiostro
                                  : AppColors.nebbiaChiara,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            sottotesto,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: AppTheme.numerico(
                              size: 13,
                              color: AppColors.zolfo,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l.insegnamento,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.pietra,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (l.aula.isNotEmpty)
                          _TagScuro(
                            icon: Icons.meeting_room_outlined,
                            label: l.aula,
                            highlight: true,
                          ),
                        if (l.docente.isNotEmpty)
                          _TagScuro(
                            icon: Icons.person_outline,
                            label: l.docente,
                          ),
                      ],
                    ),
                    if (progresso != null) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: progresso,
                          minHeight: 4,
                          backgroundColor: const Color(0xFF2A303C),
                          color: AppColors.zolfo,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagScuro extends StatelessWidget {
  const _TagScuro({
    required this.icon,
    required this.label,
    this.highlight = false,
  });
  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final fg = highlight ? AppColors.zolfo : AppColors.pietra;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlight ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    super.key,
    required this.day,
    required this.lezioni,
    this.ritardo = 0,
  });
  final DateTime day;
  final List<Lezione> lezioni;
  final int ritardo;

  @override
  Widget build(BuildContext context) {
    final label = DateFormat('EEEE d MMMM', 'it_IT').format(day);
    final oggi = DateUtils.isSameDay(day, DateTime.now());
    final scheme = Theme.of(context).colorScheme;
    final minutiTotali = lezioni.fold<int>(
      0,
      (sum, l) => sum + l.fine.difference(l.inizio).inMinutes.clamp(0, 1440),
    );
    final oreLabel = minutiTotali % 60 == 0
        ? '${minutiTotali ~/ 60}h'
        : '${minutiTotali ~/ 60}h ${minutiTotali % 60}m';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + ritardo),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 10),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Row(
                children: [
                  if (oggi)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mare,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'OGGI',
                        style: AppTheme.codice(
                          size: 10,
                          color: AppColors.pietra,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      label[0].toUpperCase() + label.substring(1),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: oggi ? scheme.primary : scheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${lezioni.length} lezion${lezioni.length == 1 ? 'e' : 'i'} · $oreLabel',
                    style: AppTheme.codice(
                      size: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            for (final l in lezioni) _LezioneCard(lezione: l),
          ],
        ),
      ),
    );
  }
}

/// Card di una singola lezione: barra laterale col colore della materia,
/// colonna orario (inizio, fine e durata) a sinistra, e a destra il titolo
/// con aula e docente messi in evidenza come targhette.
class _LezioneCard extends StatelessWidget {
  const _LezioneCard({required this.lezione});
  final Lezione lezione;

  @override
  Widget build(BuildContext context) {
    final l = lezione;
    final scheme = Theme.of(context).colorScheme;
    final colore = coloreMateria(l.insegnamento);
    final fmt = DateFormat('HH:mm');
    final ora = DateTime.now();
    final inCorso = ora.isAfter(l.inizio) && ora.isBefore(l.fine);
    final passata =
        DateUtils.isSameDay(l.inizio, ora) && ora.isAfter(l.fine);
    final minuti = l.fine.difference(l.inizio).inMinutes;
    final durata = minuti >= 60 && minuti % 60 == 0
        ? '${minuti ~/ 60}h'
        : '${minuti}m';

    return Opacity(
      opacity: passata ? 0.65 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: inCorso ? AppColors.zolfo : scheme.outlineVariant,
            width: inCorso ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: colore),
              // Colonna orario inizio / fine
              Container(
                width: 68,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      fmt.format(l.inizio),
                      style: AppTheme.numerico(
                        size: 16,
                        color: scheme.onSurface,
                        weight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      fmt.format(l.fine),
                      style: AppTheme.codice(
                        size: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        durata,
                        style: AppTheme.codice(
                          size: 10,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, color: scheme.outlineVariant),
              // Contenuto: materia, aula e docente
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              l.insegnamento,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          if (inCorso) ...[
                            const SizedBox(width: 8),
                            const BoardTag(
                              label: 'In corso',
                              color: AppColors.zolfo,
                              onColor: AppColors.inchiostro,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (l.aula.isNotEmpty)
                            _chip(
                              context,
                              Icons.meeting_room_outlined,
                              l.aula,
                              colore,
                            ),
                          if (l.docente.isNotEmpty)
                            _chip(
                              context,
                              Icons.person_outline,
                              l.docente,
                              scheme.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String testo,
    Color colore,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colore.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: colore.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colore),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              testo,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Riga in stile tabellone delle partenze: orario grande a sinistra,
/// contenuto al centro, una targhetta di stato a destra. Usata per
/// lezioni, prenotazioni e aule: sono tutte la stessa forma di
/// informazione — quando, dove, in che stato.
class BoardRow extends StatelessWidget {
  const BoardRow({
    super.key,
    required this.orario,
    required this.titolo,
    required this.sottotitolo,
    this.tag,
    this.onTap,
    this.trailing,
    this.accento,
  });

  final String orario;
  final String titolo;
  final String sottotitolo;
  final BoardTag? tag;
  final VoidCallback? onTap;
  final Widget? trailing;

  /// Barra verticale colorata a sinistra: usata per distinguere a colpo
  /// d'occhio elementi dello stesso tipo (es. esami per materia).
  final Color? accento;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              child: Text(orario, style: AppTheme.numerico(size: 17, color: scheme.onSurface)),
            ),
            Container(
              width: accento != null ? 3 : 1,
              height: 36,
              decoration: BoxDecoration(
                color: accento ?? scheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(right: 12),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titolo, style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(sottotitolo, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ?trailing ?? tag,
          ],
        ),
      ),
    );
  }
}

/// Targhetta di stato rettangolare, non una pillola: legge come una
/// vera etichetta di segnaletica (libero/occupato, posti, esito).
class BoardTag extends StatelessWidget {
  const BoardTag({super.key, required this.label, required this.color, this.onColor});

  final String label;
  final Color color;
  final Color? onColor;

  factory BoardTag.libera(BuildContext context) =>
      BoardTag(label: 'Libera', color: const Color(0xFF2E7D5B), onColor: Colors.white);

  factory BoardTag.occupata(BuildContext context) => BoardTag(label: 'Occupata', color: AppColors.corallo, onColor: Colors.white);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: onColor ?? Colors.white,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

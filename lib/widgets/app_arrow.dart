import 'package:flutter/material.dart';

/// Freccia di navigazione coerente in tutta l'app: chevron sottile dentro un
/// cerchietto tenue. Sostituisce la vecchia `Icon(Icons.chevron_right)`.
class AppArrow extends StatelessWidget {
  const AppArrow({super.key, this.size = 30});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.arrow_forward_ios,
        size: size * 0.43,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

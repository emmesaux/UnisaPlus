import 'package:flutter/material.dart';

/// Singolo segmento del selettore.
class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

/// Selettore segmentato moderno: traccia arrotondata con un indicatore pieno
/// che scorre fluido sotto l'opzione attiva. Sostituto più curato del
/// `SegmentedButton` di Material.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = segments.length;
    final index = segments.indexWhere((s) => s.value == value).clamp(0, n - 1);

    return Container(
      height: 50,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Stack(
        children: [
          // Indicatore scorrevole.
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            alignment: n <= 1
                ? Alignment.center
                : Alignment(-1 + 2 * index / (n - 1), 0),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(child: _segment(context, i, scheme)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _segment(BuildContext context, int i, ColorScheme scheme) {
    final seg = segments[i];
    final selected = i == segments.indexWhere((s) => s.value == value);
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(seg.value),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (seg.icon != null) ...[
              AnimatedScale(
                scale: selected ? 1.0 : 0.92,
                duration: const Duration(milliseconds: 250),
                child: Icon(seg.icon, size: 18, color: fg),
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 250),
                style: Theme.of(context).textTheme.labelLarge!.copyWith(
                      color: fg,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                child: Text(
                  seg.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

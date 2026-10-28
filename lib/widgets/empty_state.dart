import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Stato vuoto/riutilizzabile per liste senza dati o in errore.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
    this.upstream = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onRetry;

  /// Quando true aggiunge un banner che chiarisce che il disservizio è a monte
  /// (un servizio dell'Ateneo momentaneamente non raggiungibile), non un bug
  /// dell'app. Da usare solo nei rami d'errore di rete/servizio.
  final bool upstream;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (upstream) ...[
              const SizedBox(height: 16),
              const _BannerServizioAteneo(),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onRetry, child: const Text('Riprova')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Avviso discreto: il servizio dell'Ateneo è momentaneamente non raggiungibile.
/// Serve a distinguere un disservizio a monte da un errore dell'app.
class _BannerServizioAteneo extends StatelessWidget {
  const _BannerServizioAteneo();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.zolfo.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.zolfo.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.zolfo),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Servizio dell’Ateneo momentaneamente non raggiungibile. '
              'Non è un problema dell’app: riprova tra poco.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

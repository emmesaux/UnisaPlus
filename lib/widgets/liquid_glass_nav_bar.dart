import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Voce della barra di navigazione in vetro.
class GlassNavItem {
  const GlassNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barra di navigazione inferiore in stile "liquid glass":
/// pannello smerigliato (BackdropFilter), bordo luminoso e un indicatore
/// colorato che scorre tra le icone con un leggero rimbalzo (effetto liquido).
/// L'icona attiva si riempie del colore accento e mostra l'etichetta.
class LiquidGlassNavBar extends StatelessWidget {
  const LiquidGlassNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
    this.accent = AppColors.zolfo,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<GlassNavItem> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.white.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isDark ? 0.14 : 0.7),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.14),
                    blurRadius: 26,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, c) {
                  final n = items.length;
                  final itemW = c.maxWidth / n;
                  const pillW = 60.0;
                  const pillH = 50.0;
                  return Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      // Indicatore "liquido" che scorre.
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 450),
                        curve: Curves.easeOutBack,
                        left: itemW * currentIndex + (itemW - pillW) / 2,
                        top: (70 - pillH) / 2,
                        child: Container(
                          width: pillW,
                          height: pillH,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                accent.withValues(alpha: 0.95),
                                accent.withValues(alpha: 0.72),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: accent.withValues(alpha: 0.5),
                                blurRadius: 18,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(child: _buildItem(context, i, scheme, isDark)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    int i,
    ColorScheme scheme,
    bool isDark,
  ) {
    final selected = i == currentIndex;
    final item = items[i];
    final inactiveColor = isDark ? Colors.white70 : scheme.onSurfaceVariant;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: SizedBox(
        height: 70,
        child: Center(
          child: AnimatedScale(
            scale: selected ? 1.0 : 0.88,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                size: 26,
                color: selected ? AppColors.inchiostro : inactiveColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

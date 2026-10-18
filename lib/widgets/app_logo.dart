import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Nome ufficiale dell'app dedicata agli studenti dell'Università di Salerno.
const String kAppName = 'Unisa Plus';
const String kAppTagline = 'Il campus di Salerno in tasca';

/// Logo di Unisa Plus: mostra l'icona ufficiale con la "U" e il simbolo "+"
/// dorato su fondo verde mare profondo.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 44,
    this.borderRadius = 10,
  });

  final double size;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.inchiostro.withValues(alpha: 0.12),
            blurRadius: size * 0.15,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/app_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Icon(
          Icons.school,
          color: AppColors.zolfo,
          size: size * 0.55,
        ),
      ),
    );
  }
}


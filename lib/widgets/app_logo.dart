import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Nome ufficiale dell'app dedicata agli studenti dell'Università di Salerno.
const String kAppName = 'Unisa+';
const String kAppTagline = 'Il campus di Salerno in tasca';

/// Logo di Unisa+: mostra l'icona ufficiale con la "U" dorata di UNISA,
/// la colonna accademica e il simbolo "+" su fondo verde mare profondo.
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
        color: AppColors.mare,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: AppColors.inchiostro.withValues(alpha: 0.18),
            blurRadius: size * 0.18,
            offset: Offset(0, size * 0.06),
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


import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identita visiva: tabellone delle partenze applicato a lezioni e aule.
/// Stesso tipo di informazione di un tabellone da stazione: orario, luogo,
/// stato libero/occupato, letto in fretta tra un corridoio e un altro.
class AppColors {
  AppColors._();

  static const inchiostro = Color(0xFF1B2029); // testo, superfici scure
  static const pietra = Color(0xFFECEAE2); // sfondo chiaro, grigio caldo
  static const pietraAlta = Color(0xFFE2DFD4); // superfici leggermente rilevate
  static const zolfo = Color(0xFFE8A33D); // libero / attivo
  static const mare = Color(0xFF16474D); // brand, primario
  static const mareChiaro = Color(0xFF2A6B73);
  static const corallo = Color(0xFFC1443C); // occupato / errore
  static const smeraldo = Color(0xFF2E7D5B); // superato / successo
  static const verde = Color(0xFF2E7D5B);
  static const arancio = Color(0xFFE8A33D); // warning / pianificato
  static const nebbia = Color(0xFF6E7585); // testo secondario
  static const nebbiaChiara = Color(0xFFB9BDC6); // divisori
}

/// Palette stabile per distinguere le materie a colpo d'occhio. Lo stesso
/// nome di insegnamento riceve sempre lo stesso colore (hash deterministico),
/// così gli esami della stessa materia sono riconoscibili tra le righe.
const _paletteMaterie = [
  Color(0xFF2E5EAA), // blu
  Color(0xFF2E7D5B), // verde
  Color(0xFFE8A33D), // ambra
  Color(0xFFC1443C), // corallo
  Color(0xFF7B5EA7), // viola
  Color(0xFF158A8A), // teal
  Color(0xFFCB6A3E), // terracotta
  Color(0xFF4A7AB5), // azzurro
  Color(0xFF8A8B2E), // oliva
  Color(0xFFB0507A), // magenta
];

Color coloreMateria(String nome) {
  final key = nome.trim().toLowerCase();
  if (key.isEmpty) return _paletteMaterie.first;
  var hash = 0;
  for (final code in key.codeUnits) {
    hash = (hash * 31 + code) & 0x7fffffff;
  }
  return _paletteMaterie[hash % _paletteMaterie.length];
}

class AppTheme {
  AppTheme._();

  static const success = Color(0xFF2E7D5B);
  static const warning = AppColors.zolfo;

  static TextTheme _textTheme(Color onSurface, Color onSurfaceMuted) {
    final display = GoogleFonts.spaceGroteskTextTheme();
    final body = GoogleFonts.ibmPlexSansTextTheme();
    return body
        .copyWith(
          displayLarge: display.displayLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          displayMedium: display.displayMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          headlineLarge: display.headlineLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          headlineMedium: display.headlineMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600, letterSpacing: -0.2),
          headlineSmall: display.headlineSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          titleLarge: display.titleLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          titleMedium: body.titleMedium?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          titleSmall: body.titleSmall?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
          bodyLarge: body.bodyLarge?.copyWith(color: onSurface),
          bodyMedium: body.bodyMedium?.copyWith(color: onSurface),
          bodySmall: body.bodySmall?.copyWith(color: onSurfaceMuted),
          labelLarge: body.labelLarge?.copyWith(color: onSurface, fontWeight: FontWeight.w600),
        )
        .apply(bodyColor: onSurface, displayColor: onSurface);
  }

  /// Font tabulare per orari, numeri di aula e codici: Space Grotesk.
  static TextStyle numerico({double size = 20, Color? color, FontWeight weight = FontWeight.w600}) =>
      GoogleFonts.spaceGrotesk(fontSize: size, fontWeight: weight, color: color, letterSpacing: -0.2);

  /// Font per codici letterali (matricola, codice aula): IBM Plex Mono,
  /// usato solo dove il contenuto e davvero un codice, non come decoro.
  static TextStyle codice({double size = 13, Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color, letterSpacing: 0.2);

  static ThemeData light() {
    const onSurface = AppColors.inchiostro;
    const onSurfaceMuted = AppColors.nebbia;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mare,
      brightness: Brightness.light,
      primary: AppColors.mare,
      onPrimary: Colors.white,
      secondary: AppColors.zolfo,
      onSecondary: AppColors.inchiostro,
      error: AppColors.corallo,
      onError: Colors.white,
      surface: AppColors.pietra,
      surfaceContainerHigh: Colors.white,
      surfaceContainerHighest: AppColors.pietraAlta,
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceMuted,
      outline: AppColors.nebbiaChiara,
      outlineVariant: AppColors.nebbiaChiara,
    );
    return _base(scheme, onSurface, onSurfaceMuted);
  }

  static ThemeData dark() {
    const onSurface = AppColors.pietra;
    const onSurfaceMuted = AppColors.nebbiaChiara;
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.mareChiaro,
      brightness: Brightness.dark,
      primary: AppColors.mareChiaro,
      secondary: AppColors.zolfo,
      error: const Color(0xFFE2857E),
      surface: const Color(0xFF14181F),
      surfaceContainerHigh: const Color(0xFF1E232C),
      surfaceContainerHighest: const Color(0xFF262C37),
      onSurface: onSurface,
      onSurfaceVariant: onSurfaceMuted,
      outline: const Color(0xFF3A4150),
      outlineVariant: const Color(0xFF3A4150),
    );
    return _base(scheme, onSurface, onSurfaceMuted);
  }

  static ThemeData _base(ColorScheme scheme, Color onSurface, Color onSurfaceMuted) {
    final textTheme = _textTheme(onSurface, onSurfaceMuted);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: scheme.outline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: BorderSide(color: scheme.primary, width: 1.4),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return textTheme.labelLarge?.copyWith(
            fontSize: 12,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(color: selected ? scheme.primary : scheme.onSurfaceVariant);
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        side: BorderSide.none,
        labelStyle: textTheme.bodySmall,
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primary : scheme.outlineVariant,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// ------------------------------
/// BRAND PALETTE (single source of truth)
/// ------------------------------
class BrandColors {
  BrandColors._();

  static const deepNavy = Color(0xFF1C1F6E);   // DEEP NAVY
  static const purple   = Color(0xFF7A2FF2);   // PURPLE
  static const warmPurple = Color(0xFF8237DC);   // WARMER PURPLE ✅
  static const magenta  = Color(0xFFE13AD5);   // MAGENTA
  static const hotPink  = Color(0xFFFF3EA7);   // HOT PINK
  static const coral    = Color(0xFFFF6A3D);   // CORAL ORANGE
  static const yellow   = Color(0xFFFFC266);   // SOFT YELLOW (HIGHLIGHT)

  // Support / neutrals chosen to complement brand
  static const onDark   = Colors.white;        // Text on brand-dark surfaces
  static const onLight  = Color(0xFF0F0F14);   // Text on very light surfaces
  static const surface  = Color(0xFFFAF6FF);   // Subtle lilac-tinted background
  static const surface2 = Color(0xFFF2ECFF);   // Slightly deeper panel card
}

/// ------------------------------
/// Brand Gradients (centralized)
/// ------------------------------
class BrandGradients extends ThemeExtension<BrandGradients> {
  final LinearGradient appBar;
  final LinearGradient primarySweep; // fun sweep for hero areas
  final LinearGradient button;
  final LinearGradient dialogBar;

  const BrandGradients({
    required this.appBar,
    required this.primarySweep,
    required this.button,
    required this.dialogBar,
  });

  factory BrandGradients.defaultSet() => BrandGradients(
    appBar: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        BrandColors.deepNavy,
        BrandColors.purple,
        BrandColors.magenta,
        BrandColors.hotPink,
        BrandColors.coral,
      ],
      stops: [0.00, 0.25, 0.50, 0.75, 1.00],
    ),
    primarySweep: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        BrandColors.purple,
        BrandColors.magenta,
        BrandColors.hotPink,
        BrandColors.coral,
      ],
    ),
    button: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        BrandColors.purple,
        BrandColors.hotPink,
      ],
    ),
    dialogBar: const LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        BrandColors.deepNavy,
        BrandColors.magenta,
        BrandColors.coral,
        BrandColors.magenta,
        BrandColors.deepNavy,
      ],
      stops: [0.00, 0.18, 0.50, 0.82, 1.00],
    ),
  );

  @override
  BrandGradients copyWith({
    LinearGradient? appBar,
    LinearGradient? primarySweep,
    LinearGradient? button,
    LinearGradient? dialogBar,
  }) => BrandGradients(
    appBar: appBar ?? this.appBar,
    primarySweep: primarySweep ?? this.primarySweep,
    button: button ?? this.button,
    dialogBar: dialogBar ?? this.dialogBar,
  );

  @override
  BrandGradients lerp(ThemeExtension<BrandGradients>? other, double t) {
    if (other is! BrandGradients) return this;
    return BrandGradients(
      appBar: LinearGradient.lerp(appBar, other.appBar, t)!,
      primarySweep: LinearGradient.lerp(primarySweep, other.primarySweep, t)!,
      button: LinearGradient.lerp(button, other.button, t)!,
      dialogBar: LinearGradient.lerp(dialogBar, other.dialogBar, t)!,
    );
  }
}

/// Helper to access gradients from Theme
extension BrandGradientsX on BuildContext {
  BrandGradients get brandGradients => Theme.of(this).extension<BrandGradients>()!;
}

/// ------------------------------
/// App Theme (Material 3)
/// ------------------------------
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: _brandLightScheme,
      scaffoldBackgroundColor: BrandColors.surface,
      textTheme: GoogleFonts.montserratTextTheme().copyWith(
        bodyMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        bodyLarge:  GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        titleLarge:  GoogleFonts.montserrat(fontWeight: FontWeight.w600),

        labelLarge: GoogleFonts.bebasNeue(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontSize: 20, // tweak if you want bigger buttons globally
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 72,
        titleTextStyle: GoogleFonts.bebasNeue(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent, // we'll paint gradient in widgets
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            // ✅ Bebas Neue for material buttons
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.bebasNeue(
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                fontSize: 20,
              ),
            ),
            backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
            shadowColor: const WidgetStatePropertyAll(Colors.black54),
            elevation: const WidgetStatePropertyAll(2),
          ),
        ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: BrandColors.purple),
        ),
        floatingLabelStyle: TextStyle(color: BrandColors.purple),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: BrandColors.deepNavy,
        contentTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: BrandColors.surface2,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? BrandColors.purple
              : BrandColors.deepNavy.withValues(alpha: 0.4);
        }),
      ),
      extensions: <ThemeExtension<dynamic>>[
        BrandGradients.defaultSet(),
      ],
    );

    return base;
  }

  /// Optional: a dark theme that keeps brand accents punchy
  static ThemeData dark() {
    final base = ThemeData.dark(useMaterial3: true).copyWith(
      colorScheme: _brandDarkScheme,
      scaffoldBackgroundColor: const Color(0xFF0F1034),
      textTheme: GoogleFonts.montserratTextTheme(ThemeData.dark().textTheme).copyWith(
        labelLarge: GoogleFonts.bebasNeue(
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontSize: 20,
        ),
      ),
      appBarTheme: AppBarTheme(
        toolbarHeight: 72,
        titleTextStyle: GoogleFonts.bebasNeue(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          letterSpacing: 1.5,
        ),
        centerTitle: true,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      extensions: <ThemeExtension<dynamic>>[
        BrandGradients.defaultSet(),
      ],
    );

    return base;
  }

  // Carefully mapped brand colors to Material roles
  static const _brandLightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: BrandColors.purple,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE7DAFF),
    onPrimaryContainer: BrandColors.deepNavy,

    secondary: BrandColors.hotPink,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFD1EA),
    onSecondaryContainer: BrandColors.deepNavy,

    tertiary: BrandColors.coral,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE1D7),
    onTertiaryContainer: BrandColors.deepNavy,

    error: Color(0xFFB00020),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD4),
    onErrorContainer: Color(0xFF410002),

    surface: BrandColors.surface,
    onSurface: BrandColors.onLight,
    surfaceContainerHighest: BrandColors.surface2,
    surfaceContainerHigh: BrandColors.surface2,
    surfaceContainer: BrandColors.surface,
    surfaceContainerLow: BrandColors.surface,
    surfaceContainerLowest: Colors.white,

    outline: Color(0x33000000),
    outlineVariant: Color(0x1A000000),

    shadow: Color(0x33000000),
    scrim: Color(0x66000000),
    inversePrimary: BrandColors.yellow,
    inverseSurface: BrandColors.deepNavy,
    onInverseSurface: Colors.white,
  );

  static const _brandDarkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: BrandColors.purple,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFF3B1F8A),
    onPrimaryContainer: Colors.white,

    secondary: BrandColors.hotPink,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFF8C165E),
    onSecondaryContainer: Colors.white,

    tertiary: BrandColors.coral,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFF8E2F16),
    onTertiaryContainer: Colors.white,

    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    errorContainer: Color(0xFF93000A),
    onErrorContainer: Color(0xFFFFDAD6),

    surface: Color(0xFF111133),
    onSurface: Colors.white,
    surfaceContainerHighest: Color(0xFF1A1A3F),
    surfaceContainerHigh: Color(0xFF18183B),
    surfaceContainer: Color(0xFF161637),
    surfaceContainerLow: Color(0xFF141435),
    surfaceContainerLowest: Color(0xFF121233),

    outline: Color(0x33FFFFFF),
    outlineVariant: Color(0x1AFFFFFF),

    shadow: Color(0xCC000000),
    scrim: Color(0xCC000000),
    inversePrimary: BrandColors.yellow,
    inverseSurface: Colors.white,
    onInverseSurface: BrandColors.deepNavy,
  );
}

/// ------------------------------
/// Convenience Widgets / Painters
/// ------------------------------

/// A gradient-styled AppBar that uses the theme's BrandGradients.appBar
/// A gradient-styled AppBar that uses the theme's BrandGradients.appBar
PreferredSizeWidget gradientAppBar(
    BuildContext context,
    String title, {
      PreferredSizeWidget? bottom,
      List<Widget>? actions,
    }) {
  final gradients = context.brandGradients;
  return AppBar(
    title: Text(title),
    actions: actions,
    bottom: bottom,
    flexibleSpace: Container(
      decoration: BoxDecoration(
        gradient: gradients.appBar,
      ),
    ),
  );
}

/// Gradient button surface that you can wrap around ElevatedButton to match brand
class GradientButtonSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadiusGeometry borderRadius;

  const GradientButtonSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  Widget build(BuildContext context) {
    final gradients = context.brandGradients;
    return Container(
      decoration: BoxDecoration(
        gradient: gradients.button,
        borderRadius: borderRadius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            offset: const Offset(2, 4),
            blurRadius: 6,
          ),
        ],
      ),
      padding: padding,
      child: DefaultTextStyle(
        style: GoogleFonts.bebasNeue(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
          fontSize: 20,
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// A decorative bar for dialogs (replaces hard-coded gradient in RequestPage)
class DialogGradientBar extends StatelessWidget {
  const DialogGradientBar({super.key});

  @override
  Widget build(BuildContext context) {
    final gradients = context.brandGradients;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: gradients.dialogBar,
      ),
      alignment: Alignment.center,
      child: Text(
        'Submitted',
        style: Theme.of(context).appBarTheme.titleTextStyle,
      ),
    );
  }
}

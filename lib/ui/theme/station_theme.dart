import 'package:flutter/material.dart';

import 'station_palette.dart';

export 'station_palette.dart';

/// Body font of the Station UI (Vazirmatn, `font-weight:300` like the reference body).
const String kStationFont = 'Vazirmatn';

/// Latin small-caps labels (`.lat` → Cormorant Garamond, letter-spacing .16em, uppercase).
const String kStationLatin = 'CormorantGaramond';

/// Typography helpers of the Station UI.
class StationText {
  StationText._();

  static TextStyle lat(BuildContext context, {double size = 11, Color? color, FontWeight weight = FontWeight.w500}) =>
      TextStyle(
        fontFamily: kStationLatin,
        fontSize: size,
        letterSpacing: size * .16,
        fontWeight: weight,
        color: color ?? StationPalette.of(context).gold,
        height: 1.2,
      );

  static TextStyle body(BuildContext context, {double size = 14, FontWeight weight = FontWeight.w300, Color? color}) =>
      TextStyle(fontFamily: kStationFont, fontSize: size, fontWeight: weight, color: color ?? StationPalette.of(context).ink);

  static TextStyle mute(BuildContext context, {double size = 12}) =>
      TextStyle(fontFamily: kStationFont, fontSize: size, fontWeight: FontWeight.w300, color: StationPalette.of(context).mute);

  static TextStyle title(BuildContext context, {double size = 19}) =>
      TextStyle(fontFamily: kStationFont, fontSize: size, fontWeight: FontWeight.w400, color: StationPalette.of(context).ink);
}

/// The app theme: Material 3 wired to the Station tokens of [skin].
ThemeData buildStationTheme(StationSkin skin) {
  final StationPalette p = StationPalette.forSkin(skin);
  final bool light = p.isLight;
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: p.gold,
    brightness: light ? Brightness.light : Brightness.dark,
  ).copyWith(
    primary: p.gold,
    onPrimary: p.primaryInk,
    secondary: p.gold2,
    tertiary: p.gold3,
    surface: light ? Colors.white : const Color(0xFF0F0C2B),
    onSurface: p.ink,
    error: const Color(0xFFFF5A6E),
    outline: p.line,
  );
  final TextTheme base = (light ? ThemeData.light() : ThemeData.dark()).textTheme.apply(
        fontFamily: kStationFont,
        bodyColor: p.ink,
        displayColor: p.ink,
      );
  final OutlineInputBorder field = OutlineInputBorder(
    borderRadius: BorderRadius.circular(99),
    borderSide: BorderSide(color: p.line, width: light ? 2 : 1),
  );
  return ThemeData(
    useMaterial3: true,
    brightness: light ? Brightness.light : Brightness.dark,
    colorScheme: scheme,
    fontFamily: kStationFont,
    textTheme: base,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: <ThemeExtension<dynamic>>[p, NxThemeColors.fromPalette(p)],
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: p.ink,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: kStationFont, fontSize: 19, fontWeight: FontWeight.w400, color: p.ink),
    ),
    cardTheme: CardThemeData(
      color: light ? Colors.white : const Color(0xFF110D2E),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: BorderSide(color: p.line)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: light ? Colors.white : const Color(0xFF14103A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: p.gold)),
      titleTextStyle: TextStyle(fontFamily: kStationFont, fontSize: 20, fontWeight: FontWeight.w400, color: p.ink),
      contentTextStyle: TextStyle(fontFamily: kStationFont, fontSize: 13, color: p.mute),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: light ? Colors.white : const Color(0xFF14103A),
      modalBackgroundColor: light ? Colors.white : const Color(0xFF14103A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      showDragHandle: true,
      dragHandleColor: p.gold2.withValues(alpha: .25),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: light ? const Color(0xFF0A2276) : const Color(0xF0140C32),
      contentTextStyle: const TextStyle(fontFamily: kStationFont, fontSize: 12.5, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99), side: BorderSide(color: p.line)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      hintStyle: TextStyle(color: p.mute, fontFamily: kStationFont),
      labelStyle: TextStyle(color: p.mute, fontFamily: kStationFont),
      border: field,
      enabledBorder: field,
      focusedBorder: field.copyWith(borderSide: BorderSide(color: p.gold, width: light ? 2 : 1.2)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.primaryInk,
        textStyle: const TextStyle(fontFamily: kStationFont, fontWeight: FontWeight.w500, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.gold,
        foregroundColor: p.primaryInk,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        side: BorderSide(color: p.line, width: light ? 2 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.gold2)),
    iconTheme: IconThemeData(color: p.ink),
    dividerTheme: DividerThemeData(color: p.line, thickness: 1, space: 1),
    listTileTheme: ListTileThemeData(iconColor: p.gold2, textColor: p.ink),
    switchTheme: SwitchThemeData(
      thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) => s.contains(WidgetState.selected) ? p.gold : p.track),
      trackOutlineColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    ),
    sliderTheme: SliderThemeData(activeTrackColor: p.gold, thumbColor: p.gold2, inactiveTrackColor: p.track),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: p.gold, linearTrackColor: p.track),
    chipTheme: ChipThemeData(
      backgroundColor: p.inputFill,
      selectedColor: p.gold,
      side: BorderSide(color: p.line),
      shape: const StadiumBorder(),
      labelStyle: TextStyle(fontFamily: kStationFont, color: p.ink, fontSize: 12.5),
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.gold2,
      unselectedLabelColor: p.mute,
      indicatorColor: p.gold,
      dividerColor: p.line,
      labelStyle: const TextStyle(fontFamily: kStationFont, fontSize: 13.5, fontWeight: FontWeight.w500),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: StationPageTransitions(),
      TargetPlatform.iOS: StationPageTransitions(),
    }),
  );
}

/// `#scr` transition: rises 7% with a fade (`transform:translateY(7%);opacity:0` → none).
class StationPageTransitions extends PageTransitionsBuilder {
  const StationPageTransitions();

  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    final CurvedAnimation a = CurvedAnimation(parent: animation, curve: kStationEase, reverseCurve: Curves.easeIn);
    return FadeTransition(
      opacity: a,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, .07), end: Offset.zero).animate(a),
        child: child,
      ),
    );
  }
}

/// `--ease: cubic-bezier(.22,.8,.2,1)`.
const Curve kStationEase = Cubic(.22, .8, .2, 1);

// =====================================================================================================================
// Shared tokens for screens that still read flat colours (games' HUDs, tournaments, admin). Every value is taken from
// the Station NEON palette, so they render in the new look; themed screens read [StationPalette.of] instead.
// =====================================================================================================================

class NxColors {
  NxColors._();
  static const Color champagne = Color(0xFFFFE3C2);
  static const Color turquoise = Color(0xFF5CC8FF);
  static const Color gold = Color(0xFFFFC27A);
  static const Color pink = Color(0xFFFF4F8B);
  static const Color danger = Color(0xFFFF5A6E);
  static const Color success = Color(0xFF3DDC97);
  static const Color glass = Color(0x14FFFFFF);
  static const Color textDim = Color(0x9EFFECE0);
  static const Color luxeBg = Color(0xFF04031A);
  static const Color panel = Color(0xFF110D2E);
  static const Color panelWarm = Color(0xFF191045);
  static const Color goldLine = Color(0x4DFF7A3D);
  static const Color ink = Color(0xFFFFF0E6);
  static const Color mutedInk = Color(0x9EFFECE0);
  static const Color goldDeep = Color(0xFFFF7A3D);
}

/// Theme-aware colours for widgets outside the Station kit (`NxThemeColors.of(context)`).
@immutable
class NxThemeColors extends ThemeExtension<NxThemeColors> {
  const NxThemeColors({
    required this.accent,
    required this.accentSecondary,
    required this.background,
    required this.backgroundMid,
    required this.surface,
    required this.surfaceRaised,
    required this.border,
    required this.text,
    required this.muted,
    this.premiumPanels = true,
  });

  factory NxThemeColors.fromPalette(StationPalette p) => NxThemeColors(
        accent: p.gold,
        accentSecondary: p.gold2,
        background: p.bg,
        backgroundMid: p.isLight ? const Color(0xFFCFE0FF) : const Color(0xFF0A0820),
        surface: p.isLight ? Colors.white : const Color(0xFF110D2E),
        surfaceRaised: p.isLight ? const Color(0xFFF4F8FF) : const Color(0xFF191045),
        border: p.line,
        text: p.ink,
        muted: p.mute,
      );

  final Color accent;
  final Color accentSecondary;
  final Color background;
  final Color backgroundMid;
  final Color surface;
  final Color surfaceRaised;
  final Color border;
  final Color text;
  final Color muted;
  final bool premiumPanels;

  static final NxThemeColors neon = NxThemeColors.fromPalette(StationPalette.neon);
  static final NxThemeColors gameplay = NxThemeColors.fromPalette(StationPalette.neon);

  static NxThemeColors of(BuildContext context) => Theme.of(context).extension<NxThemeColors>() ?? neon;

  @override
  NxThemeColors copyWith() => this;

  @override
  NxThemeColors lerp(ThemeExtension<NxThemeColors>? other, double t) => other is NxThemeColors && t > .5 ? other : this;
}

/// Per-world accent (Station `W[i].c`).
@immutable
class WorldPalette {
  const WorldPalette(this.primary, this.secondary, this.background, {this.light = false});
  final Color primary;
  final Color secondary;
  final List<Color> background;
  final bool light;

  static const List<Color> _ramp = <Color>[Color(0xFF2A1560), Color(0xFF110D2E), Color(0xFF04031A)];
  static const WorldPalette hub = WorldPalette(Color(0xFFFF7A3D), Color(0xFFFFC27A), _ramp);
  static const WorldPalette nova = WorldPalette(Color(0xFFFF5C8A), Color(0xFFFFC27A), _ramp);
  static const WorldPalette orbit = WorldPalette(Color(0xFF5C7CFF), Color(0xFFFFC27A), _ramp);
  static const WorldPalette arcade = WorldPalette(Color(0xFFFF7A3D), Color(0xFFFFC27A), _ramp);
  static const WorldPalette oracle = WorldPalette(Color(0xFFC25BFF), Color(0xFFFFC27A), _ramp);
  static const WorldPalette personal = WorldPalette(Color(0xFF7C5CFF), Color(0xFFFFC27A), _ramp);
  static const WorldPalette social = WorldPalette(Color(0xFFFF6F61), Color(0xFFFFC27A), _ramp);
  static const WorldPalette exchange = WorldPalette(Color(0xFFFF9A3D), Color(0xFFFFC27A), _ramp);
}

class NxSpace {
  NxSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

class NxRadius {
  NxRadius._();
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
}

class NxMotion {
  NxMotion._();
  static const Duration fast = Duration(milliseconds: 160);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 550);
  static const Curve curve = kStationEase;
}

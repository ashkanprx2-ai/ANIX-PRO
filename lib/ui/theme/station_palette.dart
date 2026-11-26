import 'package:flutter/material.dart';

/// The two skins of the NEXORA Station UI (UI.zip: `nexora-neon.css` and `nexora-white.css`).
enum StationSkin { neon, white }

/// Design tokens of the NEXORA Station UI, one set per [StationSkin].
///
/// Names follow the CSS custom properties of the reference (`--bg`, `--ink`, `--mute`, `--gold`, `--gold2`, `--gold3`,
/// `--line`, `--glass`, `--neo`) so the Flutter widgets read like the stylesheet they were rebuilt from.
@immutable
class StationPalette extends ThemeExtension<StationPalette> {
  const StationPalette({
    required this.skin,
    required this.bg,
    required this.ink,
    required this.mute,
    required this.gold,
    required this.gold2,
    required this.gold3,
    required this.line,
    required this.glass,
    required this.primary,
    required this.primaryInk,
    required this.primaryShadow,
    required this.primaryBorder,
    required this.ghost,
    required this.ghostShadow,
    required this.cardFill,
    required this.cardBorder,
    required this.cardShadow,
    required this.plate,
    required this.plateInk,
    required this.tileFill,
    required this.tileBorder,
    required this.navBg,
    required this.navBorder,
    required this.popBg,
    required this.toastBg,
    required this.toastInk,
    required this.inputFill,
    required this.bar,
    required this.track,
    required this.dust,
    required this.hubImage,
    required this.worldImage,
    required this.screenImage,
    required this.logo,
    required this.worldColors,
  });

  final StationSkin skin;
  final Color bg;
  final Color ink;
  final Color mute;
  final Color gold;
  final Color gold2;
  final Color gold3;
  final Color line;
  final Gradient glass;

  /// Primary button (`.btn`): fill, text colour, the extruded 3D under-shadow and optional border.
  final Gradient primary;
  final Color primaryInk;
  final Color primaryShadow;
  final Color? primaryBorder;

  /// Ghost button (`.btn.g`).
  final Gradient ghost;
  final Color ghostShadow;

  /// Card (`.cd`): padding-box fill + border-box gradient border.
  final Gradient cardFill;
  final Gradient cardBorder;
  final Color cardShadow;

  /// Navy plate used by heroes / tiles in the white skin (and deep panel in neon).
  final Gradient plate;
  final Color plateInk;
  final Gradient tileFill;
  final Gradient tileBorder;
  final Color navBg;
  final Color navBorder;
  final Gradient popBg;
  final Gradient toastBg;
  final Color toastInk;
  final Color inputFill;
  final Gradient bar;
  final Color track;
  final Color dust;
  final String hubImage;
  final String worldImage;
  final String screenImage;
  final String logo;

  /// `PAL` in nexora-neon.js: the accent of every world, by index.
  final List<Color> worldColors;

  bool get isLight => skin == StationSkin.white;

  Color worldColor(int i) => worldColors[i % worldColors.length];

  static StationPalette of(BuildContext context) =>
      Theme.of(context).extension<StationPalette>() ?? StationPalette.neon;

  static StationPalette forSkin(StationSkin s) => s == StationSkin.white ? white : neon;

  // ---------------------------------------------------------------- NEON (orange / magenta / indigo)
  static const StationPalette neon = StationPalette(
    skin: StationSkin.neon,
    bg: Color(0xFF04031A),
    ink: Color(0xFFFFF0E6),
    mute: Color(0x9EFFECE0),
    gold: Color(0xFFFF7A3D),
    gold2: Color(0xFFFFC27A),
    gold3: Color(0xFFC43A7A),
    line: Color(0x4DFF7A3D),
    glass: LinearGradient(
        begin: Alignment(-0.5, -1), end: Alignment(0.5, 1), colors: <Color>[Color(0x14FFFFFF), Color(0x126E50FF)]),
    primary: LinearGradient(colors: <Color>[Color(0xFFFF9A3D), Color(0xFFFF4F8B)]),
    primaryInk: Color(0xFF1B0710),
    primaryShadow: Color(0xFF9C2250),
    primaryBorder: null,
    ghost: LinearGradient(
        begin: Alignment(-0.5, -1), end: Alignment(0.5, 1), colors: <Color>[Color(0x14FFFFFF), Color(0x126E50FF)]),
    ghostShadow: Color(0xFF1A1244),
    cardFill: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF110D2E), Color(0xFF0A0820)]),
    cardBorder: LinearGradient(
        begin: Alignment(-0.5, -1),
        end: Alignment(0.5, 1),
        colors: <Color>[Color(0xFFFF8A3D), Color(0xFFD63A8A), Color(0xFF4A5CFF)],
        stops: <double>[0, .55, 1]),
    cardShadow: Color(0x73000000),
    plate: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF191045), Color(0xFF0A0820)]),
    plateInk: Color(0xFFFFF0E6),
    tileFill: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF0F0C2B), Color(0xFF0A0820)]),
    tileBorder: LinearGradient(begin: Alignment(-0.5, -1), end: Alignment(0.5, 1), colors: <Color>[Color(0x99FF8A3D), Color(0x994A5CFF)]),
    navBg: Color(0xA80E0A28),
    navBorder: Color(0x4DFF7A3D),
    popBg: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF191045), Color(0xFF0A0820)]),
    toastBg: LinearGradient(colors: <Color>[Color(0xF0140C32), Color(0xF0140C32)]),
    toastInk: Color(0xFFFFF0E6),
    inputFill: Color(0x12FFFFFF),
    bar: LinearGradient(colors: <Color>[Color(0xFFFF9A3D), Color(0xFFFF4F8B), Color(0xFF6A5CFF)]),
    track: Color(0x24FFC27A),
    dust: Color(0xFFFFC27A),
    hubImage: 'assets/station/neon2/bg1.webp',
    worldImage: 'assets/station/neon2/bg2.webp',
    screenImage: 'assets/station/neon2/bg2.webp',
    logo: 'assets/station/neon2/logo.webp',
    worldColors: <Color>[
      Color(0xFFFF7A3D), Color(0xFFFF5C8A), Color(0xFFC25BFF), Color(0xFF5C7CFF),
      Color(0xFFFF9A3D), Color(0xFFFF6F61), Color(0xFF7C5CFF), Color(0xFFFFB03D),
    ],
  );

  // ---------------------------------------------------------------- WHITE (ice crystal, gold frames, navy plates)
  static const StationPalette white = StationPalette(
    skin: StationSkin.white,
    bg: Color(0xFFDFE9FF),
    ink: Color(0xFF0C1A4A),
    mute: Color(0xC70C1A4A),
    gold: Color(0xFFD19A22),
    gold2: Color(0xFFA8700A),
    gold3: Color(0xFF8D5F0A),
    line: Color(0x8CC9972B),
    glass: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xDBFFFFFF), Color(0xC7EAF3FF)]),
    primary: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF3A6BFF), Color(0xFF0A2AA8)]),
    primaryInk: Colors.white,
    primaryShadow: Color(0xFF061A6E),
    primaryBorder: Color(0xFFE0B04A),
    ghost: LinearGradient(colors: <Color>[Colors.white, Colors.white]),
    ghostShadow: Color(0x59785A14),
    cardFill: LinearGradient(colors: <Color>[Colors.white, Colors.white]),
    cardBorder: LinearGradient(
        begin: Alignment(-0.5, -1),
        end: Alignment(0.5, 1),
        colors: <Color>[Color(0xFFFFE596), Color(0xFFC98F1C), Color(0xFFFFE596)]),
    cardShadow: Color(0x735A3C0A),
    plate: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF1A3A9A), Color(0xFF071447)]),
    plateInk: Colors.white,
    tileFill: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF1A3A9A), Color(0xFF071447)]),
    tileBorder: LinearGradient(
        begin: Alignment(-0.5, -1),
        end: Alignment(0.5, 1),
        colors: <Color>[Color(0xFFFFE596), Color(0xFFC98F1C), Color(0xFFFFE596)]),
    navBg: Color(0xD1FFFFFF),
    navBorder: Color(0xFFD9A93A),
    popBg: LinearGradient(colors: <Color>[Colors.white, Color(0xFFE6EEFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
    toastBg: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF1A3A9A), Color(0xFF071447)]),
    toastInk: Colors.white,
    inputFill: Colors.white,
    bar: LinearGradient(colors: <Color>[Color(0xFFFFD77A), Color(0xFFD19A22)]),
    track: Color(0x330C1A4A),
    dust: Color(0xFFC9972B),
    hubImage: 'assets/station/white/bg.webp',
    worldImage: 'assets/station/white/bg.webp',
    screenImage: 'assets/station/white/bg.webp',
    logo: 'assets/station/white/logo.webp',
    worldColors: <Color>[
      Color(0xFFC98F1C), Color(0xFF2F62FF), Color(0xFFD1409A), Color(0xFF1AA0D0),
      Color(0xFFE07B2A), Color(0xFF7A4FE0), Color(0xFF18A07A), Color(0xFFC9A21C),
    ],
  );

  /// Resolves an atlas icon name (r1c1 … r5c6, g_*) to an asset. The atlas names that have a unified hub icon
  /// (`assets/station/hub/*.webp`) use it in both skins, so every screen shares one icon family.
  String icon(String name, {bool nav = false}) {
    final String? h = _hubIcons[name];
    if (h != null) return 'assets/station/hub/$h.webp';
    return 'assets/station/icons/$name.webp';
  }

  static const Map<String, String> _hubIcons = <String, String>{
    'r2c5': 'cup',
    'r2c6': 'rank',
    'r3c1': 'voice',
    'r3c2': 'listen',
    'r3c3': 'messages',
    'r3c4': 'friends',
    'r3c5': 'calendar',
    'r3c6': 'gift',
    'r4c1': 'shop',
    'r4c2': 'settings',
    'r4c3': 'medal',
    'r4c4': 'account',
    'r4c5': 'controller',
    'r4c6': 'duel',
    'r5c1': 'space',
    'r5c2': 'ai',
    'r5c3': 'news',
    'r5c4': 'cup',
    'r5c6': 'wheel',
  };

  @override
  StationPalette copyWith() => this;

  @override
  StationPalette lerp(ThemeExtension<StationPalette>? other, double t) =>
      other is StationPalette && t > .5 ? other : this;
}

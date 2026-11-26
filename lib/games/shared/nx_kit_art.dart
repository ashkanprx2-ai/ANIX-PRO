import 'package:flutter/material.dart';

/// NX kit: the owner's neon / gold UI art (uploads 2026-11-25, cut by tool/nx_kit_slice.py + tool/nx_kit_export2.py).
/// Every widget falls back to a Material icon when an asset fails to load, so a missing file never breaks a screen.
class NxKit {
  NxKit._();
  static const String _d = 'assets/ui/nx_kit/';
  static const String coin = '${_d}coin.webp';
  static const String gem = '${_d}gem.webp';
  static const String gemPurple = '${_d}gem_purple.webp';
  static const String goldOrb = '${_d}gold_orb.webp';
  static const String star = '${_d}star.webp';
  static const String trophy = '${_d}trophy.webp';
  static const String chest = '${_d}chest.webp';
  static const String ring = '${_d}ring.webp';
  static const String playButton = '${_d}play_button.webp';
  static const String toggleOn = '${_d}toggle_on.webp';
  static const String toggleOff = '${_d}toggle_off.webp';
  static const String close = '${_d}btn_close.webp';
  static const String back = '${_d}btn_back.webp';
  static const String btnRing = '${_d}btn_ring.webp';
  static const String energyRing = '${_d}energy_ring.webp';
  static const String badgeWings = '${_d}badge_wings.webp';
  static const String panelA = '${_d}panel_a.webp';
  static const String panelB = '${_d}panel_b.webp';
  static const String barCyan = '${_d}bar_cyan.webp';
  static const String barPurple = '${_d}bar_purple.webp';
  static const String barSmall = '${_d}bar_small.webp';
  static const String barSmallB = '${_d}bar_small_b.webp';
  static const String barTiny = '${_d}bar_tiny.webp';
  static const String die3dPurple = '${_d}die3d_purple.webp';
  static const String die3dPink = '${_d}die3d_pink.webp';
  static const String die3dPurpleB = '${_d}die3d_purple_b.webp';
  static const String die3dSilver = '${_d}die3d_silver.webp';
  static const String chipCyan = '${_d}chip_cyan.webp';
  static const String chipPurple = '${_d}chip_purple.webp';
  static const String chipCyanB = '${_d}chip_cyan_b.webp';
  static const String chipPurpleB = '${_d}chip_purple_b.webp';
  static const List<String> orbs = <String>[
    '${_d}orb_cyan.webp',
    '${_d}orb_green.webp',
    '${_d}orb_orange.webp',
    '${_d}orb_gray.webp',
  ];

  // gold / navy ornaments (142597, 142600, 142601)
  static const String cornerA = '${_d}ornate/corner_a.webp';
  static const String cornerB = '${_d}ornate/corner_b.webp';
  static const String cornerLarge = '${_d}ornate/corner_large.webp';
  static const String cornerScroll = '${_d}ornate/corner_scroll.webp';
  static const String medallion = '${_d}ornate/medallion.webp';
  static const String crest = '${_d}ornate/crest.webp';
  static const String dividerA = '${_d}ornate/divider_a.webp';
  static const String dividerB = '${_d}ornate/divider_b.webp';
  static const String headerA = '${_d}ornate/header_a.webp';
  static const String headerB = '${_d}ornate/header_b.webp';

  /// Gold emblems (142591), 10 tiers, lowest first.
  static String emblem(int i) => '${_d}emblems/emblem_${i.clamp(0, 9)}.webp';

  /// Crest shields / stickers (139192 bottom row).
  static const String shieldChampion = '${_d}badges/shield_champion.webp';
  static const String shieldEagle = '${_d}badges/shield_eagle.webp';
  static const String shieldLion = '${_d}badges/shield_lion.webp';
  static const String shieldStar = '${_d}badges/shield_star.webp';
  static const String shieldFootball = '${_d}badges/shield_football.webp';
  static const String stickerTrophy = '${_d}badges/sticker_trophy.webp';
  static const String stickerFireball = '${_d}badges/sticker_fireball.webp';
  static const String stickerGoal = '${_d}badges/sticker_goal.webp';

  /// Rarity -> shield badge for shop cards.
  static String rarityBadge(String rarity) => switch (rarity) {
        'legendary' => shieldChampion,
        'epic' => shieldEagle,
        'rare' => shieldStar,
        _ => shieldLion,
      };

  /// Rarity -> gold emblem (tier badges).
  static String rarityEmblem(String rarity) => switch (rarity) {
        'legendary' => emblem(9),
        'epic' => emblem(7),
        'rare' => emblem(4),
        _ => emblem(1),
      };
}

/// An NX kit image with an icon fallback.
class NxKitImage extends StatelessWidget {
  const NxKitImage(this.asset, {super.key, this.size = 18, this.fallback = Icons.circle, this.color, this.width,
      this.height, this.fit = BoxFit.contain});
  final String asset;
  final double size;
  final double? width, height;
  final IconData fallback;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final double w = width ?? size, h = height ?? size;
    final double dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    return Image.asset(
      asset,
      width: w,
      height: h,
      fit: fit,
      cacheWidth: (w * dpr).clamp(16, 1024).round(),
      filterQuality: FilterQuality.medium,
      errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
          Icon(fallback, size: size, color: color ?? const Color(0xFFFFC94A)),
    );
  }
}

/// The coin currency icon (gold coin with a star, upload 18816).
class NxCoinIcon extends StatelessWidget {
  const NxCoinIcon({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) =>
      NxKitImage(NxKit.coin, size: size, fallback: Icons.monetization_on_rounded, color: const Color(0xFFFFC94A));
}

/// The gem (الماس) currency icon (upload 139657).
class NxGemIcon extends StatelessWidget {
  const NxGemIcon({super.key, this.size = 18});
  final double size;
  @override
  Widget build(BuildContext context) =>
      NxKitImage(NxKit.gem, size: size, fallback: Icons.diamond_rounded, color: const Color(0xFF6FE7FF));
}

/// Gold ornamental corners around [child] (shop, result and tournament dialogs).
class NxOrnateFrame extends StatelessWidget {
  const NxOrnateFrame({super.key, required this.child, this.corner = 34, this.asset = NxKit.cornerA});
  final Widget child;
  final double corner;
  final String asset;

  @override
  Widget build(BuildContext context) {
    Widget c(double sx, double sy) => IgnorePointer(
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.diagonal3Values(sx, sy, 1),
            child: NxKitImage(asset, size: corner, fallback: Icons.crop_square_rounded),
          ),
        );
    return Stack(clipBehavior: Clip.none, children: <Widget>[
      child,
      Positioned(left: -4, top: -4, child: c(1, 1)),
      Positioned(right: -4, top: -4, child: c(-1, 1)),
      Positioned(left: -4, bottom: -4, child: c(1, -1)),
      Positioned(right: -4, bottom: -4, child: c(-1, -1)),
    ]);
  }
}

/// Gold header ornament + title (lobby / dialog headers).
class NxOrnateHeader extends StatelessWidget {
  const NxOrnateHeader({super.key, required this.title, this.color = const Color(0xFFFFD27A)});
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      const NxKitImage(NxKit.headerA, width: 120, height: 34, fallback: Icons.auto_awesome_rounded),
      const SizedBox(height: 2),
      Text(title,
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: 0.4)),
      const SizedBox(height: 4),
      const NxKitImage(NxKit.dividerA, width: 180, height: 14, fallback: Icons.more_horiz_rounded),
    ]);
  }
}

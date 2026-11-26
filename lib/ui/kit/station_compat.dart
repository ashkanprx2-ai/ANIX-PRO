import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/companion/companion.dart';
import '../../core/profile/profile_service.dart';
import '../widgets/companion_widgets.dart';
import 'station_kit.dart';

export 'station_awards.dart';
export 'station_kit.dart';

// =====================================================================================================================
// Station adapters for the pages that survived the rebuild (tournaments, admin, NOVA gallery, ORBIT network, social
// station, talk room, online lobby / match, game host and the games' own sheets).
//
// The old UI (core/ui2, core/widgets, core/theme) is deleted. These classes keep the call sites' constructor shapes but
// every one of them now draws with the Station kit (StationSurface / StationButton / StationScreen / Station palette
// and sheets), so no old-look widget remains anywhere in the app.
// =====================================================================================================================

// ------------------------------------------------------------------------------------------------ tokens

/// Station colour tokens under the names the surviving pages read (`Luxe.gold`, `Luxe.inkOf(context)` …).
class Luxe {
  Luxe._();

  static const Color bg = Color(0xFF04031A);
  static const Color ink = Color(0xFFFFF0E6);
  static const Color mute = Color(0x9EFFECE0);
  static const Color gold = Color(0xFFFFC27A);
  static const Color gold2 = Color(0xFFFFE3C2);
  static const Color gold3 = Color(0xFFFF7A3D);
  static const Color line = Color(0x4DFF7A3D);
  static const Color panel = Color(0xFF110D2E);

  static const Color dayBg = Color(0xFFEAF1FF);
  static const Color dayInk = Color(0xFF0B1F5C);
  static const Color dayMute = Color(0xB30B1F5C);
  static const Color dayGold = Color(0xFF2A55E0);
  static const Color dayGold2 = Color(0xFF4F7BFF);
  static const Color dayLine = Color(0x332A55E0);
  static const Color dayPanel = Colors.white;

  static bool isLight(BuildContext context) => StationPalette.of(context).isLight;
  static Color bgOf(BuildContext context) => StationPalette.of(context).bg;
  static Color inkOf(BuildContext context) => StationPalette.of(context).ink;
  static Color muteOf(BuildContext context) => StationPalette.of(context).mute;
  static Color goldOf(BuildContext context) => StationPalette.of(context).gold;
  static Color lineOf(BuildContext context) => StationPalette.of(context).line;
  static Color panelOf(BuildContext context) => isLight(context) ? dayPanel : panel;

  static const LinearGradient goldGrad =
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFFFF9A3D), Color(0xFFFF4F8B)]);
  static const LinearGradient dayGoldGrad =
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF3A6BFF), Color(0xFF0A2AA8)]);
  static const LinearGradient glass = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF110D2E), Color(0xFF0A0820)]);
  static const LinearGradient dayGlass =
      LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Colors.white, Color(0xFFF4F8FF)]);
  static const Curve ease = kStationEase;

  static const String hubBg = 'assets/station/hub.webp';
  static const String splash = 'assets/station/splash.webp';
  static String icon(String n) => 'assets/station/icons/$n.webp';

  static TextStyle get latin => const TextStyle(fontFamily: kStationLatin, letterSpacing: 1.8, fontWeight: FontWeight.w600, color: gold, fontSize: 11);

  static bool reduceMotion(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}

class LuxeSpace {
  LuxeSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 14;
  static const double lg = 20;
  static const double xl = 28;
}

class LuxeRadius {
  LuxeRadius._();
  static const double sm = 14;
  static const double md = 20;
  static const double lg = 26;
  static const double pill = 99;
}

/// Flat Station tokens under the names the games' sheets and the tournament pages read (`Nx2.text` …).
class Nx2 {
  Nx2._();
  static const Color deep = Color(0xFF04031A);
  static const Color night = Color(0xFF110D2E);
  static const Color plum = Color(0xFF191045);
  static const Color violet = Color(0xFF7C5CFF);
  static const Color magenta = Color(0xFFFF4F8B);
  static const Color cyan = Color(0xFFFFC27A);
  static const Color gold = Color(0xFFFFC27A);
  static const Color goldDeep = Color(0xFFFF7A3D);
  static const Color text = Color(0xFFFFF0E6);
  static const Color muted = Color(0x9EFFECE0);
  static const Color success = Color(0xFF3DDC97);
  static const Color danger = Color(0xFFFF5A6E);

  static const LinearGradient neon = LinearGradient(colors: <Color>[Color(0xFFFF9A3D), Color(0xFFFF4F8B)]);
  static const LinearGradient goldGrad = LinearGradient(colors: <Color>[Color(0xFFFFE3C2), Color(0xFFFFC27A), Color(0xFFFF7A3D)]);

  static const TextStyle title = TextStyle(fontFamily: kStationFont, fontSize: 18, fontWeight: FontWeight.w500, color: text);
  static const TextStyle label = TextStyle(fontFamily: kStationFont, fontSize: 12, fontWeight: FontWeight.w500, color: text);
}

/// Background scene of a page; every value draws the Station skin background.
enum Nx2Scene { castle, room, hub, social, arcade, voiceStage, trophyHall, panorama }

/// Bottom-dock destinations (kept for call sites; the Station home has its own floating nav).
enum Nx2Tab { home, social, oracle, games, shop, tournaments, rewards, profile }

/// One in-page section (NOVA's Feed/Explore/Reels, ORBIT's Chats/Calls/Contacts) → a Station `.tabs` entry.
class NxDockSection {
  const NxDockSection({required this.icon, required this.label, this.badge = 0, this.activeIcon});
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final int badge;
}

// ------------------------------------------------------------------------------------------------ scaffolds

/// A world page → `#scr` ([StationScreen]) with optional `.tabs` sections on top.
class NxWorldScaffold extends StatelessWidget {
  const NxWorldScaffold({
    super.key,
    required this.title,
    this.palette = WorldPalette.hub,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.showWallet = true,
    this.dock,
    this.sections,
    this.sectionIndex = 0,
    this.onSectionSelect,
    this.room = false,
    this.scene,
  });
  final String title;
  final WorldPalette palette;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool showWallet;
  final Nx2Tab? dock;
  final List<NxDockSection>? sections;
  final int sectionIndex;
  final ValueChanged<int>? onSectionSelect;
  final bool room;
  final Nx2Scene? scene;

  @override
  Widget build(BuildContext context) {
    final List<NxDockSection>? s = sections;
    return StationScreen(
      title: title,
      balance: showWallet,
      actions: actions ?? const <Widget>[],
      fab: floatingActionButton,
      bottom: bottomNavigationBar,
      child: s == null || s.isEmpty
          ? body
          : Column(children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: StationTabs(
                  labels: <String>[for (final NxDockSection d in s) d.badge > 0 ? '${d.label} · ${nxNum(context, d.badge)}' : d.label],
                  index: sectionIndex.clamp(0, s.length - 1),
                  onChanged: (int i) => onSectionSelect?.call(i),
                ),
              ),
              Expanded(child: body),
            ]),
    );
  }
}

/// Page background → Station skin backdrop.
class NxBackground extends StatelessWidget {
  const NxBackground({super.key, this.palette = WorldPalette.hub, this.child, this.stars = true});
  final WorldPalette palette;
  final Widget? child;
  final bool stars;

  @override
  Widget build(BuildContext context) =>
      StationBackdrop(image: StationPalette.of(context).screenImage, dust: stars, child: child ?? const SizedBox.expand());
}

class NxBrandBackground extends StatelessWidget {
  const NxBrandBackground({super.key, this.child, this.room = false, this.scene});
  final Widget? child;
  final bool room;
  final Nx2Scene? scene;

  @override
  Widget build(BuildContext context) =>
      StationBackdrop(image: StationPalette.of(context).screenImage, dust: false, child: child ?? const SizedBox.expand());
}

/// `.cd` card. Keeps the old named parameters; [tint] / [borderColor] become a soft glow / hairline.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(NxSpace.md),
    this.radius = NxRadius.lg,
    this.tint,
    this.borderColor,
    this.blur = true,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  final Color? borderColor;
  final bool blur;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget s = StationSurface(
      radius: radius,
      padding: padding,
      border: borderColor == null ? null : LinearGradient(colors: <Color>[borderColor!, borderColor!.withValues(alpha: .35)]),
      glow: tint == null ? null : tint!.withValues(alpha: (tint!.a * 4).clamp(0, .45)),
      child: child,
    );
    return onTap == null ? s : StationPress(onTap: onTap, tilt: false, child: s);
  }
}

class Nx2Panel extends StatelessWidget {
  const Nx2Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.cut = 14,
    this.gold = false,
    this.tint,
    this.borderColor,
    this.glow = 0.35,
    this.gems = false,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double cut;
  final bool gold;
  final Color? tint;
  final Color? borderColor;
  final double glow;
  final bool gems;

  @override
  Widget build(BuildContext context) =>
      GlassPanel(padding: padding, radius: 22, tint: tint, borderColor: borderColor ?? (gold ? StationPalette.of(context).gold : null), onTap: onTap, child: child);
}

class LuxeCard extends StatelessWidget {
  const LuxeCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(LuxeSpace.md),
    this.radius = LuxeRadius.lg,
    this.onTap,
    this.semantics,
    this.glow,
    this.tint,
    this.borderColor,
    this.blur = 12,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final String? semantics;
  final Color? glow;
  final Color? tint;
  final Color? borderColor;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final Widget s = StationSurface(
      radius: radius,
      padding: padding,
      glow: glow,
      border: borderColor == null ? null : LinearGradient(colors: <Color>[borderColor!, borderColor!.withValues(alpha: .35)]),
      child: child,
    );
    final Widget w = onTap == null ? s : StationPress(onTap: onTap, tilt: false, child: s);
    return semantics == null ? w : Semantics(label: semantics, button: onTap != null, child: w);
  }
}

// ------------------------------------------------------------------------------------------------ small parts

/// `.pill` chip.
class NxPill extends StatelessWidget {
  const NxPill({super.key, required this.label, this.icon, this.color});
  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Color c = color ?? p.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: p.isLight ? .14 : .12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: c.withValues(alpha: .45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: 14, color: c), const SizedBox(width: 4)],
        Flexible(
          child: Text(label,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: kStationFont, fontSize: 11.5, fontWeight: FontWeight.w500, color: p.isLight ? p.ink : c)),
        ),
      ]),
    );
  }
}

class XpBar extends ConsumerWidget {
  const XpBar({super.key, this.height = 10});
  final double height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileService p = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: <Widget>[
      Row(children: <Widget>[
        Text(fa ? 'سطح ${nxNum(context, p.level)}' : 'Level ${p.level}', style: StationText.body(context, size: 13, weight: FontWeight.w500)),
        const Spacer(),
        Text('${nxNum(context, p.xpIntoLevel)} XP', style: StationText.mute(context, size: 11)),
      ]),
      StationBar(p.levelProgress, height: height * .6),
    ]);
  }
}

/// The active companion (ORACLE or LUNA) in a pose — every former "ORACLE avatar" call site.
class OracleAvatar extends StatelessWidget {
  const OracleAvatar({super.key, this.pose = 'idle', this.size = 90});
  final String pose;
  final double size;

  static CompanionMood moodFor(String pose) => switch (pose) {
        'sleep' => CompanionMood.sleep,
        'calm' => CompanionMood.smart,
        'present' => CompanionMood.sign,
        'hero_wave' || 'wave' => CompanionMood.salute,
        'happy' => CompanionMood.cheer,
        'think' => CompanionMood.smart,
        'sad' => CompanionMood.cry,
        _ => CompanionMood.happy,
      };

  @override
  Widget build(BuildContext context) => CompanionMascot(mood: moodFor(pose), size: size);
}

class OnlineOnlyNotice extends StatelessWidget {
  const OnlineOnlyNotice({super.key, required this.featureFa, required this.featureEn});
  final String featureFa;
  final String featureEn;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    return StationCard(
      child: Row(children: <Widget>[
        Icon(Icons.cloud_off_rounded, color: p.gold),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            fa ? '$featureFa به اینترنت و حساب آنلاین نیاز دارد.' : '$featureEn needs an internet connection and an online account.',
            style: StationText.body(context, size: 13),
          ),
        ),
      ]),
    );
  }
}

class Nx2SectionHeader extends StatelessWidget {
  const Nx2SectionHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => StationTitle(
        title,
        trailing: action == null
            ? null
            : GestureDetector(
                onTap: onAction,
                child: Text(action!, style: TextStyle(fontFamily: kStationFont, color: StationPalette.of(context).gold, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ),
      );
}

class LuxeSection extends StatelessWidget {
  const LuxeSection({super.key, required this.title, this.trailing, this.top = LuxeSpace.lg});
  final String title;
  final Widget? trailing;
  final double top;

  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: top - 12 < 0 ? 0 : top - 12), child: StationTitle(title, trailing: trailing));
}

class LuxeStat extends StatelessWidget {
  const LuxeStat({super.key, required this.label, this.icon, this.color, this.onTap});
  final String label;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Color c = color ?? p.gold;
    final Widget chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(gradient: p.ghost, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line)),
      child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (icon != null) ...<Widget>[Icon(icon, size: 15, color: c), const SizedBox(width: 6)],
        Text(label, style: TextStyle(fontFamily: kStationFont, fontSize: 12.5, color: p.ink, fontWeight: FontWeight.w500)),
      ]),
    );
    return onTap == null ? chip : StationPress(onTap: onTap, tilt: false, child: chip);
  }
}

class LuxeListRow extends StatelessWidget {
  const LuxeListRow({super.key, required this.title, this.subtitle, this.leading, this.trailing, this.onTap, this.selected = false, this.tint});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool selected;
  final Color? tint;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          radius: 20,
          borderColor: selected ? StationPalette.of(context).gold : null,
          tint: tint,
          child: StationRow(first: true, leading: leading, title: title, subtitle: subtitle, trailing: trailing, onTap: onTap),
        ),
      );
}

class LuxeEmpty extends StatelessWidget {
  const LuxeEmpty({super.key, required this.title, this.message, this.icon = Icons.auto_awesome_outlined, this.action});
  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 12),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        const CompanionMascot(mood: CompanionMood.confused, size: 96),
        const SizedBox(height: 10),
        Text(title, textAlign: TextAlign.center, style: StationText.title(context, size: 16)),
        if (message != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: TextStyle(fontFamily: kStationFont, color: p.mute, fontSize: 12.5, height: 1.7)),
        ],
        if (action != null) ...<Widget>[const SizedBox(height: 12), action!],
      ]),
    );
  }
}

class LuxeLoading extends StatelessWidget {
  const LuxeLoading({super.key, this.label, this.height = 120});
  final String? label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return SizedBox(
      height: height,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.4, color: p.gold)),
          if (label != null) ...<Widget>[const SizedBox(height: 10), Text(label!, style: StationText.mute(context))],
        ]),
      ),
    );
  }
}

class LuxeHeader extends StatelessWidget {
  const LuxeHeader({super.key, required this.title, this.subtitle, this.onBack, this.trailing = const <Widget>[], this.showBack = true});
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final List<Widget> trailing;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        child: Row(children: <Widget>[
          if (showBack) ...<Widget>[
            StationRoundButton(icon: Icons.arrow_back_rounded, onTap: onBack ?? () => Navigator.of(context).maybePop(), tooltip: stx(context, 'بازگشت', 'Back')),
            const SizedBox(width: 11),
          ],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: StationText.title(context)),
              if (subtitle != null) Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: StationText.mute(context, size: 11.5)),
            ]),
          ),
          ...trailing.map((Widget w) => Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: w)),
        ]),
      );
}

// ------------------------------------------------------------------------------------------------ buttons & toggles

class LuxePress extends StatelessWidget {
  const LuxePress({super.key, required this.child, this.onTap, this.semantics});
  final Widget child;
  final VoidCallback? onTap;
  final String? semantics;

  @override
  Widget build(BuildContext context) {
    final Widget w = StationPress(onTap: onTap, tilt: false, child: child);
    return semantics == null ? w : Semantics(label: semantics, button: true, child: w);
  }
}

enum LuxeButtonKind { primary, ghost, danger }

class LuxeButton extends StatelessWidget {
  const LuxeButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.kind = LuxeButtonKind.primary,
    this.height = 52,
    this.fontSize = 14,
    this.loading = false,
    this.expand = true,
    this.uppercase = true,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final LuxeButtonKind kind;
  final double height;
  final double fontSize;
  final bool loading;
  final bool expand;
  final bool uppercase;

  @override
  Widget build(BuildContext context) => StationButton(
        label: label,
        icon: icon,
        onTap: onTap,
        busy: loading,
        expand: expand,
        small: height < 46,
        ghost: kind == LuxeButtonKind.ghost,
        danger: kind == LuxeButtonKind.danger,
      );
}

class LuxeIconButton extends StatelessWidget {
  const LuxeIconButton({super.key, required this.icon, this.onTap, this.tooltip, this.size = 42, this.color});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => StationRoundButton(icon: icon, onTap: onTap, tooltip: tooltip, size: size);
}

class AnixSwitchTile extends StatelessWidget {
  const AnixSwitchTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.activeColor,
  });
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => _StationTileRow(
        padding: contentPadding,
        leading: secondary,
        title: title,
        subtitle: subtitle,
        trailing: StationToggle(value: value, onChanged: (bool v) => onChanged?.call(v)),
        onTap: onChanged == null ? null : () => onChanged!(!value),
        enabled: onChanged != null,
      );
}

class AnixCheckboxTile extends StatelessWidget {
  const AnixCheckboxTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.title,
    this.subtitle,
    this.secondary,
    this.contentPadding,
    this.dense,
    this.activeColor,
  });
  final bool value;
  final ValueChanged<bool?>? onChanged;
  final Widget? title;
  final Widget? subtitle;
  final Widget? secondary;
  final EdgeInsetsGeometry? contentPadding;
  final bool? dense;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return _StationTileRow(
      padding: contentPadding,
      leading: secondary,
      title: title,
      subtitle: subtitle,
      enabled: onChanged != null,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      trailing: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          gradient: value ? p.primary : null,
          borderRadius: BorderRadius.circular(8),
          border: value ? null : Border.all(color: p.line, width: 1.5),
        ),
        child: value ? Icon(Icons.check_rounded, size: 17, color: p.primaryInk) : null,
      ),
    );
  }
}

class _StationTileRow extends StatelessWidget {
  const _StationTileRow({this.padding, this.leading, this.title, this.subtitle, required this.trailing, this.onTap, this.enabled = true});
  final EdgeInsetsGeometry? padding;
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Opacity(
      opacity: enabled ? 1 : .5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(vertical: 10),
          child: Row(children: <Widget>[
            if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
                if (title != null)
                  DefaultTextStyle.merge(style: TextStyle(fontFamily: kStationFont, color: p.ink, fontSize: 14, fontWeight: FontWeight.w400), child: title!),
                if (subtitle != null)
                  DefaultTextStyle.merge(style: TextStyle(fontFamily: kStationFont, color: p.mute, fontSize: 12, height: 1.5), child: subtitle!),
              ]),
            ),
            const SizedBox(width: 10),
            trailing,
          ]),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ dialogs, sheets, toasts

/// Station `#modal` card as a dialog.
class AnixDialog extends StatelessWidget {
  const AnixDialog({super.key, this.title, this.content, this.actions, this.icon, this.backgroundColor, this.shape});
  final Widget? title;
  final Color? backgroundColor;
  final ShapeBorder? shape;
  final Widget? content;
  final List<Widget>? actions;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: StationSurface(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
        child: Theme(
          data: Theme.of(context).copyWith(
            textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.mute, textStyle: const TextStyle(fontFamily: kStationFont))),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: p.gold,
                foregroundColor: p.primaryInk,
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontFamily: kStationFont, fontWeight: FontWeight.w500),
              ),
            ),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            if (icon != null) Center(child: IconTheme.merge(data: IconThemeData(color: p.gold, size: 34), child: icon!)),
            if (icon != null) const SizedBox(height: 10),
            if (title != null)
              DefaultTextStyle.merge(
                style: TextStyle(fontFamily: kStationFont, fontSize: 17, fontWeight: FontWeight.w500, color: p.ink),
                textAlign: TextAlign.center,
                child: title!,
              ),
            if (content != null) ...<Widget>[
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: DefaultTextStyle.merge(style: TextStyle(fontFamily: kStationFont, fontSize: 13.5, height: 1.7, color: p.mute), child: content!),
                ),
              ),
            ],
            if (actions != null && actions!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: actions!),
            ],
          ]),
        ),
      ),
    );
  }
}

/// Station `#sheet` around an arbitrary builder (keeps showModalBottomSheet's options).
Future<T?> showAnixSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useSafeArea = false,
  bool? showDragHandle,
  BoxConstraints? constraints,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    showDragHandle: false,
    constraints: constraints,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C030306),
    builder: (BuildContext ctx) => _StationSheetFrame(child: Builder(builder: builder)),
  );
}

Future<T?> showLuxeSheet<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showAnixSheet<T>(context: context, builder: builder, isScrollControlled: true);

class _StationSheetFrame extends StatelessWidget {
  const _StationSheetFrame({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: p.popBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border(top: BorderSide(color: p.line)),
        boxShadow: <BoxShadow>[BoxShadow(color: p.cardShadow, blurRadius: 30)],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Container(
            width: 44,
            height: 5,
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            decoration: BoxDecoration(color: p.mute.withValues(alpha: .4), borderRadius: BorderRadius.circular(99)),
          ),
          Flexible(child: child),
        ]),
      ),
    );
  }
}

Future<bool?> showLuxeConfirm(
  BuildContext context, {
  required String title,
  String? message,
  String confirm = 'OK',
  String? cancel,
  bool danger = false,
}) =>
    showStationConfirm(context, title: title, message: message ?? '', confirm: confirm, cancel: cancel, danger: danger);

Future<String?> showLuxePrompt(
  BuildContext context, {
  required String title,
  String? message,
  String? hint,
  String confirm = 'OK',
  int maxLength = 60,
  String? initial,
}) =>
    showStationPrompt(context, title: title, message: message ?? '', hint: hint ?? '', initial: initial ?? '', confirm: confirm, maxLength: maxLength);

/// Station `#toast` (pill at the bottom). With an action it uses the messenger so the action stays tappable.
void luxeToast(
  BuildContext context,
  String message, {
  bool error = false,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  if (actionLabel == null || onAction == null) {
    stationToast(context, message, error: error, duration: duration);
    return;
  }
  final ScaffoldMessengerState? m = ScaffoldMessenger.maybeOf(context);
  if (m == null) return;
  luxeToastState(m, message, error: error, icon: icon, actionLabel: actionLabel, onAction: onAction, duration: duration);
}

/// The same toast for callers holding only the root messenger (call / invite / announcement / tournament watchers).
void luxeToastState(
  ScaffoldMessengerState m,
  String message, {
  bool error = false,
  IconData? icon,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final StationPalette p = StationPalette.of(m.context);
  final bool hasAction = actionLabel != null && onAction != null;
  m
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      duration: hasAction ? const Duration(seconds: 8) : duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: p.toastBg,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: error ? const Color(0xFFFF5A6E) : p.line),
          boxShadow: <BoxShadow>[BoxShadow(color: p.cardShadow, blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: <Widget>[
          if (icon != null || error) ...<Widget>[
            Icon(icon ?? Icons.error_outline_rounded, size: 18, color: error ? const Color(0xFFFF5A6E) : p.toastInk),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(message, style: TextStyle(fontFamily: kStationFont, color: p.toastInk, fontSize: 13, fontWeight: FontWeight.w400))),
          if (hasAction)
            GestureDetector(
              onTap: () {
                m.hideCurrentSnackBar();
                onAction();
              },
              child: Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(99)),
                child: Text(actionLabel, style: TextStyle(fontFamily: kStationFont, color: p.primaryInk, fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
        ]),
      ),
    ));
}

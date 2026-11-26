import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/profile/profile_service.dart';
import '../../core/storage/local_store.dart';
import '../../core/settings/app_settings.dart';
import '../theme/station_theme.dart';

export '../theme/station_theme.dart';

// =====================================================================================================================
// NEXORA Station UI kit — native Flutter rebuild of UI.zip (NEXORA_Station_Luxe.html + nexora-*.css).
// Class names map to the reference CSS: StationCard = .cd, StationButton = .btn, StationSeg = .seg, StationTabs = .tabs,
// StationToggle = .tg, StationTile = .tile, StationRow = .row, StationBar = .bar, StationStat = .stat,
// StationLetter = .a / .sq, StationGameCard = .gcard, StationScreen = #scr, showStationModal = #modal, stationToast =
// #toast, showStationSheet = #sheet, StationDust = #dust canvas.
// =====================================================================================================================

/// Persian digits (`toLocaleString('fa-IR')`) when the UI is Persian.
String nxNum(BuildContext context, num n, {bool group = true}) {
  final bool fa = Localizations.maybeLocaleOf(context)?.languageCode != 'en';
  String s = n is int || n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(1);
  if (group) {
    final bool neg = s.startsWith('-');
    String d = neg ? s.substring(1) : s;
    final List<String> parts = d.split('.');
    final String i = parts[0].replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    d = parts.length > 1 ? '$i.${parts[1]}' : i;
    s = neg ? '-$d' : d;
  }
  if (!fa) return s;
  const String f = '۰۱۲۳۴۵۶۷۸۹';
  return s.replaceAllMapped(RegExp(r'[0-9,]'), (Match m) => m[0] == ',' ? '٬' : f[int.parse(m[0]!)]);
}

bool stationFa(BuildContext context) => Localizations.maybeLocaleOf(context)?.languageCode != 'en';
String stx(BuildContext context, String fa, String en) => stationFa(context) ? fa : en;

/// Icon from the UI.zip icon atlas (r1c1 … r5c6, g_*), swapped per skin like the CSS `content:url()` rules.
class StationIcon extends StatelessWidget {
  const StationIcon(this.name, {super.key, this.size = 48, this.nav = false, this.radius});
  final String name;
  final double size;
  final bool nav;
  final double? radius;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool cover = name.startsWith('g_');
    Widget img = Image.asset(
      name.startsWith('assets/') ? name : p.icon(name, nav: nav),
      width: size,
      height: size,
      fit: cover ? BoxFit.cover : BoxFit.contain,
      cacheWidth: (size * 3).round(),
      errorBuilder: (_, __, ___) => Icon(Icons.blur_on_rounded, size: size * .7, color: p.gold),
    );
    if (cover) {
      img = ClipRRect(borderRadius: BorderRadius.circular(radius ?? size * .27), child: img);
    }
    return img;
  }
}

// ------------------------------------------------------------------------------------------------ backdrop + dust

/// Full-bleed background (`#hubbg` / `#world::before` / `#scr`): the skin's image, a soft vignette and gold dust.
class StationBackdrop extends ConsumerWidget {
  const StationBackdrop({super.key, required this.child, this.image, this.dust = true, this.tint, this.opacity = 1});
  final Widget child;
  final String? image;
  final bool dust;
  final Color? tint;
  final double opacity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StationPalette p = StationPalette.of(context);
    final bool low = ref.watch(settingsProvider.select((AppSettings s) => s.quality == GraphicsQuality.low));
    return Stack(fit: StackFit.expand, children: <Widget>[
      ColoredBox(color: p.bg),
      if (!p.isLight)
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.1, colors: <Color>[Color(0xFF2A1560), Color(0x0004031A)]),
          ),
        ),
      Opacity(
        opacity: opacity,
        child: Image.asset(image ?? p.screenImage, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
      ),
      DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: p.isLight
                ? const <Color>[Color(0x40FFFFFF), Color(0x00FFFFFF), Color(0x80DFE9FF)]
                : const <Color>[Color(0x8004031A), Color(0x0004031A), Color(0xC704031A)],
            stops: const <double>[0, .4, 1],
          ),
        ),
      ),
      if (tint != null)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
                center: const Alignment(0, -1), radius: 1.0, colors: <Color>[tint!.withValues(alpha: .22), tint!.withValues(alpha: 0)]),
          ),
        ),
      if (dust && !low) IgnorePointer(child: StationDust(color: p.dust, opacity: p.isLight ? .45 : 1)),
      child,
    ]);
  }
}

/// `#dust`: 48 slow rising motes that twinkle.
class StationDust extends StatefulWidget {
  const StationDust({super.key, required this.color, this.opacity = 1});
  final Color color;
  final double opacity;

  @override
  State<StationDust> createState() => _StationDustState();
}

class _StationDustState extends State<StationDust> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 60))..repeat();
  final List<_Mote> _m = List<_Mote>.generate(48, (int i) {
    final math.Random r = math.Random(i * 7919);
    return _Mote(r.nextDouble(), r.nextDouble(), .4 + r.nextDouble() * 1.3, .06 + r.nextDouble() * .1, r.nextDouble() * 6);
  });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return const SizedBox.shrink();
    return Opacity(
      opacity: widget.opacity,
      child: RepaintBoundary(
        child: CustomPaint(painter: _DustPainter(_c, _m, widget.color), size: Size.infinite),
      ),
    );
  }
}

class _Mote {
  _Mote(this.x, this.y, this.r, this.s, this.a);
  final double x, y, r, s, a;
}

class _DustPainter extends CustomPainter {
  _DustPainter(this.anim, this.motes, this.color) : super(repaint: anim);
  final Animation<double> anim;
  final List<_Mote> motes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double t = anim.value * 60000;
    final Paint p = Paint();
    for (final _Mote m in motes) {
      final double y = (m.y - t * m.s * .00003) % 1.04 - .02;
      final double x = (m.x + math.sin(t * .0003 + m.a) * .01) * size.width;
      final double al = .12 + .32 * (.5 + .5 * math.sin(t * .0011 + m.a));
      p.color = color.withValues(alpha: al);
      canvas.drawCircle(Offset(x, (1 - y) * size.height), m.r, p);
    }
  }

  @override
  bool shouldRepaint(covariant _DustPainter old) => false;
}

// ------------------------------------------------------------------------------------------------ press layer

/// The "light 3D press layer" of nexora-nav.js: neon cards tilt toward the finger and sink a little, a ring bursts at
/// the touch point; white skin and low quality just scale down.
class StationPress extends ConsumerStatefulWidget {
  const StationPress({super.key, required this.child, this.onTap, this.onLongPress, this.tilt = true, this.burst = true});
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool tilt;
  final bool burst;

  @override
  ConsumerState<StationPress> createState() => _StationPressState();
}

class _StationPressState extends ConsumerState<StationPress> with SingleTickerProviderStateMixin {
  Offset? _local;
  Size _size = Size.zero;
  late final AnimationController _ring = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  Offset _ringAt = Offset.zero;

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    // Station chrome is also drawn inside bare game widgets (tests, embedded boards) where no store exists yet.
    final AppSettings? s = LocalStore.ready ? ref.watch(settingsProvider) : null;
    final bool fancy = s != null && !p.isLight && s.quality != GraphicsQuality.low && !s.reducedMotion;
    final bool enabled = widget.onTap != null || widget.onLongPress != null;
    Matrix4 m = Matrix4.identity();
    if (_local != null && _size != Size.zero) {
      final double x = _local!.dx / _size.width * 2 - 1, y = _local!.dy / _size.height * 2 - 1;
      m = Matrix4.identity()..setEntry(3, 2, .0011);
      if (fancy && widget.tilt) {
        m
          ..rotateX(-y * 9 * math.pi / 180)
          ..rotateY(x * 9 * math.pi / 180);
      }
      m.scaleByDouble(.97, .97, 1, 1);
    }
    return Builder(builder: (BuildContext context) {
      return Listener(
        onPointerDown: enabled
            ? (PointerDownEvent e) {
                final RenderBox? b = context.findRenderObject() as RenderBox?;
                setState(() {
                  _size = b?.size ?? Size.zero;
                  _local = e.localPosition;
                  _ringAt = e.localPosition;
                });
                if (fancy && widget.burst) _ring.forward(from: 0);
              }
            : null,
        onPointerMove: enabled && _local != null ? (PointerMoveEvent e) => setState(() => _local = e.localPosition) : null,
        onPointerUp: (_) => setState(() => _local = null),
        onPointerCancel: (_) => setState(() => _local = null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap == null
              ? null
              : () {
                  if ((s?.haptics ?? false)) HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onLongPress: widget.onLongPress,
          child: Stack(clipBehavior: Clip.none, children: <Widget>[
            AnimatedContainer(
              duration: Duration(milliseconds: _local == null ? 300 : 80),
              curve: kStationEase,
              transform: m,
              transformAlignment: Alignment.center,
              child: widget.child,
            ),
            if (fancy && widget.burst)
              Positioned(
                left: _ringAt.dx - 23,
                top: _ringAt.dy - 23,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _ring,
                    builder: (_, __) => _ring.value == 0 || _ring.value == 1
                        ? const SizedBox(width: 46, height: 46)
                        : Opacity(
                            opacity: 1 - _ring.value,
                            child: Transform.scale(
                              scale: .2 + 2.2 * _ring.value,
                              child: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: p.gold2, width: 2)),
                              ),
                            ),
                          ),
                  ),
                ),
              ),
          ]),
        ),
      );
    });
  }
}

// ------------------------------------------------------------------------------------------------ surfaces

/// A surface with a gradient fill inside a gradient hairline border (CSS `padding-box` / `border-box` trick).
class StationSurface extends StatelessWidget {
  const StationSurface({
    super.key,
    required this.child,
    this.fill,
    this.border,
    this.radius = 24,
    this.borderWidth,
    this.padding = EdgeInsets.zero,
    this.shadow,
    this.glow,
  });
  final Widget child;
  final Gradient? fill;
  final Gradient? border;
  final double radius;
  final double? borderWidth;
  final EdgeInsetsGeometry padding;
  final Color? shadow;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final double bw = borderWidth ?? (p.isLight ? 2 : 1);
    return Container(
      decoration: BoxDecoration(
        gradient: border ?? p.cardBorder,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: <BoxShadow>[
          BoxShadow(color: shadow ?? p.cardShadow, offset: Offset(0, p.isLight ? 5 : 4)),
          if (glow != null) BoxShadow(color: glow!.withValues(alpha: .45), blurRadius: 26, spreadRadius: -6),
        ],
      ),
      padding: EdgeInsets.all(bw),
      child: Container(
        decoration: BoxDecoration(gradient: fill ?? p.cardFill, borderRadius: BorderRadius.circular(radius - bw)),
        padding: padding,
        child: child,
      ),
    );
  }
}

/// `.cd` — the card. [hero] = `.cd.hero` (centred, navy plate in the white skin).
class StationCard extends StatelessWidget {
  const StationCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
    this.hero = false,
    this.margin = const EdgeInsets.only(bottom: 12),
    this.glow,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool hero;
  final EdgeInsetsGeometry margin;
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool plate = hero && p.isLight;
    Widget c = StationSurface(
      fill: plate ? p.plate : null,
      padding: padding,
      glow: glow,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: plate ? p.plateInk : p.ink, fontFamily: kStationFont),
        child: hero ? Center(child: child) : child,
      ),
    );
    if (onTap != null) c = StationPress(onTap: onTap, child: c);
    return Padding(padding: margin, child: c);
  }
}

/// `.hero` content: icon/image, title, subtitle, optional rarity dots and extra children.
class StationHero extends StatelessWidget {
  const StationHero({super.key, this.icon, this.image, this.title, this.subtitle, this.latin, this.rarity, this.children = const <Widget>[]});
  final String? icon;
  final Widget? image;
  final String? title;
  final String? subtitle;
  final String? latin;
  final int? rarity;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Color sub = p.isLight ? const Color(0xFFD7E0FF) : p.mute;
    return StationCard(
      hero: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (image != null) image!,
        if (icon != null) StationIcon(icon!, size: icon!.startsWith('g_') ? 88 : 76),
        if (title != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(title!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400)),
        ],
        if (latin != null) Text(latin!.toUpperCase(), style: StationText.lat(context, size: 11, color: p.isLight ? const Color(0xFFFFD77A) : p.gold)),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 3),
          Text(subtitle!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: sub)),
        ],
        if (rarity != null) ...<Widget>[const SizedBox(height: 8), StationRarity(rarity!)],
        ...children,
      ]),
    );
  }
}

/// `.rr` rarity dots (1–4).
class StationRarity extends StatelessWidget {
  const StationRarity(this.value, {super.key, this.color});
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Color c = color ?? p.gold;
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      for (int n = 1; n <= 4; n++)
        Container(
          width: 5,
          height: 5,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: n <= value ? c : p.gold2.withValues(alpha: .2),
            boxShadow: n <= value ? <BoxShadow>[BoxShadow(color: c, blurRadius: 6)] : null,
          ),
        ),
    ]);
  }
}

// ------------------------------------------------------------------------------------------------ buttons

/// `.btn` — the extruded 3D button. [ghost] = `.btn.g`, [small] = `.btn.sm`.
class StationButton extends ConsumerStatefulWidget {
  const StationButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.leading,
    this.ghost = false,
    this.small = false,
    this.expand = true,
    this.danger = false,
    this.busy = false,
    this.margin,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// A custom mark in place of [icon] (e.g. a brand logo); [icon] wins when both are set.
  final Widget? leading;
  final bool ghost;
  final bool small;
  final bool expand;
  final bool danger;
  final bool busy;
  final EdgeInsetsGeometry? margin;

  @override
  ConsumerState<StationButton> createState() => _StationButtonState();
}

class _StationButtonState extends ConsumerState<StationButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool enabled = widget.onTap != null && !widget.busy;
    final bool ghost = widget.ghost;
    final Gradient fill = widget.danger
        ? const LinearGradient(colors: <Color>[Color(0xFFFF6B6B), Color(0xFFD1304A)])
        : ghost
            ? p.ghost
            : p.primary;
    final Color ink = ghost ? p.ink : (widget.danger ? Colors.white : p.primaryInk);
    final Color shadow = widget.danger ? const Color(0xFF7A1424) : (ghost ? p.ghostShadow : p.primaryShadow);
    final double depth = widget.small ? 3 : 5;
    final BorderRadius r = BorderRadius.circular(widget.small ? 99 : 20);
    final Border? border = ghost
        ? Border.all(color: p.isLight ? const Color(0xFFC98F1C) : p.line, width: p.isLight ? 2 : 1)
        : (p.primaryBorder != null && !widget.danger ? Border.all(color: p.primaryBorder!, width: 2) : null);
    final Widget label = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (widget.busy)
          SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: ink))
        else if (widget.icon != null)
          Icon(widget.icon, size: widget.small ? 15 : 18, color: ink)
        else if (widget.leading != null)
          widget.leading!,
        if (widget.icon != null || widget.leading != null || widget.busy) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: widget.small ? 12.5 : 15, fontWeight: FontWeight.w500, color: ink, fontFamily: kStationFont),
          ),
        ),
      ],
    );
    final Widget body = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      transform: Matrix4.translationValues(0, _down ? depth - 1 : 0, 0),
      padding: EdgeInsets.symmetric(horizontal: widget.small ? 16 : 18, vertical: widget.small ? 8 : 15),
      decoration: BoxDecoration(
        gradient: fill,
        borderRadius: r,
        border: border,
        boxShadow: <BoxShadow>[
          BoxShadow(color: shadow, offset: Offset(0, _down ? 1 : depth)),
          if (!ghost && !p.isLight && !widget.danger) BoxShadow(color: const Color(0xFFFF4F8B).withValues(alpha: .35), blurRadius: 24, spreadRadius: -6),
        ],
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: <Color>[Colors.white.withValues(alpha: ghost ? .06 : .22), Colors.white.withValues(alpha: 0)],
        ),
      ),
      child: label,
    );
    return Padding(
      padding: widget.margin ?? EdgeInsets.only(top: widget.small ? 0 : 10),
      child: Opacity(
        opacity: enabled ? 1 : .4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => setState(() => _down = true) : null,
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: enabled
              ? () {
                  if (LocalStore.ready && ref.read(settingsProvider).haptics) HapticFeedback.lightImpact();
                  widget.onTap!();
                }
              : null,
          child: body,
        ),
      ),
    );
  }
}

/// `.rb` — round glass icon button.
class StationRoundButton extends StatelessWidget {
  const StationRoundButton({super.key, required this.icon, this.onTap, this.size = 40, this.active = false, this.tooltip, this.child});
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final bool active;
  final String? tooltip;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Widget b = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: active ? p.primary : (p.isLight ? null : p.glass),
          color: active ? null : (p.isLight ? Colors.white : null),
          border: Border.all(color: p.isLight ? const Color(0xFFD9A93A) : p.line, width: p.isLight ? 2 : 1),
        ),
        child: child ?? Icon(icon, size: size * .45, color: active ? p.primaryInk : p.ink),
      ),
    );
    return tooltip == null ? b : Tooltip(message: tooltip!, child: b);
  }
}

// ------------------------------------------------------------------------------------------------ selectors

/// `.seg` — horizontally scrolling pill selector.
class StationSeg extends StatelessWidget {
  const StationSeg({super.key, required this.labels, required this.index, required this.onChanged, this.margin});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Padding(
      padding: margin ?? const EdgeInsets.only(top: 2, bottom: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: <Widget>[
          for (int k = 0; k < labels.length; k++)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 6),
              child: StationPill(label: labels[k], on: k == index, onTap: () => onChanged(k), palette: p),
            ),
        ]),
      ),
    );
  }
}

/// One `.seg button` / `#wtabs button` pill.
class StationPill extends StatelessWidget {
  const StationPill({super.key, required this.label, required this.on, this.onTap, this.palette, this.icon});
  final String label;
  final bool on;
  final VoidCallback? onTap;
  final StationPalette? palette;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = palette ?? StationPalette.of(context);
    final Gradient? fill = on ? (p.isLight ? p.plate : p.primary) : (p.isLight ? const LinearGradient(colors: <Color>[Colors.white, Colors.white]) : null);
    final Color ink = on ? (p.isLight ? const Color(0xFFFFD77A) : p.primaryInk) : (p.isLight ? p.ink : p.mute);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: kStationEase,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          gradient: fill,
          borderRadius: BorderRadius.circular(99),
          border: Border.all(
              color: on ? (p.isLight ? const Color(0xFFE0B04A) : Colors.transparent) : (p.isLight ? const Color(0xFFD19A22) : p.line),
              width: p.isLight ? 2 : 1),
          boxShadow: <BoxShadow>[
            BoxShadow(color: p.isLight ? const Color(0x4D785A14) : const Color(0x80000000), offset: const Offset(0, 3)),
            if (on && !p.isLight) BoxShadow(color: const Color(0xFFFF4F8B).withValues(alpha: .4), blurRadius: 22, spreadRadius: -4),
          ],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (icon != null) ...<Widget>[Icon(icon, size: 14, color: ink), const SizedBox(width: 5)],
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  color: ink,
                  fontWeight: p.isLight || on ? FontWeight.w500 : FontWeight.w300,
                  fontFamily: kStationFont)),
        ]),
      ),
    );
  }
}

/// `.tabs` — underline tabs that share the width.
class StationTabs extends StatelessWidget {
  const StationTabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.isLight ? p.gold : p.line, width: p.isLight ? 2 : 1))),
      child: Row(children: <Widget>[
        for (int k = 0; k < labels.length; k++)
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(k),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: k == index ? p.gold : Colors.transparent, width: 2)),
                ),
                child: Text(labels[k],
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, color: k == index ? p.gold2 : p.mute, fontWeight: FontWeight.w400)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// `.tg` — the toggle.
class StationToggle extends StatelessWidget {
  const StationToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Opacity(
        opacity: onChanged == null ? .45 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 46,
          height: 27,
          padding: const EdgeInsets.all(3),
          alignment: value ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: value ? p.primary : null,
            color: value ? null : p.track,
          ),
          child: Container(width: 21, height: 21, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------ rows, tiles, stats

/// `.ttl` — section caption.
class StationTitle extends StatelessWidget {
  const StationTitle(this.text, {super.key, this.trailing, this.center = false});
  final String text;
  final Widget? trailing;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 9),
      child: Row(children: <Widget>[
        Expanded(
            child: Text(text,
                textAlign: center ? TextAlign.center : TextAlign.start,
                style: TextStyle(fontSize: 12.5, color: p.gold, fontWeight: FontWeight.w400))),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// `.row` — list row with a hairline top border.
class StationRow extends StatelessWidget {
  const StationRow({super.key, this.leading, required this.title, this.subtitle, this.trailing, this.onTap, this.first = false, this.child});
  final Widget? leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool first;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: first ? null : Border(top: BorderSide(color: p.isLight ? const Color(0x240C1A4A) : p.gold.withValues(alpha: .1))),
        ),
        child: Row(children: <Widget>[
          if (leading != null) ...<Widget>[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: <Widget>[
              Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(subtitle!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: p.mute)),
              if (child != null) child!,
            ]),
          ),
          if (trailing != null) ...<Widget>[const SizedBox(width: 10), trailing!],
        ]),
      ),
    );
  }
}

/// Builds a card of rows where only the first row has no top border.
class StationRows extends StatelessWidget {
  const StationRows({super.key, required this.children, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 2)});
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => StationCard(padding: padding, child: Column(children: children));
}

/// `.bar` — progress bar.
class StationBar extends StatelessWidget {
  const StationBar(this.value, {super.key, this.height = 6, this.margin = const EdgeInsets.only(top: 7)});
  final double value;
  final double height;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: Stack(children: <Widget>[
            Positioned.fill(child: ColoredBox(color: p.track)),
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: value.clamp(0.0, 1.0),
              child: DecoratedBox(decoration: BoxDecoration(gradient: p.bar, borderRadius: BorderRadius.circular(height))),
            ),
          ]),
        ),
      ),
    );
  }
}

/// `.stat` — big number + caption.
class StationStat extends StatelessWidget {
  const StationStat({super.key, required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: p.gold2)),
      Text(label, style: TextStyle(fontSize: 11, color: p.mute), textAlign: TextAlign.center),
    ]);
  }
}

/// A card of 2–4 stats side by side (`.cd.g3`).
class StationStats extends StatelessWidget {
  const StationStats(this.items, {super.key});
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) => StationCard(
        child: Row(children: <Widget>[
          for (final (String v, String l) in items) Expanded(child: StationStat(value: v, label: l)),
        ]),
      );
}

/// `.tile` — square-ish tile (navy plate in the white skin).
class StationTile extends StatelessWidget {
  const StationTile({
    super.key,
    this.icon,
    this.image,
    required this.title,
    this.subtitle,
    this.on = false,
    this.locked = false,
    this.onTap,
    this.footer,
  });
  final String? icon;
  final Widget? image;
  final String title;
  final String? subtitle;
  final bool on;
  final bool locked;
  final VoidCallback? onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    Widget t = StationSurface(
      fill: p.tileFill,
      border: on ? LinearGradient(colors: <Color>[p.gold, p.gold2]) : p.tileBorder,
      radius: 20,
      borderWidth: on ? 2 : null,
      glow: on ? p.gold : null,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: p.plateInk),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          if (image != null) image!,
          if (icon != null) StationIcon(icon!, size: 42),
          const SizedBox(height: 4),
          Text(title,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.plateInk)),
          if (subtitle != null)
            Text(subtitle!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, color: p.isLight ? Colors.white.withValues(alpha: .65) : p.mute)),
          if (footer != null) ...<Widget>[const SizedBox(height: 8), footer!],
        ]),
      ),
    );
    if (locked) {
      t = Opacity(opacity: .38, child: ColorFiltered(colorFilter: const ColorFilter.matrix(_grey), child: t));
    }
    return onTap == null ? t : StationPress(onTap: onTap, child: t);
  }
}

const List<double> _grey = <double>[
  .33, .59, .11, 0, 0, //
  .33, .59, .11, 0, 0, //
  .33, .59, .11, 0, 0, //
  0, 0, 0, 1, 0,
];

/// `.g2` / `.g3` grid of fixed columns that sizes to its content.
class StationGrid extends StatelessWidget {
  const StationGrid({super.key, required this.children, this.columns = 2, this.gap = 12, this.margin = const EdgeInsets.only(bottom: 12)});
  final List<Widget> children;
  final int columns;
  final double gap;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i += columns) {
      rows.add(Padding(
        padding: EdgeInsets.only(bottom: i + columns < children.length ? gap : 0),
        child: IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            for (int k = 0; k < columns; k++) ...<Widget>[
              if (k > 0) SizedBox(width: gap),
              Expanded(child: i + k < children.length ? children[i + k] : const SizedBox.shrink()),
            ],
          ]),
        ),
      ));
    }
    return Padding(padding: margin, child: Column(children: rows));
  }
}

/// `.a` (round) / `.sq` (rounded square) letter avatar with a hue from the name; shows [imageUrl] when given.
class StationLetter extends StatelessWidget {
  const StationLetter(this.name, {super.key, this.size = 42, this.square = false, this.online = false, this.imageUrl, this.badge, this.asset});
  final String name;
  final double size;
  final bool square;
  final bool online;
  final String? imageUrl;
  final String? asset;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final String n = name.trim().isEmpty ? '?' : name.trim();
    final int code = n.runes.first;
    final Color bg = HSLColor.fromAHSL(1, ((code * (square ? 47 : 37)) % 360).toDouble(), .35, square ? .22 : .24).toColor();
    final BorderRadius r = BorderRadius.circular(square ? size * .36 : size);
    Widget inner = Center(
      child: Text(String.fromCharCode(code).toUpperCase(),
          style: TextStyle(fontSize: size * .36, color: Colors.white, fontWeight: FontWeight.w400)),
    );
    if (asset != null) {
      inner = Image.asset(asset!, fit: BoxFit.cover, width: size, height: size);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      inner = Image.network(imageUrl!, fit: BoxFit.cover, width: size, height: size, errorBuilder: (_, __, ___) => inner);
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: r,
              border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.gold3, width: 1.5),
            ),
            child: ClipRRect(borderRadius: r, child: inner),
          ),
        ),
        if (online)
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: size * .24,
              height: size * .24,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: const Color(0xFF7BE0A4), border: Border.all(color: const Color(0xFF0C0D12), width: 2)),
            ),
          ),
        if (badge != null) PositionedDirectional(top: -5, end: -5, child: badge!),
      ]),
    );
  }
}

/// `.av` gold ring avatar (HUD / profile).
class StationRingAvatar extends StatelessWidget {
  const StationRingAvatar({super.key, required this.name, this.size = 42, this.imageUrl, this.level});
  final String name;
  final double size;
  final String? imageUrl;
  final int? level;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final String initials = name.trim().isEmpty
        ? 'NX'
        : name.trim().split(RegExp(r'\s+')).take(2).map((String w) => String.fromCharCode(w.runes.first)).join().toUpperCase();
    return SizedBox(
      width: size,
      height: size,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        Container(
          padding: const EdgeInsets.all(1.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: p.isLight
                ? const LinearGradient(colors: <Color>[Color(0xFFE0B04A), Color(0xFFE0B04A)])
                : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFFC27A), Color(0xFFFF4F8B), Color(0xFF4A5CFF)]),
          ),
          child: ClipOval(
            child: Container(
              color: p.isLight ? const Color(0xFF0A1A5A) : const Color(0xFF14102E),
              alignment: Alignment.center,
              child: imageUrl != null && imageUrl!.isNotEmpty
                  ? Image.network(imageUrl!, fit: BoxFit.cover, width: size, height: size,
                      errorBuilder: (_, __, ___) => _initials(initials, p))
                  : p.isLight
                      ? Image.asset('assets/station/white/lion.webp', fit: BoxFit.cover, width: size, height: size)
                      : _initials(initials, p),
            ),
          ),
        ),
        if (level != null)
          PositionedDirectional(
            bottom: -4,
            end: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              alignment: Alignment.center,
              decoration: BoxDecoration(gradient: p.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('$level',
                  style: TextStyle(fontFamily: kStationLatin, fontWeight: FontWeight.w600, fontSize: 11, color: p.primaryInk, height: 1)),
            ),
          ),
      ]),
    );
  }

  Widget _initials(String s, StationPalette p) => Text(s,
      style: TextStyle(fontFamily: kStationLatin, fontSize: size * .38, letterSpacing: size * .02, color: p.ink, fontWeight: FontWeight.w500));
}

/// `.inp` — pill text field.
class StationInput extends StatelessWidget {
  const StationInput({
    super.key,
    this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
    this.prefix,
  });
  final TextEditingController? controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;
  final Widget? prefix;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      maxLength: maxLength,
      obscureText: obscure,
      keyboardType: keyboardType,
      maxLines: obscure ? 1 : maxLines,
      minLines: 1,
      style: TextStyle(color: p.ink, fontSize: 14, fontFamily: kStationFont),
      decoration: InputDecoration(hintText: hint, counterText: '', prefixIcon: prefix),
    );
  }
}

/// `.gcard` — big gradient card with art, title and meta line.
class StationGameCard extends StatelessWidget {
  const StationGameCard({super.key, required this.title, this.icon, this.color, this.meta = const <String>[], this.onTap, this.wide = false, this.gradient});
  final String title;
  final String? icon;
  final Color? color;
  final List<String> meta;
  final VoidCallback? onTap;
  final bool wide;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool cover = icon?.startsWith('g_') ?? false;
    final Gradient bg = p.isLight
        ? p.plate
        : gradient ??
            LinearGradient(
                begin: const Alignment(-.3, -1),
                end: const Alignment(.3, 1),
                colors: <Color>[color ?? p.gold, const Color(0xFF0A0A12)],
                stops: const <double>[0, .95]);
    final Widget card = AspectRatio(
      aspectRatio: wide ? 2.4 : 1 / .8,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          border: p.isLight ? Border.all(color: const Color(0xFFE0B04A), width: 3) : Border.all(color: p.line),
          boxShadow: <BoxShadow>[BoxShadow(color: p.isLight ? const Color(0x665A3C0A) : const Color(0x73000000), offset: const Offset(0, 5))],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(p.isLight ? 23 : 25),
          child: Stack(fit: StackFit.expand, children: <Widget>[
            DecoratedBox(decoration: BoxDecoration(gradient: bg)),
            if (icon != null)
              cover
                  ? Image.asset(p.icon(icon!), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink())
                  : Align(
                      alignment: const Alignment(0, -.55),
                      child: FractionallySizedBox(widthFactor: .7, heightFactor: .6, child: StationIcon(icon!, size: 120)),
                    ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[Color(0x00000000), Color(0xD104031A)],
                  stops: <double>[.45, 1],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white)),
                const SizedBox(height: 4),
                Row(children: <Widget>[
                  for (final String m in meta.take(1))
                    Expanded(
                      child: Text(m,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: p.isLight ? const Color(0xFFFFD77A) : p.gold2)),
                    ),
                  if (meta.isEmpty) const Spacer(),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFF0E6)),
                    child: const Icon(Icons.arrow_back_rounded, size: 14, color: Color(0xFF14110A)),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
    if (!p.isLight) return StationPress(onTap: onTap, child: card);
    // White skin: a crown sits on top of every game card.
    return StationPress(
      onTap: onTap,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        card,
        Positioned(
          top: -17,
          left: 0,
          right: 0,
          child: Center(child: Image.asset('assets/station/white/crown.webp', width: 64, height: 34)),
        ),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------ currency

class StationCoin extends StatelessWidget {
  const StationCoin({super.key, this.size = 14});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _CoinPainter());
}

class _CoinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final double k = s.width / 24;
    final Offset c = Offset(12 * k, 12 * k);
    canvas.drawCircle(c, 9.5 * k, Paint()..color = const Color(0xFFD9B872));
    canvas.drawCircle(c, 9.5 * k, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2 * k..color = const Color(0xFFF6E7BD));
    canvas.drawCircle(c, 5.8 * k, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2 * k..color = const Color(0xFF8A6A2C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class StationGem extends StatelessWidget {
  const StationGem({super.key, this.size = 14});
  final double size;
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _GemPainter());
}

class _GemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final double k = s.width / 24;
    final Path p = Path()
      ..moveTo(12 * k, 22 * k)
      ..lineTo(2.5 * k, 9.2 * k)
      ..lineTo(6.6 * k, 3 * k)
      ..lineTo(17.4 * k, 3 * k)
      ..lineTo(21.5 * k, 9.2 * k)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFF6E7BD));
    canvas.drawPath(p, Paint()..style = PaintingStyle.stroke..strokeWidth = k..color = const Color(0xFFD9B872));
    final Path f = Path()
      ..moveTo(2.5 * k, 9.2 * k)
      ..lineTo(21.5 * k, 9.2 * k)
      ..moveTo(9 * k, 3 * k)
      ..lineTo(7.4 * k, 9.2 * k)
      ..lineTo(12 * k, 22 * k)
      ..lineTo(16.6 * k, 9.2 * k)
      ..lineTo(15 * k, 3 * k);
    canvas.drawPath(f, Paint()..style = PaintingStyle.stroke..strokeWidth = .8 * k..color = const Color(0xFF8A6A2C));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// `.bal` — coin + gem chips (live from the profile wallet).
class StationBalance extends ConsumerWidget {
  const StationBalance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileService prof = ref.watch(profileProvider);
    final StationPalette p = StationPalette.of(context);
    Widget chip(Widget icon, int v) => Container(
          margin: const EdgeInsetsDirectional.only(start: 6),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            gradient: p.isLight ? null : p.glass,
            color: p.isLight ? Colors.white : null,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: p.isLight ? const Color(0xFFD9A93A) : p.line, width: p.isLight ? 2 : 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            icon,
            const SizedBox(width: 5),
            Text(nxNum(context, v), style: TextStyle(fontSize: 11.5, color: p.ink)),
          ]),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      chip(const StationCoin(), prof.coins),
      chip(const StationGem(), prof.gems),
    ]);
  }
}

// ------------------------------------------------------------------------------------------------ screen (#scr)

/// `#scr` — every page: back button, title, latin caption, live balance, scrolling body over the skin background.
class StationScreen extends StatelessWidget {
  const StationScreen({
    super.key,
    required this.title,
    this.latin,
    this.children,
    this.child,
    this.actions = const <Widget>[],
    this.balance = true,
    this.fab,
    this.bottom,
    this.onBack,
    this.padding = const EdgeInsets.fromLTRB(16, 2, 16, 50),
    this.tint,
    this.scrollController,
    this.back = true,
  });
  final String title;
  final String? latin;
  final List<Widget>? children;
  final Widget? child;
  final List<Widget> actions;
  final bool balance;
  final Widget? fab;
  final Widget? bottom;
  final VoidCallback? onBack;
  final EdgeInsetsGeometry padding;
  final Color? tint;
  final ScrollController? scrollController;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Widget body = child ??
        ListView(
          controller: scrollController,
          padding: padding,
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          children: children ?? const <Widget>[],
        );
    return Scaffold(
      backgroundColor: p.bg,
      resizeToAvoidBottomInset: true,
      body: StationBackdrop(
        image: p.screenImage,
        tint: tint,
        dust: false,
        child: SafeArea(
          bottom: false,
          child: Column(children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Row(children: <Widget>[
                if (back) ...<Widget>[
                  StationRoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: onBack ?? () => Navigator.of(context).maybePop(),
                    tooltip: stx(context, 'بازگشت', 'Back'),
                  ),
                  const SizedBox(width: 11),
                ],
                Expanded(
                  child: Text(title,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w400, color: p.ink)),
                ),
                ...actions.map((Widget a) => Padding(padding: const EdgeInsetsDirectional.only(start: 6), child: a)),
                if (balance) const StationBalance(),
              ]),
            ),
            Expanded(child: body),
            if (bottom != null) bottom!,
          ]),
        ),
      ),
      floatingActionButton: fab,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

/// `.fab` — floating pill action.
class StationFab extends StatelessWidget {
  const StationFab({super.key, required this.label, required this.onTap, this.icon = Icons.add_rounded});
  final String label;
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 24, 14),
        decoration: BoxDecoration(
          gradient: p.primary,
          borderRadius: BorderRadius.circular(99),
          border: p.primaryBorder == null ? null : Border.all(color: p.primaryBorder!, width: 2),
          boxShadow: <BoxShadow>[BoxShadow(color: p.primaryShadow, offset: const Offset(0, 5)), const BoxShadow(color: Color(0x99000000), blurRadius: 30, offset: Offset(0, 14))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Icon(icon, color: p.primaryInk, size: 20),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: p.primaryInk, fontSize: 15, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

/// Empty / offline / loading placeholder in the Station voice.
class StationEmpty extends StatelessWidget {
  const StationEmpty({super.key, required this.text, this.icon = 'r5c6', this.action, this.onAction, this.loading = false});
  final String text;
  final String icon;
  final String? action;
  final VoidCallback? onAction;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return StationCard(
      hero: true,
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (loading)
          Padding(padding: const EdgeInsets.all(12), child: CircularProgressIndicator(color: p.gold, strokeWidth: 2))
        else
          StationIcon(icon, size: 64),
        const SizedBox(height: 8),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.isLight ? Colors.white : p.mute, height: 1.8)),
        if (action != null && onAction != null) StationButton(label: action!, onTap: onAction, small: true, expand: false, margin: const EdgeInsets.only(top: 12)),
      ]),
    );
  }
}

// ------------------------------------------------------------------------------------------------ overlays

/// `#modal` — centred celebration card ("عالی!").
Future<void> showStationModal(BuildContext context, {String big = '✨', Widget? art, required String title, String text = '', String? button}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'modal',
    barrierColor: const Color(0xB3030306),
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (BuildContext ctx, _, __) {
      final StationPalette p = StationPalette.of(ctx);
      return Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: math.min(MediaQuery.sizeOf(ctx).width * .82, 320),
            padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
            decoration: BoxDecoration(
              gradient: p.isLight
                  ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Colors.white, Color(0xFFE3ECFF)])
                  : p.popBg,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.gold, width: p.isLight ? 3 : 1),
              boxShadow: <BoxShadow>[BoxShadow(color: p.gold.withValues(alpha: .5), blurRadius: 60, spreadRadius: -10)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              art ?? Text(big, style: const TextStyle(fontSize: 34)),
              const SizedBox(height: 6),
              Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: p.ink)),
              if (text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: p.mute, height: 1.7)),
                ),
              StationButton(label: button ?? stx(ctx, 'عالی!', 'Great!'), onTap: () => Navigator.of(ctx).pop()),
            ]),
          ),
        ),
      );
    },
    transitionBuilder: (BuildContext ctx, Animation<double> a, _, Widget child) {
      final double v = kStationEase.transform(a.value);
      return Opacity(
        opacity: a.value,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0011)
            ..rotateX((1 - v) * -40 * math.pi / 180)
            ..scaleByDouble(.9 + .1 * v, .9 + .1 * v, 1, 1),
          child: child,
        ),
      );
    },
  );
}

OverlayEntry? _toastEntry;
Timer? _toastTimer;

/// `#toast` — a pill above the nav that fades out after 1.8 s.
void stationToast(BuildContext context, String text, {bool error = false, Duration duration = const Duration(milliseconds: 1800)}) {
  final OverlayState? o = Overlay.maybeOf(context, rootOverlay: true);
  if (o == null) return;
  final StationPalette p = StationPalette.of(context);
  _toastTimer?.cancel();
  _toastEntry?.remove();
  final OverlayEntry e = OverlayEntry(
    builder: (BuildContext ctx) => Positioned(
      left: 24,
      right: 24,
      bottom: 120 + MediaQuery.paddingOf(ctx).bottom,
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: kStationEase,
            builder: (_, double v, Widget? c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c)),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                decoration: BoxDecoration(
                  gradient: p.toastBg,
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(color: error ? const Color(0xFFFF5A6E) : (p.isLight ? const Color(0xFFE0B04A) : p.line), width: p.isLight ? 2 : 1),
                ),
                child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.toastInk, fontFamily: kStationFont)),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  _toastEntry = e;
  o.insert(e);
  _toastTimer = Timer(duration, () {
    if (_toastEntry == e) {
      e.remove();
      _toastEntry = null;
    }
  });
}

/// One option of [showStationSheet] (`.opt`).
class StationSheetOption {
  const StationSheetOption({required this.label, this.icon, this.onTap, this.danger = false});
  final String label;
  final String? icon;
  final VoidCallback? onTap;
  final bool danger;
}

/// `#sheet` — bottom sheet with grab handle, art, title, description and options.
Future<T?> showStationSheet<T>(
  BuildContext context, {
  String? icon,
  Widget? art,
  String? title,
  String? text,
  List<StationSheetOption> options = const <StationSheetOption>[],
  Widget? child,
  bool scroll = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x8C030306),
    showDragHandle: false,
    builder: (BuildContext ctx) {
      final StationPalette p = StationPalette.of(ctx);
      final Widget content = Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        Container(
          width: 40,
          height: 4,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(color: p.gold2.withValues(alpha: .25), borderRadius: BorderRadius.circular(4)),
        ),
        if (art != null) art,
        if (icon != null) StationIcon(icon, size: 120),
        if (title != null) Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w400, color: p.ink)),
        if (text != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 4, 0, 14),
            child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.mute, height: 1.7)),
          ),
        if (child != null) child,
        for (final StationSheetOption o in options)
          Padding(
            padding: const EdgeInsets.only(top: 9),
            child: StationPress(
              onTap: () {
                Navigator.of(ctx).pop();
                o.onTap?.call();
              },
              child: StationSurface(
                fill: p.isLight ? null : p.glass,
                border: p.isLight ? null : LinearGradient(colors: <Color>[p.line, p.line]),
                radius: 20,
                padding: const EdgeInsets.all(15),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                  if (o.icon != null) ...<Widget>[StationIcon(o.icon!, size: 30), const SizedBox(width: 10)],
                  Text(o.label, style: TextStyle(fontSize: 14, color: o.danger ? const Color(0xFFFF5A6E) : p.ink)),
                ]),
              ),
            ),
          ),
      ]);
      return Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * .9),
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.paddingOf(ctx).bottom + 22 + MediaQuery.viewInsetsOf(ctx).bottom),
        decoration: BoxDecoration(
          gradient: p.isLight ? const LinearGradient(colors: <Color>[Colors.white, Colors.white]) : p.popBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: p.isLight ? const Color(0xFFD9A93A) : p.line, width: p.isLight ? 2 : 1)),
        ),
        child: scroll ? SingleChildScrollView(child: content) : content,
      );
    },
  );
}

/// Confirm dialog in the Station look. Returns true on confirm.
Future<bool> showStationConfirm(BuildContext context,
    {required String title, String message = '', String? confirm, String? cancel, bool danger = false}) async {
  final bool? r = await showStationSheet<bool>(
    context,
    title: title,
    text: message,
    child: Builder(
      builder: (BuildContext ctx) => Column(children: <Widget>[
        StationButton(label: confirm ?? stx(ctx, 'تأیید', 'Confirm'), danger: danger, onTap: () => Navigator.of(ctx).pop(true)),
        StationButton(label: cancel ?? stx(ctx, 'انصراف', 'Cancel'), ghost: true, onTap: () => Navigator.of(ctx).pop(false)),
      ]),
    ),
  );
  return r ?? false;
}

/// Text prompt in the Station look. Returns null on cancel.
Future<String?> showStationPrompt(BuildContext context,
    {required String title, String message = '', String hint = '', String initial = '', String? confirm, int? maxLength, bool obscure = false}) {
  final TextEditingController c = TextEditingController(text: initial);
  return showStationSheet<String>(
    context,
    title: title,
    text: message,
    child: Builder(
      builder: (BuildContext ctx) => Column(children: <Widget>[
        StationInput(controller: c, hint: hint, autofocus: true, maxLength: maxLength, obscure: obscure, onSubmitted: (String v) => Navigator.of(ctx).pop(v.trim())),
        StationButton(label: confirm ?? stx(ctx, 'تأیید', 'OK'), onTap: () => Navigator.of(ctx).pop(c.text.trim())),
        StationButton(label: stx(ctx, 'انصراف', 'Cancel'), ghost: true, onTap: () => Navigator.of(ctx).pop()),
      ]),
    ),
  );
}

/// `#launch` — the game loading screen (wordmark, glowing icon, progress bar and status lines) before a game opens.
Future<void> showStationLaunch(BuildContext context, {required String name, required String icon}) {
  return Navigator.of(context, rootNavigator: true).push(PageRouteBuilder<void>(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => _LaunchPage(name: name, icon: icon),
    transitionsBuilder: (_, Animation<double> a, __, Widget c) => FadeTransition(opacity: a, child: c),
  ));
}

class _LaunchPage extends StatefulWidget {
  const _LaunchPage({required this.name, required this.icon});
  final String name;
  final String icon;
  @override
  State<_LaunchPage> createState() => _LaunchPageState();
}

class _LaunchPageState extends State<_LaunchPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward().whenComplete(() {
      if (mounted) Navigator.of(context).pop();
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final List<String> tips = stationFa(context)
        ? const <String>['در حال اتصال به سرور…', 'جست‌وجوی حریف…', 'دریافت اطلاعات بازی…', 'آماده‌سازی صحنه…']
        : const <String>['Connecting…', 'Finding players…', 'Loading the game…', 'Preparing the scene…'];
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: SizedBox(
          width: math.min(MediaQuery.sizeOf(context).width * .8, 320),
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, _) => Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
              Image.asset('assets/station/wordmark.png', width: 150, color: p.isLight ? p.ink : null),
              Container(
                width: 100,
                height: 100,
                margin: const EdgeInsets.symmetric(vertical: 20),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: p.isLight ? p.plate : null,
                  border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.gold),
                  boxShadow: <BoxShadow>[BoxShadow(color: p.gold.withValues(alpha: .35 + .3 * math.sin(_c.value * math.pi * 3).abs()), blurRadius: 60, spreadRadius: -10)],
                ),
                child: StationIcon(widget.icon, size: 70, radius: 22),
              ),
              Text(widget.name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w400, color: p.ink)),
              const SizedBox(height: 18),
              StationBar(_c.value),
              const SizedBox(height: 12),
              Text(tips[(_c.value * 4).floor().clamp(0, 3)], style: TextStyle(fontSize: 12, color: p.mute)),
            ]),
          ),
        ),
      ),
    );
  }
}

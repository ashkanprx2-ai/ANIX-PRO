import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'station_kit.dart';

/// One entry of a hub grid: a large illustration and a name.
class StationHubEntry {
  const StationHubEntry({required this.label, required this.image, required this.onTap, this.badge});
  final String label;

  /// An `assets/...` path (unified hub / game icons) or an atlas name understood by [StationIcon].
  final String image;
  final VoidCallback onTap;
  final String? badge;
}

/// The one hub grid of the app (Games, Events, Rewards, Chat, AI, Shop, Profile, Tournaments, More):
/// a uniform two-column grid of equal-size [StationHubCard]s; an odd last card sits centred.
/// Rows are built lazily, so a long list (30 games) stays cheap on low-end phones.
class StationHubGrid extends StatelessWidget {
  const StationHubGrid({
    super.key,
    required this.entries,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 24),
    this.gap = 14,
    this.aspect = 1.22,
    this.physics = const BouncingScrollPhysics(),
    this.header,
  });

  final List<StationHubEntry> entries;
  final EdgeInsets padding;
  final double gap;

  /// width / height of every card.
  final double aspect;
  final ScrollPhysics physics;

  /// Optional widget above the first row.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
      final double w = ((c.maxWidth - padding.horizontal - gap) / 2).floorToDouble();
      final double h = (w / aspect).floorToDouble();
      final int rows = (entries.length + 1) ~/ 2;
      final int extra = header == null ? 0 : 1;
      return ListView.builder(
        padding: padding,
        physics: physics,
        itemCount: rows + extra,
        itemExtent: header == null ? h + gap : null,
        itemBuilder: (BuildContext context, int r) {
          if (header != null) {
            if (r == 0) return header!;
            r -= 1;
          }
          final int a = r * 2;
          final bool single = a + 1 >= entries.length;
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: SizedBox(
              height: h,
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                SizedBox(width: w, height: h, child: StationHubCard(entry: entries[a], index: a)),
                if (!single) ...<Widget>[
                  SizedBox(width: gap),
                  SizedBox(width: w, height: h, child: StationHubCard(entry: entries[a + 1], index: a + 1)),
                ],
              ]),
            ),
          );
        },
      );
    });
  }
}

/// A framed neon panel: big centred illustration in the upper ~70 % and a dark rounded label pill at the bottom.
class StationHubCard extends StatelessWidget {
  const StationHubCard({super.key, required this.entry, this.index = 0});
  final StationHubEntry entry;
  final int index;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    final Gradient frame = p.isLight
        ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFFFFE596), Color(0xFFC98F1C)])
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFFFF9A6A), Color(0xFFE04A9A), Color(0xFF5A6CFF)],
            stops: <double>[0, .5, 1]);
    final Gradient fill = p.isLight
        ? p.plate
        : const RadialGradient(center: Alignment(0, -.35), radius: 1.0, colors: <Color>[Color(0xFF26205E), Color(0xFF0B0A26)]);
    return RepaintBoundary(
      child: StationPress(
        onTap: entry.onTap,
        child: Container(
          decoration: BoxDecoration(
            gradient: frame,
            borderRadius: BorderRadius.circular(20),
            boxShadow: <BoxShadow>[
              const BoxShadow(color: Color(0x80000000), offset: Offset(0, 5), blurRadius: 8),
              if (!p.isLight) const BoxShadow(color: Color(0x40E04A9A), blurRadius: 18, spreadRadius: -4),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(gradient: fill, borderRadius: BorderRadius.circular(18)),
            padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
            child: LayoutBuilder(builder: (BuildContext context, BoxConstraints c) {
              const double pill = 30;
              final double art = math.max(24, math.min(c.maxWidth * .86, c.maxHeight - pill - 2));
              final int cache = (art * dpr).round();
              return Column(children: <Widget>[
                Expanded(
                  child: Center(
                    child: entry.image.startsWith('assets/')
                        ? Image.asset(
                            entry.image,
                            width: art,
                            height: art,
                            fit: BoxFit.contain,
                            cacheWidth: cache,
                            cacheHeight: cache,
                            filterQuality: FilterQuality.medium,
                            errorBuilder: (_, __, ___) => Icon(Icons.sports_esports_rounded, size: art * .6, color: p.gold2),
                          )
                        : StationIcon(entry.image, size: art),
                  ),
                ),
                Container(
                  height: pill,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: p.isLight ? const Color(0xE6071040) : const Color(0xE6060518),
                    borderRadius: BorderRadius.circular(pill / 2),
                    border: Border.all(color: p.isLight ? const Color(0x99FFD77A) : const Color(0x40FFFFFF)),
                  ),
                  child: Text(
                    entry.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontFamily: kStationFont, fontSize: 13.5, height: 1.25, fontWeight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ]);
            }),
          ),
        ),
      ),
    );
  }
}

/// Chip row of a hub: horizontal (RTL-aware) scroll of icon + label pills; the active one is gold/orange.
class StationHubChips extends StatelessWidget {
  const StationHubChips({super.key, required this.labels, required this.index, required this.onChanged, this.icons = const <IconData>[]});
  final List<String> labels;
  final List<IconData> icons;
  final int index;
  final ValueChanged<int> onChanged;

  static const double height = 38;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    return SizedBox(
      height: height + 8,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        physics: const BouncingScrollPhysics(),
        itemCount: labels.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int k) {
          final bool on = k == index;
          final Color ink = on ? const Color(0xFF1B0B02) : (p.isLight ? p.ink : const Color(0xFFF3E9FF));
          return GestureDetector(
            onTap: () => onChanged(k),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              height: height,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: on
                    ? const LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFFFFD45A), Color(0xFFFF9A2A)])
                    : null,
                color: on ? null : (p.isLight ? Colors.white : const Color(0xCC0D0B2A)),
                borderRadius: BorderRadius.circular(height / 2),
                border: Border.all(color: on ? const Color(0xFFFFE7A0) : (p.isLight ? const Color(0xFFD19A22) : const Color(0x55FFFFFF))),
                boxShadow: on ? const <BoxShadow>[BoxShadow(color: Color(0x66FFA02A), blurRadius: 12, spreadRadius: -2)] : null,
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                if (k < icons.length) ...<Widget>[Icon(icons[k], size: 17, color: on ? ink : const Color(0xFFFFC27A)), const SizedBox(width: 6)],
                Text(labels[k],
                    maxLines: 1,
                    style: TextStyle(fontFamily: kStationFont, fontSize: 13.5, height: 1.3, fontWeight: on ? FontWeight.w700 : FontWeight.w400, color: ink)),
              ]),
            ),
          );
        },
      ),
    );
  }
}

/// Hub header: close on the left, centred title with a glowing underline, round world icon on the right.
class StationHubHeader extends StatelessWidget {
  const StationHubHeader({super.key, required this.title, required this.icon, required this.onClose});
  final String title;
  final String icon;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final Widget close = StationRoundButton(icon: Icons.close_rounded, size: 46, onTap: onClose, tooltip: stx(context, 'بازگشت', 'Back'));
    final Widget orb = Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: p.isLight ? p.plate : const RadialGradient(colors: <Color>[Color(0xFF2A2068), Color(0xFF0C0A28)]),
        border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : const Color(0x80FFB46A), width: 1.4),
      ),
      child: icon.startsWith('assets/')
          ? Image.asset(icon, width: 40, height: 40, cacheWidth: 120, cacheHeight: 120, errorBuilder: (_, __, ___) => const SizedBox.shrink())
          : StationIcon(icon, size: 40),
    );
    final Widget mid = Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: kStationFont, fontSize: 24, height: 1.3, fontWeight: FontWeight.w700, color: p.ink)),
      const SizedBox(height: 4),
      Container(
        width: 150,
        height: 3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          gradient: const LinearGradient(colors: <Color>[Color(0x00FFB040), Color(0xFFFFC24A), Color(0x00FFB040)]),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x99FFB040), blurRadius: 10)],
        ),
      ),
    ]);
    // Physical layout regardless of text direction: close on the left, icon on the right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(children: <Widget>[
          close,
          Expanded(child: Directionality(textDirection: Directionality.of(context), child: Center(child: mid))),
          orb,
        ]),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/companion/companion.dart';
import '../kit/station_kit.dart';

/// Round portrait of a companion (the active one by default).
class CompanionAvatar extends ConsumerWidget {
  const CompanionAvatar({super.key, this.id, this.size = 42, this.ring = true});
  final CompanionId? id;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CompanionInfo c = CompanionInfo.of(id ?? ref.watch(companionProvider).active);
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ring ? 1.5 : 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: ring ? LinearGradient(colors: <Color>[c.color, const Color(0xFFFFC27A), c.color]) : null,
      ),
      child: ClipOval(
        child: ColoredBox(
          color: const Color(0xFF14102E),
          child: Image.asset(c.avatar, fit: BoxFit.cover, width: size, height: size),
        ),
      ),
    );
  }
}

/// A companion sticker for a mood that gently bobs (the mascot used on cards, sheets and empty states).
class CompanionMascot extends ConsumerStatefulWidget {
  const CompanionMascot({super.key, this.id, this.mood = CompanionMood.happy, this.size = 120, this.bob = true});
  final CompanionId? id;
  final CompanionMood mood;
  final double size;
  final bool bob;

  @override
  ConsumerState<CompanionMascot> createState() => _CompanionMascotState();
}

class _CompanionMascotState extends ConsumerState<CompanionMascot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CompanionInfo c = CompanionInfo.of(widget.id ?? ref.watch(companionProvider).active);
    final bool reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final Widget img = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      child: Image.asset(c.mood(widget.mood),
          key: ValueKey<String>(c.mood(widget.mood)), width: widget.size, height: widget.size, fit: BoxFit.contain, cacheWidth: (widget.size * 2.5).round()),
    );
    if (!widget.bob || reduced) return img;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, Widget? child) => Transform.translate(offset: Offset(0, math.sin(_c.value * 2 * math.pi) * 4), child: child),
      child: img,
    );
  }
}

/// The AI-page selector: both companions side by side with their art; tapping one makes it active everywhere.
class CompanionSelector extends ConsumerWidget {
  const CompanionSelector({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CompanionController ctl = ref.watch(companionProvider);
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    Widget card(CompanionInfo c) {
      final bool on = ctl.active == c.id;
      return Expanded(
        child: StationPress(
          onTap: () {
            if (on) return;
            ctl.select(c.id);
            stationToast(context, fa ? '${c.nameFa} همراه تو شد 💜' : '${c.nameEn} is now your companion');
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: kStationEase,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: on ? LinearGradient(colors: <Color>[c.color, p.gold2]) : p.tileBorder,
              boxShadow: <BoxShadow>[
                BoxShadow(color: p.cardShadow, offset: const Offset(0, 4)),
                if (on) BoxShadow(color: c.color.withValues(alpha: .55), blurRadius: 30, spreadRadius: -6),
              ],
            ),
            padding: EdgeInsets.all(on ? 2 : 1),
            child: Container(
              decoration: BoxDecoration(gradient: p.tileFill, borderRadius: BorderRadius.circular(22)),
              padding: EdgeInsets.fromLTRB(10, compact ? 10 : 14, 10, 12),
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                CompanionMascot(id: c.id, mood: on ? CompanionMood.happy : CompanionMood.wink, size: compact ? 84 : 118, bob: on),
                const SizedBox(height: 6),
                Text(c.name(fa), style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: p.plateInk)),
                Text(c.nameEn, style: StationText.lat(context, size: 10, color: p.isLight ? const Color(0xFFFFD77A) : c.color)),
                if (!compact) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(c.bio(fa),
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, height: 1.6, color: p.isLight ? Colors.white70 : p.mute)),
                ],
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: on ? p.primary : null,
                    borderRadius: BorderRadius.circular(99),
                    border: on ? null : Border.all(color: p.line),
                  ),
                  child: Text(on ? stx(context, 'فعال', 'ACTIVE') : stx(context, 'انتخاب', 'SELECT'),
                      style: TextStyle(fontSize: 11, color: on ? p.primaryInk : (p.isLight ? Colors.white : p.mute), fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          card(CompanionInfo.oracle),
          const SizedBox(width: 12),
          card(CompanionInfo.luna),
        ]),
      ),
    );
  }
}

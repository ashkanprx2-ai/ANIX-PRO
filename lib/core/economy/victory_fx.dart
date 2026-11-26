// Victory effects: the gem (الماس) item for EVERY online game (2026-11-26, work/rematch-spectator).
//
// Until now gem items existed only in finger soccer (teams, custom team). A victory effect is a cosmetic burst the
// buyer sees on the online result screen of any game when they win. It never changes play, so it is fair in every
// game (card, board, physics and hidden-role games alike).
//
// Server: core project, supabase/migrations/20261126210100_rs02_gem_victory_fx.sql adds the nx_catalog rows
// `nx_fx:<style>` (currency 'gems'). Buying goes through the existing nx_buy_with_gems RPC (GemShop.buy): the server
// takes the price from the catalog, charges through nx_wallet_apply (gem ledger) and grants the item into the player's
// inventory. Nothing on this phone changes a balance. The equipped effect is the profile slot [kVictoryFxSlot].
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../profile/profile_service.dart';
import '../../ui/kit/station_compat.dart';

import '../../games/shared/nx_kit_art.dart';
import 'gem_shop.dart';

/// Profile slot of the equipped victory effect.
const String kVictoryFxSlot = 'win_fx';

class VictoryFx {
  const VictoryFx(this.style, this.nameFa, this.nameEn, this.price, this.colors, {this.icon = Icons.auto_awesome_rounded});
  final String style;
  final String nameFa, nameEn;

  /// Built-in gem price (the server catalog wins once loaded).
  final int price;
  final List<Color> colors;
  final IconData icon;

  /// Catalog / inventory id (`nx_fx:fire`).
  String get itemId => 'nx_fx:$style';
}

/// Same styles and prices as the finger-soccer fs_fx catalog rows.
const List<VictoryFx> kVictoryFx = <VictoryFx>[
  VictoryFx('sparks', 'جرقه', 'Sparks', 200, <Color>[Color(0xFFFFE08A), Color(0xFFFFB13B), Colors.white],
      icon: Icons.flare_rounded),
  VictoryFx('neon', 'نئون', 'Neon', 200, <Color>[Color(0xFF39FFE0), Color(0xFFFF4FD8), Color(0xFF7C5CFF)],
      icon: Icons.blur_on_rounded),
  VictoryFx('fire', 'آتش', 'Fire', 250, <Color>[Color(0xFFFF4D1F), Color(0xFFFF9F1C), Color(0xFFFFE066)],
      icon: Icons.local_fire_department_rounded),
  VictoryFx('frost', 'یخ', 'Frost', 250, <Color>[Color(0xFFBFF4FF), Color(0xFF6FD3FF), Colors.white],
      icon: Icons.ac_unit_rounded),
  VictoryFx('lightning', 'صاعقه', 'Lightning', 300, <Color>[Color(0xFFFFF36B), Color(0xFF8FD8FF), Colors.white],
      icon: Icons.bolt_rounded),
  VictoryFx('rainbow', 'رنگین‌کمان', 'Rainbow', 350,
      <Color>[Color(0xFFFF4D4D), Color(0xFFFFB13B), Color(0xFFFFF36B), Color(0xFF4DFF88), Color(0xFF4DB8FF), Color(0xFFB84DFF)],
      icon: Icons.looks_rounded),
];

VictoryFx? victoryFxById(String? itemId) {
  if (itemId == null) return null;
  for (final VictoryFx f in kVictoryFx) {
    if (f.itemId == itemId) return f;
  }
  return null;
}

/// The effect this player has equipped and owns (null: none).
VictoryFx? equippedVictoryFx(ProfileService? p) {
  if (p == null) return null;
  final String? id = p.equipped[kVictoryFxSlot];
  if (id == null || !p.owns(id)) return null;
  return victoryFxById(id);
}

/// Gem price of [f] (server catalog when loaded).
int victoryFxPrice(VictoryFx f) => GemShop.instance.price(f.itemId) ?? f.price;

/// A one-shot particle burst over the result screen (ignores touches). Nothing when [reducedMotion].
class VictoryFxBurst extends StatefulWidget {
  const VictoryFxBurst({super.key, required this.fx, this.reducedMotion = false});
  final VictoryFx fx;
  final bool reducedMotion;

  @override
  State<VictoryFxBurst> createState() => _VictoryFxBurstState();
}

class _VictoryFxBurstState extends State<VictoryFxBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
  late final List<_Spark> _sparks = _make();

  List<_Spark> _make() {
    final math.Random r = math.Random();
    return <_Spark>[
      for (int i = 0; i < 90; i++)
        _Spark(
          angle: r.nextDouble() * math.pi * 2,
          speed: .25 + r.nextDouble() * .75,
          size: 2 + r.nextDouble() * 5,
          delay: r.nextDouble() * .35,
          color: widget.fx.colors[i % widget.fx.colors.length],
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (!widget.reducedMotion) unawaited(_a.forward());
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reducedMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _a,
        builder: (BuildContext context, _) =>
            CustomPaint(painter: _BurstPainter(_sparks, _a.value), size: Size.infinite),
      ),
    );
  }
}

class _Spark {
  const _Spark({required this.angle, required this.speed, required this.size, required this.delay, required this.color});
  final double angle, speed, size, delay;
  final Color color;
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.sparks, this.t);
  final List<_Spark> sparks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = Offset(size.width / 2, size.height * .36);
    final double reach = math.min(size.width, size.height) * .55;
    final Paint p = Paint();
    for (final _Spark s in sparks) {
      final double k = ((t - s.delay) / (1 - s.delay)).clamp(0.0, 1.0);
      if (k <= 0 || k >= 1) continue;
      final double ease = 1 - math.pow(1 - k, 3).toDouble();
      final Offset at = c +
          Offset(math.cos(s.angle), math.sin(s.angle)) * (reach * s.speed * ease) +
          Offset(0, 60 * k * k); // a little gravity
      p.color = s.color.withValues(alpha: (1 - k).clamp(0.0, 1.0));
      canvas.drawCircle(at, s.size * (1 - k * .5), p);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.t != t;
}

/// Bottom sheet: every victory effect with its gem price; buy (server RPC through [GemShop.buy]) or equip.
Future<void> showVictoryFxShop(BuildContext context, {required bool fa}) => showAnixSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext ctx) => _VictoryFxShop(fa: fa),
    );

class _VictoryFxShop extends StatefulWidget {
  const _VictoryFxShop({required this.fa});
  final bool fa;

  @override
  State<_VictoryFxShop> createState() => _VictoryFxShopState();
}

class _VictoryFxShopState extends State<_VictoryFxShop> {
  String _t(String f, String e) => widget.fa ? f : e;

  @override
  void initState() {
    super.initState();
    GemShop.instance.addListener(_changed);
    ProfileService.current?.addListener(_changed);
    if (!GemShop.instance.loaded) unawaited(GemShop.instance.refresh());
  }

  @override
  void dispose() {
    GemShop.instance.removeListener(_changed);
    ProfileService.current?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _buy(VictoryFx f) async {
    final ProfileService? p = ProfileService.current;
    final int price = victoryFxPrice(f);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AnixDialog(
        title: Text(_t('افکت پیروزی ${f.nameFa}', 'Victory FX · ${f.nameEn}')),
        content: Text(_t('خرید با $price الماس؟\nموجودی بعد از خرید: ${(p?.gems ?? 0) - price}',
            'Buy for $price gems?\nBalance after purchase: ${(p?.gems ?? 0) - price}')),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(_t('انصراف', 'Cancel'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(_t('خرید', 'Buy'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final GemBuyResult r = await GemShop.instance.buy(f.itemId);
    if (!mounted) return;
    if (r.ok) ProfileService.current?.equip(kVictoryFxSlot, f.itemId);
    luxeToast(context, r.ok ? _t('افکت ${f.nameFa} فعال شد ✓', '${f.nameEn} equipped ✓') : gemErrorText(r.error, widget.fa),
        error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    final ProfileService? p = ProfileService.current;
    final GemShop shop = GemShop.instance;
    final String? on = p?.equipped[kVictoryFxSlot];
    return Directionality(
      textDirection: widget.fa ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Row(children: <Widget>[
              Expanded(
                child: Text(_t('افکت پیروزی · همه بازی‌ها', 'Victory effects · every game'),
                    style: const TextStyle(color: Luxe.gold2, fontWeight: FontWeight.w900, fontSize: 17)),
              ),
              const NxGemIcon(size: 18),
              const SizedBox(width: 4),
              Text('${p?.gems ?? 0}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 4),
            Text(
                _t('وقتی در بازی آنلاین برنده می‌شوی روی صفحه‌ی نتیجه پخش می‌شود. فقط ظاهری است و روی بازی اثری ندارد.',
                    'Plays on the online result screen when you win. Cosmetic only: it never changes the game.'),
                style: const TextStyle(color: Luxe.mute, fontSize: 12)),
            if (!shop.online)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_t('برای خرید با الماس وارد حساب شو.', 'Sign in to buy with gems.'),
                    style: const TextStyle(color: Color(0xFFFF8A9A), fontSize: 12)),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(shrinkWrap: true, children: <Widget>[
                for (final VictoryFx f in kVictoryFx)
                  if (shop.forSale(f.itemId) || (p?.owns(f.itemId) ?? false))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: f.colors.first.withValues(alpha: .22),
                        child: Icon(f.icon, color: f.colors.first),
                      ),
                      title: Text(_t(f.nameFa, f.nameEn),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                      trailing: (p?.owns(f.itemId) ?? false)
                          ? (on == f.itemId
                              ? TextButton(
                                  onPressed: () => p?.unequip(kVictoryFxSlot),
                                  child: Text(_t('فعال ✓', 'On ✓')),
                                )
                              : OutlinedButton(
                                  onPressed: () => p?.equip(kVictoryFxSlot, f.itemId),
                                  child: Text(_t('انتخاب', 'Use')),
                                ))
                          : FilledButton.icon(
                              onPressed: shop.online && !shop.busy ? () => _buy(f) : null,
                              icon: const NxGemIcon(size: 14),
                              label: Text('${victoryFxPrice(f)}'),
                            ),
                    ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

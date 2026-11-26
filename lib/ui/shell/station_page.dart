import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/online/online_service.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../kit/station_kit.dart';
import 'station_worlds.dart';

/// The Station hub (`#hub` + `#world` + `#nav` + `#more` + `#np` of NEXORA_Station_Luxe.html):
/// 3D carousel of the eight worlds, the world view with tabs and an item grid, the floating nav with the centre
/// «روم» button, the «بیشتر» popup, the profile HUD popover and the right-hand navigation drawer.
class StationPage extends ConsumerStatefulWidget {
  const StationPage({super.key, this.initialWorld});

  /// Opens straight into a world (index into [buildStationWorlds]) — used by /station/:k deep links.
  final int? initialWorld;

  @override
  ConsumerState<StationPage> createState() => _StationPageState();
}

class _StationPageState extends ConsumerState<StationPage> with TickerProviderStateMixin {
  late final List<StationWorld> _worlds = buildStationWorlds();
  int _idx = 0;
  int? _world; // open world
  int _tab = 0;
  bool _more = false;
  bool _drawer = false;
  bool _pop = false;
  double _dragDx = 0;
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    final int? w = widget.initialWorld;
    if (w != null && w >= 0 && w < _worlds.length) {
      _idx = w;
      _world = w;
      _pos.value = w.toDouble();
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool get _reduced => ref.read(settingsProvider).reducedMotion;

  void _go(int k) {
    final int n = k.clamp(0, _worlds.length - 1);
    setState(() => _idx = n);
    if (_reduced) {
      _pos.value = n.toDouble();
    } else {
      _pos.animateTo(n.toDouble(), duration: const Duration(milliseconds: 800), curve: kStationEase);
    }
    if (ref.read(settingsProvider).haptics) HapticFeedback.selectionClick();
  }

  void _openWorld(int i) {
    setState(() {
      _world = i;
      _idx = i;
      _tab = 0;
      _more = false;
      _drawer = false;
      _pop = false;
    });
    _pos.value = i.toDouble();
    if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
  }

  void _closeWorld() => setState(() => _world = null);

  void _nav(String target) {
    setState(() {
      _pop = false;
      _drawer = false;
    });
    if (target == 'more') {
      setState(() => _more = !_more);
      return;
    }
    setState(() => _more = false);
    if (target == 'home') {
      _closeWorld();
    } else if (target == 'chat') {
      context.push('/social');
    } else if (target == 'rooms') {
      context.push('/rooms');
    } else if (target.startsWith('w')) {
      _openWorld(int.parse(target.substring(1)));
    } else if (target.startsWith('/')) {
      context.push(target);
    }
  }

  bool _back() {
    if (_drawer || _more || _pop) {
      setState(() {
        _drawer = false;
        _more = false;
        _pop = false;
      });
      return true;
    }
    if (_world != null) {
      _closeWorld();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool inWorld = _world != null;
    final Color c = p.worldColor(_world ?? _idx);
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool did, _) {
        if (did) return;
        if (!_back()) SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: p.bg,
        body: StationBackdrop(
          image: inWorld ? p.worldImage : p.hubImage,
          tint: inWorld ? c : null,
          child: Stack(children: <Widget>[
            // ----------------------------------------------------------- hub
            AnimatedOpacity(
              opacity: inWorld ? 0 : 1,
              duration: const Duration(milliseconds: 600),
              curve: kStationEase,
              child: IgnorePointer(
                ignoring: inWorld,
                child: AnimatedScale(
                  scale: inWorld ? .94 : 1,
                  duration: const Duration(milliseconds: 700),
                  curve: kStationEase,
                  child: _hub(context, p, pad),
                ),
              ),
            ),
            // ----------------------------------------------------------- world
            if (inWorld) _WorldView(
              key: ValueKey<int>(_world!),
              world: _worlds[_world!],
              color: c,
              tab: _tab,
              onTab: (int t) => setState(() => _tab = t),
              onClose: _closeWorld,
            ),
            // ----------------------------------------------------------- HUD
            if (!inWorld) ...<Widget>[
              PositionedDirectional(top: pad.top + 14, start: 14, child: _profileHud(context, p)),
              PositionedDirectional(
                top: pad.top + 24,
                end: 14,
                child: StationRoundButton(
                  icon: Icons.menu_rounded,
                  tooltip: stx(context, 'پنل ناوبری', 'Navigation'),
                  onTap: () => setState(() {
                    _drawer = true;
                    _pop = false;
                  }),
                ),
              ),
            ],
            if (_pop && !inWorld)
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _pop = false)),
              ),
            if (_pop && !inWorld) PositionedDirectional(top: pad.top + 76, start: 14, child: const _ProfilePop()),
            // ----------------------------------------------------------- more
            if (_more)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _more = false),
                  child: const ColoredBox(color: Color(0x80030306)),
                ),
              ),
            if (_more)
              Positioned(left: 14, right: 14, bottom: pad.bottom + 104, child: _MorePanel(onPick: _nav)),
            // ----------------------------------------------------------- nav
            Positioned(
              left: 14,
              right: 14,
              bottom: pad.bottom + 12,
              child: _NavBar(
                active: _more ? 'more' : (inWorld ? 'w$_world' : 'home'),
                onTap: _nav,
              ),
            ),
            // ----------------------------------------------------------- drawer
            if (_drawer)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _drawer = false),
                  child: ColoredBox(color: p.isLight ? const Color(0x730C1A4A) : const Color(0x8C03030C)),
                ),
              ),
            AnimatedPositionedDirectional(
              duration: const Duration(milliseconds: 400),
              curve: kStationEase,
              top: 0,
              bottom: 0,
              end: _drawer ? 0 : -math.min(MediaQuery.sizeOf(context).width * .86, 340) - 20,
              width: math.min(MediaQuery.sizeOf(context).width * .86, 340),
              child: _Drawer(
                worlds: _worlds,
                onWorld: (int i) => _openWorld(i),
                onClose: () => setState(() => _drawer = false),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _hub(BuildContext context, StationPalette p, EdgeInsets pad) {
    final Size sz = MediaQuery.sizeOf(context);
    final StationWorld w = _worlds[_idx];
    final bool fa = stationFa(context);
    return Padding(
      padding: EdgeInsets.only(top: pad.top + 70, bottom: pad.bottom + 120),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
        SizedBox(
          height: 96,
          child: Image.asset(p.logo, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
        ),
        SizedBox(
          height: math.min(sz.height * .48, 450),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _dragDx = 0,
            onHorizontalDragUpdate: (DragUpdateDetails d) => _dragDx += d.delta.dx,
            onHorizontalDragEnd: (_) {
              if (_dragDx.abs() > 40) _go(_idx + (_dragDx < 0 ? 1 : -1));
            },
            child: AnimatedBuilder(
              animation: _pos,
              builder: (BuildContext context, _) => _carousel(context, p, sz),
            ),
          ),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Column(key: ValueKey<int>(_idx), children: <Widget>[
            Text(fa ? w.fa : w.en, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w400, color: p.ink)),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Text(fa ? w.tagFa : w.tagEn, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.mute)),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          for (int i = 0; i < _worlds.length; i++)
            GestureDetector(
              onTap: () => _go(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                curve: kStationEase,
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: i == _idx ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(9),
                  gradient: i == _idx ? p.primary : null,
                  color: i == _idx ? null : p.gold2.withValues(alpha: .25),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _carousel(BuildContext context, StationPalette p, Size sz) {
    final double cw = math.min(sz.width * .6, 236);
    final double ch = cw * 4.3 / 3;
    final double pos = _pos.value;
    final List<int> order = List<int>.generate(_worlds.length, (int i) => i)
      ..sort((int a, int b) => (b - pos).abs().compareTo((a - pos).abs()));
    return Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: <Widget>[
      for (final int k in order)
        if ((k - pos).abs() <= 2.6) _card(context, p, k, k - pos, cw, ch),
    ]);
  }

  Widget _card(BuildContext context, StationPalette p, int k, double o, double cw, double ch) {
    final double a = o.abs();
    final double scale = a < 1 ? 1.04 - (1.04 - .91) * a : 1 - .09 * a;
    final Matrix4 m = Matrix4.identity()
      ..setEntry(3, 2, 1 / 1100)
      ..translateByDouble(o * cw * .64, 0, -a * 150, 1)
      ..rotateY(-o * 30 * math.pi / 180)
      ..scaleByDouble(scale, scale, 1, 1);
    final StationWorld w = _worlds[k];
    final Color c = p.worldColor(k);
    final bool fa = stationFa(context);
    return Opacity(
      opacity: a > 2 ? 0 : (1 - a * .3).clamp(0.0, 1.0),
      child: Transform(
        alignment: Alignment.center,
        transform: m,
        child: GestureDetector(
          onTap: () => k == _idx ? _openWorld(k) : _go(k),
          child: SizedBox(
            width: cw,
            height: ch,
            child: Stack(fit: StackFit.expand, children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(p.isLight ? 26 : 24),
                  gradient: p.isLight
                      ? const LinearGradient(colors: <Color>[Color(0xFFFFE596), Color(0xFFC98F1C), Color(0xFFFFE596)])
                      : null,
                  boxShadow: <BoxShadow>[
                    if (p.isLight) const BoxShadow(color: Color(0x665A3C0A), offset: Offset(0, 6)),
                    if (!p.isLight) BoxShadow(color: c.withValues(alpha: .35), blurRadius: 50, spreadRadius: -14),
                  ],
                ),
                padding: EdgeInsets.all(p.isLight ? 3 : 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(p.isLight ? 23 : 24),
                  child: Stack(fit: StackFit.expand, children: <Widget>[
                    if (p.isLight)
                      DecoratedBox(decoration: BoxDecoration(gradient: p.plate))
                    else
                      Image.asset('assets/station/neon/card.webp', fit: BoxFit.fill),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: p.isLight
                              ? const <Color>[Color(0x00000000), Color(0xB3030828)]
                              : const <Color>[Color(0x00000000), Color(0xA606051A)],
                          stops: const <double>[.55, 1],
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
              Align(
                alignment: const Alignment(0, -.42),
                child: StationIcon(w.icon, size: cw * .5),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 26,
                child: Column(children: <Widget>[
                  Text(fa ? w.fa : w.en,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w500, color: Colors.white)),
                  Text(w.en,
                      style: StationText.lat(context, size: 11, color: p.isLight ? const Color(0xFFFFD77A) : p.gold2)),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _profileHud(BuildContext context, StationPalette p) {
    final ProfileService prof = ref.watch(profileProvider);
    return GestureDetector(
      onTap: () => setState(() => _pop = !_pop),
      child: Container(
        width: 52,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: p.isLight ? p.plate : const LinearGradient(colors: <Color>[Color(0x17FFFFFF), Color(0x05FFFFFF)]),
          border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.line, width: p.isLight ? 2 : 1),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x80000000), blurRadius: 30, offset: Offset(0, 14), spreadRadius: -14)],
        ),
        child: StationRingAvatar(name: prof.username, size: 44, imageUrl: prof.avatarUrl, level: prof.level),
      ),
    );
  }
}

/// The profile popover (`.pop` under the HUD): name, rank, XP bar, coins, gems, XP.
class _ProfilePop extends ConsumerWidget {
  const _ProfilePop();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StationPalette p = StationPalette.of(context);
    final ProfileService prof = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    Widget line(Widget? icon, String label, String value) => Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: p.gold.withValues(alpha: .1)))),
          child: Row(children: <Widget>[
            SizedBox(width: 15, child: icon),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: p.ink))),
            Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: p.gold2)),
          ]),
        );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: .88, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: kStationEase,
      builder: (_, double v, Widget? c) => Transform.scale(alignment: AlignmentDirectional.topStart, scale: v, child: Opacity(opacity: ((v - .88) / .12).clamp(0.0, 1.0), child: c)),
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          onTap: () => context.push('/s/profile'),
          child: Container(
            width: 240,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: p.isLight ? const LinearGradient(colors: <Color>[Colors.white, Colors.white]) : p.popBg,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: p.isLight ? const Color(0xFFD9A93A) : p.line, width: p.isLight ? 2 : 1),
              boxShadow: const <BoxShadow>[BoxShadow(color: Color(0xA6000000), blurRadius: 60, offset: Offset(0, 30), spreadRadius: -20)],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
              Row(children: <Widget>[
                StationRingAvatar(name: prof.username, size: 46, imageUrl: prof.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(prof.username.isEmpty ? 'NEXORA' : prof.username,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.ink)),
                    Text('${stx(context, 'سطح', 'Level')} ${nxNum(context, prof.level)} · ${fa ? prof.rankTitleFa : prof.rankTitleEn}',
                        style: TextStyle(fontSize: 11, color: p.mute)),
                  ]),
                ),
              ]),
              StationBar(prof.levelProgress, height: 4, margin: const EdgeInsets.symmetric(vertical: 12)),
              line(const StationCoin(size: 15), stx(context, 'سکه', 'Coins'), nxNum(context, prof.coins)),
              line(const StationGem(size: 15), stx(context, 'جم', 'Gems'), nxNum(context, prof.gems)),
              line(null, 'XP',
                  '${nxNum(context, prof.xpIntoLevel)} / ${nxNum(context, ProfileService.xpForLevel(prof.level))}'),
            ]),
          ),
        ),
      ),
    );
  }
}

/// `#world` — head (orb, title, close), `#wtabs` and the item grid (`.ic`).
class _WorldView extends ConsumerWidget {
  const _WorldView({super.key, required this.world, required this.color, required this.tab, required this.onTab, required this.onClose});
  final StationWorld world;
  final Color color;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final List<StationItem> list = world.items.where((StationItem x) => tab == 0 || x.tab == tab).toList();
    final List<String> tabs = <String>[stx(context, 'همه', 'All'), ...(fa ? world.tabsFa : world.tabsEn)];
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: kStationEase,
      builder: (_, double v, Widget? c) {
        final Matrix4 m = Matrix4.identity()
          ..setEntry(3, 2, 1 / 1200)
          ..rotateY((1 - v) * -14 * math.pi / 180)
          ..scaleByDouble(1 + (1 - v) * .04, 1 + (1 - v) * .04, 1, 1);
        return Opacity(opacity: v, child: Transform(alignment: Alignment.center, transform: m, child: c));
      },
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 6, 0, 10),
              child: Row(children: <Widget>[
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: p.isLight
                        ? p.plate
                        : RadialGradient(center: const Alignment(-.3, -.4), colors: <Color>[color.withValues(alpha: .3), color.withValues(alpha: 0)]),
                    border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : color.withValues(alpha: .45), width: p.isLight ? 2 : 1),
                  ),
                  child: StationIcon(world.icon, size: 40),
                ),
                const SizedBox(width: 14),
                Expanded(child: Text(fa ? world.fa : world.en, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w400, color: p.ink))),
                StationRoundButton(icon: Icons.close_rounded, size: 42, onTap: onClose, tooltip: stx(context, 'بازگشت', 'Back')),
              ]),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(top: 4, bottom: 14),
                children: <Widget>[
                  for (int k = 0; k < tabs.length; k++)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: StationPill(label: tabs[k], on: k == tab, onTap: () => onTab(k)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: EdgeInsets.fromLTRB(2, 4, 2, 150 + MediaQuery.paddingOf(context).bottom),
                physics: const BouncingScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1.25),
                itemCount: list.length + (world.k == 'personal' ? 1 : 0),
                itemBuilder: (BuildContext context, int i) {
                  if (world.k == 'personal') {
                    if (i == 0) return const _ProfileStrip();
                    i -= 1;
                  }
                  return _ItemTile(item: list[i], color: color, delay: i);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// `.prof` — the profile strip at the top of the PROFILE world (spans one tile; tap opens the profile).
class _ProfileStrip extends ConsumerWidget {
  const _ProfileStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StationPalette p = StationPalette.of(context);
    final ProfileService prof = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    return StationPress(
      onTap: () => context.push('/s/profile'),
      child: StationSurface(
        padding: const EdgeInsets.all(14),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          StationRingAvatar(name: prof.username, size: 54, imageUrl: prof.avatarUrl, level: prof.level),
          const SizedBox(height: 8),
          Text(prof.username.isEmpty ? 'NEXORA' : prof.username,
              maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: p.ink)),
          Text(fa ? prof.rankTitleFa : prof.rankTitleEn, style: TextStyle(fontSize: 11, color: p.mute)),
          StationBar(prof.levelProgress, height: 4),
        ]),
      ),
    );
  }
}

/// `.ic` — one item tile (neon: `tile.webp` plate; white: navy plate with a gold frame).
class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.color, required this.delay});
  final StationItem item;
  final Color color;
  final int delay;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final Widget body = Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      StationIcon(item.icon, size: item.icon.startsWith('g_') ? 56 : 48, radius: 15),
      const SizedBox(height: 6),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(fa ? item.fa : item.en,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: p.isLight ? Colors.white : p.ink)),
      ),
    ]);
    final Widget tile = p.isLight
        ? StationSurface(fill: p.tileFill, border: p.tileBorder, radius: 22, child: body)
        : Container(
            decoration: BoxDecoration(
              image: const DecorationImage(image: AssetImage('assets/station/neon/tile.webp'), fit: BoxFit.fill),
              borderRadius: BorderRadius.circular(22),
              boxShadow: <BoxShadow>[const BoxShadow(color: Color(0x73000000), offset: Offset(0, 4)), BoxShadow(color: color.withValues(alpha: .18), blurRadius: 30, spreadRadius: -8)],
            ),
            child: body,
          );
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 800 + delay * 60),
      curve: Interval(math.min(delay * .06, .5), 1, curve: kStationEase),
      builder: (_, double v, Widget? c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 16 * (1 - v)), child: c)),
      child: StationPress(onTap: () => item.open(context), child: tile),
    );
  }
}

/// `#nav` — the floating glass bar with the round centre «روم» button.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.active, required this.onTap});
  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    return SizedBox(
      height: 92,
      child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: <Widget>[
        Container(
          height: 66,
          decoration: BoxDecoration(
            color: p.navBg,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: p.navBorder, width: p.isLight ? 2 : 1),
            boxShadow: <BoxShadow>[
              BoxShadow(color: p.isLight ? const Color(0x59785A14) : const Color(0x66000000), offset: const Offset(0, 6)),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          child: Row(children: <Widget>[
            for (final StationNavEntry e in kStationNav)
              if (e.icon == null)
                const SizedBox(width: 74)
              else
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onTap(e.target),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 450),
                      curve: kStationEase,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        gradient: active == e.target
                            ? LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: <Color>[p.gold.withValues(alpha: .2), p.gold.withValues(alpha: .03)])
                            : null,
                        border: active == e.target ? Border.all(color: p.gold.withValues(alpha: .25)) : null,
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                        StationIcon(e.icon!, size: 26, nav: true),
                        const SizedBox(height: 2),
                        Text(fa ? e.fa : e.en,
                            style: TextStyle(fontSize: 9.5, color: active == e.target ? p.gold2 : (p.isLight ? p.ink : p.mute))),
                      ]),
                    ),
                  ),
                ),
          ]),
        ),
        // Centre «روم» button (clean pass: 62 px, label instead of art).
        Positioned(
          bottom: 66 - 62 + 22,
          child: GestureDetector(
            onTap: () => onTap('rooms'),
            child: Container(
              width: 62,
              height: 62,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.isLight
                    ? const RadialGradient(center: Alignment(0, -.4), colors: <Color>[Color(0xFF2B4FD0), Color(0xFF050C33)], stops: <double>[0, .72])
                    : const RadialGradient(center: Alignment(0, -.4), colors: <Color>[Color(0xFF3A1A5A), Color(0xFF0A0820)], stops: <double>[0, .72]),
                border: Border.all(color: p.isLight ? const Color(0xFFE8B94D) : p.gold, width: p.isLight ? 3 : 1.5),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: p.bg.withValues(alpha: .88), spreadRadius: 6),
                  BoxShadow(color: p.gold.withValues(alpha: .5), blurRadius: 34, spreadRadius: -4),
                ],
              ),
              child: Text(fa ? 'روم' : 'ROOMS',
                  style: TextStyle(
                      fontSize: fa ? 15 : 11,
                      fontWeight: FontWeight.w600,
                      color: p.isLight ? const Color(0xFFFFD77A) : const Color(0xFFFFD2A0))),
            ),
          ),
        ),
      ]),
    );
  }
}

/// `#more` — the 3-column popup above the nav.
class _MorePanel extends StatelessWidget {
  const _MorePanel({required this.onPick});
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 550),
      curve: kStationEase,
      builder: (_, double v, Widget? c) =>
          Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: Transform.scale(scale: .96 + .04 * v, child: c))),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: p.isLight ? const LinearGradient(colors: <Color>[Colors.white, Colors.white]) : p.popBg,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: p.isLight ? const Color(0xFFD9A93A) : p.line, width: p.isLight ? 2 : 1),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0xA6000000), blurRadius: 60, offset: Offset(0, 30), spreadRadius: -20)],
        ),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.05,
          children: <Widget>[
            for (final StationNavEntry e in kStationMore)
              StationPress(
                onTap: () => onPick(e.target),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: p.isLight ? p.plate : p.glass,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.line, width: p.isLight ? 2 : 1),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    StationIcon(e.icon!, size: 34),
                    const SizedBox(height: 6),
                    Text(fa ? e.fa : e.en, style: TextStyle(fontSize: 12, color: p.isLight ? Colors.white : p.ink)),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// `#np` — navigation drawer: me card, every world, shortcuts (rooms, chats, games, records, profile, viewers,
/// settings, theme switch).
class _Drawer extends ConsumerWidget {
  const _Drawer({required this.worlds, required this.onWorld, required this.onClose});
  final List<StationWorld> worlds;
  final ValueChanged<int> onWorld;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final StationPalette p = StationPalette.of(context);
    final ProfileService prof = ref.watch(profileProvider);
    final bool signedIn = ref.watch(onlineProvider.select((OnlineService o) => o.user != null && !o.isGuest));
    final bool fa = stationFa(context);
    void go(String route) {
      onClose();
      Future<void>.delayed(const Duration(milliseconds: 120), () {
        if (context.mounted) context.push(route);
      });
    }

    final List<(String, String, VoidCallback)> links = <(String, String, VoidCallback)>[
      ('🏠', stx(context, 'روم‌ها', 'Rooms'), () => go('/rooms')),
      ('💬', stx(context, 'گپ‌ها', 'Chats'), () => go('/social')),
      ('🎮', stx(context, 'همه‌ی بازی‌ها', 'All games'), () => go('/s/games')),
      ('📊', stx(context, 'رکوردها', 'Records'), () => go('/s/games?records=1')),
      ('👤', stx(context, 'پروفایل من', 'My profile'), () => go('/s/profile')),
      ('👁', stx(context, 'کی منو دیده؟', 'Who viewed me?'), () => go('/s/viewers')),
      ('🤖', stx(context, 'اوراکل و لونا', 'ORACLE & LUNA'), () => go('/oracle')),
      ('⚙️', stx(context, 'تنظیمات', 'Settings'), () => go('/settings')),
      ('🎨', stx(context, 'تغییر تم', 'Switch theme'), () {
        final AppSettings s = ref.read(settingsProvider);
        s.stationSkin = s.stationSkin == StationSkin.white ? StationSkin.neon : StationSkin.white;
        stationToast(context, s.stationSkin == StationSkin.white ? stx(context, 'تم سفید فعال شد', 'White theme on') : stx(context, 'تم نارنجی ـ سرمه‌ای فعال شد', 'Neon theme on'));
      }),
      if (!signedIn) ('🔑', stx(context, 'ورود / ثبت‌نام', 'Sign in'), () => go('/auth')),
    ];
    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        onHorizontalDragEnd: (DragEndDetails d) {
          if ((d.primaryVelocity ?? 0) > 300) onClose();
        },
        child: Container(
          padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 16, 16, 24),
          decoration: BoxDecoration(
            gradient: p.isLight
                ? const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Colors.white, Color(0xFFD8E5FF)])
                : LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[p.bg, Colors.black]),
            border: BorderDirectional(start: BorderSide(color: p.line)),
          ),
          child: ListView(padding: EdgeInsets.zero, children: <Widget>[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: p.isLight ? null : p.glass,
                color: p.isLight ? Colors.white : null,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: p.line, width: p.isLight ? 2 : 1),
              ),
              child: Row(children: <Widget>[
                StationRingAvatar(name: prof.username, size: 42, imageUrl: prof.avatarUrl),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(prof.username.isEmpty ? 'NEXORA' : prof.username,
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: p.ink)),
                    Text('${stx(context, 'سطح', 'Level')} ${nxNum(context, prof.level)} · ${fa ? prof.rankTitleFa : prof.rankTitleEn}',
                        style: TextStyle(fontSize: 11, color: p.mute)),
                  ]),
                ),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                  Text('🪙 ${nxNum(context, prof.coins)}', style: TextStyle(fontSize: 12, color: p.ink)),
                  Text('💎 ${nxNum(context, prof.gems)}', style: TextStyle(fontSize: 12, color: p.ink)),
                ]),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
              child: Text(stx(context, 'بخش‌های برنامه', 'Sections'), style: TextStyle(fontSize: 12, color: p.gold)),
            ),
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: .82,
              children: <Widget>[
                for (int i = 0; i < worlds.length; i++)
                  GestureDetector(
                    onTap: () => onWorld(i),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(2, 10, 2, 8),
                      decoration: BoxDecoration(
                        gradient: p.isLight ? p.plate : p.glass,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: p.isLight ? const Color(0xFFE0B04A) : p.line, width: p.isLight ? 2 : 1),
                      ),
                      child: Column(children: <Widget>[
                        StationIcon(worlds[i].icon, size: 30),
                        const SizedBox(height: 4),
                        Text(fa ? worlds[i].fa : worlds[i].en,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10.5, color: p.isLight ? Colors.white : p.ink)),
                      ]),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 14, 2, 8),
              child: Text(stx(context, 'میان‌بُرها', 'Shortcuts'), style: TextStyle(fontSize: 12, color: p.gold)),
            ),
            for (final (String e, String label, VoidCallback f) in links)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: GestureDetector(
                  onTap: f,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      gradient: p.isLight ? null : p.glass,
                      color: p.isLight ? Colors.white : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.line, width: p.isLight ? 2 : 1),
                    ),
                    child: Row(children: <Widget>[
                      Text('$e  $label', style: TextStyle(fontSize: 14, color: p.ink)),
                      const Spacer(),
                      Icon(Icons.chevron_left_rounded, color: p.gold, size: 18, textDirection: TextDirection.ltr),
                    ]),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }
}

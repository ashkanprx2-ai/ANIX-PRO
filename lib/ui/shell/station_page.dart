import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/online/online_service.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../kit/station_hub_grid.dart';
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
  bool _pop = false;
  double _dragDx = 0;
  late final AnimationController _pos = AnimationController.unbounded(vsync: this, value: 0);

  @override
  void initState() {
    super.initState();
    final int? w = widget.initialWorld;
    if (w != null && w >= 0 && w < _worlds.length) {
      _world = w;
      if (w < kStationCarouselWorlds) {
        _idx = w;
        _pos.value = w.toDouble();
      }
    }
  }

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  bool get _reduced => ref.read(settingsProvider).reducedMotion;

  void _go(int k) {
    final int n = k.clamp(0, kStationCarouselWorlds - 1);
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
      if (i < kStationCarouselWorlds) _idx = i;
      _tab = 0;
      _pop = false;
    });
    if (i < kStationCarouselWorlds) _pos.value = i.toDouble();
    if (ref.read(settingsProvider).haptics) HapticFeedback.mediumImpact();
  }

  void _closeWorld() => setState(() => _world = null);

  void _nav(String target) {
    setState(() => _pop = false);
    if (target == 'home') {
      _closeWorld();
    } else if (target == 'rooms') {
      context.push('/rooms');
    } else if (target.startsWith('w')) {
      _openWorld(int.parse(target.substring(1)));
    } else if (target.startsWith('world:')) {
      _openWorld(int.parse(target.substring(6)));
    } else if (target == 'action:theme') {
      final AppSettings s = ref.read(settingsProvider);
      s.stationSkin = s.stationSkin == StationSkin.white ? StationSkin.neon : StationSkin.white;
      stationToast(context, s.stationSkin == StationSkin.white ? stx(context, 'تم سفید فعال شد', 'White theme on') : stx(context, 'تم نارنجی ـ سرمه‌ای فعال شد', 'Neon theme on'));
    } else if (target.startsWith('/')) {
      context.push(target);
    }
  }

  bool _back() {
    if (_pop) {
      setState(() => _pop = false);
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
              tab: _tab,
              onTab: (int t) => setState(() => _tab = t),
              onClose: _closeWorld,
              onItem: _nav,
            ),
            // ----------------------------------------------------------- HUD
            if (!inWorld) PositionedDirectional(top: pad.top + 14, start: 14, child: _profileHud(context, p)),
            if (_pop && !inWorld)
              Positioned.fill(
                child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => setState(() => _pop = false)),
              ),
            if (_pop && !inWorld) PositionedDirectional(top: pad.top + 76, start: 14, child: const _ProfilePop()),
            // ----------------------------------------------------------- nav
            Positioned(
              left: 14,
              right: 14,
              bottom: pad.bottom + 12,
              child: _NavBar(active: inWorld ? 'w$_world' : 'home', onTap: _nav),
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
          for (int i = 0; i < kStationCarouselWorlds; i++)
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
    final List<int> order = List<int>.generate(kStationCarouselWorlds, (int i) => i)
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

/// A hub (`#world`): header, chip row and the shared [StationHubGrid]. «بیشتر» adds sign-in when signed out.
class _WorldView extends ConsumerWidget {
  const _WorldView({super.key, required this.world, required this.tab, required this.onTab, required this.onClose, required this.onItem});
  final StationWorld world;
  final int tab;
  final ValueChanged<int> onTab;
  final VoidCallback onClose;
  final ValueChanged<String> onItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool fa = stationFa(context);
    final bool signedIn = ref.watch(onlineProvider.select((OnlineService o) => o.user != null && !o.isGuest));
    final List<StationItem> list = <StationItem>[
      ...world.items.where((StationItem x) => tab == 0 || x.tab == tab),
      if (world.k == 'more' && !signedIn)
        const StationItem(fa: 'ورود / ثبت‌نام', en: 'Sign in', tab: 0, rarity: 1, icon: 'assets/station/hub/account.webp', route: '/auth'),
    ];
    final List<String> tabs = <String>[if ((fa ? world.tabsFa : world.tabsEn).isNotEmpty) stx(context, 'همه', 'All'), ...(fa ? world.tabsFa : world.tabsEn)];
    final double bottom = MediaQuery.paddingOf(context).bottom + 92 + 28;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: kStationEase,
      builder: (_, double v, Widget? c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 18 * (1 - v)), child: c)),
      child: SafeArea(
        bottom: false,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
          StationHubHeader(title: fa ? world.fa : world.en, icon: world.icon, onClose: onClose),
          if (tabs.isNotEmpty) StationHubChips(labels: tabs, icons: world.tabIcons, index: tab, onChanged: onTab),
          const SizedBox(height: 8),
          Expanded(
            child: StationHubGrid(
              key: PageStorageKey<String>('hub-${world.k}-$tab'),
              padding: EdgeInsets.fromLTRB(16, 6, 16, bottom),
              entries: <StationHubEntry>[
                for (final StationItem it in list)
                  StationHubEntry(
                    label: fa ? it.fa : it.en,
                    image: it.icon,
                    onTap: () => (it.route.startsWith('/') && it.route != '/') ? it.open(context) : onItem(it.route),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// `#nav` — the floating glass bar: خانه · چت · centre gold «روم» · تورنمنت · بیشتر.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.active, required this.onTap});
  final String active;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    return RepaintBoundary(
      child: SizedBox(
        height: 92,
        child: Stack(clipBehavior: Clip.none, alignment: Alignment.bottomCenter, children: <Widget>[
          Container(
            height: 66,
            decoration: BoxDecoration(
              // Nearly opaque: the hub grid scrolls underneath.
              color: p.isLight ? p.navBg : const Color(0xF20C0926),
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
                  const SizedBox(width: 78)
                else
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => onTap(e.target),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: kStationEase,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: active == e.target
                              ? LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: <Color>[p.gold.withValues(alpha: .22), p.gold.withValues(alpha: .04)])
                              : null,
                          border: active == e.target ? Border.all(color: p.gold.withValues(alpha: .3)) : null,
                        ),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                          Icon(e.icon, size: 24, color: active == e.target ? const Color(0xFFFFC24A) : (p.isLight ? p.ink : const Color(0xFFE9DDF8))),
                          const SizedBox(height: 2),
                          Text(fa ? e.fa : e.en,
                              maxLines: 1,
                              style: TextStyle(
                                  fontFamily: kStationFont,
                                  fontSize: 11,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                  color: active == e.target ? const Color(0xFFFFC24A) : (p.isLight ? p.ink : const Color(0xFFE9DDF8)))),
                        ]),
                      ),
                    ),
                  ),
            ]),
          ),
          // Centre «روم» button: gold ring, house icon, label.
          Positioned(
            bottom: 22,
            child: GestureDetector(
              onTap: () => onTap('rooms'),
              child: Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(center: Alignment(0, -.4), colors: <Color>[Color(0xFF3A2A12), Color(0xFF120A04)], stops: <double>[0, .8]),
                  border: Border.all(color: const Color(0xFFFFC24A), width: 3),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: p.bg.withValues(alpha: .85), spreadRadius: 5),
                    const BoxShadow(color: Color(0x99FFB030), blurRadius: 26, spreadRadius: -2),
                  ],
                ),
                child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                  const Icon(Icons.meeting_room_rounded, size: 24, color: Color(0xFFFFC24A)),
                  Text(fa ? 'روم' : 'ROOMS',
                      style: TextStyle(
                          fontFamily: kStationFont, fontSize: fa ? 13 : 9.5, height: 1.15, fontWeight: FontWeight.w700, color: const Color(0xFFFFD77A))),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

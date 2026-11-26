// Team select: the owner's NX pucks by category (tabs), a uniform grid of pucks with their names (each puck exactly as
// cut — selection and lock state live on the tile, never on the art), the picked team's stat card (power / time / aim)
// with select-or-buy + shop buttons, team one / team two toggle, the side's captain, and the ready button with its
// countdown.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nexora/core/economy/gem_shop.dart';

import '../core/bm_data.dart';
import '../core/bm_engine.dart';
import 'fs_intro_data.dart';
import 'fs_intro_ui.dart';
import 'fs_shop.dart';

/// Who plays a side (captain avatar under the toggle).
class FsSidePlayer {
  const FsSidePlayer({required this.name, required this.portrait, required this.badge, this.dim = false});
  final String name;

  /// Asset path of the avatar portrait.
  final String portrait;

  /// Text of the small pill under the avatar ("سطح ۱۴", "ربات").
  final String badge;
  final bool dim;
}

class FsTeamSelect extends StatefulWidget {
  const FsTeamSelect({
    super.key,
    required this.fa,
    required this.teams,
    required this.players,
    required this.onReady,
    required this.onShop,
    required this.onBar,
    this.onChat,
    this.ownedOnlySide0 = true,
    this.readyLabel = 'آماده',
    this.countdown = 45,
    this.freeze = false,
    this.topLane = 0,
    this.side = 0,
    this.onSide,
    this.fixedSide,
  });
  final bool fa;

  /// Team id per side; changed in place by the picker.
  final List<String> teams;
  final List<FsSidePlayer> players;
  final void Function(List<String> teams) onReady;
  final VoidCallback onShop;
  final VoidCallback onBar;
  final VoidCallback? onChat;
  final bool ownedOnlySide0;
  final String readyLabel;
  final int countdown;

  /// Tests: no countdown timer.
  final bool freeze;
  final double topLane;
  final int side;
  final ValueChanged<int>? onSide;

  /// Online: the only side this phone picks for (the opponent picks theirs on their own phone). The other side's
  /// toggle shows a hint instead of switching, so the arrows / buy button can only change this side.
  final int? fixedSide;

  @override
  State<FsTeamSelect> createState() => _FsTeamSelectState();
}

class _FsTeamSelectState extends State<FsTeamSelect> {
  late int _side = widget.side;
  late final List<int> _browse = <int>[
    for (final String t in widget.teams) kBmTeams.indexWhere((BmTeam x) => x.id == t).clamp(0, kBmTeams.length - 1),
  ];
  late final List<String> _categories = <String>[
    for (final String t in widget.teams) bmTeam(t).cat,
  ];
  late int _left = widget.countdown;
  Timer? _timer;
  bool _done = false;
  String _toast = '';
  Timer? _toastT;

  @override
  void initState() {
    super.initState();
    GemShop.instance.addListener(_changed);
    if (!widget.freeze) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (_left <= 1) {
          _ready();
          return;
        }
        setState(() => _left--);
      });
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    _toastT?.cancel();
    GemShop.instance.removeListener(_changed);
    super.dispose();
  }

  void _ready() {
    if (_done) return;
    _done = true;
    _timer?.cancel();
    widget.onReady(List<String>.of(widget.teams));
  }

  void _say(String s) {
    _toastT?.cancel();
    setState(() => _toast = s);
    _toastT = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _toast = '');
    });
  }

  BmTeam get _t => kBmTeams[_browse[_side]];
  String get _category => _categories[_side];

  /// Tiles of the active category: the NX pucks, or in the custom tab every shared custom team (the "create" tile
  /// is not a team and lives in the shop).
  List<BmTeam> get _categoryTeams => kBmTeams
      .where((BmTeam t) => t.cat == _category && t.id != kCustomTeamId)
      .toList(growable: false);

  /// Tapping a puck shows it in the stat card; an owned puck (any puck for the opponent side) is also picked.
  void _browseTeam(BmTeam t) => setState(() {
        _browse[_side] = kBmTeams.indexOf(t);
        if (!_needsOwn || GemShop.instance.ownsTeam(t.id)) widget.teams[_side] = t.id;
      });

  void _pickCategory(String category) => setState(() {
        _categories[_side] = category;
        final List<BmTeam> group = _categoryTeams;
        if (group.isEmpty) return;
        final int at = group.indexWhere((BmTeam t) => t.id == widget.teams[_side]);
        _browse[_side] = kBmTeams.indexOf(at < 0 ? group.first : group[at]);
      });

  bool get _needsOwn => _side == 0 && widget.ownedOnlySide0;

  Future<void> _selectOrBuy() async {
    final BmTeam t = _t;
    if (t.id == kCustomTeamId) {
      // the "create" tile is not a team: the player's own custom team is listed with the shared ones
      _say(widget.fa ? 'تیم اختصاصی را در لابی بساز' : 'Create your custom team in the lobby');
      return;
    }
    if (_needsOwn && !GemShop.instance.ownsTeam(t.id)) {
      final bool ok = await fsBuyTeam(context, t, widget.fa);
      if (!ok || !mounted) return;
    }
    setState(() => widget.teams[_side] = t.id);
  }

  void _showTable() {
    final List<BmTeam> rows = List<BmTeam>.of(kBmTeams)
      ..sort((BmTeam a, BmTeam b) => (b.power + b.accuracy).compareTo(a.power + a.accuracy));
    showDialog<void>(
      context: context,
      builder: (BuildContext c) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: kFsNavy,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 60),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: kFsNavyEdge)),
          child: Column(children: <Widget>[
            const SizedBox(height: 14),
            Text('جدول تیم ها', style: fsText(18, weight: FontWeight.w900)),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: <Widget>[
                SizedBox(width: 28, child: Text('#', style: fsText(11, color: const Color(0xFF9EA3C7)))),
                Expanded(child: Text('تیم', style: fsText(11, color: const Color(0xFF9EA3C7)))),
                for (final String h in <String>['قدرت', 'زمان', 'هدف'])
                  SizedBox(width: 40, child: Text(h, textAlign: TextAlign.center, style: fsText(11, color: const Color(0xFF9EA3C7)))),
              ]),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: rows.length,
                itemBuilder: (BuildContext c, int i) {
                  final BmTeam t = rows[i];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(color: kFsNavyTile, borderRadius: BorderRadius.circular(8)),
                    child: Row(children: <Widget>[
                      SizedBox(width: 28, child: Text(fsFa(i + 1), style: fsText(12))),
                      SizedBox(width: 26, height: 26, child: Image.asset(bmTeamThumb(t), cacheWidth: 64, errorBuilder: (_, __, ___) => const SizedBox())),
                      const SizedBox(width: 6),
                      Expanded(child: Text(fsTeamName(t, widget.fa), overflow: TextOverflow.ellipsis, style: fsText(12))),
                      for (final int v in <int>[t.power, fsTimeStat(t), t.accuracy])
                        SizedBox(width: 40, child: Text(fsFa(v), textAlign: TextAlign.center, style: fsText(12, color: kFsLime))),
                    ]),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _tab(String category, String label) {
    final bool on = _category == category;
    return Expanded(
      child: FsPress(
        key: ValueKey<String>('fs_tab_$category'),
        onTap: () => _pickCategory(category),
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: on ? const <Color>[Color(0xFFC8F53A), Color(0xFF7DCB12)] : const <Color>[Color(0xFF22C3A2), kFsTealDark]),
            border: Border.all(color: on ? const Color(0xFF3F8F0A) : const Color(0xFF0A5E4D)),
          ),
          alignment: Alignment.center,
          child: Text(label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              softWrap: false,
              style: fsText(10.5, color: on ? const Color(0xFF173A05) : Colors.white, weight: FontWeight.w900, height: 1.4)),
        ),
      ),
    );
  }

  /// One grid tile: the puck exactly as cut, its name, and under the name its price (locked) or a tick (picked).
  Widget _tile(BmTeam t, bool fa) {
    final GemShop shop = GemShop.instance;
    final bool browsed = _t.id == t.id;
    final bool picked = widget.teams[_side] == t.id;
    final bool locked = _needsOwn && !shop.ownsTeam(t.id);
    final String? url = t.crestUrl;
    return GestureDetector(
      key: ValueKey<String>('fs_team_${t.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _browseTeam(t),
      child: Container(
        decoration: BoxDecoration(
          color: browsed ? const Color(0xFF2E3460) : const Color(0xCC1C2038),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: picked ? kFsLime : (browsed ? kFsYellow : kFsNavyEdge), width: picked || browsed ? 2 : 1),
        ),
        padding: const EdgeInsets.fromLTRB(3, 5, 3, 3),
        child: Column(children: <Widget>[
          SizedBox(
            width: 60,
            height: 60,
            child: url != null && url.isNotEmpty
                ? FsDisc3D(asset: t.asset, r: 26, depth: 4, networkUrl: url)
                : Image.asset(bmTeamThumb(t),
                    width: 60,
                    height: 60,
                    fit: BoxFit.contain,
                    cacheWidth: 128,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => const SizedBox()),
          ),
          const SizedBox(height: 3),
          Expanded(
            child: Text(fsTeamName(t, fa),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: fsText(9.5, weight: FontWeight.w800, height: 1.15)),
          ),
          SizedBox(
            height: 14,
            child: locked
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                    Text(fsFa(shop.teamPrice(t.id)), style: fsText(9.5, color: kFsYellow, weight: FontWeight.w900, height: 1)),
                    const SizedBox(width: 2),
                    const FsGem(size: 10),
                  ])
                : picked
                    ? const Icon(Icons.check_circle_rounded, size: 13, color: kFsLime)
                    : const SizedBox(),
          ),
        ]),
      ),
    );
  }

  Widget _bar(String label, int v) => Row(textDirection: TextDirection.rtl, children: <Widget>[
        SizedBox(width: 34, child: Text(label, style: fsText(11, color: const Color(0xFF3B2A12), weight: FontWeight.w900, height: 1))),
        Expanded(
          child: Container(
            height: 12,
            decoration: BoxDecoration(
                color: const Color(0xFF151515), borderRadius: BorderRadius.circular(3), border: Border.all(color: const Color(0xFF2C2C2C))),
            alignment: Alignment.centerRight,
            child: FractionallySizedBox(
              widthFactor: (v / 10).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF8BEA3A), kFsBarGreen, Color(0xFF3F9A10)]),
                ),
              ),
            ),
          ),
        ),
        SizedBox(width: 18, child: Text(fsFa(v), textAlign: TextAlign.center, style: fsText(11, color: const Color(0xFF3B2A12), weight: FontWeight.w900, height: 1))),
      ]);

  Widget _toggle(int side, double left) {
    final bool on = _side == side;
    return Positioned(
      left: left,
      top: 479,
      child: FsPress(
        onTap: () {
          final int? fx = widget.fixedSide;
          if (fx != null && side != fx) {
            _say(widget.fa ? 'حریف تیمش را خودش انتخاب می‌کند' : 'Your opponent picks their own team');
            return;
          }
          setState(() => _side = side);
          widget.onSide?.call(side);
        },
        child: FsBevel(
          w: 86,
          h: 29,
          radius: 4,
          lipH: 4,
          top: on ? const Color(0xFFB4F04A) : const Color(0xFFFFE466),
          bottom: on ? const Color(0xFF79D012) : const Color(0xFFFFC814),
          lip: on ? const Color(0xFF3F8F0A) : const Color(0xFFC98E00),
          child: Text(side == 0 ? 'تیم یک' : 'تیم دو',
              style: fsText(13, color: on ? const Color(0xFF15430A) : const Color(0xFF5A3D00), weight: FontWeight.w900)),
        ),
      ),
    );
  }

  Widget _captain(FsSidePlayer p, double cx) => Positioned(
        left: cx - 50,
        top: 528,
        width: 100,
        child: Opacity(
          opacity: p.dim ? .55 : 1,
          child: Column(children: <Widget>[
            Container(
              width: 98,
              height: 17,
              decoration: BoxDecoration(color: const Color(0xCC4A4A4A), borderRadius: BorderRadius.circular(4)),
              child: Center(child: Text('کاپیتان', style: fsText(10.5, height: 1))),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 66,
              child: Stack(clipBehavior: Clip.none, alignment: Alignment.topCenter, children: <Widget>[
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF2B3050),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(p.portrait,
                        fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.person, color: Colors.white)),
                  ),
                ),
                Positioned(
                  top: 44,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    height: 15,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                    child: Center(child: Text(p.badge, style: fsText(9.5, color: const Color(0xFF333333), height: 1))),
                  ),
                ),
              ]),
            ),
            Container(
              width: 99,
              height: 17,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
              child: Center(
                  child: Text(p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: fsText(10.5, color: const Color(0xFF1E2A4A), weight: FontWeight.w900, height: 1))),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final BmTeam t = _t;
    final bool owned = !_needsOwn || GemShop.instance.ownsTeam(t.id);
    final bool picked = widget.teams[_side] == t.id;
    final Widget action = !owned
        ? fsBuyButton('خرید', GemShop.instance.teamPrice(t.id), 130, 28, size: 12)
        : picked
            ? fsGreyButton('انتخاب شده', 130, 28, size: 12)
            : fsLimeButton('انتخاب', 130, 28, size: 12);
    final List<BmTeam> group = _categoryTeams;
    return FsCanvas(topLane: widget.topLane, children: <Widget>[
      Positioned(
        left: 8,
        right: 8,
        top: 40,
        height: 34,
        child: Row(children: <Widget>[
          for (final List<Object> row in kBmCats) _tab(row[0] as String, fsTeamCategoryName(row[0] as String, widget.fa)),
          FsPress(
            onTap: _showTable,
            child: Container(
              width: 34,
              height: 34,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF22C3A2), kFsTealDark]),
                border: Border.all(color: const Color(0xFF0A5E4D)),
              ),
              child: const Icon(Icons.leaderboard_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
      Positioned(
        left: 8,
        right: 8,
        top: 80,
        height: 318,
        child: group.isEmpty
            ? Center(
                child: Text(widget.fa ? 'هنوز تیم اختصاصی‌ای نیست؛ در فروشگاه بساز' : 'No custom teams yet — create one in the shop',
                    textAlign: TextAlign.center, style: fsText(12)))
            : RepaintBoundary(
                child: GridView.builder(
                  key: ValueKey<String>('fs_grid_$_category'),
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, mainAxisSpacing: 6, crossAxisSpacing: 6, childAspectRatio: 80 / 108),
                  itemCount: group.length,
                  itemBuilder: (BuildContext c, int i) => _tile(group[i], widget.fa),
                ),
              ),
      ),
      Positioned(
        left: 8,
        top: 404,
        width: 206,
        height: 70,
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
          decoration: BoxDecoration(
            color: kFsCream,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kFsCreamEdge, width: 2),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x66000000), blurRadius: 5, offset: Offset(0, 2))],
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            _bar('قدرت', t.power),
            _bar('زمان', fsTimeStat(t)),
            _bar('هدف', t.accuracy),
          ]),
        ),
      ),
      Positioned(
        left: 220,
        top: 402,
        width: 132,
        child: Column(children: <Widget>[
          Text(fsTeamName(t, widget.fa),
              maxLines: 1, overflow: TextOverflow.ellipsis, style: fsText(12.5, weight: FontWeight.w900, height: 1.2)),
          const SizedBox(height: 3),
          FsPress(onTap: picked && owned ? null : _selectOrBuy, child: action),
          const SizedBox(height: 4),
          FsPress(
            onTap: widget.onShop,
            child: FsBevel(
              w: 130,
              h: 24,
              radius: 5,
              lipH: 3,
              top: const Color(0xFFFFFFFF),
              bottom: const Color(0xFFDADADA),
              lip: const Color(0xFF7B7B7B),
              child: Text('فروشگاه', style: fsText(12, color: const Color(0xFF333333), weight: FontWeight.w900)),
            ),
          ),
        ]),
      ),
      _toggle(0, 193),
      _toggle(1, 81),
      _captain(widget.players[_side.clamp(0, widget.players.length - 1)], 181),
      Positioned(
        left: 103,
        top: 724,
        child: FsPress(
          onTap: _ready,
          child: Container(
            width: 154,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9).withValues(alpha: .93),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF9A9A9A)),
              boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x55000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Text(widget.readyLabel, style: fsText(14, color: const Color(0xFF222222), weight: FontWeight.w700, height: 1)),
              const SizedBox(width: 12),
              Text(fsFa(_left), style: fsText(22, color: const Color(0xFF111111), weight: FontWeight.w900, height: 1)),
            ]),
          ),
        ),
      ),
      Positioned(left: 0, top: 730, child: FsBarHandle(players: widget.players.length, onTap: widget.onBar)),
      Positioned(left: 270, top: 683, child: FsChatButton(onTap: widget.onChat)),
      if (_toast.isNotEmpty)
        Positioned(
          left: 40,
          right: 40,
          top: 660,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: const Color(0xE61C2038), borderRadius: BorderRadius.circular(14)),
              child: Text(_toast, style: fsText(12)),
            ),
          ),
        ),
    ]);
  }
}

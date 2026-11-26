import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sfx_service.dart';
import '../../core/storage/local_store.dart';
import '../arcade_kit/arcade_fx.dart';
import '../solo/solo_kit.dart';
import 'water_sort_art.dart';
import 'water_sort_core.dart';

/// ===================== WATER SORT — BOARD =====================
/// Tap a tube to lift it, tap another to pour: the tube flies over, tilts until its liquid
/// meets the lip, and a glossy stream arcs into the target while one drains and the other
/// fills. Full single-colour tubes get corked. Boosters: undo, an extra empty tube, a hint
/// (from the solver) and restart. Levels are endless and saved; the session score is what
/// the shell reports when the player ends the run.
/// ==============================================================

const String _kLevelKey = 'water_sort.level';
const String _kBestLevelKey = 'water_sort.best_level';
const int _kUndoPerLevel = 5;
const int _kTubePerLevel = 1;
const int _kHintPerLevel = 2;

String wsFaNum(int n) => n.toString().split('').map((String d) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(d)]).join();

class WaterSortBoard extends SoloBoard {
  const WaterSortBoard({super.key, required super.run, this.startLevel});

  /// Forces the starting level (render tests); otherwise the saved level is used.
  final int? startLevel;

  @override
  WaterSortBoardState createState() => WaterSortBoardState();
}

class WsTubeVis {
  double lift = 0;
  double liftTarget = 0;
  double wave = 0;
  double shake = 0;
  double cork = -1;
  double appear = 1;
  double shine = -1;
  final List<WsBubble> bubbles = <WsBubble>[];
}

class WsPour {
  WsPour(this.move, this.src, this.dst, this.dir, this.a0, this.a1);
  final WsMove move;
  final WsTube src; // snapshot before the pour
  final WsTube dst;
  final double dir;
  final double a0; // tilt when the liquid first reaches the lip
  final double a1; // tilt once the run has left
  double t = 0;

  static const double moveDur = 0.26;
  static const double backDur = 0.3;
  double get pourDur => 0.22 + 0.13 * move.amount;
  double get total => moveDur + pourDur + backDur;

  /// 0..1 progress of the actual pouring phase.
  double get flow => ((t - moveDur) / pourDur).clamp(0.0, 1.0);

  /// Eased volume transferred so far (0..1), shared by the draining and the filling tube.
  double get vol => Curves.easeInOutSine.transform(flow);
  bool get done => t >= total;
}

class WaterSortBoardState extends SoloBoardState<WaterSortBoard> {
  late int level;
  late WsLevel cur;
  late WsBoard board;
  final List<WsTubeVis> vis = <WsTubeVis>[];
  final List<WsPour> pours = <WsPour>[];
  final math.Random _rnd = math.Random(7);
  int? selected;
  int moves = 0;
  int boosters = 0;
  int undoLeft = _kUndoPerLevel;
  int tubeLeft = _kTubePerLevel;
  int hintLeft = _kHintPerLevel;
  List<int>? hint;
  double hintT = 0;
  bool stuck = false;
  double celebrate = -1;
  bool complete = false;
  int lastStars = 0;
  int lastPoints = 0;
  int clearedThisRun = 0;
  String? toast;
  double toastT = 0;

  // Layout cache.
  Size _laid = Size.zero;
  int _laidN = -1;
  EdgeInsets pad = EdgeInsets.zero;
  WsGeom geom = WsGeom(40);
  final List<Offset> homes = <Offset>[];
  final List<Rect> shelves = <Rect>[];
  final List<double> shelfOf = <double>[];
  double slot = 60;
  Rect? _bgRect;

  bool get isFa => widget.run.launch.isFa;
  String tx(String fa, String en) => isFa ? fa : en;

  LocalStore? get _store {
    try {
      return LocalStore.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    WsArt.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void reset() {
    level = widget.startLevel ?? math.max(1, _store?.getInt(_kLevelKey) ?? 1);
    widget.run.set(0);
    clearedThisRun = 0;
    _loadLevel();
  }

  void _loadLevel() {
    cur = WsLevel.generate(level);
    board = cur.board.copy();
    vis
      ..clear()
      ..addAll(<WsTubeVis>[for (int i = 0; i < board.tubes.length; i++) WsTubeVis()..appear = 0]);
    for (int i = 0; i < vis.length; i++) {
      vis[i].appear = -i * 0.06; // staggered pop-in
    }
    pours.clear();
    selected = null;
    moves = 0;
    boosters = 0;
    undoLeft = _kUndoPerLevel;
    tubeLeft = _kTubePerLevel;
    hintLeft = _kHintPerLevel;
    hint = null;
    stuck = false;
    celebrate = -1;
    complete = false;
    _laidN = -1;
  }

  // ------------------------------------------------------------------ layout

  void _layout(Size size) {
    final int n = board.tubes.length;
    if (size == _laid && n == _laidN) return;
    _laid = size;
    _laidN = n;
    final double top = pad.top + 150;
    final double bottom = size.height - pad.bottom - 124;
    final double h = math.max(200, bottom - top);
    final double wAvail = size.width - 20;
    int bestRows = 1;
    double bestW = 0;
    for (int rows = 1; rows <= 4; rows++) {
      final int per = (n / rows).ceil();
      final double sw = wAvail / per;
      final double rh = h / rows;
      final double w = math.min(math.min(sw * 0.6, rh / (4.3 * 1.3)), 62);
      if (w > bestW + 0.5) {
        bestW = w;
        bestRows = rows;
      }
    }
    geom = WsGeom(bestW);
    final int per = (n / bestRows).ceil();
    slot = math.min(wAvail / per, bestW * 2.05);
    final double rh = h / bestRows;
    homes.clear();
    shelves.clear();
    shelfOf.clear();
    int idx = 0;
    for (int r = 0; r < bestRows; r++) {
      final int cnt = math.min(per, n - idx);
      if (cnt <= 0) break;
      final double blockH = geom.len * 1.22;
      final double mouthY = top + r * rh + (rh - blockH) / 2 + geom.len * 0.2;
      final double shelfY = mouthY + geom.len + 4;
      for (int j = 0; j < cnt; j++) {
        homes.add(Offset(size.width / 2 + (j - (cnt - 1) / 2) * slot, mouthY));
        shelfOf.add(shelfY);
      }
      final double half = (cnt - 1) / 2 * slot + geom.w * 1.1;
      shelves.add(Rect.fromLTRB(size.width / 2 - half, shelfY, size.width / 2 + half, shelfY + math.max(8, geom.w * 0.22)));
      idx += cnt;
    }
  }

  Offset _mouth(int i) => homes[i] + Offset(math.sin(vis[i].shake * 40) * vis[i].shake * 26, -vis[i].lift * geom.u * 0.95);

  // ------------------------------------------------------------------ geometry helpers

  /// Liquid level (local y, relative to the mouth) of [units] when tilted by [phi].
  double _levelAt(double units, double phi) {
    final List<Offset> lp = geom.polygon();
    final double area = wsAreaBelow(lp, geom.len - units * geom.u);
    final double c = math.cos(phi);
    final double s = math.sin(phi);
    final List<Offset> rp = <Offset>[for (final Offset p in lp) Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c)];
    double lo = -geom.len * 2;
    double hi = geom.len * 2;
    for (int i = 0; i < 24; i++) {
      final double mid = (lo + hi) / 2;
      if (wsAreaBelow(rp, mid) > area) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  /// Tilt at which [units] of liquid just reach the lip (dir = +1, lip at local (+w/2, 0)).
  double _pourAngle(double units) {
    if (units <= 0.05) return 118 * math.pi / 180;
    double lo = 12 * math.pi / 180;
    double hi = 125 * math.pi / 180;
    for (int i = 0; i < 18; i++) {
      final double mid = (lo + hi) / 2;
      final double lipY = geom.w / 2 * math.sin(mid);
      // Screen y grows downward: liquid level above (smaller than) the lip means it spills.
      if (_levelAt(units, mid) > lipY) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  Offset _lipLocal(double dir) => Offset(dir * geom.w / 2, 0);

  /// Mouth position that puts the lip right above the target's mouth for tilt [phi].
  Offset _pourMouth(WsPour p, double phi) {
    final Offset target = homes[p.move.to] + Offset(-p.dir * geom.w * 0.12, -geom.len * 0.2);
    final double a = p.dir * phi;
    final Offset lip = _lipLocal(p.dir);
    final Offset rot = Offset(lip.dx * math.cos(a) - lip.dy * math.sin(a), lip.dx * math.sin(a) + lip.dy * math.cos(a));
    return target - rot;
  }

  /// Mouth position + angle of a pouring tube at its current time.
  (Offset, double) _pourPose(WsPour p) {
    final Offset home = homes[p.move.from];
    if (p.t < WsPour.moveDur) {
      final double k = Curves.easeInOutCubic.transform(p.t / WsPour.moveDur);
      final Offset start = home + Offset(0, -geom.u * 0.95);
      return (Offset.lerp(start, _pourMouth(p, p.a0), k)!, p.dir * p.a0 * k);
    }
    if (p.t < WsPour.moveDur + p.pourDur) {
      final double f = p.vol;
      final double a = ui.lerpDouble(p.a0, p.a1, f)!;
      return (_pourMouth(p, a), p.dir * a);
    }
    final double k = Curves.easeInOutCubic.transform(((p.t - WsPour.moveDur - p.pourDur) / WsPour.backDur).clamp(0.0, 1.0));
    return (Offset.lerp(_pourMouth(p, p.a1), home, k)!, p.dir * p.a1 * (1 - k));
  }

  List<WsSeg> _segs(WsTube t, {double drain = 0, int? addColor, double add = 0}) {
    final List<WsSeg> out = <WsSeg>[];
    for (int i = 0; i < t.units.length; i++) {
      final bool h = t.hidden[i];
      if (out.isNotEmpty && out.last.color == t.units[i] && out.last.hidden == h) {
        out.last.amount += 1;
      } else {
        out.add(WsSeg(t.units[i], 1, hidden: h));
      }
    }
    double d = drain;
    while (d > 0 && out.isNotEmpty) {
      final double take = math.min(d, out.last.amount);
      out.last.amount -= take;
      d -= take;
      if (out.last.amount <= 0.0001) out.removeLast();
    }
    if (addColor != null && add > 0) {
      if (out.isNotEmpty && out.last.color == addColor && !out.last.hidden) {
        out.last.amount += add;
      } else {
        out.add(WsSeg(addColor, add));
      }
    }
    return out;
  }

  double _units(WsTube t) => t.units.length.toDouble();

  // ------------------------------------------------------------------ input

  bool _busy(int i) => pours.any((WsPour p) => p.move.from == i || p.move.to == i);

  void _onTap(TapDownDetails d) {
    if (!widget.run.playing || widget.run.over || complete || celebrate >= 0) return;
    final Offset at = d.localPosition;
    int? hit;
    for (int i = 0; i < homes.length && i < board.tubes.length; i++) {
      final Offset m = homes[i];
      final Rect r = Rect.fromLTRB(m.dx - slot / 2, m.dy - geom.len * 0.35, m.dx + slot / 2, m.dy + geom.len + 14);
      if (r.contains(at)) {
        hit = i;
        break;
      }
    }
    if (hit == null) {
      _deselect();
      return;
    }
    if (_busy(hit)) return;
    final int? s = selected;
    if (s == null) {
      final WsTube t = board.tubes[hit];
      if (t.isEmpty || t.complete) {
        vis[hit].shake = 0.25;
        HapticFeedback.selectionClick();
        return;
      }
      selected = hit;
      vis[hit].liftTarget = 1;
      vis[hit].wave = 2.5;
      HapticFeedback.selectionClick();
      NxSfx.instance.play('tick', gain: 0.7);
      return;
    }
    if (s == hit) {
      _deselect();
      return;
    }
    if (board.canPour(s, hit)) {
      _startPour(s, hit);
    } else {
      // Invalid target: wobble it and switch the selection when the tapped tube can pour.
      vis[hit].shake = 0.3;
      HapticFeedback.lightImpact();
      final WsTube t = board.tubes[hit];
      _deselect();
      if (!t.isEmpty && !t.complete) {
        selected = hit;
        vis[hit].liftTarget = 1;
      }
    }
  }

  void _deselect() {
    final int? s = selected;
    if (s != null && s < vis.length) {
      vis[s].liftTarget = 0;
      vis[s].wave = math.max(vis[s].wave, 2.2);
    }
    selected = null;
  }

  void _startPour(int a, int b) {
    final WsTube srcBefore = board.tubes[a].copy();
    final WsTube dstBefore = board.tubes[b].copy();
    final WsMove? m = board.pour(a, b);
    if (m == null) return;
    selected = null;
    vis[a].liftTarget = 0;
    hint = null;
    stuck = false;
    moves++;
    final double dir = homes[b].dx >= _laid.width / 2 ? 1 : -1;
    final double a0 = _pourAngle(_units(srcBefore));
    final double a1 = math.max(a0 + 0.12, _pourAngle(_units(srcBefore) - m.amount) + 0.1);
    pours.add(WsPour(m, srcBefore, dstBefore, dir, a0, a1));
    HapticFeedback.lightImpact();
    NxSfx.instance.play('join', gain: 0.45);
    setState(() {});
  }

  // ------------------------------------------------------------------ boosters

  void undo() {
    if (pours.isNotEmpty || complete || celebrate >= 0) return;
    if (undoLeft <= 0) {
      _toast(tx('برگشت تمام شد', 'No undos left'));
      return;
    }
    final WsMove? m = board.undo();
    if (m == null) {
      _toast(tx('حرکتی برای برگشت نیست', 'Nothing to undo'));
      return;
    }
    undoLeft--;
    boosters++;
    _deselect();
    stuck = false;
    hint = null;
    for (final int i in <int>[m.from, m.to]) {
      vis[i].wave = 4;
      if (!board.tubes[i].complete) vis[i].cork = -1;
    }
    HapticFeedback.selectionClick();
    NxSfx.instance.play('leave', gain: 0.5);
    setState(() {});
  }

  void addTube() {
    if (pours.isNotEmpty || complete || celebrate >= 0) return;
    if (tubeLeft <= 0) {
      _toast(tx('لوله‌ی اضافه استفاده شد', 'Extra tube already used'));
      return;
    }
    tubeLeft--;
    boosters++;
    board.tubes.add(WsTube(<int>[]));
    vis.add(WsTubeVis()..appear = 0);
    _laidN = -1;
    stuck = false;
    HapticFeedback.mediumImpact();
    NxSfx.instance.play('ready', gain: 0.6);
    setState(() {});
  }

  void showHint() {
    if (pours.isNotEmpty || complete || celebrate >= 0) return;
    if (hintLeft <= 0) {
      _toast(tx('راهنما تمام شد', 'No hints left'));
      return;
    }
    final List<List<int>>? sol = board.solve(limit: 30000);
    if (sol == null || sol.isEmpty) {
      _toast(tx('از این‌جا راهی نیست؛ برگرد یا لوله اضافه کن', 'No way out from here: undo or add a tube'));
      return;
    }
    hintLeft--;
    boosters++;
    _deselect();
    hint = sol.first;
    hintT = 0;
    HapticFeedback.selectionClick();
    setState(() {});
  }

  void restartLevel() {
    if (pours.isNotEmpty || celebrate >= 0) return;
    _loadLevel();
    HapticFeedback.mediumImpact();
    setState(() {});
  }

  void nextLevel() {
    level++;
    _loadLevel();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  void finishRun() {
    if (pours.isNotEmpty) return;
    widget.run.gameOver();
    setState(() {});
  }

  void _toast(String s) {
    toast = s;
    toastT = 2.2;
    HapticFeedback.lightImpact();
    setState(() {});
  }

  // ------------------------------------------------------------------ simulation

  @override
  bool get simulating => true;

  @override
  void step(double dt) {
    final bool live = widget.run.playing && !widget.run.over;
    for (int i = 0; i < vis.length; i++) {
      final WsTubeVis v = vis[i];
      v.lift += (v.liftTarget - v.lift) * math.min(1, dt * 16);
      v.wave *= math.exp(-dt * 2.4);
      v.shake = math.max(0, v.shake - dt);
      if (v.appear < 1) v.appear = math.min(1, v.appear + dt * 3.2);
      if (v.cork >= 0 && v.cork < 1) {
        v.cork = math.min(1, v.cork + dt * 1.6);
        if (v.cork >= 1) v.shine = 0;
      }
      if (v.shine >= 0) {
        v.shine += dt * 0.9;
        if (v.shine > 1.2) v.shine = -1 - _rnd.nextDouble() * 4; // re-arm after a pause
      } else if (v.shine < -1) {
        v.shine += dt;
        if (v.shine >= -1) v.shine = 0;
      }
      // Bubbles rise and pop at the surface.
      final double level = i < board.tubes.length ? _displayUnits(i) : 0;
      for (int b = v.bubbles.length - 1; b >= 0; b--) {
        final WsBubble q = v.bubbles[b];
        q.y += q.v * dt;
        q.x += math.sin(clock * 6 + b) * dt * 0.05;
        if (q.y >= level - 0.08) v.bubbles.removeAt(b);
      }
      if (live && level > 0.3 && _rnd.nextDouble() < dt * 0.35 && v.bubbles.length < 6) {
        v.bubbles.add(WsBubble((_rnd.nextDouble() - 0.5) * 0.5, 0.15, 0.9 + _rnd.nextDouble() * 1.2, 0.5 + _rnd.nextDouble() * 0.6));
      }
    }
    if (toastT > 0) {
      toastT -= dt;
      if (toastT <= 0) setState(() => toast = null);
    }
    hintT += dt;
    for (int k = pours.length - 1; k >= 0; k--) {
      final WsPour p = pours[k];
      final double before = p.flow;
      p.t += dt;
      final double after = p.flow;
      if (after > 0 && before < 1) {
        // Splash + bubbles in the target while the stream runs.
        final Offset impact = _impact(p);
        final Color c = kWsColors[p.move.color];
        if (_rnd.nextDouble() < 0.7) {
          fx.burst(impact, Color.lerp(c, Colors.white, 0.2)!,
              count: 2, speed: 170, life: 0.4, size: 2.6, gravity: 900, spread: 1.7, direction: -math.pi / 2, kind: ParticleKind.orb);
        }
        if (_rnd.nextDouble() < dt * 4) fx.ring(impact, Colors.white.withValues(alpha: 0.35), size: geom.w * 0.08, life: 0.25);
        final WsTubeVis dv = vis[p.move.to];
        dv.wave = math.max(dv.wave, 3.2);
        if (_rnd.nextDouble() < dt * 22 && dv.bubbles.length < 14) {
          dv.bubbles.add(WsBubble((_rnd.nextDouble() - 0.5) * 0.6, math.max(0.1, _units(p.dst) - 0.6), 0.8 + _rnd.nextDouble() * 1.6,
              0.8 + _rnd.nextDouble() * 1.4));
        }
      }
      if (p.done) {
        pours.removeAt(k);
        _afterPour(p);
      }
    }
    if (celebrate >= 0) {
      final double was = celebrate;
      celebrate += dt;
      for (final double at in <double>[0.55, 0.85, 1.15]) {
        if (was < at && celebrate >= at) {
          fx.confetti(Offset(_laid.width * (0.2 + _rnd.nextDouble() * 0.6), _laid.height * (0.35 + _rnd.nextDouble() * 0.2)), count: 70);
          fx.flashScreen(const Color(0xFFE9C8FF), 0.18);
        }
      }
      if (was < 1.5 && celebrate >= 1.5) {
        setState(() => complete = true);
      }
    }
  }

  double _displayUnits(int i) {
    for (final WsPour p in pours) {
      if (p.move.to == i) return _units(p.dst) + p.move.amount * p.vol;
      if (p.move.from == i) return _units(p.src) - p.move.amount * p.vol;
    }
    return _units(board.tubes[i]);
  }

  Offset _impact(WsPour p) {
    final Offset m = homes[p.move.to];
    final double units = _units(p.dst) + p.move.amount * p.vol;
    return Offset(m.dx, m.dy + geom.len - units * geom.u);
  }

  void _afterPour(WsPour p) {
    final int a = p.move.from;
    final int b = p.move.to;
    vis[a].wave = 3;
    vis[b].wave = math.max(vis[b].wave, 2);
    if (p.move.revealed.isNotEmpty) {
      final Offset m = homes[a];
      final Offset at = Offset(m.dx, m.dy + geom.len - (board.tubes[a].units.length - 0.5) * geom.u);
      fx.burst(at, const Color(0xFFD9C2FF), count: 16, speed: 140, life: 0.5, size: 3);
      fx.ring(at, kWsColors[board.tubes[a].units.last], size: geom.w * 0.4);
    }
    if (board.tubes[b].complete && vis[b].cork < 0) {
      vis[b].cork = 0;
      final Offset m = homes[b];
      final Color c = kWsColors[board.tubes[b].units.first];
      fx.burst(m + Offset(0, geom.len * 0.4), c, count: 26, speed: 220, life: 0.7, size: 3.4);
      fx.burst(m, Colors.white, count: 10, speed: 160, life: 0.5, size: 2, kind: ParticleKind.orb);
      fx.text(tx('عالی!', 'Sealed!'), m + Offset(0, -geom.len * 0.35), Color.lerp(c, Colors.white, 0.4)!, size: 18);
      HapticFeedback.mediumImpact();
      NxSfx.instance.play('ready', gain: 0.8);
    }
    if (board.solved) {
      if (pours.isEmpty && celebrate < 0) _levelCleared();
      return;
    }
    if (pours.isEmpty && !board.hasMove) {
      setState(() => stuck = true);
      HapticFeedback.heavyImpact();
    }
  }

  void _levelCleared() {
    celebrate = 0;
    _deselect();
    lastStars = WsLevel.stars(moves: moves, par: cur.par, boostersUsed: boosters);
    lastPoints = WsLevel.points(cur.spec, lastStars);
    widget.run.add(lastPoints);
    clearedThisRun++;
    fx.text('+$lastPoints', Offset(_laid.width / 2, _laid.height * 0.42), const Color(0xFFFFE07A), size: 30);
    fx.shake(5);
    HapticFeedback.heavyImpact();
    NxSfx.instance.play('win', gain: 0.8);
    final LocalStore? st = _store;
    if (st != null && widget.startLevel == null) {
      st.setInt(_kLevelKey, level + 1);
      if (level + 1 > (st.getInt(_kBestLevelKey) ?? 0)) st.setInt(_kBestLevelKey, level + 1);
    }
    for (final WsTubeVis v in vis) {
      v.wave = 5;
    }
  }

  // ------------------------------------------------------------------ paint

  @override
  void paint(Canvas canvas, Size size) {
    _layout(size);
    final double t = clock;
    _bgRect = WsPainter.stage(canvas, size, t, animate: widget.run.launch.fancyEffects && !widget.run.launch.reducedMotion);
    for (final Rect s in shelves) {
      WsPainter.shelf(canvas, s, t);
    }
    final Set<int> flying = <int>{for (final WsPour p in pours) p.move.from};
    final Map<int, WsPour> filling = <int, WsPour>{for (final WsPour p in pours) p.move.to: p};
    // Reflections first (under everything).
    for (int i = 0; i < board.tubes.length && i < homes.length; i++) {
      if (vis[i].appear <= 0) continue;
      final List<WsSeg> segs = flying.contains(i)
          ? <WsSeg>[]
          : filling.containsKey(i)
              ? _segs(filling[i]!.dst, addColor: filling[i]!.move.color, add: filling[i]!.move.amount * filling[i]!.vol)
              : _segs(board.tubes[i]);
      WsPainter.reflection(canvas, homes[i], geom, segs, shelfOf[i] + math.max(8, geom.w * 0.22));
    }
    // Resting tubes.
    for (int i = 0; i < board.tubes.length && i < homes.length; i++) {
      if (flying.contains(i)) continue;
      final WsTubeVis v = vis[i];
      final double sc = v.appear <= 0 ? 0 : LuxeBoardPainter.easeOutBack(v.appear);
      final WsPour? f = filling[i];
      final List<WsSeg> segs =
          f != null ? _segs(f.dst, addColor: f.move.color, add: f.move.amount * f.vol) : _segs(board.tubes[i]);
      final bool isHint = hint != null && (hint![0] == i || hint![1] == i);
      final double sel = selected == i ? 1.0 : (isHint ? 0.5 + 0.5 * math.sin(hintT * 6) : v.lift);
      final Offset mouth = _mouth(i) + Offset(0, geom.len * (1 - sc));
      WsPainter.tube(canvas,
          mouth: mouth,
          angle: math.sin(v.shake * 50) * v.shake * 0.25,
          g: geom,
          segs: segs,
          t: t + i * 0.7,
          wave: v.wave,
          selected: sel,
          corkT: board.tubes[i].complete && f == null ? math.max(0, v.cork) : -1,
          scale: sc,
          bubbles: v.bubbles,
          refractRect: _bgRect,
          accent: isHint ? const Color(0xFFFFE07A) : const Color(0xFFE6C4FF));
      if (board.tubes[i].complete && v.cork >= 1 && v.shine >= 0 && v.shine <= 1.2) _shine(canvas, mouth, v.shine);
    }
    if (hint != null && pours.isEmpty) _hintArrow(canvas, hint![0], hint![1], t);
    // Pouring tubes + streams on top.
    for (final WsPour p in pours) {
      final (Offset mouth, double angle) = _pourPose(p);
      final List<WsSeg> segs = _segs(p.src, drain: p.move.amount * p.vol);
      WsPainter.tube(canvas, mouth: mouth, angle: angle, g: geom, segs: segs, t: t, wave: 1.2, selected: 0.6);
      if (p.t > WsPour.moveDur && p.t < WsPour.moveDur + p.pourDur + 0.08) {
        final double ft = p.t - WsPour.moveDur;
        final double head = (ft / 0.12).clamp(0.0, 1.0);
        final double tail = ((ft - p.pourDur + 0.1) / 0.18).clamp(0.0, 1.0);
        final Offset lip = mouth +
            Offset(_lipLocal(p.dir).dx * math.cos(angle) - _lipLocal(p.dir).dy * math.sin(angle),
                _lipLocal(p.dir).dx * math.sin(angle) + _lipLocal(p.dir).dy * math.cos(angle));
        WsPainter.stream(canvas, lip, _impact(p), geom.w * 0.3, kWsColors[p.move.color], t,
            head: head, tail: tail, dir: p.dir);
      }
    }
    LuxeBoardPainter.vignette(canvas, size);
  }

  void _shine(Canvas canvas, Offset mouth, double k) {
    final Path p = geom.interior().shift(mouth);
    canvas.save();
    canvas.clipPath(p);
    final double y = mouth.dy + geom.len * (1.2 - k * 1.5);
    canvas.drawPath(
        Path()
          ..moveTo(mouth.dx - geom.w, y)
          ..lineTo(mouth.dx + geom.w, y - geom.w * 0.9)
          ..lineTo(mouth.dx + geom.w, y - geom.w * 0.5)
          ..lineTo(mouth.dx - geom.w, y + geom.w * 0.4)
          ..close(),
        Paint()
          ..blendMode = BlendMode.plus
          ..color = const Color(0x55FFFFFF));
    canvas.restore();
  }

  void _hintArrow(Canvas canvas, int a, int b, double t) {
    final Offset p0 = homes[a] + Offset(0, -geom.len * 0.12);
    final Offset p1 = homes[b] + Offset(0, -geom.len * 0.12);
    final Offset ctrl = Offset((p0.dx + p1.dx) / 2, math.min(p0.dy, p1.dy) - geom.len * 0.55);
    final Path path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(ctrl.dx, ctrl.dy, p1.dx, p1.dy);
    final double pulse = 0.6 + 0.4 * math.sin(t * 6);
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..color = const Color(0xFFFFD34E).withValues(alpha: 0.35 * pulse)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    for (final ui.PathMetric m in path.computeMetrics()) {
      final double len = m.length;
      for (double d = (t * 60) % 16; d < len - 10; d += 16) {
        final ui.Tangent? tg = m.getTangentForOffset(d);
        if (tg == null) continue;
        canvas.drawCircle(tg.position, 2.4, Paint()..color = const Color(0xFFFFE9A3).withValues(alpha: pulse));
      }
      final ui.Tangent? end = m.getTangentForOffset(len);
      if (end != null) {
        final Offset dir = end.vector / end.vector.distance;
        final Offset nrm = Offset(-dir.dy, dir.dx);
        final Path head = Path()
          ..moveTo(end.position.dx, end.position.dy)
          ..lineTo(end.position.dx - dir.dx * 14 + nrm.dx * 8, end.position.dy - dir.dy * 14 + nrm.dy * 8)
          ..lineTo(end.position.dx - dir.dx * 14 - nrm.dx * 8, end.position.dy - dir.dy * 14 - nrm.dy * 8)
          ..close();
        canvas.drawPath(head, Paint()..color = const Color(0xFFFFE07A));
      }
    }
  }

  // ------------------------------------------------------------------ widgets

  @override
  Widget build(BuildContext context) {
    pad = MediaQuery.paddingOf(context);
    final bool canAct = widget.run.playing && !widget.run.over && !complete && celebrate < 0;
    return Stack(fit: StackFit.expand, children: <Widget>[
      GestureDetector(behavior: HitTestBehavior.opaque, onTapDown: _onTap, child: super.build(context)),
      Positioned(
        top: pad.top + 94,
        left: 0,
        right: 0,
        child: IgnorePointer(child: Center(child: _levelPill())),
      ),
      Positioned(
        left: 10,
        right: 10,
        bottom: pad.bottom + 14,
        child: AnimatedOpacity(
          opacity: widget.run.playing || widget.run.over ? 1 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: _boosterBar(canAct),
        ),
      ),
      if (stuck && canAct)
        Positioned(left: 24, right: 24, bottom: pad.bottom + 128, child: _banner(
          tx('حرکتی نمانده! برگرد، لوله اضافه کن یا از نو شروع کن', 'Out of moves! Undo, add a tube or restart'),
          const Color(0xFFFF6B8A),
        )),
      if (toast != null)
        Positioned(left: 24, right: 24, top: pad.top + 140, child: IgnorePointer(child: _banner(toast!, const Color(0xFFB98CFF)))),
      if (complete) Positioned.fill(child: _completeCard()),
    ]);
  }

  TextStyle _ts(double size, {FontWeight w = FontWeight.w800, Color c = Colors.white}) => TextStyle(
        fontFamily: isFa ? 'Estedad' : 'ChakraPetch',
        fontSize: size,
        fontWeight: w,
        color: c,
        height: 1.2,
        shadows: const <Shadow>[Shadow(color: Color(0xAA12052A), blurRadius: 6, offset: Offset(0, 2))],
      );

  Widget _levelPill() {
    final String lv = isFa ? 'مرحله ${wsFaNum(level)}' : 'LEVEL $level';
    return Row(mainAxisSize: MainAxisSize.min, textDirection: isFa ? TextDirection.rtl : TextDirection.ltr, children: <Widget>[
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(colors: <Color>[Color(0xE67B3CFF), Color(0xE6C04BFF)]),
          border: Border.all(color: const Color(0xAAF3E2FF)),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x887B3CFF), blurRadius: 18, spreadRadius: -2)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.science_rounded, size: 16, color: Colors.white),
          const SizedBox(width: 6),
          Text(lv, style: _ts(15, w: FontWeight.w900)),
          if (cur.spec.mystery) ...<Widget>[
            const SizedBox(width: 6),
            const Icon(Icons.help_rounded, size: 15, color: Color(0xFFFFE07A)),
          ],
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: const Color(0x66150830),
          border: Border.all(color: const Color(0x8839E1FF)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.all_inclusive_rounded, size: 16, color: Color(0xFF7DEBFF)),
          const SizedBox(width: 4),
          Text(tx('بی‌پایان', 'ENDLESS'), style: _ts(11.5, c: const Color(0xFFBFF4FF))),
        ]),
      ),
    ]);
  }

  Widget _banner(String s, Color c) => TweenAnimationBuilder<double>(
        key: ValueKey<String>(s),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutBack,
        builder: (_, double k, Widget? child) => Transform.scale(scale: 0.8 + 0.2 * k, child: Opacity(opacity: k.clamp(0, 1), child: child)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: <Color>[Color(0xEE24104A), Color(0xEE140828)]),
            border: Border.all(color: c.withValues(alpha: 0.8)),
            boxShadow: <BoxShadow>[BoxShadow(color: c.withValues(alpha: 0.35), blurRadius: 20)],
          ),
          child: Text(s, textAlign: TextAlign.center, textDirection: isFa ? TextDirection.rtl : TextDirection.ltr, style: _ts(13.5)),
        ),
      );

  Widget _boosterBar(bool canAct) {
    final bool idle = canAct && pours.isEmpty;
    final List<Widget> items = <Widget>[
      _WsButton(icon: Icons.undo_rounded, label: tx('برگشت', 'Undo'), badge: undoLeft, enabled: idle && undoLeft > 0 && board.history.isNotEmpty,
          onTap: undo, style: _ts, pulse: stuck),
      _WsButton(icon: Icons.add_rounded, label: tx('لوله +', '+Tube'), badge: tubeLeft, enabled: idle && tubeLeft > 0, onTap: addTube,
          style: _ts, pulse: stuck, glyph: Icons.science_rounded),
      _WsButton(icon: Icons.lightbulb_rounded, label: tx('راهنما', 'Hint'), badge: hintLeft, enabled: idle && hintLeft > 0,
          onTap: showHint, style: _ts),
      _WsButton(icon: Icons.refresh_rounded, label: tx('از نو', 'Restart'), enabled: canAct && pours.isEmpty, onTap: restartLevel,
          style: _ts, pulse: stuck),
      _WsButton(icon: Icons.flag_rounded, label: tx('پایان', 'Finish'), enabled: canAct && pours.isEmpty, onTap: finishRun,
          style: _ts, hot: true),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: <Color>[Color(0xCC2A1257), Color(0xE6130726)]),
        border: Border.all(color: const Color(0x66D9B8FF)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x667B3CFF), blurRadius: 26, spreadRadius: -6),
          BoxShadow(color: Color(0x99000000), blurRadius: 18, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
        children: items,
      ),
    );
  }

  Widget _completeCard() {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutBack,
      builder: (_, double k, Widget? child) => Container(
        color: const Color(0xFF0A0418).withValues(alpha: 0.55 * k.clamp(0, 1)),
        alignment: Alignment.center,
        child: Transform.scale(scale: 0.7 + 0.3 * k, child: Opacity(opacity: k.clamp(0, 1), child: child)),
      ),
      child: Container(
        width: 300,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: <Color>[Color(0xF5401C86), Color(0xF51A0A3A)]),
          border: Border.all(color: const Color(0xCCF0DAFF), width: 1.3),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0xAA9B4DFF), blurRadius: 50, spreadRadius: -4),
            BoxShadow(color: Colors.black54, blurRadius: 30, offset: Offset(0, 18)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
          Text(tx('مرحله کامل شد!', 'LEVEL COMPLETE!'), textAlign: TextAlign.center, style: _ts(24, w: FontWeight.w900, c: const Color(0xFFFFE9A8))),
          const SizedBox(height: 4),
          Text(isFa ? 'مرحله ${wsFaNum(level)}' : 'Level $level', style: _ts(14, c: const Color(0xFFD9C8FF))),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            for (int i = 0; i < 3; i++)
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 500 + i * 220),
                curve: Curves.elasticOut,
                builder: (_, double k, __) => Transform.scale(
                  scale: (k * 1.0).clamp(0.0, 1.4),
                  child: Padding(
                    padding: EdgeInsets.only(bottom: i == 1 ? 14 : 0, left: 4, right: 4),
                    child: Icon(Icons.star_rounded,
                        size: i == 1 ? 62 : 48,
                        color: i < lastStars ? const Color(0xFFFFD34E) : const Color(0x44FFFFFF),
                        shadows: i < lastStars
                            ? const <Shadow>[Shadow(color: Color(0xFFFF9D2E), blurRadius: 20)]
                            : const <Shadow>[]),
                  ),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('+$lastPoints', textDirection: TextDirection.ltr, style: _ts(34, w: FontWeight.w900).copyWith(fontFamily: 'ChakraPetch')),
          Text(isFa ? '${wsFaNum(moves)} حرکت' : '$moves moves', style: _ts(12.5, c: const Color(0xFFBBA8E8))),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: nextLevel,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(colors: <Color>[Color(0xFF39E1FF), Color(0xFFB98CFF)]),
                boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x8839E1FF), blurRadius: 20, offset: Offset(0, 6))],
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                Text(tx('مرحله بعد', 'NEXT LEVEL'), style: _ts(16, w: FontWeight.w900, c: const Color(0xFF12072A)).copyWith(shadows: const <Shadow>[])),
                const SizedBox(width: 6),
                Icon(isFa ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, color: const Color(0xFF12072A)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: finishRunFromCard,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Text(tx('پایان و ثبت امتیاز', 'Finish & submit score'), style: _ts(13, c: const Color(0xFFD9C8FF))),
            ),
          ),
        ]),
      ),
    );
  }

  void finishRunFromCard() {
    level++;
    _loadLevel();
    widget.run.gameOver();
    setState(() {});
  }
}

/// Round glass booster button with a count badge and a press bounce.
class _WsButton extends StatefulWidget {
  const _WsButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.style,
    this.badge,
    this.enabled = true,
    this.pulse = false,
    this.hot = false,
    this.glyph,
  });
  final IconData icon;
  final IconData? glyph;
  final String label;
  final VoidCallback onTap;
  final TextStyle Function(double size, {FontWeight w, Color c}) style;
  final int? badge;
  final bool enabled;
  final bool pulse;
  final bool hot;

  @override
  State<_WsButton> createState() => _WsButtonState();
}

class _WsButtonState extends State<_WsButton> with SingleTickerProviderStateMixin {
  bool _down = false;
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didUpdateWidget(covariant _WsButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse && widget.enabled) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true);
    } else if (_pulse.isAnimating) {
      _pulse.stop();
      _pulse.value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List<Color> grad = widget.hot
        ? const <Color>[Color(0xFFFF6FA8), Color(0xFF9B2CFF)]
        : const <Color>[Color(0xFF9F6BFF), Color(0xFF4A1E9E)];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (_, Widget? child) => Transform.scale(scale: (_down ? 0.9 : 1.0) + _pulse.value * 0.08, child: child),
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.42,
          child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Stack(clipBehavior: Clip.none, children: <Widget>[
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(center: const Alignment(-0.3, -0.5), radius: 1.0, colors: <Color>[
                    Color.lerp(grad[0], Colors.white, 0.25)!,
                    grad[0],
                    grad[1],
                  ], stops: const <double>[0, 0.45, 1]),
                  border: Border.all(color: const Color(0xCCF5E8FF), width: 1.4),
                  boxShadow: <BoxShadow>[
                    BoxShadow(color: grad[0].withValues(alpha: 0.55), blurRadius: 16, spreadRadius: -2),
                    const BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4)),
                  ],
                ),
                child: Stack(alignment: Alignment.center, children: <Widget>[
                  // Glass highlight.
                  Positioned(
                    top: 5,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                            colors: <Color>[Color(0x88FFFFFF), Color(0x00FFFFFF)]),
                      ),
                    ),
                  ),
                  if (widget.glyph != null)
                    Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                      Icon(widget.glyph, color: Colors.white, size: 21, shadows: const <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 4)]),
                      Icon(widget.icon, color: Colors.white, size: 15),
                    ])
                  else
                    Icon(widget.icon, color: Colors.white, size: 25, shadows: const <Shadow>[Shadow(color: Color(0x99000000), blurRadius: 4)]),
                ]),
              ),
              if (widget.badge != null)
                Positioned(
                  top: -4,
                  right: -6,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: const LinearGradient(colors: <Color>[Color(0xFFFFE07A), Color(0xFFFF9D2E)]),
                      border: Border.all(color: const Color(0xFF2A0F55), width: 1.4),
                    ),
                    child: Text('${widget.badge}',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            fontFamily: 'ChakraPetch', fontSize: 11.5, fontWeight: FontWeight.w900, color: Color(0xFF2A0F55), height: 1.2)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            Text(widget.label, maxLines: 1, style: widget.style(11.5, w: FontWeight.w700, c: const Color(0xFFEBDDFF))),
          ]),
        ),
      ),
    );
  }
}

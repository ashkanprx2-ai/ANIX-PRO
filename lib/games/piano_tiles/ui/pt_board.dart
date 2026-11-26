import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/storage/local_store.dart';
import '../../solo/solo_kit.dart';
import '../core/pt_engine.dart';
import '../core/pt_songs.dart';
import 'pt_art.dart';
import 'pt_audio.dart';

/// ===================== PIANO TILES · BOARD =====================
/// «پیانو تایلز»: a Magic-Tiles-style piano on a Persian night sky.
///  * Song picker → start tile → the melody plays one synthesised piano note per tap.
///  * Short, long-hold and double tiles; speed rises through the song; 3 stars on the progress
///    bar; after the song ends it loops endlessly (∞), faster each time, crowns per loop.
///  * A miss (empty lane or a tile slipping off the bottom) flashes red, rewinds so the player
///    sees it, and ends the run through the shared solo shell (score, best, medals, rematch).
/// ================================================================

class PianoTilesBoard extends SoloBoard {
  const PianoTilesBoard({super.key, required super.run, this.initialSong});

  /// Tests: start straight on this song instead of the picker.
  final String? initialSong;

  @override
  State<PianoTilesBoard> createState() => PianoTilesBoardState();
}

enum PtPhase { picker, play, paused, countdown, over }

class _Spark {
  _Spark(this.p, this.v, this.life, this.color, this.size, this.kind, [this.spin = 0]);
  Offset p;
  Offset v;
  double t = 0;
  final double life;
  final Color color;
  final double size;
  final int kind; // 0 spark, 1 star, 2 note glyph, 3 ring, 4 flash, 5 beam(lane in size)
  final double spin;
}

class _Bokeh {
  _Bokeh(this.x, this.y, this.r, this.depth, this.speed, this.phase, this.color);
  final double x, y, r, depth, speed, phase;
  final Color color;
}

class PianoTilesBoardState extends SoloBoardState<PianoTilesBoard> with WidgetsBindingObserver {
  late PtEngine engine;
  PtSong song = kPtSongs.first;
  PtPhase phase = PtPhase.picker;
  late final PtAudio audio = PtAudio(enabled: widget.run.launch.soundOn);
  final PtText _text = PtText();
  PtArtCache? _art;
  double _dpr = 2;
  final List<_Spark> _fx = <_Spark>[];
  late final List<_Bokeh> _bokeh;
  double _introT = 0; // seconds since the song was picked
  double _comboT = 9;
  String _judge = '';
  double _starPop = 0;
  int _starShown = 0;
  double _songDoneT = 9;
  double _overT = 0;
  bool _overSent = false;
  double _countdown = 0;
  double _bgScroll = 0; // px, for parallax (keeps drifting slowly while idle)
  final Map<int, (int lane, double row)> _lanePress = <int, (int, double)>{};
  final Map<String, int> _bestStars = <String, int>{};
  bool _immersive = false;
  final math.Random _rng = math.Random(7);

  bool get isFa => widget.run.launch.isFa;
  String tx(String fa, String en) => isFa ? fa : en;
  bool get fancy => widget.run.launch.fancyEffects && !widget.run.launch.reducedMotion;

  @override
  bool get simulating => true;

  @override
  void initState() {
    final math.Random r = math.Random(widget.run.seed);
    const List<Color> cols = <Color>[Color(0xFFC9B6FF), Color(0xFF9FD8FF), Color(0xFFFFB8E6), Color(0xFFFFE3A8), Color(0xFFB08CFF)];
    _bokeh = List<_Bokeh>.generate(
      36,
      (int i) => _Bokeh(r.nextDouble(), r.nextDouble(), 3 + math.pow(r.nextDouble(), 2.2) * 34, 0.15 + r.nextDouble() * 0.85,
          4 + r.nextDouble() * 14, r.nextDouble() * math.pi * 2, cols[r.nextInt(cols.length)]),
    );
    for (final PtSong s in kPtSongs) {
      try {
        _bestStars[s.id] = LocalStore.instance.getInt('pt_stars_${s.id}') ?? 0;
      } catch (_) {}
    }
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.initialSong != null) pickSong(ptSong(widget.initialSong!));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _setImmersive(false);
    unawaited(audio.dispose());
    _art?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && phase == PtPhase.play && engine.started) _pause();
  }

  void _setImmersive(bool on) {
    if (_immersive == on) return;
    _immersive = on;
    final ValueNotifier<bool>? n = widget.run.launch.immersive;
    if (n == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => n.value = on);
  }

  @override
  void reset() {
    engine = PtEngine(song, seed: widget.run.seed);
    _fx.clear();
    _starShown = 0;
    _starPop = 0;
    _songDoneT = 9;
    _comboT = 9;
    _overT = 0;
    _overSent = false;
    _lanePress.clear();
  }

  void pickSong(PtSong s) {
    song = s;
    reset();
    widget.run.set(0);
    widget.run.status.value = '♪ ${tx(s.titleFa, s.titleEn)}';
    _introT = 0;
    phase = PtPhase.play;
    _setImmersive(true);
    unawaited(audio.preload(s));
    if (mounted) setState(() {});
  }

  /// Phase changes rebuild the widget layer (HUD buttons, overlays); the canvas repaints every frame anyway.
  void _setPhase(PtPhase p) {
    if (phase == p) return;
    phase = p;
    if (mounted) setState(() {});
  }

  void _pause() {
    if (phase != PtPhase.play) return;
    setState(() => phase = PtPhase.paused);
    _lanePress.keys.toList().forEach(engine.release);
    _lanePress.clear();
  }

  void _resume() => setState(() {
        phase = PtPhase.countdown;
        _countdown = 3;
      });

  void _toPicker() {
    setState(() {
      phase = PtPhase.picker;
      reset();
      widget.run.set(0);
      widget.run.status.value = '';
    });
    _setImmersive(false);
  }

  void _restartSong() => pickSong(song);

  Future<void> _close() async {
    if (phase == PtPhase.play && engine.started) _pause();
    await Navigator.of(context).maybePop();
  }

  // ------------------------------------------------------------------ simulation

  double _rowH(Size s) => s.height / 4.25;

  @override
  void step(double dt) {
    final bool live = phase == PtPhase.play && widget.run.playing && !widget.run.over;
    if (phase == PtPhase.countdown) {
      _countdown -= dt;
      if (_countdown <= 0) _setPhase(PtPhase.play);
    }
    if (live) {
      _introT += dt;
      final double before = engine.scroll;
      engine.step(dt);
      _bgScroll += (engine.scroll - before) * _rowH(lastSize);
      _drainEvents();
    } else {
      engine.clock += dt;
    }
    _bgScroll += dt * (live && engine.started ? 0 : 14);
    if (phase == PtPhase.over) {
      _overT += dt;
      if (_overT > 1.25 && !_overSent) {
        _overSent = true;
        widget.run.gameOver();
      }
    }
    _comboT += dt;
    _songDoneT += dt;
    _starPop = math.max(0, _starPop - dt * 1.6);
    for (final _Spark s in _fx) {
      s.t += dt;
      s.p += s.v * dt;
      if (s.kind == 0) s.v = s.v + Offset(0, 520 * dt);
      if (s.kind == 1 || s.kind == 2) s.v = s.v * (1 - 1.6 * dt);
    }
    _fx.removeWhere((_Spark s) => s.t >= s.life);
    // embers rising off the head of a hold being played
    if (fancy && phase == PtPhase.play && !lastSize.isEmpty) {
      final double laneW = lastSize.width / 4;
      for (final PtTile t in engine.tiles) {
        if (!t.holding || _rng.nextDouble() > dt * 40) continue;
        final double y = _y(t.row + t.fill, lastSize);
        _spark(Offset((t.lane + 0.5) * laneW + (_rng.nextDouble() - 0.5) * laneW * 0.6, y), PtPalette.goldLight, 120);
      }
    }
  }

  void _drainEvents() {
    final Size size = lastSize;
    if (size.isEmpty) {
      engine.events.clear();
      return;
    }
    final double laneW = size.width / 4;
    final double rowH = _rowH(size);
    for (final PtEvent e in engine.events) {
      final PtTile? t = e.tile;
      switch (e.kind) {
        case PtEventKind.hit:
        case PtEventKind.holdStart:
          audio.note(t!.pitch);
          final Offset c = Offset((t.lane + 0.5) * laneW, _y(t.row, size) - rowH * 0.5);
          _burst(c, laneW, t.lane, big: t.perfect);
          widget.run.set(engine.score);
          HapticFeedback.selectionClick();
          _judge = t.perfect ? tx('عالی!', 'PERFECT') : tx('خوب', 'GREAT');
          _comboT = 0;
        case PtEventKind.holdTick:
          widget.run.set(engine.score);
          final Offset c = Offset((t!.lane + 0.5) * laneW, _y(t.row + t.fill, size));
          _ring(c, laneW * 0.32, PtPalette.goldLight, 0.35);
          for (int i = 0; i < 6; i++) {
            _spark(c, PtPalette.gold, 160);
          }
        case PtEventKind.holdDone:
          widget.run.set(engine.score);
          final Offset c = Offset((t!.lane + 0.5) * laneW, _y(t.top, size));
          _burst(c, laneW, t.lane, big: true);
          HapticFeedback.lightImpact();
        case PtEventKind.star:
          _starPop = 1;
          _starShown = e.value;
          audio.star();
          HapticFeedback.mediumImpact();
          final double x = size.width * (0.05 + 0.88 * (e.value / 3));
          final Offset at = Offset(x, MediaQuery.paddingOf(context).top + 7);
          for (int i = 0; i < 26; i++) {
            _spark(at, i.isEven ? PtPalette.gold : Colors.white, 260);
          }
          _ring(at, 34, PtPalette.goldLight, 0.6);
          _saveStars();
        case PtEventKind.songDone:
          _songDoneT = 0;
          audio.win();
          fx.flashScreen(PtPalette.goldLight, 0.22);
          for (int i = 0; i < 70; i++) {
            _spark(Offset(size.width / 2, size.height * 0.4), <Color>[PtPalette.gold, PtPalette.cyan, PtPalette.rose, Colors.white][i % 4], 420);
          }
          _saveStars();
        case PtEventKind.miss:
          _onMiss();
      }
    }
    engine.events.clear();
  }

  void _onMiss() {
    _setPhase(PtPhase.over);
    _overT = 0;
    audio.miss();
    HapticFeedback.heavyImpact();
    fx.shake(12);
    fx.flashScreen(PtPalette.red, 0.3);
    _saveStars();
    _setImmersive(false);
  }

  void _saveStars() {
    final int s = engine.stars;
    if (s > (_bestStars[song.id] ?? 0)) {
      _bestStars[song.id] = s;
      try {
        unawaited(LocalStore.instance.setInt('pt_stars_${song.id}', s));
      } catch (_) {}
    }
  }

  void _spark(Offset c, Color col, double speed) {
    if (!fancy && _fx.length > 40) return;
    final math.Random r = _rng;
    final double a = r.nextDouble() * math.pi * 2;
    final double v = speed * (0.35 + r.nextDouble() * 0.75);
    _fx.add(_Spark(c, Offset(math.cos(a) * v, math.sin(a) * v - speed * 0.35), 0.45 + r.nextDouble() * 0.45, col, 1.2 + r.nextDouble() * 2.4, 0));
  }

  void _ring(Offset c, double size, Color col, double life) => _fx.add(_Spark(c, Offset.zero, life, col, size, 3));

  void _burst(Offset c, double laneW, int lane, {bool big = false}) {
    final math.Random r = _rng;
    _fx.add(_Spark(Offset((lane + 0.5) * laneW, 0), Offset.zero, 0.42, PtPalette.lilac, lane.toDouble(), 5));
    _fx.add(_Spark(c, Offset.zero, 0.3, Colors.white, laneW * 0.9, 4));
    _ring(c, laneW * (big ? 0.95 : 0.75), PtPalette.goldLight, 0.5);
    _ring(c, laneW * 0.55, PtPalette.lilac, 0.38);
    final int n = fancy ? (big ? 18 : 12) : 5;
    for (int i = 0; i < n; i++) {
      _spark(c, i % 3 == 0 ? Colors.white : PtPalette.gold, 300);
    }
    if (fancy) {
      for (int i = 0; i < 3; i++) {
        final double a = -math.pi / 2 + (r.nextDouble() - 0.5) * 2.2;
        final double v = 110 + r.nextDouble() * 120;
        _fx.add(_Spark(c, Offset(math.cos(a) * v, math.sin(a) * v), 0.8, PtPalette.goldLight, 5 + r.nextDouble() * 4, 1, (r.nextDouble() - 0.5) * 8));
      }
      final double sway = (r.nextDouble() - 0.5) * 60;
      _fx.add(_Spark(c + Offset(sway * 0.3, -10), Offset(sway, -90 - r.nextDouble() * 50), 1.1, Colors.white, 1 + r.nextDouble() * 0.4, 2, (r.nextDouble() - 0.5) * 1.2));
    }
  }

  // ------------------------------------------------------------------ input

  double get _viewScroll {
    if (phase != PtPhase.over) return engine.scroll;
    final double k = Curves.easeOutCubic.transform((_overT / 0.35).clamp(0.0, 1.0));
    return engine.scroll - engine.rewind * k;
  }

  double _y(double row, Size s) => s.height - (row - _viewScroll) * _rowH(s);

  void _down(PointerDownEvent e) {
    if (phase != PtPhase.play || !widget.run.playing || widget.run.over || lastSize.isEmpty) return;
    final int lane = (e.localPosition.dx / (lastSize.width / 4)).floor().clamp(0, 3);
    final double row = engine.scroll + (lastSize.height - e.localPosition.dy) / _rowH(lastSize);
    _lanePress[e.pointer] = (lane, row);
    final PtTap r = engine.press(lane, row, pointer: e.pointer);
    if (r == PtTap.ghost) HapticFeedback.selectionClick();
    _drainEvents();
  }

  void _up(PointerEvent e) {
    _lanePress.remove(e.pointer);
    engine.release(e.pointer);
  }

  /// Tests: world-space tap target of the next tile (null when none).
  Offset? debugNextTap() {
    final List<PtTile> n = engine.next;
    if (n.isEmpty || lastSize.isEmpty) return null;
    final PtTile t = n.first;
    return Offset((t.lane + 0.5) * lastSize.width / 4, _y(t.row, lastSize) - _rowH(lastSize) * 0.4);
  }

  // ------------------------------------------------------------------ painting

  PtArtCache _cache(Size size) {
    final double rowH = _rowH(size);
    final Size tile = Size(size.width / 4 - 5, rowH - 5);
    final PtArtCache? a = _art;
    if (a != null && a.size == size && a.dpr == _dpr) return a;
    a?.dispose();
    return _art = PtArtCache(size, _dpr, tile, rowH);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final PtArtCache art = _cache(size);
    _paintSky(canvas, size, art);
    _paintLanes(canvas, size);
    if (phase != PtPhase.picker) {
      _paintTiles(canvas, size, art);
      _paintFx(canvas, size);
      _paintMiss(canvas, size);
      _paintProgress(canvas, size);
      _paintCaptions(canvas, size);
      _paintCountdown(canvas, size);
    }
    _paintVignette(canvas, size);
  }

  void _paintSky(Canvas c, Size s, PtArtCache art) {
    final Rect r = Offset.zero & s;
    c.drawRect(
      r,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[PtPalette.skyTop, PtPalette.skyMid, PtPalette.skyLow, PtPalette.skyBottom],
          stops: <double>[0, 0.38, 0.72, 1],
        ).createShader(r),
    );
    final double t = clock;
    // drifting nebula mist
    for (int i = 0; i < 3; i++) {
      final Offset o = Offset(
        s.width * (0.25 + 0.5 * (0.5 + 0.5 * math.sin(t * 0.07 + i * 2.1))),
        s.height * (0.2 + i * 0.3) + math.sin(t * 0.11 + i) * 30,
      );
      final double rad = s.width * (0.55 + 0.1 * i);
      final Color col = <Color>[const Color(0xFFB06CFF), const Color(0xFFFF7FC8), const Color(0xFF6C8CFF)][i];
      c.drawCircle(o, rad, Paint()..shader = RadialGradient(colors: <Color>[col.withValues(alpha: 0.16), col.withValues(alpha: 0)]).createShader(Rect.fromCircle(center: o, radius: rad)));
    }
    // far girih layer (slow parallax) and near layer (faster)
    _patternLayer(c, s, art.patternFar, art.farCell, _bgScroll * 0.06, math.sin(t * 0.05) * 18);
    // central slowly-turning shamseh rosette
    final Offset rc = Offset(s.width / 2, s.height * 0.42 + (_bgScroll * 0.03) % 40);
    c.save();
    c.translate(rc.dx, rc.dy);
    c.rotate(t * 0.04);
    final Paint ro = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = PtPalette.line.withValues(alpha: 0.08);
    for (int k = 0; k < 3; k++) {
      c.drawPath(rosettePath(Offset.zero, s.width * (0.48 - k * 0.12), 16, 0.82, rot: k * 0.1), ro);
    }
    c.drawPath(khatamPath(Offset.zero, s.width * 0.18), ro);
    c.restore();
    _patternLayer(c, s, art.patternNear, art.nearCell, _bgScroll * 0.2, 0);
    // soft light shafts from the top
    for (int i = 0; i < 3; i++) {
      final double x = s.width * (0.2 + 0.3 * i) + math.sin(t * 0.13 + i * 1.7) * s.width * 0.08;
      final Path p = Path()
        ..moveTo(x - 20, 0)
        ..lineTo(x + 30, 0)
        ..lineTo(x + 120 + i * 20, s.height)
        ..lineTo(x - 10 + i * 20, s.height)
        ..close();
      c.drawPath(
          p,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                const Color(0xFFD9C8FF).withValues(alpha: 0.07 + 0.03 * math.sin(t * 0.6 + i)),
                const Color(0x00D9C8FF),
              ],
            ).createShader(r));
    }
    _paintBokeh(c, s, art);
  }

  void _patternLayer(Canvas c, Size s, ui.Image img, double cell, double dy, double dx) {
    final double k = 1 / _dpr;
    final Float64List m = Float64List.fromList(<double>[k, 0, 0, 0, 0, k, 0, 0, 0, 0, 1, 0, dx % cell, dy % cell, 0, 1]);
    c.drawRect(
      Offset.zero & s,
      Paint()
        ..shader = ui.ImageShader(img, TileMode.repeated, TileMode.repeated, m, filterQuality: FilterQuality.medium),
    );
  }

  void _paintBokeh(Canvas c, Size s, PtArtCache art) {
    final List<RSTransform> xf = <RSTransform>[];
    final List<Rect> src = <Rect>[];
    final List<Color> col = <Color>[];
    final double side = 64 * _dpr;
    final Rect sr = Rect.fromLTWH(0, 0, side, side);
    final double span = s.height + 80;
    for (final _Bokeh b in _bokeh) {
      final double y = (b.y * span + _bgScroll * b.depth * 0.45 + clock * b.speed * b.depth) % span - 40;
      final double x = b.x * s.width + math.sin(clock * 0.3 + b.phase) * 10 * b.depth;
      final double tw = 0.55 + 0.45 * math.sin(clock * (0.8 + b.depth) + b.phase);
      final double scale = (b.r * 2) / side;
      xf.add(RSTransform.fromComponents(rotation: 0, scale: scale, anchorX: side / 2, anchorY: side / 2, translateX: x, translateY: y));
      src.add(sr);
      col.add(b.color.withValues(alpha: (0.10 + 0.32 * (1 - b.depth * 0.6)) * tw));
    }
    c.drawAtlas(art.bokeh, xf, src, col, BlendMode.modulate, null, Paint()..blendMode = BlendMode.plus);
  }

  void _paintLanes(Canvas c, Size s) {
    final Rect r = Offset.zero & s;
    final Paint p = Paint()
      ..strokeWidth = 1
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[PtPalette.line.withValues(alpha: 0.05), PtPalette.line.withValues(alpha: 0.32), PtPalette.line.withValues(alpha: 0.14)],
      ).createShader(r);
    for (int i = 1; i < 4; i++) {
      final double x = s.width * i / 4;
      c.drawLine(Offset(x, 0), Offset(x, s.height), p);
    }
    // a whisper of gold at the bottom edge: where tiles must be caught
    c.drawRect(
      Rect.fromLTWH(0, s.height - 3, s.width, 3),
      Paint()
        ..shader = LinearGradient(colors: <Color>[
          PtPalette.gold.withValues(alpha: 0),
          PtPalette.gold.withValues(alpha: 0.4),
          PtPalette.gold.withValues(alpha: 0),
        ]).createShader(r),
    );
  }

  void _paintTiles(Canvas c, Size s, PtArtCache art) {
    final double laneW = s.width / 4;
    final double rowH = _rowH(s);
    final bool blink = phase == PtPhase.over && ((_overT * 7).floor().isEven);
    for (final PtTile t in engine.tiles) {
      final double bottom = _y(t.row, s);
      final double top = _y(t.top, s);
      if (bottom < -20 || top > s.height + 20) continue;
      final Rect body = Rect.fromLTRB(t.lane * laneW + 2.5, top + 2.5, (t.lane + 1) * laneW - 2.5, bottom - 2.5);
      final bool missed = engine.missTile == t;
      if (t.hit && !t.isHold) {
        _paintGlass(c, body, engine.clock - t.hitAt);
        continue;
      }
      final ui.Image img = art.tileImage(t.len, start: t.isStart);
      final Rect dst = body.inflate(kTileMargin);
      if (t.isHold && t.hit) {
        _paintHold(c, img, dst, body, t, rowH);
        continue;
      }
      final Paint ip = Paint()..filterQuality = FilterQuality.medium;
      if (missed && blink) ip.colorFilter = const ColorFilter.mode(Color(0xFFFF2D55), BlendMode.modulate);
      c.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst, ip);
      if (missed) {
        c.drawRRect(RRect.fromRectAndRadius(body, const Radius.circular(12)), Paint()
          ..color = PtPalette.red.withValues(alpha: blink ? 0.75 : 0.35)
          ..blendMode = BlendMode.srcOver);
      }
      if (t.isStart) {
        final double pulse = 0.5 + 0.5 * math.sin(clock * 4);
        c.drawRRect(
            RRect.fromRectAndRadius(body.inflate(2 + pulse * 3), const Radius.circular(15)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = PtPalette.cyan.withValues(alpha: 0.35 + 0.4 * pulse)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
        _text.draw(c, tx('شروع', 'START'), Offset(body.center.dx, body.top + body.height * 0.24), 21,
            family: isFa ? 'Lalezar' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa,
            shadows: const <Shadow>[Shadow(color: Color(0xFF00AEEF), blurRadius: 12)]);
      }
      if (t.isDouble && !t.hit) {
        // twin marker: a small pair of pearls at the top so doubles read at a glance
        final Paint g = Paint()..shader = goldShader(body);
        c.drawCircle(Offset(body.center.dx - 5, body.top + 12), 2.2, g);
        c.drawCircle(Offset(body.center.dx + 5, body.top + 12), 2.2, g);
      }
    }
  }

  void _paintGlass(Canvas c, Rect body, double age) {
    final double k = (age / 0.45).clamp(0.0, 1.0);
    final RRect rr = RRect.fromRectAndRadius(body.inflate(k * 3), const Radius.circular(13));
    c.drawRRect(rr, Paint()..color = const Color(0xFFCBB8FF).withValues(alpha: 0.24 * (1 - k) + 0.06));
    c.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = PtPalette.gold.withValues(alpha: 0.85 * (1 - k) + 0.12)
          ..maskFilter = k < 1 ? MaskFilter.blur(BlurStyle.normal, 2 + 4 * (1 - k)) : null);
    if (k < 1) {
      paintMedallion(c, Offset(body.center.dx, body.top + body.height * 0.56), math.min(body.width * 0.2, 26) * (1 + k * 0.6),
          glow: 1 - k);
    }
  }

  void _paintHold(Canvas c, ui.Image img, Rect dst, Rect body, PtTile t, double rowH) {
    c.drawImageRect(img, Offset.zero & Size(img.width.toDouble(), img.height.toDouble()), dst, Paint()..filterQuality = FilterQuality.medium);
    final double fillPx = (t.fill / t.len) * body.height;
    final Rect f = Rect.fromLTRB(body.left, body.bottom - fillPx, body.right, body.bottom);
    final RRect rr = RRect.fromRectAndRadius(body, const Radius.circular(13));
    c.save();
    c.clipRRect(rr);
    c.drawRect(
        f,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: <Color>[
              const Color(0xFF5B3BD9).withValues(alpha: 0.9),
              const Color(0xFF9A6BE8).withValues(alpha: 0.85),
              const Color(0xFFD9A84E).withValues(alpha: 0.9),
              PtPalette.goldLight,
            ],
            stops: const <double>[0, 0.45, 0.85, 1],
          ).createShader(f));
    // the rail and medallion stay visible through the fill as engraved gold
    final double mr = math.min(body.width * 0.2, 26);
    paintMedallion(c, Offset(body.center.dx, body.bottom - rowH * 0.5), mr, glow: t.holding ? 0.6 : 0.2);
    c.drawRect(
        f,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: <Color>[Colors.white.withValues(alpha: 0.0), Colors.white.withValues(alpha: 0.12), Colors.white.withValues(alpha: 0.0)],
          ).createShader(f));
    c.restore();
    if (t.holding || !t.holdDone) {
      // glowing head of the fill
      final double y = f.top;
      c.drawRect(
          Rect.fromLTRB(body.left + 4, y - 3, body.right - 4, y + 3),
          Paint()
            ..color = PtPalette.goldLight.withValues(alpha: t.holding ? 0.95 : 0.4)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
    }
    if (t.holdDone) {
      c.drawRRect(rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = PtPalette.goldLight.withValues(alpha: 0.7)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _paintFx(Canvas c, Size s) {
    final double laneW = s.width / 4;
    final Paint add = Paint()..blendMode = BlendMode.plus;
    for (final _Spark f in _fx) {
      final double k = f.t / f.life;
      final double a = (1 - k).clamp(0.0, 1.0);
      switch (f.kind) {
        case 0:
          add
            ..shader = null
            ..maskFilter = null
            ..color = f.color.withValues(alpha: a);
          c.drawCircle(f.p, f.size * (1 - k * 0.5), add);
          add.color = f.color.withValues(alpha: a * 0.35);
          c.drawCircle(f.p, f.size * 3, add);
        case 1:
          c.save();
          c.translate(f.p.dx, f.p.dy);
          c.rotate(f.spin * f.t);
          c.drawPath(khatamPath(Offset.zero, f.size * (1 - k * 0.3)), Paint()
            ..blendMode = BlendMode.plus
            ..color = f.color.withValues(alpha: a));
          c.restore();
        case 2:
          c.save();
          c.translate(f.p.dx + math.sin(f.t * 5) * 6, f.p.dy);
          c.rotate(f.spin * 0.3);
          c.scale(f.size);
          c.drawPath(kNoteGlyph, Paint()..color = f.color.withValues(alpha: a * 0.9));
          c.restore();
        case 3:
          final double rad = f.size * Curves.easeOutCubic.transform(k);
          c.drawCircle(f.p, rad, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3 * a + 0.5
            ..color = f.color.withValues(alpha: a * 0.9));
        case 4:
          c.drawCircle(
              f.p,
              f.size,
              Paint()
                ..blendMode = BlendMode.plus
                ..shader = RadialGradient(colors: <Color>[Colors.white.withValues(alpha: 0.45 * a), PtPalette.gold.withValues(alpha: 0.18 * a), Colors.transparent])
                    .createShader(Rect.fromCircle(center: f.p, radius: f.size)));
        case 5:
          final Rect lane = Rect.fromLTWH(f.size * laneW, 0, laneW, s.height);
          c.drawRect(
              lane,
              Paint()
                ..blendMode = BlendMode.plus
                ..shader = LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: <Color>[PtPalette.lilac.withValues(alpha: 0.30 * a), PtPalette.lilac.withValues(alpha: 0.04 * a)],
                ).createShader(lane));
      }
    }
  }

  void _paintMiss(Canvas c, Size s) {
    if (phase != PtPhase.over || engine.missTile != null || engine.missLane < 0) return;
    final double laneW = s.width / 4;
    final double bottom = _y(engine.missRow, s);
    final Rect cell = Rect.fromLTRB(engine.missLane * laneW + 2.5, bottom - _rowH(s) + 2.5, (engine.missLane + 1) * laneW - 2.5, bottom - 2.5);
    final bool on = (_overT * 7).floor().isEven;
    c.drawRRect(RRect.fromRectAndRadius(cell, const Radius.circular(12)), Paint()..color = PtPalette.red.withValues(alpha: on ? 0.85 : 0.4));
    c.drawRRect(
        RRect.fromRectAndRadius(cell, const Radius.circular(12)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFFFFB3C0)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3));
  }

  void _paintProgress(Canvas c, Size s) {
    final double top = MediaQuery.paddingOf(context).top - 4;
    final double left = s.width * 0.05, right = s.width * 0.93;
    final RRect track = RRect.fromLTRBR(left, top + 9, right, top + 14, const Radius.circular(3));
    c.drawRRect(track, Paint()..color = const Color(0x66120A33));
    c.drawRRect(track, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = PtPalette.line.withValues(alpha: 0.35));
    final double p = engine.endless ? 1 : engine.progress;
    if (p > 0) {
      final RRect fill = RRect.fromLTRBR(left, top + 9, left + (right - left) * p, top + 14, const Radius.circular(3));
      c.drawRRect(fill, Paint()..shader = const LinearGradient(colors: <Color>[PtPalette.cyan, Color(0xFF9D7BFF), PtPalette.gold]).createShader(track.outerRect));
      c.drawRRect(fill, Paint()
        ..color = PtPalette.cyan.withValues(alpha: 0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
    for (int i = 1; i <= 3; i++) {
      final Offset o = Offset(left + (right - left) * i / 3, top + 12);
      final bool lit = _starShown >= i || engine.stars >= i;
      final double pop = (lit && i == _starShown) ? _starPop : 0;
      final double r = 8 + pop * 6;
      final Path star = rosettePath(o, r, 5, 0.45, rot: -math.pi / 2);
      if (lit) {
        c.drawCircle(o, r * 1.8, Paint()..shader = RadialGradient(colors: <Color>[PtPalette.gold.withValues(alpha: 0.5), Colors.transparent]).createShader(Rect.fromCircle(center: o, radius: r * 1.8)));
        c.drawPath(star, Paint()..shader = goldShader(Rect.fromCircle(center: o, radius: r)));
        c.drawPath(star, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xFF7A5420));
      } else {
        c.drawPath(star, Paint()..color = const Color(0xFF2A2060));
        c.drawPath(star, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = PtPalette.line.withValues(alpha: 0.45));
      }
    }
    if (engine.loops > 0) {
      // crowns for endless laps
      _text.draw(c, '∞ ×${engine.loops}', Offset(right - 6, top + 30), 13, family: 'ChakraPetch', weight: FontWeight.w700, rtl: false,
          color: PtPalette.goldLight, shadows: const <Shadow>[Shadow(color: Color(0xFF000000), blurRadius: 4)]);
    }
  }

  void _paintCaptions(Canvas c, Size s) {
    // song title card, fading after the first notes
    final double shown = engine.started ? (1 - engine.scroll / 1.4).clamp(0.0, 1.0) : 1;
    if (shown > 0.01) {
      final double y = s.height * 0.37;
      final double rise = (1 - Curves.easeOutBack.transform((_introT / 0.6).clamp(0.0, 1.0))) * 24;
      final Paint fg = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[Colors.white, Color(0xFFEDE3FF)],
        ).createShader(Rect.fromLTWH(0, y - 30, s.width, 60));
      c.saveLayer(Offset.zero & s, Paint()..color = Colors.white.withValues(alpha: shown));
      final TextPainter title = _text.get(tx(song.titleFa, song.titleEn), isFa ? 44 : 38,
          family: isFa ? 'Lalezar' : 'ChakraPetch',
          weight: FontWeight.w700,
          rtl: isFa,
          foreground: fg,
          shadows: const <Shadow>[Shadow(color: Color(0xAA1A0B45), offset: Offset(0, 3), blurRadius: 8), Shadow(color: Color(0x88B08CFF), blurRadius: 24)]);
      title.paint(c, Offset(s.width / 2 - title.width / 2, y - title.height / 2 + rise));
      _text.draw(c, tx(song.subtitleFa, song.subtitleEn), Offset(s.width / 2, y + 40 + rise), 16,
          family: isFa ? 'Estedad' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa,
          color: const Color(0xFFE9E0FF), shadows: const <Shadow>[Shadow(color: Color(0xAA1A0B45), blurRadius: 6)]);
      // ornament rule under the subtitle
      final double w = 70;
      final Paint g = Paint()..shader = goldShader(Rect.fromLTWH(s.width / 2 - w, y + 58, w * 2, 4));
      c.drawRect(Rect.fromLTWH(s.width / 2 - w, y + 62 + rise, w - 10, 1.2), g);
      c.drawRect(Rect.fromLTWH(s.width / 2 + 10, y + 62 + rise, w - 10, 1.2), g);
      c.drawPath(khatamPath(Offset(s.width / 2, y + 62.6 + rise), 5), g);
      c.restore();
    }
    // judgement + combo
    if (_comboT < 0.8 && engine.combo > 1 && phase != PtPhase.over) {
      final double k = _comboT / 0.8;
      final double pop = 1 + 0.35 * (1 - Curves.easeOutBack.transform((_comboT / 0.18).clamp(0.0, 1.0)));
      c.save();
      c.translate(s.width / 2, s.height * 0.3);
      c.scale(pop);
      final double a = (1 - k * k).clamp(0.0, 1.0);
      c.saveLayer(Rect.fromCenter(center: Offset.zero, width: s.width, height: 120), Paint()..color = Colors.white.withValues(alpha: a));
      _text.draw(c, _judge, const Offset(0, -18), 22,
          family: isFa ? 'Lalezar' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa,
          color: const Color(0xFFFFF5DA), shadows: const <Shadow>[Shadow(color: Color(0xCCE6C276), blurRadius: 14)]);
      _text.draw(c, '×${engine.combo}', const Offset(0, 12), 26, family: 'ChakraPetch', weight: FontWeight.w700, rtl: false,
          color: Colors.white, shadows: const <Shadow>[Shadow(color: PtPalette.cyan, blurRadius: 12)]);
      c.restore();
      c.restore();
    }
    // song complete → endless banner
    if (_songDoneT < 2.6) {
      final double k = _songDoneT / 2.6;
      final double a = (k < 0.15 ? k / 0.15 : (1 - (k - 0.7).clamp(0.0, 0.3) / 0.3)).clamp(0.0, 1.0);
      final double y = s.height * 0.42;
      final Rect band = Rect.fromCenter(center: Offset(s.width / 2, y), width: s.width, height: 92);
      c.drawRect(band, Paint()
        ..shader = LinearGradient(colors: <Color>[
          Colors.transparent,
          const Color(0xFF1A0F4A).withValues(alpha: 0.82 * a),
          const Color(0xFF1A0F4A).withValues(alpha: 0.82 * a),
          Colors.transparent,
        ], stops: const <double>[0, 0.2, 0.8, 1]).createShader(band));
      c.saveLayer(band, Paint()..color = Colors.white.withValues(alpha: a));
      _text.draw(c, tx('ترانه کامل شد!', 'SONG COMPLETE!'), Offset(s.width / 2, y - 14), 30,
          family: isFa ? 'Lalezar' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa,
          color: PtPalette.goldLight, shadows: const <Shadow>[Shadow(color: PtPalette.gold, blurRadius: 18)]);
      _text.draw(c, tx('∞ حالت بی‌پایان · سریع‌تر!', '∞ ENDLESS · FASTER!'), Offset(s.width / 2, y + 22), 15,
          family: isFa ? 'Estedad' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa, color: Colors.white);
      c.restore();
    }
    // results: earned stars under the shell's game-over title
    if (phase == PtPhase.over && _overT > 0.5) {
      final double k = Curves.easeOutBack.transform(((_overT - 0.5) / 0.5).clamp(0.0, 1.0));
      final double y = s.height * 0.66;
      for (int i = 0; i < 3; i++) {
        final Offset o = Offset(s.width / 2 + (i - 1) * 58, y - (i == 1 ? 12 : 0));
        final double r = (i == 1 ? 24 : 19) * k;
        if (r <= 0.5) continue;
        final Path star = rosettePath(o, r, 5, 0.45, rot: -math.pi / 2);
        final bool lit = engine.stars > i;
        if (lit) {
          c.drawCircle(o, r * 2, Paint()..shader = RadialGradient(colors: <Color>[PtPalette.gold.withValues(alpha: 0.45), Colors.transparent]).createShader(Rect.fromCircle(center: o, radius: r * 2)));
        }
        c.drawPath(star, lit ? (Paint()..shader = goldShader(Rect.fromCircle(center: o, radius: r))) : (Paint()..color = const Color(0xFF2A2060)));
        c.drawPath(star, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = lit ? const Color(0xFF7A5420) : PtPalette.line.withValues(alpha: 0.5));
      }
      final int pct = engine.endless ? 100 : (engine.progress * 100).round();
      final String line = engine.endless
          ? tx('${engine.loops} دور کامل · بهترین ترکیب ${engine.bestCombo}', '${engine.loops} laps · best combo ${engine.bestCombo}')
          : tx('$pct٪ از ترانه · بهترین ترکیب ${engine.bestCombo}', '$pct% of the song · best combo ${engine.bestCombo}');
      _text.draw(c, line, Offset(s.width / 2, y + 44), 15, family: isFa ? 'Estedad' : 'ChakraPetch', weight: FontWeight.w700, rtl: isFa,
          shadows: const <Shadow>[Shadow(color: Color(0xCC000000), blurRadius: 6)]);
    }
  }

  void _paintCountdown(Canvas c, Size s) {
    if (phase != PtPhase.countdown) return;
    final int n = _countdown.ceil().clamp(1, 3);
    final double f = _countdown - _countdown.floor(); // 1 -> 0 within each second
    final double k = Curves.easeOutBack.transform(((1 - f) * 3).clamp(0.0, 1.0));
    final Offset o = Offset(s.width / 2, s.height * 0.45);
    c.drawCircle(o, 70, Paint()..shader = RadialGradient(colors: <Color>[PtPalette.gold.withValues(alpha: 0.35 * f + 0.1), Colors.transparent]).createShader(Rect.fromCircle(center: o, radius: 70)));
    c.drawPath(khatamPath(o, 62, rot: clock), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..shader = goldShader(Rect.fromCircle(center: o, radius: 62)));
    c.save();
    c.translate(o.dx, o.dy);
    c.scale(0.6 + 0.4 * k);
    _text.draw(c, '$n', Offset.zero, 84, family: 'ChakraPetch', weight: FontWeight.w700, rtl: false,
        shadows: const <Shadow>[Shadow(color: PtPalette.gold, blurRadius: 28)]);
    c.restore();
  }

  void _paintVignette(Canvas c, Size s) {
    final Rect r = Offset.zero & s;
    c.drawRect(r, Paint()
      ..shader = const RadialGradient(radius: 1.0, colors: <Color>[Color(0x00000000), Color(0x5A0A0425)], stops: <double>[0.6, 1]).createShader(r));
  }

  // ------------------------------------------------------------------ widgets

  @override
  Widget build(BuildContext context) {
    _dpr = MediaQuery.devicePixelRatioOf(context);
    final EdgeInsets pad = MediaQuery.paddingOf(context);
    final bool hud = phase != PtPhase.picker && phase != PtPhase.over && widget.run.playing;
    return Stack(fit: StackFit.expand, children: <Widget>[
      Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _down,
        onPointerUp: _up,
        onPointerCancel: _up,
        child: super.build(context),
      ),
      if (hud) ...<Widget>[
        Positioned(
          top: pad.top + 30,
          left: 10,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Row(children: <Widget>[
              _EndlessChip(label: tx('بی‌پایان', 'ENDLESS'), fa: isFa),
              const SizedBox(width: 8),
              _RoundButton(icon: Icons.pause_rounded, onTap: _pause, keyName: 'pt_pause'),
            ]),
          ),
        ),
        Positioned(top: pad.top + 30, right: 10, child: _RoundButton(icon: Icons.close_rounded, onTap: _close, keyName: 'pt_close')),
      ],
      if (phase == PtPhase.picker && widget.run.playing)
        Positioned.fill(
          child: _SongPicker(
            fa: isFa,
            best: _bestStars,
            onPick: pickSong,
            top: pad.top + 96,
          ),
        ),
      if (phase == PtPhase.paused) Positioned.fill(child: _pauseCard()),
    ]);
  }

  Widget _pauseCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          color: const Color(0x88120A33),
          alignment: Alignment.center,
          child: Directionality(
            textDirection: isFa ? TextDirection.rtl : TextDirection.ltr,
            child: _GlassCard(
              width: 300,
              child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
                CustomPaint(size: const Size(56, 56), painter: _MedallionPainter()),
                const SizedBox(height: 10),
                Text(tx('مکث', 'PAUSED'),
                    style: TextStyle(fontFamily: isFa ? 'Lalezar' : 'ChakraPetch', fontSize: 34, color: Colors.white, fontWeight: FontWeight.w700)),
                Text(tx(song.titleFa, song.titleEn), style: const TextStyle(fontFamily: 'Estedad', fontSize: 14, color: Color(0xFFD9CCFF))),
                const SizedBox(height: 18),
                _GoldButton(label: tx('ادامه', 'RESUME'), icon: Icons.play_arrow_rounded, onTap: _resume, primary: true, keyName: 'pt_resume'),
                const SizedBox(height: 10),
                _GoldButton(label: tx('شروع دوباره', 'RESTART'), icon: Icons.replay_rounded, onTap: _restartSong),
                const SizedBox(height: 10),
                _GoldButton(label: tx('ترانهٔ دیگر', 'OTHER SONG'), icon: Icons.queue_music_rounded, onTap: _toPicker),
                const SizedBox(height: 10),
                _GoldButton(label: tx('خروج', 'QUIT'), icon: Icons.close_rounded, onTap: _close),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================================================================== widgets

class _EndlessChip extends StatelessWidget {
  const _EndlessChip({required this.label, required this.fa});
  final String label;
  final bool fa;

  @override
  Widget build(BuildContext context) => Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: const LinearGradient(colors: <Color>[Color(0xFFD8C8FF), Color(0xFFB39BFF)]),
          border: Border.all(color: const Color(0xFF2A1A66), width: 1.6),
          boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x668C6BFF), blurRadius: 10)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          const Icon(Icons.all_inclusive_rounded, size: 18, color: Color(0xFF1E1250)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                fontFamily: fa ? 'Lalezar' : 'ChakraPetch',
                fontSize: 16,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E1250),
              )),
        ]),
      );
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onTap, required this.keyName});
  final IconData icon;
  final VoidCallback onTap;
  final String keyName;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: ValueKey<String>(keyName),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF2A2F55), Color(0xFF141733)]),
            border: Border.all(color: const Color(0xFF6E62B8), width: 1.2),
            boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 3))],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child, this.width});
  final Widget child;
  final double? width;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xF01C1550), Color(0xF00D0F33)],
          ),
          border: Border.all(color: PtPalette.gold.withValues(alpha: 0.55), width: 1.2),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x668C6BFF), blurRadius: 34, spreadRadius: -6),
            BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 14)),
          ],
        ),
        child: child,
      );
}

class _GoldButton extends StatelessWidget {
  const _GoldButton({required this.label, required this.icon, required this.onTap, this.primary = false, this.keyName});
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;
  final String? keyName;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: keyName == null ? null : ValueKey<String>(keyName!),
        onTap: onTap,
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: primary
                ? const LinearGradient(colors: <Color>[PtPalette.goldLight, PtPalette.gold, PtPalette.goldDeep])
                : const LinearGradient(colors: <Color>[Color(0xFF2B2466), Color(0xFF1B1747)]),
            border: Border.all(color: primary ? const Color(0xFFFFF4D0) : PtPalette.gold.withValues(alpha: 0.4)),
            boxShadow: primary ? const <BoxShadow>[BoxShadow(color: Color(0x66E6C276), blurRadius: 16, offset: Offset(0, 4))] : null,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Icon(icon, color: primary ? const Color(0xFF2A1A05) : Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                  fontFamily: 'Estedad',
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: primary ? const Color(0xFF2A1A05) : Colors.white,
                )),
          ]),
        ),
      );
}

class _MedallionPainter extends CustomPainter {
  _MedallionPainter({this.index});
  final int? index;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset c = size.center(Offset.zero);
    final double r = size.width * 0.34;
    canvas.drawCircle(c, size.width * 0.5, Paint()
      ..shader = const RadialGradient(colors: <Color>[Color(0xFF26306E), Color(0xFF0C1033)]).createShader(Offset.zero & size));
    canvas.drawCircle(c, size.width * 0.5 - 1, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..shader = goldShader(Offset.zero & size));
    paintMedallion(canvas, c, r);
  }

  @override
  bool shouldRepaint(covariant _MedallionPainter old) => old.index != index;
}

class _SongPicker extends StatelessWidget {
  const _SongPicker({required this.fa, required this.best, required this.onPick, required this.top});
  final bool fa;
  final Map<String, int> best;
  final void Function(PtSong) onPick;
  final double top;

  @override
  Widget build(BuildContext context) {
    final int total = best.values.fold(0, (int a, int b) => a + b);
    return Directionality(
      textDirection: fa ? TextDirection.rtl : TextDirection.ltr,
      child: Column(children: <Widget>[
        SizedBox(height: top),
        ShaderMask(
          shaderCallback: (Rect r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[PtPalette.goldLight, PtPalette.gold, Color(0xFFC79A4A)],
          ).createShader(r),
          child: Text(fa ? 'پیانو تایلز' : 'PIANO TILES',
              style: TextStyle(
                fontFamily: fa ? 'Lalezar' : 'ChakraPetch',
                fontSize: 40,
                height: 1.1,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                shadows: const <Shadow>[Shadow(color: Color(0xAA120838), offset: Offset(0, 3), blurRadius: 8)],
              )),
        ),
        const SizedBox(height: 2),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
          Text(fa ? 'یک ترانه انتخاب کن' : 'Choose a song',
              style: const TextStyle(fontFamily: 'Estedad', fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFFE2D8FF))),
          const SizedBox(width: 10),
          const Icon(Icons.star_rounded, color: PtPalette.gold, size: 18),
          Text(' $total / ${kPtSongs.length * 3}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontFamily: 'ChakraPetch', fontWeight: FontWeight.w700, fontSize: 14, color: PtPalette.goldLight)),
        ]),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            itemCount: kPtSongs.length,
            itemBuilder: (BuildContext c, int i) => _SongCard(song: kPtSongs[i], index: i, fa: fa, stars: best[kPtSongs[i].id] ?? 0, onTap: () => onPick(kPtSongs[i])),
          ),
        ),
      ]),
    );
  }
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.index, required this.fa, required this.stars, required this.onTap});
  final PtSong song;
  final int index;
  final bool fa;
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        key: ValueKey<String>('pt_song_${song.id}'),
        onTap: onTap,
        child: Container(
          height: 78,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xEE10163E), Color(0xEE1A2560)],
            ),
            border: Border.all(color: PtPalette.gold.withValues(alpha: 0.45), width: 1),
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Color(0x55100630), blurRadius: 14, offset: Offset(0, 6)),
              BoxShadow(color: Color(0x338C6BFF), blurRadius: 18, spreadRadius: -4),
            ],
          ),
          child: Row(children: <Widget>[
            CustomPaint(size: const Size(52, 52), painter: _MedallionPainter(index: index)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(fa ? song.titleFa : song.titleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: fa ? 'Lalezar' : 'ChakraPetch', fontSize: 21, height: 1.15, color: Colors.white, fontWeight: FontWeight.w700)),
                Text(fa ? song.subtitleFa : song.subtitleEn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontFamily: 'Estedad', fontSize: 12.5, height: 1.3, color: Color(0xFFBFB2EE), fontWeight: FontWeight.w500)),
                Row(children: <Widget>[
                  for (int k = 0; k < 3; k++)
                    Icon(Icons.music_note_rounded, size: 13, color: k < song.level ? PtPalette.cyan : const Color(0xFF3B3B7A)),
                ]),
              ]),
            ),
            Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
                for (int k = 0; k < 3; k++)
                  Icon(Icons.star_rounded, size: 18, color: k < stars ? PtPalette.gold : const Color(0xFF3A3470)),
              ]),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(colors: <Color>[PtPalette.goldLight, PtPalette.gold, PtPalette.goldDeep]),
                  boxShadow: const <BoxShadow>[BoxShadow(color: Color(0x55E6C276), blurRadius: 8)],
                ),
                child: const Icon(Icons.play_arrow_rounded, size: 20, color: Color(0xFF2A1A05)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

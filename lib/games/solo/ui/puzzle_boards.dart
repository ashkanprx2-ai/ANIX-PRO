import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../arcade_kit/arcade_fx.dart';
import '../core/solo_rules.dart';
import '../core/solo_rules_b.dart';
import '../core/solo_rules_c.dart';
import '../solo_kit.dart';
import 'solo_art.dart';

// =====================================================================================
// NX 2048 — aurora backdrop, frosted board, jewel-gradient tiles that glow brighter as
// they grow, merge pops with sparks, swipe anywhere (arrows still work).
// =====================================================================================
class World2048Board extends SoloBoard {
  const World2048Board({super.key, required super.run});
  @override
  World2048BoardState createState() => World2048BoardState();
}

class World2048BoardState extends SoloBoardState<World2048Board> {
  late World2048Game world;
  final Map<String, double> _pop = <String, double>{};
  final Map<String, double> _merge = <String, double>{};
  int _moves = 0;
  Offset _drag = Offset.zero;

  // Gradient pairs per exponent (2 .. 2048+).
  static const List<List<Color>> _tile = <List<Color>>[
    <Color>[Color(0x14FFFFFF), Color(0x0AFFFFFF)], // empty
    <Color>[Color(0xFF3B4A7A), Color(0xFF26305A)], // 2
    <Color>[Color(0xFF4A3F8F), Color(0xFF2F2766)], // 4
    <Color>[Color(0xFF7A3FC2), Color(0xFF4E2490)], // 8
    <Color>[Color(0xFFB23FD1), Color(0xFF7A1FA0)], // 16
    <Color>[Color(0xFFE5409A), Color(0xFFA81F6A)], // 32
    <Color>[Color(0xFFFF5470), Color(0xFFC72A45)], // 64
    <Color>[Color(0xFFFF8A3D), Color(0xFFD85A1A)], // 128
    <Color>[Color(0xFFFFB534), Color(0xFFE08A10)], // 256
    <Color>[Color(0xFFFFD84A), Color(0xFFE8B01A)], // 512
    <Color>[Color(0xFF8CF06A), Color(0xFF36C25A)], // 1024
    <Color>[Color(0xFF5CF2FF), Color(0xFF1FA8E0)], // 2048+
  ];

  @override
  void reset() {
    world = World2048Game(seed: widget.run.seed);
    world.board.spawn();
    world.board.spawn();
    widget.run.set(0);
    _moves = 0;
  }

  @override
  void step(double dt) {
    for (final String k in _pop.keys.toList()) {
      _pop[k] = math.min(1.0, _pop[k]! + dt * 5);
    }
    for (final String k in _merge.keys.toList()) {
      _merge[k] = _merge[k]! - dt * 2.2;
      if (_merge[k]! <= 0) _merge.remove(k);
    }
  }

  Rect _area(Size size) {
    final double board = math.min(size.width - 32, size.height - 240);
    return Rect.fromCenter(center: Offset(size.width / 2, size.height * 0.5), width: board, height: board);
  }

  void _move(int dir) {
    if (world.over) return;
    final List<List<int>> before = <List<int>>[for (final List<int> r in world.board.cells) List<int>.of(r)];
    final int gained = world.move(dir);
    final List<List<int>> after = world.board.cells;
    if (gained == 0 && _sameBoard(before, after)) return;
    final Rect area = _area(lastSize);
    final double gap = area.width * 0.028;
    final double cell = (area.width - gap * 5) / 4;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (before[r][c] != after[r][c] && after[r][c] != 0) {
          _pop['$r:$c'] = before[r][c] == 0 ? 0.0 : 0.55;
          // A cell whose value grew past every value that could slide in is a merge.
          if (after[r][c] > before[r][c] && before[r][c] != 0 || (gained > 0 && after[r][c] >= 4 && !_rowColHas(before, r, c, after[r][c]))) {
            _merge['$r:$c'] = 1;
            final Offset at = Offset(area.left + gap + c * (cell + gap) + cell / 2, area.top + gap + r * (cell + gap) + cell / 2);
            final int idx = (math.log(after[r][c]) / math.ln2).round().clamp(0, _tile.length - 1);
            fx.burst(at, _tile[idx][0], count: 6 + idx, speed: 160 + idx * 14, life: 0.45, size: 3);
            if (after[r][c] >= 128) fx.ring(at, _tile[idx][0], size: cell * 0.35);
            if (after[r][c] >= 512) fx.flashScreen(_tile[idx][0], 0.12);
          }
        }
      }
    }
    _moves++;
    if (gained > 0) fx.text('+$gained', Offset(lastSize.width / 2, area.top - 50), const Color(0xFFFFE36B), size: 18 + math.min(12, gained / 40));
    widget.run.set(world.score);
    if (world.over) {
      fx.shake(8);
      widget.run.gameOver();
    }
    setState(() {});
  }

  bool _rowColHas(List<List<int>> b, int r, int c, int v) {
    for (int i = 0; i < 4; i++) {
      if (b[r][i] == v || b[i][c] == v) return true;
    }
    return false;
  }

  bool _sameBoard(List<List<int>> a, List<List<int>> b) {
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (a[r][c] != b[r][c]) return false;
      }
    }
    return true;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    SoloArt.sky(canvas, Offset.zero & size, const <Color>[Color(0xFF120A2E), Color(0xFF0A0820), Color(0xFF050412)]);
    // Aurora ribbons.
    for (int i = 0; i < 3; i++) {
      final Path p = Path()..moveTo(0, size.height * (0.18 + i * 0.1));
      for (double x = 0; x <= size.width; x += 12) {
        p.lineTo(x, size.height * (0.18 + i * 0.1) + math.sin(x * 0.012 + t * (0.4 + i * 0.15) + i) * 34);
      }
      canvas.drawPath(p, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 40
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26)
        ..color = <Color>[const Color(0xFFFF4FD8), const Color(0xFF5CF2FF), const Color(0xFF8D6BFF)][i].withValues(alpha: 0.16));
    }
    SoloArt.stars(canvas, Offset.zero & size, t, count: 50, seed: 3);

    final Rect area = _area(size);
    final double gap = area.width * 0.028;
    final double cell = (area.width - gap * 5) / 4;
    final RRect boardR = RRect.fromRectAndRadius(area.inflate(gap * 0.6), const Radius.circular(24));
    canvas.drawRRect(boardR.shift(const Offset(0, 14)), Paint()
      ..color = Colors.black.withValues(alpha: 0.55)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20));
    canvas.drawRRect(boardR, Paint()
      ..shader = ui.Gradient.linear(area.topLeft, area.bottomRight, const <Color>[Color(0xE6221A44), Color(0xE60E0B22)]));
    canvas.drawRRect(boardR, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..shader = ui.Gradient.linear(area.topLeft, area.bottomRight, const <Color>[Color(0xAAFF8FD1), Color(0x335CF2FF), Color(0xAA8D6BFF)], <double>[0.0, 0.5, 1.0]));

    int maxIdx = 0;
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final Rect rr = Rect.fromLTWH(area.left + gap + c * (cell + gap), area.top + gap + r * (cell + gap), cell, cell);
        canvas.drawRRect(RRect.fromRectAndRadius(rr, Radius.circular(cell * 0.18)), Paint()..color = const Color(0x12FFFFFF));
      }
    }
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        final int v = world.board.cell(r, c);
        if (v == 0) continue;
        final Rect rr = Rect.fromLTWH(area.left + gap + c * (cell + gap), area.top + gap + r * (cell + gap), cell, cell);
        final double pop = _pop['$r:$c'] ?? 1.0;
        final double scale = 0.6 + 0.4 * LuxeBoardPainter.easeOutBack(pop);
        final double merge = _merge['$r:$c'] ?? 0;
        final Rect sr = Rect.fromCenter(center: rr.center, width: rr.width * scale * (1 + merge * 0.08), height: rr.height * scale * (1 + merge * 0.08));
        final int idx = (math.log(v) / math.ln2).round().clamp(1, _tile.length - 1);
        maxIdx = math.max(maxIdx, idx);
        final List<Color> g = _tile[idx];
        final RRect tr = RRect.fromRectAndRadius(sr, Radius.circular(cell * 0.18));
        if (idx >= 6) {
          canvas.drawRRect(tr.inflate(2), Paint()
            ..color = g[0].withValues(alpha: 0.25 + 0.12 * (idx - 6) + merge * 0.3 + 0.05 * math.sin(t * 3 + r + c))
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8 + idx.toDouble()));
        }
        canvas.drawRRect(tr.shift(Offset(0, cell * 0.05)), Paint()..color = SoloArt.tone(g[1], -0.15));
        canvas.drawRRect(tr, Paint()..shader = ui.Gradient.linear(sr.topLeft, sr.bottomRight, g));
        // Glass sheen.
        canvas.save();
        canvas.clipRRect(tr);
        canvas.drawPath(
            Path()
              ..moveTo(sr.left, sr.top)
              ..lineTo(sr.right, sr.top)
              ..lineTo(sr.right, sr.top + sr.height * 0.18)
              ..quadraticBezierTo(sr.center.dx, sr.top + sr.height * 0.48, sr.left, sr.top + sr.height * 0.36)
              ..close(),
            Paint()..color = Colors.white.withValues(alpha: 0.13));
        canvas.restore();
        canvas.drawRRect(tr, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withValues(alpha: 0.22));
        final double fs = cell * (v >= 1000 ? 0.27 : v >= 100 ? 0.33 : 0.42) * scale;
        SoloArt.bigLabel(canvas, '$v', sr.center, size: fs, color: Colors.white, glow: idx >= 6 ? g[0] : const Color(0x00000000));
      }
    }
    SoloArt.bigLabel(canvas, '${world.score}', Offset(size.width / 2, area.top - 70), size: 34, color: Colors.white,
        glow: _tile[math.max(1, maxIdx)][0]);
    LuxeBoardPainter.text(canvas, 'SCORE  ·  $_moves MOVES', Offset(size.width / 2, area.top - 40),
        color: const Color(0xFFBFB3E6), size: 11, weight: FontWeight.w700);
    paintVignette(canvas, size, 0.5);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _drag = Offset.zero,
          onPanUpdate: (DragUpdateDetails d) => _drag += d.delta,
          onPanEnd: (_) {
            if (_drag.distance < 24) return;
            if (_drag.dx.abs() > _drag.dy.abs()) {
              _move(_drag.dx < 0 ? 0 : 2);
            } else {
              _move(_drag.dy < 0 ? 1 : 3);
            }
          },
          child: super.build(context),
        ),
        Positioned(
          left: 18,
          bottom: 28,
          right: 18,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            Row(children: <Widget>[
              _arrow(Icons.chevron_left_rounded, () => _move(0)),
              const SizedBox(width: 8),
              _arrow(Icons.keyboard_arrow_down_rounded, () => _move(3)),
            ]),
            Row(children: <Widget>[
              _arrow(Icons.keyboard_arrow_up_rounded, () => _move(1)),
              const SizedBox(width: 8),
              _arrow(Icons.chevron_right_rounded, () => _move(2)),
            ]),
          ]),
        ),
      ]);

  Widget _arrow(IconData i, VoidCallback tap) => SoloPad(icon: i, onTap: tap, size: 62, accent: const Color(0xFFFF8FD1));
}

// =====================================================================================
// TETRIS RUSH — neon glass well with depth grid, bevelled jewel blocks, ghost piece,
// NEXT preview, hard-drop streaks and line-clear lasers with SINGLE … TETRIS! callouts.
// =====================================================================================
class TetrisBoard extends SoloBoard {
  const TetrisBoard({super.key, required super.run});
  @override
  TetrisBoardState createState() => TetrisBoardState();
}

class TetrisBoardState extends SoloBoardState<TetrisBoard> {
  late TetrisWorld world;
  final List<(int, double)> _clears = <(int, double)>[];
  (int, int, int, double)? _streak; // x0, x1, yTop, life

  static const List<Color> _pieceColours = <Color>[
    Color(0xFF2FE6FF), // i cyan
    Color(0xFFFFD83B), // o yellow
    Color(0xFFB45CFF), // t purple
    Color(0xFF48E07A), // s green
    Color(0xFFFF4A63), // z red
    Color(0xFF3F7BFF), // j blue
    Color(0xFFFF9A2E), // l orange
  ];

  @override
  void reset() {
    world = TetrisWorld(seed: widget.run.seed);
    _clears.clear();
    widget.run.set(0);
  }

  Tetromino? _ghost() {
    Tetromino? p = world.current;
    if (p == null) return null;
    while (!world.collides(p!.moved(0, 1))) {
      p = p.moved(0, 1);
    }
    return p;
  }

  List<int> _fullRowsIf(Tetromino? p) {
    if (p == null) return <int>[];
    final List<List<int>> b = <List<int>>[for (final List<int> r in world.board) List<int>.of(r)];
    for (final (int, int) c in p.cells) {
      if (c.$2 >= 0 && c.$2 < TetrisWorld.rows && c.$1 >= 0 && c.$1 < TetrisWorld.cols) b[c.$2][c.$1] = 1;
    }
    return <int>[for (int r = 0; r < TetrisWorld.rows; r++) if (b[r].every((int v) => v != 0)) r];
  }

  void _afterLock(int linesBefore, List<int> rows) {
    final int n = world.lines - linesBefore;
    if (n <= 0 || lastSize == Size.zero) return;
    final Rect well = _well(lastSize);
    final double cell = well.width / TetrisWorld.cols;
    for (final int r in rows) {
      _clears.add((r, 0.45));
      for (int c = 0; c < TetrisWorld.cols; c++) {
        fx.burst(Offset(well.left + (c + 0.5) * cell, well.top + (r + 0.5) * cell), _pieceColours[(c + r) % 7], count: 4, speed: 260, life: 0.6,
            size: 3.5, gravity: 400);
      }
    }
    const List<String> names = <String>['SINGLE', 'DOUBLE', 'TRIPLE', 'TETRIS!'];
    fx.text(names[(n - 1).clamp(0, 3)], Offset(well.center.dx, well.top + well.height * 0.35), n >= 4 ? const Color(0xFFFFD83B) : Colors.white,
        size: n >= 4 ? 38 : 26);
    fx.shake(3.0 + n * 3);
    if (n >= 4) fx.flashScreen(const Color(0xFF2FE6FF), 0.3);
  }

  @override
  void step(double dt) {
    final int before = world.lines;
    final List<int> rows = _fullRowsIf(world.current);
    world.tick(dt);
    _afterLock(before, rows);
    for (int i = _clears.length - 1; i >= 0; i--) {
      final (int, double) c = _clears[i];
      if (c.$2 - dt <= 0) {
        _clears.removeAt(i);
      } else {
        _clears[i] = (c.$1, c.$2 - dt);
      }
    }
    if (_streak != null) {
      final (int, int, int, double) s = _streak!;
      _streak = s.$4 - dt <= 0 ? null : (s.$1, s.$2, s.$3, s.$4 - dt);
    }
    widget.run.set(world.score + world.lines * 100);
    if (world.over) widget.run.gameOver();
  }

  void _hardDrop() {
    final Tetromino? p = world.current;
    final Tetromino? g = _ghost();
    if (p == null || g == null) return;
    int x0 = 99, x1 = -1, yTop = 99;
    for (final (int, int) c in p.cells) {
      x0 = math.min(x0, c.$1);
      x1 = math.max(x1, c.$1);
      yTop = math.min(yTop, c.$2);
    }
    final int before = world.lines;
    final List<int> rows = _fullRowsIf(g);
    final int landY = g.cells.map(((int, int) c) => c.$2).reduce(math.max);
    world.hardDrop();
    _streak = (x0, x1, yTop, 0.25);
    if (lastSize != Size.zero) {
      final Rect well = _well(lastSize);
      final double cell = well.width / TetrisWorld.cols;
      fx.burst(Offset(well.left + (x0 + x1 + 1) / 2 * cell, well.top + (landY + 1) * cell), _pieceColours[p.kind.index], count: 12, speed: 200,
          life: 0.35, size: 3, spread: math.pi, direction: -math.pi / 2);
      fx.shake(4);
    }
    _afterLock(before, rows);
    setState(() {});
  }

  Rect _well(Size size) {
    final double cell = math.min((size.width - 120) / TetrisWorld.cols, (size.height - 220) / TetrisWorld.rows);
    final double w = cell * TetrisWorld.cols;
    final double h = cell * TetrisWorld.rows;
    return Rect.fromLTWH((size.width - w) / 2 - 30, size.height * 0.5 - 8 - h / 2, w, h);
  }

  void _block(Canvas canvas, Rect r, Color c, {double alpha = 1}) {
    if (alpha < 1) canvas.saveLayer(r.inflate(4), Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
    final double rad = r.width * 0.16;
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(rad)), Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomRight,
        <Color>[SoloArt.tone(c, 0.18), c, SoloArt.tone(c, -0.2)], <double>[0.0, 0.5, 1.0]));
    final Rect inner = r.deflate(r.width * 0.18);
    canvas.drawRRect(RRect.fromRectAndRadius(inner, Radius.circular(rad * 0.6)), Paint()
      ..shader = ui.Gradient.linear(inner.topLeft, inner.bottomRight, <Color>[SoloArt.tone(c, 0.08), SoloArt.tone(c, -0.08)]));
    canvas.drawLine(r.topLeft + Offset(rad, 1.2), r.topRight + Offset(-rad, 1.2), Paint()
      ..color = Colors.white.withValues(alpha: 0.7)
      ..strokeWidth = 1.4);
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(rad)), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.black.withValues(alpha: 0.35));
    if (alpha < 1) canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    SoloArt.sky(canvas, Offset.zero & size, const <Color>[Color(0xFF0E0A2A), Color(0xFF070616), Color(0xFF03030A)]);
    SoloArt.stars(canvas, Offset.zero & size, t, count: 60, seed: 21, drift: t * 4);
    final Rect well = _well(size);
    final double cell = well.width / TetrisWorld.cols;
    final double level = (world.lines / 10).floorToDouble();
    final Color frame = SoloArt.hue(250 + level * 35, s: 0.85, l: 0.6);

    // Well: glass with a perspective floor grid.
    final RRect wr = RRect.fromRectAndRadius(well.inflate(7), const Radius.circular(14));
    canvas.drawRRect(wr.shift(const Offset(0, 12)), Paint()
      ..color = Colors.black.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18));
    canvas.drawRRect(wr, Paint()..shader = ui.Gradient.linear(well.topCenter, well.bottomCenter, const <Color>[Color(0xEE0D0B24), Color(0xEE15112E)]));
    final Paint gp = Paint()
      ..color = Colors.white.withValues(alpha: 0.045)
      ..strokeWidth = 1;
    for (int c = 1; c < TetrisWorld.cols; c++) {
      canvas.drawLine(Offset(well.left + c * cell, well.top), Offset(well.left + c * cell, well.bottom), gp);
    }
    for (int r = 1; r < TetrisWorld.rows; r++) {
      canvas.drawLine(Offset(well.left, well.top + r * cell), Offset(well.right, well.top + r * cell), gp);
    }
    SoloArt.neonPath(canvas, Path()..addRRect(wr), frame, width: 2, glow: 10 + 4 * math.sin(t * 2.5));

    // Locked cells.
    for (int r = 0; r < TetrisWorld.rows; r++) {
      for (int c = 0; c < TetrisWorld.cols; c++) {
        final int v = world.board[r][c];
        if (v == 0) continue;
        _block(canvas, Rect.fromLTWH(well.left + c * cell + 1, well.top + r * cell + 1, cell - 2, cell - 2), _pieceColours[(v - 1) % 7]);
      }
    }
    // Line-clear lasers.
    for (final (int, double) cl in _clears) {
      final double k = cl.$2 / 0.45;
      final Rect band = Rect.fromLTWH(well.left, well.top + cl.$1 * cell, well.width, cell);
      canvas.drawRect(band.inflate(cell * 0.3 * (1 - k)), Paint()
        ..color = Colors.white.withValues(alpha: 0.75 * k)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    }
    // Hard-drop streak.
    if (_streak != null) {
      final (int, int, int, double) s = _streak!;
      final double k = s.$4 / 0.25;
      final Rect st = Rect.fromLTRB(well.left + s.$1 * cell, well.top + math.max(0, s.$3) * cell, well.left + (s.$2 + 1) * cell, well.bottom);
      canvas.drawRect(st, Paint()
        ..shader = ui.Gradient.linear(st.topCenter, st.bottomCenter, <Color>[Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.35 * k)]));
    }
    // Ghost + active piece.
    final Tetromino? p = world.current;
    if (p != null) {
      final Color pc = _pieceColours[p.kind.index];
      final Tetromino? g = _ghost();
      if (g != null) {
        for (final (int, int) c in g.cells) {
          if (c.$2 < 0) continue;
          final Rect r = Rect.fromLTWH(well.left + c.$1 * cell + 2, well.top + c.$2 * cell + 2, cell - 4, cell - 4);
          canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * 0.16)), Paint()..color = pc.withValues(alpha: 0.12));
          canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(cell * 0.16)), Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = pc.withValues(alpha: 0.55));
        }
      }
      for (final (int, int) c in p.cells) {
        if (c.$2 < 0) continue;
        final Rect r = Rect.fromLTWH(well.left + c.$1 * cell + 1, well.top + c.$2 * cell + 1, cell - 2, cell - 2);
        canvas.drawRRect(RRect.fromRectAndRadius(r.inflate(2), Radius.circular(cell * 0.2)), Paint()
          ..color = pc.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
        _block(canvas, r, pc);
      }
    }

    // Side panel: NEXT, LINES, LEVEL.
    final double px = well.right + 18;
    final Rect nextBox = Rect.fromLTWH(px, well.top, 72, 72);
    canvas.drawRRect(RRect.fromRectAndRadius(nextBox, const Radius.circular(12)), Paint()..color = const Color(0xCC120F2C));
    SoloArt.neonPath(canvas, Path()..addRRect(RRect.fromRectAndRadius(nextBox, const Radius.circular(12))), frame, width: 1.2, glow: 6);
    LuxeBoardPainter.text(canvas, 'NEXT', nextBox.topCenter + const Offset(0, 11), color: const Color(0xFFBFB3E6), size: 10, weight: FontWeight.w700);
    final Tetromino np = Tetromino(world.next, 0, 0, 0);
    final List<(int, int)> cells = np.cells;
    final int minX = cells.map(((int, int) c) => c.$1).reduce(math.min), maxX = cells.map(((int, int) c) => c.$1).reduce(math.max);
    final int minY = cells.map(((int, int) c) => c.$2).reduce(math.min), maxY = cells.map(((int, int) c) => c.$2).reduce(math.max);
    const double nc = 13;
    final Offset o = nextBox.center + Offset(-(maxX - minX + 1) * nc / 2, -(maxY - minY + 1) * nc / 2 + 7);
    for (final (int, int) c in cells) {
      _block(canvas, Rect.fromLTWH(o.dx + (c.$1 - minX) * nc, o.dy + (c.$2 - minY) * nc, nc - 1, nc - 1), _pieceColours[world.next.index]);
    }
    LuxeBoardPainter.text(canvas, 'LINES', Offset(nextBox.center.dx, nextBox.bottom + 26), color: const Color(0xFFBFB3E6), size: 10, weight: FontWeight.w700);
    SoloArt.bigLabel(canvas, '${world.lines}', Offset(nextBox.center.dx, nextBox.bottom + 50), size: 24, color: Colors.white, glow: frame);
    LuxeBoardPainter.text(canvas, 'LEVEL', Offset(nextBox.center.dx, nextBox.bottom + 86), color: const Color(0xFFBFB3E6), size: 10, weight: FontWeight.w700);
    SoloArt.bigLabel(canvas, '${level.toInt() + 1}', Offset(nextBox.center.dx, nextBox.bottom + 110), size: 24, color: Colors.white, glow: frame);
    paintVignette(canvas, size, 0.5);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        super.build(context),
        Positioned(
          left: 16,
          right: 16,
          bottom: 26,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
            Row(children: <Widget>[
              SoloPad(icon: Icons.chevron_left_rounded, onTap: () => setState(world.moveLeft), size: 62, accent: const Color(0xFF8D8CFF)),
              const SizedBox(width: 8),
              SoloPad(icon: Icons.chevron_right_rounded, onTap: () => setState(world.moveRight), size: 62, accent: const Color(0xFF8D8CFF)),
            ]),
            Row(children: <Widget>[
              SoloPad(icon: Icons.rotate_right_rounded, onTap: () => setState(world.rotate), size: 62, accent: const Color(0xFF8D8CFF)),
              const SizedBox(width: 8),
              SoloPad(
                icon: Icons.keyboard_double_arrow_down_rounded,
                onTap: _hardDrop,
                size: 62,
                accent: const Color(0xFF2FE6FF),
              ),
            ]),
          ]),
        ),
      ]);
}

// =====================================================================================
// STACK TOWER — true 3D slabs (top + front + side faces) shifting hue floor by floor, a
// smooth rising camera, sliced-off chunks that tumble away, perfect-drop shockwaves.
// =====================================================================================
class StackBoard extends SoloBoard {
  const StackBoard({super.key, required super.run});
  @override
  StackBoardState createState() => StackBoardState();
}

class _Chunk {
  _Chunk(this.left, this.width, this.floor, this.hue);
  final double left, width;
  final int floor;
  final double hue;
  double drop = 0, vy = 0, rot = 0;
  double life = 2;
}

class StackBoardState extends SoloBoardState<StackBoard> {
  late StackWorld world;
  double _cam = 0;
  int _streak = 0;
  double _wave = 0;
  final List<_Chunk> _chunks = <_Chunk>[];
  double _hue0 = 0;

  @override
  void reset() {
    world = StackWorld(seed: widget.run.seed);
    widget.run.set(0);
    _cam = 0;
    _streak = 0;
    _wave = 0;
    _chunks.clear();
    _hue0 = (widget.run.seed * 37 % 360).toDouble();
  }

  double _hue(int floor) => _hue0 + floor * 8.0;

  @override
  void step(double dt) {
    world.update(dt);
    _cam = LuxeBoardPainter.lerp(_cam, world.blocks.length.toDouble(), 1 - math.pow(0.02, dt).toDouble());
    if (_wave > 0) _wave -= dt * 1.6;
    for (final _Chunk c in _chunks) {
      c.vy += 9 * dt;
      c.drop += c.vy * dt;
      c.rot += dt * 1.8;
      c.life -= dt;
    }
    _chunks.removeWhere((_Chunk c) => c.life <= 0);
  }

  void _drop() {
    if (world.over) return;
    final double ml = world.movingLeft, mw = world.movingWidth;
    final int floor = world.blocks.length;
    final String r = world.drop();
    if (r == 'perfect') {
      _streak++;
      _wave = 1;
      fx.text(_streak > 1 ? 'PERFECT ×$_streak' : 'PERFECT', Offset(lastSize.width / 2, lastSize.height * 0.3), Colors.white, size: 26);
      fx.flashScreen(Colors.white, 0.12);
      widget.run.set(world.floors * 10 + world.perfect * 15);
    } else if (r == 'ok') {
      _streak = 0;
      final StackBlock nb = world.blocks.last;
      if (ml < nb.left) _chunks.add(_Chunk(ml, nb.left - ml, floor, _hue(floor)));
      if (ml + mw > nb.left + nb.width) _chunks.add(_Chunk(nb.left + nb.width, ml + mw - nb.left - nb.width, floor, _hue(floor)));
      fx.shake(3);
      widget.run.set(world.floors * 10 + world.perfect * 15);
    } else {
      _chunks.add(_Chunk(ml, mw, floor, _hue(floor)));
      fx.shake(10);
      widget.run.gameOver();
    }
    setState(() {});
  }

  void _slab(Canvas canvas, double x, double y, double w, double h, double ox, double oy, Color c, {double alpha = 1}) {
    final Paint top = Paint()..color = SoloArt.tone(c, 0.12).withValues(alpha: alpha);
    final Paint front = Paint()
      ..shader = ui.Gradient.linear(Offset(x, y), Offset(x, y + h), <Color>[c.withValues(alpha: alpha), SoloArt.tone(c, -0.1).withValues(alpha: alpha)]);
    final Paint side = Paint()..color = SoloArt.tone(c, -0.2).withValues(alpha: alpha);
    canvas.drawPath(
        Path()
          ..moveTo(x + w, y)
          ..lineTo(x + w + ox, y - oy)
          ..lineTo(x + w + ox, y - oy + h)
          ..lineTo(x + w, y + h)
          ..close(),
        side);
    canvas.drawRect(Rect.fromLTWH(x, y, w, h), front);
    canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..lineTo(x + w, y)
          ..lineTo(x + w + ox, y - oy)
          ..lineTo(x + ox, y - oy)
          ..close(),
        top);
    canvas.drawLine(Offset(x, y), Offset(x + w, y), Paint()
      ..color = Colors.white.withValues(alpha: 0.35 * alpha)
      ..strokeWidth = 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    final double h0 = _hue(world.blocks.length);
    SoloArt.sky(canvas, Offset.zero & size, <Color>[
      SoloArt.hue(h0 + 30, s: 0.55, l: 0.32),
      SoloArt.hue(h0 + 10, s: 0.5, l: 0.16),
      SoloArt.hue(h0, s: 0.45, l: 0.07),
    ]);
    if (world.floors > 15) {
      SoloArt.stars(canvas, Rect.fromLTWH(0, 0, size.width, size.height * 0.6), t, count: 50, seed: 5);
    }
    // Drifting clouds.
    for (int i = 0; i < 5; i++) {
      final double y = ((i * 170 + _cam * 30) % (size.height + 200)) - 100;
      final double x = ((i * 97 + t * (8 + i * 3)) % (size.width + 200)) - 100;
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 160, height: 34), Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }

    final double boardW = math.min(size.width * 0.62, 340);
    final double ox = boardW * 0.16, oy = boardW * 0.12;
    final double left = (size.width - boardW - ox) / 2;
    const double bh = 26;
    final double anchorY = size.height * 0.56;
    double yOf(int floor) => anchorY + (_cam - floor - 1) * bh;

    // Plinth.
    final double py = yOf(0) + bh;
    _slab(canvas, left - 10, py, boardW + 20, size.height, ox, oy, const Color(0xFF1E1B2E));

    final int firstVisible = math.max(0, (_cam - (size.height - anchorY) / bh - 2).floor());
    for (int i = firstVisible; i < world.blocks.length; i++) {
      final StackBlock b = world.blocks[i];
      final double y = yOf(i);
      if (y > size.height + bh) continue;
      _slab(canvas, left + b.left * boardW, y, b.width * boardW, bh, ox, oy, SoloArt.hue(_hue(i), s: 0.7, l: 0.58));
    }
    // Perfect shockwave around the top block.
    if (_wave > 0 && world.blocks.isNotEmpty) {
      final StackBlock b = world.blocks.last;
      final double y = yOf(world.blocks.length - 1);
      final double grow = (1 - _wave) * 22;
      final Path outline = Path()
        ..moveTo(left + b.left * boardW - grow, y + grow * 0.3)
        ..lineTo(left + (b.left + b.width) * boardW + grow, y + grow * 0.3)
        ..lineTo(left + (b.left + b.width) * boardW + ox + grow, y - oy - grow * 0.3)
        ..lineTo(left + b.left * boardW + ox - grow, y - oy - grow * 0.3)
        ..close();
      SoloArt.neonPath(canvas, outline, Colors.white, width: 2, glow: 10, alpha: _wave.clamp(0.0, 1.0));
    }
    // Falling chunks.
    for (final _Chunk c in _chunks) {
      final double y = yOf(c.floor) + c.drop * 60;
      canvas.save();
      final double cx = left + (c.left + c.width / 2) * boardW;
      canvas.translate(cx, y + bh / 2);
      canvas.rotate(c.rot * (c.left < 0.5 ? -0.4 : 0.4));
      canvas.translate(-cx, -(y + bh / 2));
      _slab(canvas, left + c.left * boardW, y, c.width * boardW, bh, ox, oy, SoloArt.hue(c.hue, s: 0.7, l: 0.58), alpha: (c.life / 2).clamp(0.0, 1.0));
      canvas.restore();
    }
    // Moving block.
    if (!world.over) {
      final int f = world.blocks.length;
      final double y = yOf(f);
      final double x = left + world.movingLeft * boardW;
      final double w = world.movingWidth * boardW;
      SoloArt.paintBloom(canvas, Offset(x + w / 2, y + bh / 2), w * 0.6, SoloArt.hue(_hue(f)), 0.25);
      _slab(canvas, x, y, w, bh, ox, oy, SoloArt.hue(_hue(f), s: 0.75, l: 0.62));
      // Alignment guides.
      final StackBlock top = world.top;
      for (final double gx in <double>[top.left, top.left + top.width]) {
        canvas.drawLine(Offset(left + gx * boardW, y - 18), Offset(left + gx * boardW, y + bh + 4), Paint()
          ..color = Colors.white.withValues(alpha: 0.18)
          ..strokeWidth = 1);
      }
    }

    SoloArt.bigLabel(canvas, '${world.floors}', Offset(size.width / 2, size.height * 0.16), size: 52, color: Colors.white,
        glow: SoloArt.hue(h0));
    paintVignette(canvas, size, 0.45);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: _drop, child: super.build(context)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 26,
          child: Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _drop,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  gradient: LinearGradient(colors: <Color>[widget.run.skin.accent, const Color(0xFFEAFBFF)]),
                  boxShadow: <BoxShadow>[BoxShadow(color: widget.run.skin.accent.withValues(alpha: 0.42), blurRadius: 24)],
                ),
                child: const Text('DROP',
                    style: TextStyle(
                        fontFamily: 'ChakraPetch', fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: 1.4, color: Color(0xFF1A1408))),
              ),
            ),
          ),
        ),
      ]);
}

// =====================================================================================
// KNIFE HIT — a real wooden target (growth rings, bark, cracks) that bumps on every hit,
// steel knives with bevelled blades and wrapped handles, wood chips, a bouncing failed
// knife, and a stage meter of remaining knives.
// =====================================================================================
class KnifeBoard extends SoloBoard {
  const KnifeBoard({super.key, required super.run});
  @override
  KnifeBoardState createState() => KnifeBoardState();
}

class KnifeBoardState extends SoloBoardState<KnifeBoard> {
  late KnifeWorld world;
  double _fly = 0;
  bool _thrown = false;
  double _bump = 0;
  double _fail = -1;
  int _stageShown = 0;

  @override
  void reset() {
    world = KnifeWorld(seed: widget.run.seed);
    widget.run.set(0);
    _fly = 0;
    _thrown = false;
    _bump = 0;
    _fail = -1;
    _stageShown = 0;
  }

  Offset _centre(Size s) => Offset(s.width / 2, s.height * 0.40);
  double _radius(Size s) => math.min(s.width * 0.33, 140);

  @override
  void step(double dt) {
    world.update(dt);
    if (_bump > 0) _bump = math.max(0, _bump - dt * 6);
    if (_thrown) {
      _fly += dt * 4.2;
      if (_fly >= 1) {
        _thrown = false;
        _fly = 0;
        final bool ok = world.throwAt();
        widget.run.set(world.thrown * 10 + world.stage * 25);
        final Size s = lastSize;
        final Offset hit = _centre(s) + Offset(0, _radius(s));
        if (ok) {
          _bump = 1;
          fx.burst(hit, const Color(0xFFD9A066), count: 12, speed: 260, life: 0.5, size: 5, kind: ParticleKind.shard, gravity: 700,
              spread: math.pi * 0.9, direction: math.pi / 2);
          fx.burst(hit, const Color(0xFFFFF1C9), count: 6, speed: 180, life: 0.25, size: 2.5);
          fx.shake(2.5);
          if (world.stage > _stageShown) {
            _stageShown = world.stage;
            fx.text('STAGE ${world.stage + 1}', _centre(s) - Offset(0, _radius(s) + 60), const Color(0xFFFFD36B), size: 30);
            fx.burst(_centre(s), const Color(0xFF9A82FF), count: 30, speed: 420, life: 0.8, size: 4);
            fx.flashScreen(const Color(0xFF9A82FF), 0.2);
          }
        } else {
          _fail = 0;
          fx.burst(hit, Colors.white, count: 22, speed: 420, life: 0.4, size: 3);
          fx.burst(hit, const Color(0xFFFFC23B), count: 10, speed: 240, life: 0.5, size: 3, kind: ParticleKind.orb);
          fx.shake(14);
          fx.flashScreen(const Color(0xFFFF2E4E), 0.4);
          widget.run.gameOver();
        }
        setState(() {});
      }
    }
  }

  void _throw() {
    if (_thrown || world.hit) return;
    _thrown = true;
    _fly = 0;
  }

  void _knife(Canvas canvas, double len, {double alpha = 1}) {
    // Drawn pointing up (tip at y = -len/2), centred on its middle.
    final double bl = len * 0.58, hl = len * 0.42, w = len * 0.11;
    final double top = -len / 2;
    final Path blade = Path()
      ..moveTo(0, top)
      ..quadraticBezierTo(w * 0.9, top + bl * 0.25, w * 0.55, top + bl)
      ..lineTo(-w * 0.55, top + bl)
      ..lineTo(-w * 0.5, top + bl * 0.2)
      ..close();
    canvas.drawPath(blade, Paint()
      ..shader = ui.Gradient.linear(Offset(-w, 0), Offset(w, 0),
          <Color>[const Color(0xFF8C95A8).withValues(alpha: alpha), const Color(0xFFF4F7FF).withValues(alpha: alpha), const Color(0xFFA9B2C4).withValues(alpha: alpha)], <double>[0.0, 0.5, 1.0]));
    canvas.drawLine(Offset(0, top + 4), Offset(w * 0.2, top + bl - 2), Paint()
      ..color = Colors.white.withValues(alpha: 0.7 * alpha)
      ..strokeWidth = 1);
    // Guard.
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, top + bl + 2), width: w * 2.2, height: 5), const Radius.circular(2)),
        Paint()..color = const Color(0xFFD9B35A).withValues(alpha: alpha));
    // Handle with wraps.
    final Rect handle = Rect.fromLTWH(-w * 0.55, top + bl + 4, w * 1.1, hl - 6);
    canvas.drawRRect(RRect.fromRectAndRadius(handle, Radius.circular(w * 0.4)), Paint()
      ..shader = ui.Gradient.linear(handle.centerLeft, handle.centerRight,
          <Color>[const Color(0xFF3A1A12).withValues(alpha: alpha), const Color(0xFF7A3B26).withValues(alpha: alpha), const Color(0xFF3A1A12).withValues(alpha: alpha)], <double>[0.0, 0.5, 1.0]));
    for (double y = handle.top + 4; y < handle.bottom - 2; y += 5) {
      canvas.drawLine(Offset(handle.left, y), Offset(handle.right, y + 2), Paint()
        ..color = Colors.black.withValues(alpha: 0.35 * alpha)
        ..strokeWidth = 1.2);
    }
    canvas.drawCircle(Offset(0, handle.bottom), w * 0.5, Paint()..color = const Color(0xFFD9B35A).withValues(alpha: alpha));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double t = clock;
    SoloArt.sky(canvas, Offset.zero & size, const <Color>[Color(0xFF1A1030), Color(0xFF0C0818), Color(0xFF050309)]);
    final Offset c = _centre(size);
    final double r = _radius(size);
    // Spotlight cone.
    canvas.drawPath(
        Path()
          ..moveTo(c.dx - 30, 0)
          ..lineTo(c.dx + 30, 0)
          ..lineTo(c.dx + r * 1.6, c.dy + r * 1.2)
          ..lineTo(c.dx - r * 1.6, c.dy + r * 1.2)
          ..close(),
        Paint()
          ..shader = ui.Gradient.linear(Offset(c.dx, 0), Offset(c.dx, c.dy + r), const <Color>[Color(0x22FFE9C2), Color(0x00FFE9C2)]));
    SoloArt.paintBloom(canvas, c, r * 1.7, const Color(0xFF9A82FF), 0.18 + 0.06 * math.sin(t * 2));

    final double bump = _bump * 6;
    final Offset lc = c - Offset(0, bump);
    final double knifeLen = r * 0.75;

    // Stuck knives (drawn behind the log so blades sink into the wood).
    for (final double a in world.stuckAngles) {
      final double wa = a + world.rotation;
      final Offset mid = lc + Offset(math.cos(wa), math.sin(wa)) * (r + knifeLen * 0.5 - knifeLen * 0.22);
      canvas.save();
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(wa - math.pi / 2);
      _knife(canvas, knifeLen);
      canvas.restore();
    }

    // The log.
    paintShadow(canvas, lc + Offset(0, r * 1.05), r * 1.6, r * 0.25, 0.5);
    canvas.save();
    canvas.translate(lc.dx, lc.dy);
    canvas.rotate(world.rotation);
    // Bark with notches.
    final Path bark = Path();
    const int n = 36;
    for (int i = 0; i <= n; i++) {
      final double a = i * math.pi * 2 / n;
      final double rr = r * (1 + ((i * 7919) % 5) * 0.008);
      final Offset p = Offset(math.cos(a), math.sin(a)) * rr;
      if (i == 0) {
        bark.moveTo(p.dx, p.dy);
      } else {
        bark.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(bark..close(), Paint()..shader = ui.Gradient.radial(Offset.zero, r, const <Color>[Color(0xFF6B3D1E), Color(0xFF3A1E0C)], <double>[0.85, 1]));
    // Wood face with growth rings.
    final double face = r * 0.88;
    canvas.drawCircle(Offset.zero, face, Paint()..shader = ui.Gradient.radial(const Offset(-10, -14), face * 1.2,
        const <Color>[Color(0xFFF0C88A), Color(0xFFD9A066), Color(0xFFB77A42)], <double>[0, 0.6, 1]));
    for (int i = 1; i < 9; i++) {
      final double rr = face * i / 9 + math.sin(i * 2.3) * 2;
      canvas.drawCircle(Offset(math.sin(i * 1.7) * 1.5, math.cos(i) * 1.5), rr, Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = i.isEven ? 1.6 : 0.9
        ..color = const Color(0xFF8A5428).withValues(alpha: 0.35 + (i % 3) * 0.1));
    }
    // Cracks.
    final Paint crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = const Color(0xFF5A3214).withValues(alpha: 0.6);
    for (int i = 0; i < 3; i++) {
      final double a = i * 2.1 + 0.4;
      final Path p = Path()..moveTo(math.cos(a) * face * 0.15, math.sin(a) * face * 0.15);
      p.lineTo(math.cos(a + 0.12) * face * 0.45, math.sin(a + 0.12) * face * 0.45);
      p.lineTo(math.cos(a - 0.05) * face * 0.7, math.sin(a - 0.05) * face * 0.7);
      canvas.drawPath(p, crack);
    }
    // Pith + metal hub.
    paintSphere(canvas, Offset.zero, face * 0.16, const Color(0xFF8E96B0), shadow: false, rim: const Color(0xFF3A4054));
    canvas.restore();
    // Rim light.
    canvas.drawCircle(lc, r, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = ui.Gradient.linear(lc - Offset(r, r), lc + Offset(r, r), const <Color>[Color(0x88FFE9C2), Color(0x00FFE9C2)]));

    // Knife in hand / in flight.
    final double startY = size.height * 0.84;
    final double endY = c.dy + r + knifeLen * 0.5 - knifeLen * 0.22;
    if (_fail >= 0) {
      _fail += 1 / 60;
      final double k = _fail;
      canvas.save();
      canvas.translate(c.dx + k * 140, endY + 20 + k * k * 900 - k * 260);
      canvas.rotate(k * 14);
      _knife(canvas, knifeLen);
      canvas.restore();
    } else if (!world.hit) {
      final double y = LuxeBoardPainter.lerp(startY, endY, Curves.easeIn.transform(_fly));
      if (_thrown) {
        paintTrail(canvas, <Offset>[for (int i = 0; i < 6; i++) Offset(c.dx, y + (6 - i) * 14)], Colors.white, 6, alpha: 0.4);
      } else {
        SoloArt.paintBloom(canvas, Offset(c.dx, y), 40, const Color(0xFF9A82FF), 0.25 + 0.1 * math.sin(t * 4));
      }
      canvas.save();
      canvas.translate(c.dx, y);
      _knife(canvas, knifeLen);
      canvas.restore();
    }

    // Stage meter: knives left in this stage.
    final int inStage = world.thrown % 5;
    for (int i = 0; i < 5; i++) {
      final Offset p = Offset(28, size.height * 0.62 - i * 30);
      final bool used = i < inStage;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(-math.pi / 2 + math.pi);
      canvas.scale(0.42);
      _knife(canvas, 60, alpha: used ? 0.25 : 1);
      canvas.restore();
    }
    // Stage pips.
    for (int i = 0; i < 5; i++) {
      final Offset p = Offset(size.width / 2 + (i - 2) * 22, c.dy - r - 46);
      final bool done = i < world.stage % 5;
      final bool boss = i == 4;
      canvas.drawCircle(p, boss ? 7 : 5, Paint()..color = done ? const Color(0xFFFFD36B) : const Color(0x44FFFFFF));
      if (i == world.stage % 5) SoloArt.paintBloom(canvas, p, 14, const Color(0xFFFFD36B), 0.6);
    }
    SoloArt.bigLabel(canvas, '${world.thrown}', Offset(size.width / 2, c.dy - r - 82), size: 34, color: Colors.white, glow: const Color(0xFF9A82FF));
    paintVignette(canvas, size, 0.55);
  }

  @override
  Widget build(BuildContext context) => Stack(fit: StackFit.expand, children: <Widget>[
        GestureDetector(behavior: HitTestBehavior.opaque, onTap: _throw, child: super.build(context)),
        Positioned(
          right: 22,
          bottom: 30,
          child: SoloPad(icon: Icons.gps_fixed_rounded, onTap: _throw, size: 78, accent: const Color(0xFF9A82FF)),
        ),
      ]);
}

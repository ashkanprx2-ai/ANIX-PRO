import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'gs_art.dart';
import 'gs_engine.dart';
import 'gs_fx.dart';
import 'gs_meta.dart';

/// Perspective camera behind and above the squad.
class GsCam {
  GsCam(Size size, this.camX) {
    w = size.width;
    h = size.height;
    hy = h * 0.285;
    fd = 0.47 * w / GsEngine.roadHalf; // pixels per world unit at the squad (z = 0)
    f = fd * d;
    camH = (h * 0.755 - hy) / fd;
    cx = w / 2;
  }
  late final double w, h, hy, fd, f, camH, cx;
  static const double d = 6;
  final double camX;

  double s(double z) => f / math.max(0.35, z + d);
  double sx(double x, double z) => cx + (x - camX) * s(z);
  double sy(double z, [double y = 0]) => hy + (camH - y) * s(z);
  Offset p(double x, double z, [double y = 0]) => Offset(sx(x, z), sy(z, y));
}

class _Item {
  _Item(this.z, this.draw);
  final double z;
  final void Function() draw;
}

/// Draws the whole Gate Shooter world: desert backdrop with heat haze, highway, guard rails, scenery, gates, squad,
/// enemies, numbered blocks, boss, bullets and world particles.
class GsRenderer {
  final Map<String, TextPainter> _tp = <String, TextPainter>{};
  final List<_Item> _items = <_Item>[];
  late List<List<Offset>> _cracks;
  late List<Offset> _specks;
  static const double tile = 48;
  final Paint _p = Paint()..filterQuality = FilterQuality.medium;

  GsRenderer() {
    final math.Random r = math.Random(5);
    _cracks = <List<Offset>>[];
    for (int i = 0; i < 9; i++) {
      // Offsets are (x, z) in world space inside one tile.
      double x = (r.nextDouble() - 0.5) * 7.2;
      double z = r.nextDouble() * tile;
      final List<Offset> c = <Offset>[Offset(x, z)];
      final int n = 3 + r.nextInt(4);
      double a = r.nextDouble() * math.pi * 2;
      for (int k = 0; k < n; k++) {
        a += (r.nextDouble() - 0.5) * 1.4;
        x += math.cos(a) * 0.6;
        z += math.sin(a) * 1.1;
        c.add(Offset(x.clamp(-3.8, 3.8), z));
      }
      _cracks.add(c);
    }
    _specks = <Offset>[for (int i = 0; i < 60; i++) Offset((r.nextDouble() - 0.5) * 7.8, r.nextDouble() * tile)];
  }

  TextPainter text(String s, double size, Color c, {String family = 'Lalezar', Color? stroke, double strokeW = 0, List<Shadow>? shadows}) {
    final String key = '$s|${size.toStringAsFixed(0)}|${c.toARGB32()}|$family|${stroke?.toARGB32()}|$strokeW';
    final TextPainter? hit = _tp[key];
    if (hit != null) return hit;
    if (_tp.length > 400) _tp.clear();
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: family,
          fontSize: size,
          height: 1.0,
          color: stroke == null ? c : null,
          foreground: stroke == null
              ? null
              : (Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = strokeW
                ..strokeJoin = StrokeJoin.round
                ..color = stroke),
          shadows: shadows,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout();
    _tp[key] = tp;
    return tp;
  }

  void label(Canvas c, String s, Offset at, double size, Color fill, {Color outline = const Color(0xFF1A2233), double ow = 0.16}) {
    final TextPainter o = text(s, size, fill, stroke: outline, strokeW: size * ow);
    final TextPainter f = text(s, size, fill);
    final Offset tl = at - Offset(f.width / 2, f.height / 2);
    o.paint(c, tl);
    f.paint(c, tl);
  }

  // ======================================================================================== frame
  void paint(Canvas c, Size size, GsEngine e, GsParticles fx, double clock, {double bossFlash = 0, double camShakeZ = 0}) {
    final GsCam cam = GsCam(size, e.px * 0.32);
    _sky(c, cam, clock);
    _ground(c, cam, e, clock);
    _road(c, cam, e, clock);
    _haze(c, cam, clock);

    _items.clear();
    for (final GsProp p in e.props) {
      if (p.z > -4 && p.z < 95) _items.add(_Item(p.z, () => _prop(c, cam, p)));
    }
    for (final GsGate g in e.gates) {
      if (g.z > -3 && g.z < 95) _items.add(_Item(g.z + 0.01, () => _gate(c, cam, g, clock)));
    }
    for (final GsTarget t in e.targets) {
      if (t.z > -4 && t.z < 95) _items.add(_Item(t.z, () => _target(c, cam, t, e, clock, bossFlash)));
    }
    for (int i = 0; i < e.soldiers.length; i++) {
      final GsSoldier s = e.soldiers[i];
      _items.add(_Item(s.z, () => _soldier(c, cam, s, e, clock)));
    }
    _items.sort((_Item a, _Item b) => b.z.compareTo(a.z));
    // shadows first (all on the ground, under everything)
    for (final GsTarget t in e.targets) {
      if (t.z > -4 && t.z < 95) _shadow(c, cam, t.x, t.z, t.kind == GsKind.boss ? 2.6 : (t.kind == GsKind.enemy ? 0.75 : 1.05));
    }
    for (final GsSoldier s in e.soldiers) {
      _shadow(c, cam, s.x, s.z, 0.72 * e.unitScale);
    }
    for (final _Item it in _items) {
      it.draw();
    }
    _particles(c, cam, fx, back: false);
    _bullets(c, cam, e);
    _particlesFlash(c, cam, fx);
    if (e.hurtFlash > 0) _hurtVignette(c, size, e.hurtFlash);
  }

  // ======================================================================================== backdrop
  void _sky(Canvas c, GsCam cam, double t) {
    final ui.Image? bd = GsArt.get('backdrop');
    final Rect full = Rect.fromLTWH(0, 0, cam.w, cam.h);
    if (bd == null) {
      c.drawRect(
          full,
          Paint()
            ..shader = ui.Gradient.linear(Offset.zero, Offset(0, cam.hy + 40),
                const <Color>[Color(0xFF9ED3EE), Color(0xFFF6E7CC), Color(0xFFF2D7A6)], <double>[0, 0.75, 1]));
      return;
    }
    // Align the image's horizon (dune line ≈ 64 % down the art) with the road's vanishing line.
    final double sc = math.max(cam.w / bd.width, (cam.hy + 80) / (bd.height * 0.64));
    final double dw = bd.width * sc, dh = bd.height * sc;
    final double left = (cam.w - dw) / 2 - (cam.camX * 2.5).clamp(-30, 30);
    final double top = cam.hy + 6 - bd.height * 0.64 * sc;
    c.drawImageRect(bd, Rect.fromLTWH(0, 0, bd.width.toDouble(), bd.height.toDouble()), Rect.fromLTWH(left, top, dw, dh), _p);
    if (top + dh < cam.h) {
      // stretch the flat-sand foot of the art down to the bottom of the screen
      c.drawImageRect(bd, Rect.fromLTWH(0, bd.height * 0.93, bd.width.toDouble(), bd.height * 0.07),
          Rect.fromLTWH(left, top + dh - 2, dw, cam.h - (top + dh) + 4), _p);
    }
  }

  void _ground(Canvas c, GsCam cam, GsEngine e, double t) {
    // sand ripples sliding past on both sides: the main sense of speed off-road
    final Paint rp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final double off = e.distance % 6;
    for (double z = -2 - off + 6; z < 70; z += 6) {
      final double k = (1 - z / 70).clamp(0.0, 1.0);
      rp
        ..strokeWidth = math.max(0.6, 0.12 * cam.s(z))
        ..color = const Color(0xFFB9802E).withValues(alpha: 0.18 * k);
      for (final double side in <double>[-1, 1]) {
        final double x0 = side * (GsEngine.roadHalf + 1.6), x1 = side * (GsEngine.roadHalf + 14);
        final Path p = Path()..moveTo(cam.sx(x0, z), cam.sy(z));
        for (int i = 1; i <= 6; i++) {
          final double x = x0 + (x1 - x0) * i / 6;
          final double zz = z + math.sin(i * 1.3 + z * 0.7) * 0.6;
          p.lineTo(cam.sx(x, zz), cam.sy(zz));
        }
        c.drawPath(p, rp);
      }
    }
  }

  void _quad(Canvas c, GsCam cam, double x0, double x1, double z0, double z1, Paint p, {double y = 0}) {
    final Path path = Path()
      ..moveTo(cam.sx(x0, z0), cam.sy(z0, y))
      ..lineTo(cam.sx(x1, z0), cam.sy(z0, y))
      ..lineTo(cam.sx(x1, z1), cam.sy(z1, y))
      ..lineTo(cam.sx(x0, z1), cam.sy(z1, y))
      ..close();
    c.drawPath(path, p);
  }

  void _road(Canvas c, GsCam cam, GsEngine e, double t) {
    const double zn = -3.2, zf = 400;
    const double rh = GsEngine.roadHalf;
    // soft sand shadow along the shoulders
    _quad(c, cam, -rh - 2.4, rh + 2.4, zn, zf, Paint()..color = const Color(0x22704010));
    // concrete shoulders
    _quad(c, cam, -rh - 1.05, rh + 1.05, zn, zf, Paint()..color = const Color(0xFFD9D3C9));
    // asphalt: bright hazy far, deep grey near
    final Paint asphalt = Paint()
      ..shader = ui.Gradient.linear(Offset(0, cam.hy), Offset(0, cam.h), const <Color>[
        Color(0xFFD7CFC4),
        Color(0xFFA9A8A8),
        Color(0xFF8E8F93),
        Color(0xFF7E8085),
      ], const <double>[0, 0.16, 0.55, 1]);
    _quad(c, cam, -rh, rh, zn, zf, asphalt);
    // subtle centre wear (lighter lanes where tyres rolled)
    final Paint wear = Paint()..color = const Color(0x10FFFFFF);
    for (final double x in <double>[-2.6, -1.4, 1.4, 2.6]) {
      _quad(c, cam, x - 0.35, x + 0.35, zn, 120, wear);
    }

    final double dist = e.distance;
    // speckles + cracks, tiled along the road
    final Paint sp = Paint();
    final Paint cp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final double base = (dist / tile).floorToDouble() * tile;
    for (int k = 0; k < 3; k++) {
      final double tz = base + k * tile - dist;
      for (final Offset s in _specks) {
        final double z = tz + s.dy;
        if (z < zn || z > 70) continue;
        final double r = math.max(0.5, 0.045 * cam.s(z));
        sp.color = (s.dx * 10).round().isEven ? const Color(0x22000000) : const Color(0x26FFFFFF);
        c.drawCircle(cam.p(s.dx, z), r, sp);
      }
      for (final List<Offset> cr in _cracks) {
        final double z0 = tz + cr.first.dy;
        if (z0 < zn - 4 || z0 > 75) continue;
        final Path p = Path();
        for (int i = 0; i < cr.length; i++) {
          final Offset o = cam.p(cr[i].dx, tz + cr[i].dy);
          i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
        }
        final double k2 = (1 - z0 / 75).clamp(0.0, 1.0);
        cp
          ..strokeWidth = math.max(0.6, 0.05 * cam.s(z0))
          ..color = const Color(0xFF4C4C52).withValues(alpha: 0.55 * k2);
        c.drawPath(p, cp);
        cp
          ..strokeWidth = math.max(0.4, 0.025 * cam.s(z0))
          ..color = const Color(0x55FFFFFF).withValues(alpha: 0.25 * k2);
        c.drawPath(p.shift(const Offset(0.8, 0.8)), cp);
      }
    }
    // edge lines
    final Paint white = Paint()..color = const Color(0xFFF4F2EE);
    _quad(c, cam, -rh + 0.18, -rh + 0.36, zn, zf, white);
    _quad(c, cam, rh - 0.36, rh - 0.18, zn, zf, white);
    // dashed lane lines
    const double dash = 3.2, gap = 5.2;
    final double ph = dist % (dash + gap);
    for (double z = zn - ph; z < 150; z += dash + gap) {
      for (final double lx in <double>[-rh / 3, rh / 3]) {
        _quad(c, cam, lx - 0.09, lx + 0.09, z, z + dash, white);
      }
    }
    // guard rails: posts + double W-beam with metallic gradient
    for (final double side in <double>[-1, 1]) {
      final double x = side * (rh + 0.85);
      final double pph = dist % 3;
      final Paint post = Paint();
      for (double z = 150 - pph; z > zn; z -= 3) {
        final double s = cam.s(z);
        final Offset b = cam.p(x, z), tp = cam.p(x, z, 0.95);
        post
          ..color = const Color(0xFF8A8F98)
          ..strokeWidth = math.max(1, 0.13 * s);
        c.drawLine(b, tp, post);
        post
          ..color = const Color(0xFFCDD2D8)
          ..strokeWidth = math.max(0.5, 0.05 * s);
        c.drawLine(b + Offset(-side * 0.03 * s, 0), tp + Offset(-side * 0.03 * s, 0), post);
      }
      Path beam(double y0, double y1) => Path()
        ..moveTo(cam.sx(x, zn), cam.sy(zn, y0))
        ..lineTo(cam.sx(x, zf), cam.sy(zf, y0))
        ..lineTo(cam.sx(x, zf), cam.sy(zf, y1))
        ..lineTo(cam.sx(x, zn), cam.sy(zn, y1))
        ..close();
      // inner face of the beam (we see the road side of it)
      final double ix = x - side * 0.16;
      final Path face = Path()
        ..moveTo(cam.sx(x, zn), cam.sy(zn, 0.95))
        ..lineTo(cam.sx(x, zf), cam.sy(zf, 0.95))
        ..lineTo(cam.sx(ix, zf), cam.sy(zf, 0.95))
        ..lineTo(cam.sx(ix, zn), cam.sy(zn, 0.95))
        ..close();
      c.drawPath(face, Paint()..color = const Color(0xFFE9ECEF));
      c.drawPath(
          beam(0.55, 0.95),
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, cam.sy(0, 0.95)), Offset(0, cam.sy(0, 0.55)),
                const <Color>[Color(0xFFF7F8FA), Color(0xFFB4BAC2), Color(0xFFDCE0E5), Color(0xFF8E959F)], <double>[0, 0.45, 0.6, 1]));
      c.drawPath(beam(0.52, 0.56), Paint()..color = const Color(0x55000000));
    }
  }

  void _haze(Canvas c, GsCam cam, double t) {
    // atmospheric perspective over the far road
    final Rect r = Rect.fromLTWH(0, cam.hy - 30, cam.w, 120);
    c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter,
              const <Color>[Color(0x00FFF3DC), Color(0x99FFF1DA), Color(0x55FFF0D8), Color(0x00FFF0D8)], <double>[0, 0.28, 0.5, 1]));
    // mirage gleam on the far asphalt
    final double sh = 0.5 + 0.5 * math.sin(t * 1.7);
    final Offset m = Offset(cam.sx(0, 60), cam.sy(60) + 2);
    c.drawOval(
        Rect.fromCenter(center: m, width: cam.s(60) * 7, height: 6 + 3 * sh),
        Paint()
          ..shader = ui.Gradient.radial(m, cam.s(60) * 3.5,
              <Color>[const Color(0xFFDDEEFF).withValues(alpha: 0.35 + 0.2 * sh), const Color(0x00DDEEFF)]));
    // heat shimmer: thin wavering bright lines hugging the horizon
    final Paint hp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int i = 0; i < 6; i++) {
      final double y = cam.hy - 8 + i * 6.5;
      hp.color = const Color(0xFFFFFFFF).withValues(alpha: 0.07 + 0.05 * math.sin(t * 2 + i));
      final Path p = Path()..moveTo(0, y);
      for (double x = 0; x <= cam.w; x += 12) {
        p.lineTo(x, y + math.sin(x * 0.045 + t * (2.4 + i * 0.3) + i) * (1.2 + i * 0.25));
      }
      c.drawPath(p, hp);
    }
  }

  // ======================================================================================== entities
  void _shadow(Canvas c, GsCam cam, double x, double z, double r) {
    if (z < -3.4) return;
    final double s = cam.s(z);
    final Offset o = cam.p(x, z);
    final Rect rr = Rect.fromCenter(center: o + Offset(0.12 * s, 0), width: r * 2 * s, height: r * 0.7 * s);
    c.drawOval(rr, Paint()..shader = ui.Gradient.radial(rr.center, r * s, <Color>[const Color(0x55000000), const Color(0x00000000)]));
  }

  /// Haze tint for far sprites (atmospheric perspective).
  ColorFilter? _hazeFilter(double z, {double flash = 0}) {
    if (flash > 0.05) return ColorFilter.mode(const Color(0xFFFFFFFF).withValues(alpha: (flash * 0.85).clamp(0, 1)), BlendMode.srcATop);
    if (z < 38) return null;
    final double k = ((z - 38) / 55).clamp(0.0, 0.65);
    return ColorFilter.mode(const Color(0xFFF6E8D2).withValues(alpha: k), BlendMode.srcATop);
  }

  Rect _sprite(Canvas c, String key, int frame, Offset foot, double hPx, {double sx = 1, double rot = 0, ColorFilter? filter, double alpha = 1}) {
    final ui.Image? im = GsArt.get(key);
    final double asp = GsArt.aspect(key);
    final double wPx = hPx * asp;
    final Rect dst = Rect.fromLTWH(-wPx / 2, -hPx, wPx, hPx);
    if (im == null) return dst.shift(foot);
    c.save();
    c.translate(foot.dx, foot.dy);
    if (rot != 0) c.rotate(rot);
    if (sx != 1) c.scale(sx, 1);
    _p
      ..colorFilter = filter
      ..color = Color.fromRGBO(255, 255, 255, alpha);
    c.drawImageRect(im, GsArt.frames.containsKey(key) ? GsArt.frame(key, frame) : Rect.fromLTWH(0, 0, im.width.toDouble(), im.height.toDouble()),
        dst, _p);
    _p
      ..colorFilter = null
      ..color = const Color(0xFFFFFFFF);
    c.restore();
    return dst.shift(foot);
  }

  void _prop(Canvas c, GsCam cam, GsProp p) {
    final double s = cam.s(p.z);
    final Offset foot = cam.p(p.x, p.z);
    if (foot.dx < -200 || foot.dx > cam.w + 200) return;
    switch (p.kind) {
      case 0:
        _shadow(c, cam, p.x, p.z, 0.8 * p.scale);
        _sprite(c, 'cactus', 0, foot, 3.4 * p.scale * s, filter: _hazeFilter(p.z));
      case 1:
        _shadow(c, cam, p.x, p.z, 1.1 * p.scale);
        _sprite(c, 'rocks', 0, foot, 1.8 * p.scale * s, filter: _hazeFilter(p.z));
      default:
        // reflective road marker post
        final Offset top = cam.p(p.x, p.z, 1.3);
        c.drawLine(foot, top, Paint()
          ..color = const Color(0xFFF2F2F2)
          ..strokeWidth = math.max(1, 0.12 * s));
        c.drawLine(top, top + Offset(0, 0.25 * s), Paint()
          ..color = const Color(0xFFFF7A1A)
          ..strokeWidth = math.max(1, 0.13 * s));
    }
  }

  void _soldier(Canvas c, GsCam cam, GsSoldier sd, GsEngine e, double t) {
    final double s = cam.s(sd.z);
    final bool idle = e.phase == GsPhase.lobby;
    final double cyc = sd.phase * 2.2;
    final int frame = idle ? 3 : (cyc.floor() % 4);
    final double bob = idle ? math.sin(t * 3 + sd.phase * 6) * 0.03 : (math.sin(cyc * math.pi)).abs() * 0.09;
    final double hPx = 2.45 * e.unitScale * s * (0.4 + 0.6 * _easeOutBack(sd.pop.clamp(0.0, 1.0)));
    final Offset foot = cam.p(sd.x, sd.z, bob);
    final double rot = idle ? 0 : math.sin(cyc * math.pi) * 0.04;
    final Rect r = _sprite(c, 'soldier_run', frame, foot, hPx, rot: rot);
    if (GsArt.get('soldier_run') == null) _fallbackSoldier(c, r, const Color(0xFF2F6BE0));
    if (sd.flash > 0) {
      // muzzle flash at the rifle tip
      final Offset tip = Offset(r.left + r.width * 0.93, r.top + r.height * 0.39);
      _muzzle(c, tip, r.height * 0.22 * (0.6 + sd.flash * 0.6), sd.flash, const Color(0xFF7FF4FF));
    }
  }

  void _muzzle(Canvas c, Offset at, double r, double k, Color tint) {
    final Paint g = Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(at, r * 1.6, <Color>[tint.withValues(alpha: 0.75 * k), tint.withValues(alpha: 0)]);
    c.drawCircle(at, r * 1.6, g);
    final Path star = Path();
    const int n = 8;
    for (int i = 0; i < n * 2; i++) {
      final double a = i * math.pi / n - math.pi / 2;
      final double rr = i.isEven ? r : r * 0.32;
      final Offset o = at + Offset(math.cos(a) * rr, math.sin(a) * rr * 0.8);
      i == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
    }
    star.close();
    c.drawPath(star, Paint()
      ..blendMode = BlendMode.plus
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.85 * k));
  }

  void _fallbackSoldier(Canvas c, Rect r, Color helmet) {
    final Paint p = Paint()..color = const Color(0xFFCDB48A);
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(r.left + r.width * 0.25, r.top + r.height * 0.4, r.width * 0.5, r.height * 0.45),
        Radius.circular(r.width * 0.1)), p);
    c.drawCircle(Offset(r.center.dx, r.top + r.height * 0.28), r.width * 0.36, Paint()..color = helmet);
  }

  void _target(Canvas c, GsCam cam, GsTarget tg, GsEngine e, double t, double bossFlash) {
    final double s = cam.s(tg.z);
    final Offset foot = cam.p(tg.x, tg.z);
    final double wob = tg.wobble > 0 ? math.sin(tg.wobble * 18) * 0.07 * tg.wobble : 0;
    final ColorFilter? f = _hazeFilter(tg.z, flash: tg.flash);
    switch (tg.kind) {
      case GsKind.barrel:
      case GsKind.crate:
        final bool barrel = tg.kind == GsKind.barrel;
        final double hPx = (barrel ? 2.05 : 1.85) * s;
        c.save();
        c.translate(foot.dx, foot.dy);
        c.scale(1 + wob, 1 - wob * 0.6);
        final Rect r = _sprite(c, barrel ? 'barrel' : 'crate', 0, Offset.zero, hPx, filter: f);
        if (GsArt.get(barrel ? 'barrel' : 'crate') == null) {
          c.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(r.width * 0.15)),
              Paint()..color = barrel ? const Color(0xFFD8322A) : const Color(0xFF9C6A38));
        }
        // HP plate number
        final Offset lab = Offset(r.left + r.width * (barrel ? 0.51 : 0.62), r.top + r.height * (barrel ? 0.565 : 0.59));
        final double fs = math.max(7, hPx * (barrel ? 0.2 : 0.17));
        label(c, gsFa(tg.hp.ceil()), lab, fs, const Color(0xFF223047), outline: const Color(0xCCFFFFFF), ow: 0.12);
        c.restore();
      case GsKind.enemy:
        final double hPx = 2.2 * s;
        final int frame = ((tg.phase * 6).floor()) % 4;
        final double bob = (math.sin(tg.phase * 6 * math.pi / 2)).abs() * 0.06;
        final Rect r = _sprite(c, 'enemy_walk', frame, cam.p(tg.x, tg.z, bob), hPx, rot: wob * 2, filter: f);
        if (GsArt.get('enemy_walk') == null) _fallbackSoldier(c, r, const Color(0xFFD23A33));
        if (tg.hp < tg.maxHp && tg.z < 60) {
          final Rect bar = Rect.fromCenter(center: Offset(r.center.dx, r.top - 0.12 * s), width: 0.9 * s, height: math.max(2.5, 0.12 * s));
          c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(3)), Paint()..color = const Color(0xAA1A0F14));
          c.drawRRect(
              RRect.fromRectAndRadius(Rect.fromLTWH(bar.left, bar.top, bar.width * (tg.hp / tg.maxHp).clamp(0, 1), bar.height), const Radius.circular(3)),
              Paint()..color = const Color(0xFFFF4B4B));
        }
      case GsKind.boss:
        final double hPx = 6.2 * s;
        final double stomp = tg.z <= 7 ? math.max(0, math.sin(tg.phase * 5)) * 0.15 : (math.sin(tg.phase * 4)).abs() * 0.12;
        // menacing red ground glow
        final Offset fo = cam.p(tg.x, tg.z);
        c.drawOval(Rect.fromCenter(center: fo, width: 6 * s, height: 1.6 * s),
            Paint()..shader = ui.Gradient.radial(fo, 3 * s, <Color>[const Color(0x66FF3B1E), const Color(0x00FF3B1E)]));
        final Rect r = _sprite(c, 'boss', 0, cam.p(tg.x, tg.z, stomp), hPx, rot: wob, filter: f);
        if (GsArt.get('boss') == null) _fallbackSoldier(c, r, const Color(0xFF7A1E1E));
        if (bossFlash > 0) {
          _muzzle(c, Offset(r.left + r.width * 0.66, r.top + r.height * 0.44), r.height * 0.12, bossFlash, const Color(0xFFFF8A3A));
        }
        // visor glow pulse
        final Offset visor = Offset(r.left + r.width * 0.5, r.top + r.height * 0.155);
        c.drawCircle(visor, r.width * 0.12,
            Paint()
              ..blendMode = BlendMode.plus
              ..shader = ui.Gradient.radial(visor, r.width * 0.12,
                  <Color>[const Color(0xFFFF9A2A).withValues(alpha: 0.35 + 0.25 * math.sin(t * 6)), const Color(0x00FF9A2A)]));
    }
  }

  void _gate(Canvas c, GsCam cam, GsGate g, double t) {
    final double s = cam.s(g.z);
    const double h = 2.9;
    for (int i = 0; i < g.sides.length; i++) {
      final GsGateSide sd = g.sides[i];
      final bool chosen = g.passed && g.chosen == i;
      final double alpha = g.passed ? (chosen ? (1 - g.fade) : (1 - g.fade) * 0.5) : 1;
      if (alpha <= 0.01) continue;
      final Color a = sd.good ? const Color(0xFF2E9BFF) : const Color(0xFFFF3B4A);
      final Color b = sd.good ? const Color(0xFF66E0FF) : const Color(0xFFFF8A5A);
      final double x0 = sd.x0 + 0.12, x1 = sd.x1 - 0.12;
      final Rect r = Rect.fromLTRB(cam.sx(x0, g.z), cam.sy(g.z, h), cam.sx(x1, g.z), cam.sy(g.z));
      // glass panel
      c.drawRect(
          r,
          Paint()
            ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, <Color>[
              a.withValues(alpha: (0.72 + sd.flash * 0.2) * alpha),
              b.withValues(alpha: 0.32 * alpha),
              a.withValues(alpha: 0.5 * alpha),
            ], <double>[0, 0.6, 1]));
      // diagonal shine stripes
      c.save();
      c.clipRect(r);
      final Paint shine = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: 0.16 * alpha);
      final double sw = r.width * 0.12;
      final double drift = (t * 0.25 % 1) * r.width;
      for (double x = r.left - r.height + drift - r.width; x < r.right; x += r.width * 0.55) {
        final Path p = Path()
          ..moveTo(x, r.bottom)
          ..lineTo(x + sw, r.bottom)
          ..lineTo(x + sw + r.height * 0.6, r.top)
          ..lineTo(x + r.height * 0.6, r.top)
          ..close();
        c.drawPath(p, shine);
      }
      c.restore();
      if (chosen) {
        c.drawRect(r.inflate(4 * (1 - g.fade)),
            Paint()
              ..blendMode = BlendMode.plus
              ..color = b.withValues(alpha: 0.5 * (1 - g.fade)));
      }
      // frame: glowing rim + chunky posts and top bar
      final double pw = math.max(2, 0.2 * s);
      c.drawRect(r.inflate(pw * 0.8),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = pw * 1.6
            ..color = b.withValues(alpha: 0.35 * alpha));
      final Paint post = Paint()
        ..shader = ui.Gradient.linear(Offset(r.left - pw, 0), Offset(r.left + pw, 0),
            <Color>[const Color(0xFFFFFFFF).withValues(alpha: alpha), a.withValues(alpha: alpha)]);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.left - pw, r.top - pw, r.left + pw * 0.4, r.bottom), Radius.circular(pw)), post);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(r.right - pw * 0.4, r.top - pw, r.right + pw, r.bottom), Radius.circular(pw)), post);
      final Rect bar = Rect.fromLTRB(r.left - pw, r.top - pw * 1.6, r.right + pw, r.top + pw * 0.6);
      c.drawRRect(
          RRect.fromRectAndRadius(bar, Radius.circular(pw)),
          Paint()
            ..shader = ui.Gradient.linear(bar.topCenter, bar.bottomCenter,
                <Color>[const Color(0xFFFFFFFF).withValues(alpha: alpha), a.withValues(alpha: alpha)]));
      // caption + icon
      final double bump = 1 + 0.35 * sd.bump;
      final double fs = math.max(8, 0.95 * s) * bump;
      final Offset cc = Offset(r.center.dx, r.top + r.height * 0.36);
      if (alpha > 0.3) {
        label(c, GsEngine.gateLabel(sd), cc, fs, const Color(0xFFFFFFFF), outline: (sd.good ? const Color(0xFF0B3C86) : const Color(0xFF7A0F1A)), ow: 0.18);
        _gateIcon(c, sd, Offset(r.center.dx, r.top + r.height * 0.7), fs * 0.62, alpha);
      }
    }
  }

  void _gateIcon(Canvas c, GsGateSide sd, Offset at, double size, double alpha) {
    String? key;
    String? word;
    switch (sd.op) {
      case GateOp.add:
      case GateOp.sub:
      case GateOp.mul:
        key = 'recruit';
        word = 'سرباز';
      case GateOp.power:
        word = 'قدرت';
      case GateOp.rate:
        key = 'bullet';
        word = 'سرعت';
      case GateOp.heal:
        key = 'medkit';
        word = 'جان';
    }
    if (key != null && GsArt.get(key) != null) {
      _sprite(c, key, 0, at + Offset(size * 0.9, size * 0.5), size * 1.05, alpha: alpha);
      label(c, word, at + Offset(-size * 0.45, 0), size * 0.62, const Color(0xFFFFFFFF), outline: const Color(0xAA0A1430), ow: 0.16);
    } else {
      label(c, word, at, size * 0.7, const Color(0xFFFFFFFF), outline: const Color(0xAA0A1430), ow: 0.16);
    }
  }

  // ======================================================================================== bullets
  void _bullets(Canvas c, GsCam cam, GsEngine e) {
    final Paint glow = Paint()
      ..blendMode = BlendMode.plus
      ..strokeCap = StrokeCap.round;
    final Paint core = Paint()..strokeCap = StrokeCap.round;
    for (final GsBullet b in e.bullets) {
      if (b.z < -2.5) continue;
      if (!b.enemy) {
        final double y = b.y * e.unitScale;
        final double tailZ = math.max(-2.5, b.z - 3.2);
        final Offset head = cam.p(b.x, b.z, y);
        final Offset tail = cam.p(b.x - b.vx * 0.045, tailZ, y);
        final double s = cam.s(b.z);
        glow
          ..shader = ui.Gradient.linear(tail, head, const <Color>[Color(0x0022C8FF), Color(0xAA2AD8FF)])
          ..strokeWidth = math.max(2, 0.34 * s);
        c.drawLine(tail, head, glow);
        glow.shader = null;
        core
          ..color = const Color(0xFFEFFFFF)
          ..strokeWidth = math.max(1.2, 0.12 * s);
        c.drawLine(Offset.lerp(tail, head, 0.55)!, head, core);
        glow.color = const Color(0x6640E6FF);
        c.drawCircle(head, math.max(2, 0.3 * s), glow);
      } else {
        final Offset head = cam.p(b.x, b.z, b.y);
        final Offset tail = cam.p(b.x - b.vx * 0.06, b.z + 1.6, b.y);
        final double s = cam.s(b.z);
        final double r = (b.big ? 0.32 : 0.22) * s;
        glow
          ..shader = ui.Gradient.linear(tail, head, const <Color>[Color(0x00FF3A1E), Color(0xAAFF5A1E)])
          ..strokeWidth = math.max(2, r * 1.5);
        c.drawLine(tail, head, glow);
        glow.shader = ui.Gradient.radial(head, r * 2.2, const <Color>[Color(0xCCFFB23A), Color(0x00FF3A1E)]);
        c.drawCircle(head, r * 2.2, glow);
        glow.shader = null;
        c.drawCircle(head, math.max(1.5, r * 0.6), core..color = const Color(0xFFFFF4D6));
      }
    }
  }

  // ======================================================================================== particles
  void _particles(Canvas c, GsCam cam, GsParticles fx, {required bool back}) {
    final Paint p = Paint();
    for (final GsPart q in fx.parts) {
      if (q.z < -3.3 || q.kind == GsPk.flash) continue;
      final double k = (q.life / q.max).clamp(0.0, 1.0);
      final double s = cam.s(q.z);
      final Offset o = cam.p(q.x, q.z, q.y);
      switch (q.kind) {
        case GsPk.fire:
          final double r = q.size * s * 0.5;
          p
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(o, r, <Color>[
              const Color(0xFFFFF6C8).withValues(alpha: 0.9 * k),
              q.color.withValues(alpha: 0.7 * k),
              const Color(0x00B8200A),
            ], <double>[0, 0.45, 1]);
          c.drawCircle(o, r, p);
          p
            ..shader = null
            ..blendMode = BlendMode.srcOver;
        case GsPk.smoke:
        case GsPk.dust:
          final double r = q.size * s * 0.5;
          final double a = q.kind == GsPk.smoke ? 0.55 * k : 0.5 * k;
          p.shader = ui.Gradient.radial(o.translate(-r * 0.2, -r * 0.2), r, <Color>[
            Color.lerp(q.color, const Color(0xFFFFFFFF), 0.25)!.withValues(alpha: a),
            q.color.withValues(alpha: a * 0.6),
            q.color.withValues(alpha: 0),
          ], <double>[0, 0.6, 1]);
          c.drawCircle(o, r, p);
          p.shader = null;
        case GsPk.spark:
        case GsPk.ember:
          final Offset tail = cam.p(q.x - q.vx * 0.03, q.z - q.vz * 0.03, q.y - q.vy * 0.03);
          p
            ..blendMode = BlendMode.plus
            ..color = q.color.withValues(alpha: k)
            ..strokeWidth = math.max(1, q.size * s)
            ..strokeCap = StrokeCap.round;
          c.drawLine(tail, o, p);
          p.blendMode = BlendMode.srcOver;
        case GsPk.debris:
          c.save();
          c.translate(o.dx, o.dy);
          c.rotate(q.rot);
          final double sz = q.size * s;
          final Rect r = Rect.fromCenter(center: Offset.zero, width: sz * q.w, height: sz);
          p.color = q.color.withValues(alpha: math.min(1, k * 2.5));
          c.drawRect(r, p);
          p.color = const Color(0xFFFFFFFF).withValues(alpha: 0.25 * math.min(1, k * 2.5));
          c.drawRect(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.35), p);
          c.restore();
        case GsPk.ring:
          final Rect r = Rect.fromCenter(center: o, width: q.size * 2 * s, height: q.size * 0.7 * s);
          p
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1, 0.25 * s * k)
            ..color = q.color.withValues(alpha: 0.8 * k);
          c.drawOval(r, p);
          p
            ..style = PaintingStyle.fill
            ..color = const Color(0xFF2A1A10).withValues(alpha: 0.25 * k);
          c.drawOval(r.deflate(r.height * 0.15), p);
        case GsPk.flash:
          break;
      }
    }
  }

  void _particlesFlash(Canvas c, GsCam cam, GsParticles fx) {
    for (final GsPart q in fx.parts) {
      if (q.kind != GsPk.flash) continue;
      final double k = (q.life / q.max).clamp(0.0, 1.0);
      final double s = cam.s(q.z);
      final Offset o = cam.p(q.x, q.z, q.y);
      final double r = q.size * s * (1.2 - k * 0.4);
      c.drawCircle(o, r,
          Paint()
            ..blendMode = BlendMode.plus
            ..shader = ui.Gradient.radial(o, r, <Color>[q.color.withValues(alpha: k), q.color.withValues(alpha: 0)]));
    }
  }

  void _hurtVignette(Canvas c, Size size, double k) {
    final Rect r = Offset.zero & size;
    c.drawRect(
        r,
        Paint()
          ..shader = ui.Gradient.radial(r.center, size.longestSide * 0.62,
              <Color>[const Color(0x00FF0000), const Color(0xFFE0102A).withValues(alpha: 0.55 * k.clamp(0, 1))], <double>[0.55, 1]));
  }
}

double _easeOutBack(double t) {
  const double c1 = 1.70158, c3 = c1 + 1;
  final double u = t - 1;
  return 1 + c3 * u * u * u + c1 * u * u;
}

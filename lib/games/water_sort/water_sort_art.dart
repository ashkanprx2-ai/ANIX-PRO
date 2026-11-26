import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// ===================== WATER SORT — ART =====================
/// Everything the water sort board paints: the moonlit desert stage (a painted backdrop with
/// live stars, halo, fireflies and shooting stars on top), glass test tubes with refraction,
/// specular strips and a lipped rim, and glossy layered liquids that stay level under gravity
/// while a tube tilts (the bands are solved by area, so volume is conserved mid-pour).
/// =============================================================

/// Neon liquid palette (12 colours, tuned to stay distinct for colour-blind-ish contrast pairs).
const List<Color> kWsColors = <Color>[
  Color(0xFF8B2CFF), // violet
  Color(0xFF1F7BFF), // blue
  Color(0xFFFF7417), // orange
  Color(0xFFFFD21C), // yellow
  Color(0xFF24D24A), // green
  Color(0xFFFF2E4F), // red
  Color(0xFFFF4FD2), // pink
  Color(0xFF1EE6FF), // cyan
  Color(0xFFB8FF2E), // lime
  Color(0xFF9C5A2C), // cocoa
  Color(0xFFE9ECFA), // pearl
  Color(0xFFA0124F), // wine
];

const Color kWsMystery = Color(0xFF2B2346);

/// Painted assets (decoded once, shared by every board instance).
class WsArt {
  WsArt._();
  static ui.Image? bg;
  static ui.Image? cork;
  static Future<void>? _loading;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    Future<ui.Image?> one(String path) async {
      try {
        final ByteData d = await rootBundle.load(path);
        final ui.Codec c = await ui.instantiateImageCodec(d.buffer.asUint8List());
        return (await c.getNextFrame()).image;
      } catch (_) {
        return null;
      }
    }

    bg = await one('assets/games/water_sort/bg.webp');
    cork = await one('assets/games/water_sort/cork.webp');
  }
}

/// One coloured band inside a tube (amount may be fractional while pouring).
class WsSeg {
  WsSeg(this.color, this.amount, {this.hidden = false});
  final int color;
  double amount;
  final bool hidden;
}

/// A rising bubble inside a tube, in tube units (x: -0.5..0.5 of the width, y: units from the bottom).
class WsBubble {
  WsBubble(this.x, this.y, this.r, this.v);
  double x;
  double y;
  final double r;
  final double v;
}

/// Tube dimensions. Local space: origin at the mouth centre, +y down the tube axis.
class WsGeom {
  WsGeom(this.w) : len = w * 4.3;
  final double w;
  final double len;
  double get u => len * 0.205; // one unit of liquid
  double get r => w / 2;
  double get glass => math.max(1.6, w * 0.07);

  Path interior() {
    final double h = w / 2;
    return Path()
      ..moveTo(-h, 0)
      ..lineTo(-h, len - h)
      ..arcToPoint(Offset(h, len - h), radius: Radius.circular(h), clockwise: false)
      ..lineTo(h, 0)
      ..close();
  }

  List<Offset> polygon() {
    final double h = w / 2;
    final List<Offset> p = <Offset>[Offset(-h, 0), Offset(-h, len - h)];
    for (int i = 1; i < 12; i++) {
      final double a = math.pi - math.pi * i / 12;
      p.add(Offset(math.cos(a) * h, len - h + math.sin(a) * h));
    }
    p
      ..add(Offset(h, len - h))
      ..add(Offset(h, 0));
    return p;
  }
}

/// Area of [poly] where y >= [h] (Sutherland–Hodgman clip + shoelace).
double wsAreaBelow(List<Offset> poly, double h) {
  final List<Offset> out = <Offset>[];
  for (int i = 0; i < poly.length; i++) {
    final Offset a = poly[i];
    final Offset b = poly[(i + 1) % poly.length];
    final bool ia = a.dy >= h;
    final bool ib = b.dy >= h;
    if (ia) out.add(a);
    if (ia != ib) {
      final double t = (h - a.dy) / (b.dy - a.dy);
      out.add(Offset(a.dx + (b.dx - a.dx) * t, h));
    }
  }
  double s = 0;
  for (int i = 0; i < out.length; i++) {
    final Offset a = out[i];
    final Offset b = out[(i + 1) % out.length];
    s += a.dx * b.dy - b.dx * a.dy;
  }
  return s.abs() / 2;
}

class WsPainter {
  WsPainter._();

  static final Paint _p = Paint();
  static final Map<int, TextPainter> _q = <int, TextPainter>{};

  // ------------------------------------------------------------------ stage

  /// Where the painted moon sits in the backdrop image (fraction of image size).
  static const Offset _moonFrac = Offset(0.5, 0.497);

  /// Draws the backdrop (cover-fit, slow breathing parallax) and returns the image's on-screen rect
  /// (used to line up the refraction inside the glass), or null when the art is not loaded.
  static Rect? stage(Canvas canvas, Size size, double t, {bool animate = true}) {
    final Rect screen = Offset.zero & size;
    final ui.Image? img = WsArt.bg;
    Offset moon = Offset(size.width * 0.5, size.height * 0.5);
    double moonR = size.width * 0.13;
    Rect? imgRect;
    if (img != null) {
      final double iw = img.width.toDouble();
      final double ih = img.height.toDouble();
      final double s = math.max(size.width / iw, size.height / ih) * (1.04 + (animate ? math.sin(t * 0.13) * 0.012 : 0));
      final double dw = iw * s;
      final double dh = ih * s;
      final Offset o = Offset((size.width - dw) / 2 + (animate ? math.sin(t * 0.09) * 4 : 0), (size.height - dh) / 2);
      canvas.drawImageRect(img, Rect.fromLTWH(0, 0, iw, ih), Rect.fromLTWH(o.dx, o.dy, dw, dh),
          _p..filterQuality = FilterQuality.medium);
      moon = Offset(o.dx + dw * _moonFrac.dx, o.dy + dh * _moonFrac.dy);
      imgRect = Rect.fromLTWH(o.dx, o.dy, dw, dh);
      moonR = dw * 0.105;
    } else {
      canvas.drawRect(
          screen,
          Paint()
            ..shader = ui.Gradient.linear(screen.topCenter, screen.bottomCenter,
                const <Color>[Color(0xFF1A0B3D), Color(0xFF3A1773), Color(0xFF1B0A36)], <double>[0, 0.55, 1]));
    }
    // Breathing halo around the moon.
    final double pulse = 0.5 + 0.5 * math.sin(t * 0.8);
    canvas.drawCircle(
        moon,
        moonR * (3.2 + pulse * 0.25),
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.radial(moon, moonR * (3.2 + pulse * 0.25), <Color>[
            const Color(0xFFE7C9FF).withValues(alpha: 0.22 + pulse * 0.06),
            const Color(0xFF9B4DFF).withValues(alpha: 0.10),
            const Color(0x00000000),
          ], <double>[0.2, 0.5, 1]));
    // Slow god-rays from the moon.
    if (animate) {
      for (int i = 0; i < 7; i++) {
        final double a = t * 0.05 + i * math.pi * 2 / 7;
        final Path ray = Path()
          ..moveTo(moon.dx, moon.dy)
          ..lineTo(moon.dx + math.cos(a - 0.07) * size.height, moon.dy + math.sin(a - 0.07) * size.height)
          ..lineTo(moon.dx + math.cos(a + 0.07) * size.height, moon.dy + math.sin(a + 0.07) * size.height)
          ..close();
        canvas.drawPath(
            ray,
            Paint()
              ..blendMode = BlendMode.plus
              ..shader = ui.Gradient.radial(moon, size.height * 0.6,
                  <Color>[const Color(0x18C9A0FF), const Color(0x00000000)]));
      }
    }
    // Twinkling stars over the sky.
    final math.Random rnd = math.Random(11);
    for (int i = 0; i < 70; i++) {
      final Offset s = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height * 0.45);
      final double ph = rnd.nextDouble() * 6.28;
      final double sp = 0.8 + rnd.nextDouble() * 2.2;
      final double k = animate ? (0.5 + 0.5 * math.sin(t * sp + ph)) : 0.6;
      final double r = 0.5 + rnd.nextDouble() * 1.3;
      canvas.drawCircle(s, r * (0.7 + k * 0.6), _p..color = Colors.white.withValues(alpha: 0.25 + k * 0.6));
      if (r > 1.5 && k > 0.75) {
        final Paint cross = Paint()
          ..color = Colors.white.withValues(alpha: (k - 0.75) * 2.4)
          ..strokeWidth = 0.8;
        canvas.drawLine(s - Offset(r * 4, 0), s + Offset(r * 4, 0), cross);
        canvas.drawLine(s - Offset(0, r * 4), s + Offset(0, r * 4), cross);
      }
    }
    if (!animate) return imgRect;
    // Shooting star every ~9 s.
    final double cyc = t % 9.0;
    if (cyc < 0.9) {
      final int n = (t / 9.0).floor();
      final math.Random sr = math.Random(n * 31 + 7);
      final Offset a = Offset(size.width * (0.15 + sr.nextDouble() * 0.7), size.height * (0.04 + sr.nextDouble() * 0.2));
      final double k = cyc / 0.9;
      final Offset head = a + Offset(-size.width * 0.35 * k, size.height * 0.12 * k);
      final Offset tail = head + Offset(size.width * 0.12, -size.height * 0.04);
      canvas.drawLine(
          tail,
          head,
          Paint()
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round
            ..shader = ui.Gradient.linear(tail, head, <Color>[const Color(0x00FFFFFF), Colors.white.withValues(alpha: 1 - k)]));
      canvas.drawCircle(head, 2.2, _p..color = Colors.white.withValues(alpha: 1 - k));
    }
    // Fireflies / magic dust drifting up from the dunes.
    final math.Random fr = math.Random(5);
    for (int i = 0; i < 26; i++) {
      final double x0 = fr.nextDouble() * size.width;
      final double sp = 10 + fr.nextDouble() * 22;
      final double ph = fr.nextDouble() * 100;
      final double y = size.height - ((t * sp + ph * 13) % (size.height * 0.75));
      final double x = x0 + math.sin(t * 0.7 + ph) * 18;
      final double k = 0.5 + 0.5 * math.sin(t * 2.3 + ph);
      final Color c = i.isEven ? const Color(0xFFE3B8FF) : const Color(0xFFFFD6F5);
      canvas.drawCircle(Offset(x, y), 4 + k * 3,
          Paint()..shader = ui.Gradient.radial(Offset(x, y), 4 + k * 3, <Color>[c.withValues(alpha: 0.35 * k), const Color(0x00000000)]));
      canvas.drawCircle(Offset(x, y), 1.1, _p..color = c.withValues(alpha: 0.6 + 0.4 * k));
    }
    // Ground haze.
    final Rect fog = Rect.fromLTWH(0, size.height * 0.72, size.width, size.height * 0.28);
    canvas.drawRect(
        fog,
        Paint()
          ..shader = ui.Gradient.linear(fog.topCenter, fog.bottomCenter, <Color>[
            const Color(0x00140828),
            Color.lerp(const Color(0x55220E44), const Color(0x66311560), 0.5 + 0.5 * math.sin(t * 0.4))!,
          ]));
    return imgRect;
  }

  /// Glass shelf under a row of tubes, with a soft reflection of their liquids.
  static void shelf(Canvas canvas, Rect r, double t) {
    final RRect rr = RRect.fromRectAndRadius(r, Radius.circular(r.height / 2));
    canvas.drawRRect(
        rr.shift(const Offset(0, 8)),
        Paint()
          ..color = const Color(0x99080214)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10));
    canvas.drawRRect(
        rr,
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter,
              const <Color>[Color(0x66D6B8FF), Color(0x332C1060), Color(0x55190838)], <double>[0, 0.45, 1]));
    canvas.drawRRect(
        rr,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..shader = ui.Gradient.linear(r.centerLeft, r.centerRight, <Color>[
            const Color(0x22FFFFFF),
            const Color(0xCCF2E2FF),
            const Color(0x22FFFFFF),
          ], <double>[0, 0.5 + 0.35 * math.sin(t * 0.6), 1]));
    // Neon underlight.
    canvas.drawRRect(
        rr.shift(const Offset(0, 3)),
        Paint()
          ..color = const Color(0x557A3CFF)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
  }

  /// Faded mirror image of a tube's liquid on the shelf (bottom colours first, fading out).
  static void reflection(Canvas canvas, Offset mouth, WsGeom g, List<WsSeg> segs, double shelfY) {
    if (segs.isEmpty) return;
    final double depth = g.u * 1.6;
    final List<Color> cs = <Color>[];
    final List<double> st = <double>[];
    double y = 0;
    for (final WsSeg s in segs) {
      final Color c = s.hidden ? kWsMystery : kWsColors[s.color];
      final double y0 = y / depth;
      y += s.amount * g.u * 0.6;
      final double y1 = math.min(1.0, y / depth);
      cs
        ..add(c.withValues(alpha: 0.32 * (1 - y0)))
        ..add(c.withValues(alpha: 0.32 * (1 - y1)));
      st
        ..add(math.min(1.0, y0))
        ..add(y1);
      if (y >= depth) break;
    }
    if (st.last < 1) {
      cs.add(const Color(0x00000000));
      st.add(1);
    }
    final Rect r = Rect.fromLTWH(mouth.dx - g.w * 0.4, shelfY + 1, g.w * 0.8, depth);
    canvas.drawRRect(
        RRect.fromRectAndCorners(r, bottomLeft: Radius.circular(g.w * 0.4), bottomRight: Radius.circular(g.w * 0.4)),
        Paint()
          ..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, cs, st)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
  }

  // ------------------------------------------------------------------ tube

  /// Paints one tube. [mouth] is the world position of the mouth centre, [angle] the tilt (radians,
  /// clockwise). [segs] are bottom → top. [corkT] < 0 hides the cork, 0..1 animates it dropping in.
  static void tube(
    Canvas canvas, {
    required Offset mouth,
    required double angle,
    required WsGeom g,
    required List<WsSeg> segs,
    required double t,
    double wave = 0,
    double selected = 0,
    double corkT = -1,
    double scale = 1,
    List<WsBubble>? bubbles,
    Rect? refractRect,
    Color accent = const Color(0xFFE6C4FF),
  }) {
    if (scale <= 0.01) return;
    final double w = g.w;
    final Path local = g.interior();
    final bool upright = angle.abs() < 0.002;
    final Matrix4 m = Matrix4.identity()
      ..translateByDouble(mouth.dx, mouth.dy, 0, 1)
      ..rotateZ(angle)
      ..scaleByDouble(scale, scale, 1, 1);
    final Path world = local.transform(m.storage);
    final List<Offset> poly = <Offset>[
      for (final Offset p in g.polygon()) MatrixUtils.transformPoint(m, p),
    ];
    final double total = segs.fold(0.0, (double a, WsSeg s) => a + s.amount);
    final Color? topColor = segs.isEmpty ? null : (segs.last.hidden ? kWsMystery : kWsColors[segs.last.color]);

    // 1. Ambient glow of the liquid + selection aura.
    canvas.save();
    canvas.transform(m.storage);
    if (topColor != null) {
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.55, g.len - g.u * total - w * 0.2, w * 1.1, g.u * total + w * 0.35),
              Radius.circular(w * 0.5)),
          Paint()
            ..color = topColor.withValues(alpha: 0.30)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.45));
    }
    if (selected > 0.01) {
      canvas.drawPath(
          local,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = w * 0.22
            ..color = accent.withValues(alpha: 0.55 * selected)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.18));
    }
    // 2. Back wall of the glass.
    canvas.drawPath(
        local,
        Paint()
          ..shader = ui.Gradient.linear(Offset(-w / 2, 0), Offset(w / 2, 0), const <Color>[
            Color(0x30E8D8FF),
            Color(0x0EFFFFFF),
            Color(0x08FFFFFF),
            Color(0x26CBB4FF),
          ], <double>[0, 0.35, 0.7, 1]));
    canvas.restore();

    // 3. Refraction: the scene behind, mirrored and magnified inside the empty glass.
    final ui.Image? bg = WsArt.bg;
    if (upright && bg != null && refractRect != null) {
      final Rect wr = world.getBounds();
      canvas.save();
      canvas.clipPath(world);
      canvas.translate(wr.center.dx, 0);
      canvas.scale(-1, 1);
      canvas.translate(-wr.center.dx, 0);
      // Map the tube's screen rect into image space (refractRect is the image's on-screen rect).
      final double sx = bg.width / refractRect.width;
      final double sy = bg.height / refractRect.height;
      final Rect src = Rect.fromLTRB(
        (wr.left - refractRect.left) * sx,
        (wr.top - refractRect.top) * sy,
        (wr.right - refractRect.left) * sx,
        (wr.bottom - refractRect.top) * sy,
      ).deflate(wr.width * sx * 0.18);
      canvas.drawImageRect(bg, src, wr, Paint()..color = const Color(0x55FFFFFF));
      canvas.restore();
    }

    // 4. Liquid bands, level under gravity.
    double liquidTop = double.infinity;
    if (segs.isNotEmpty && total > 0.001) {
      final List<double> ys = <double>[];
      double acc = 0;
      final List<Offset> lp = g.polygon();
      final Rect pb = world.getBounds();
      double levelY(double units) {
        final double localY = g.len - units * g.u;
        if (upright) return mouth.dy + localY * scale;
        final double target = wsAreaBelow(lp, localY) * scale * scale;
        double lo = pb.top;
        double hi = pb.bottom;
        for (int i = 0; i < 22; i++) {
          final double mid = (lo + hi) / 2;
          if (wsAreaBelow(poly, mid) > target) {
            lo = mid;
          } else {
            hi = mid;
          }
        }
        return (lo + hi) / 2;
      }

      ys.add(levelY(0));
      for (final WsSeg s in segs) {
        acc += s.amount;
        ys.add(levelY(acc));
      }
      liquidTop = ys.last;
      canvas.save();
      canvas.clipPath(world);
      final double left = pb.left - 4;
      final double right = pb.right + 4;
      // Wavy surface line.
      final double amp = wave + 0.6;
      double surf(double x) =>
          liquidTop + math.sin(x * 0.22 + t * 7.5) * amp * 0.9 + math.sin(x * 0.11 - t * 4.3) * amp * 0.6;
      Path topPath(double yb) {
        final Path p = Path()..moveTo(left, yb);
        for (double x = left; x <= right + 0.1; x += 3) {
          p.lineTo(x, surf(x));
        }
        p
          ..lineTo(right, yb)
          ..close();
        return p;
      }

      for (int i = 0; i < segs.length; i++) {
        final WsSeg s = segs[i];
        if (s.amount <= 0.001) continue;
        final double yb = ys[i] + 0.5;
        final double yt = ys[i + 1];
        final Color c = s.hidden ? kWsMystery : kWsColors[s.color];
        final Paint fill = Paint()
          ..shader = ui.Gradient.linear(Offset(0, yt), Offset(0, yb), <Color>[
            Color.lerp(c, Colors.white, 0.16)!,
            c,
            Color.lerp(c, Colors.black, 0.22)!,
          ], <double>[0, 0.45, 1]);
        if (i == segs.length - 1) {
          canvas.drawPath(topPath(yb), fill);
        } else {
          canvas.drawRect(Rect.fromLTRB(left, yt, right, yb), fill);
          // Soft seam between layers.
          canvas.drawRect(Rect.fromLTRB(left, yt - 0.6, right, yt + 1.4),
              _p..color = Color.lerp(c, Colors.white, 0.35)!.withValues(alpha: 0.55));
        }
        if (s.hidden && upright && yb - yt > g.u * 0.6) {
          _question(canvas, Offset(mouth.dx, (yt + yb) / 2), g.u * 0.55);
        }
      }
      // Meniscus: a lit ellipse of the top colour plus a crisp highlight along the wave.
      final Color tc = topColor!;
      final Path men = Path()..moveTo(left, surf(left));
      for (double x = left; x <= right + 0.1; x += 3) {
        men.lineTo(x, surf(x));
      }
      for (double x = right; x >= left - 0.1; x -= 3) {
        men.lineTo(x, surf(x) + g.u * 0.16);
      }
      men.close();
      canvas.drawPath(
          men,
          Paint()
            ..shader = ui.Gradient.linear(Offset(0, liquidTop), Offset(0, liquidTop + g.u * 0.16),
                <Color>[Color.lerp(tc, Colors.white, 0.55)!, Color.lerp(tc, Colors.white, 0.12)!]));
      final Path hl = Path()..moveTo(left, surf(left));
      for (double x = left; x <= right + 0.1; x += 3) {
        hl.lineTo(x, surf(x));
      }
      canvas.drawPath(
          hl,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3
            ..color = Colors.white.withValues(alpha: 0.75));

      // Bubbles.
      if (bubbles != null && upright) {
        for (final WsBubble b in bubbles) {
          final Offset at = Offset(mouth.dx + b.x * w * scale, mouth.dy + (g.len - b.y * g.u) * scale);
          if (at.dy < liquidTop + 3) continue;
          canvas.drawCircle(at, b.r, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.9
            ..color = Colors.white.withValues(alpha: 0.55));
          canvas.drawCircle(at - Offset(b.r * 0.35, b.r * 0.35), b.r * 0.3, _p..color = Colors.white.withValues(alpha: 0.8));
        }
      }
      canvas.restore();

      // Cylinder shading over the liquid only (local space, clipped below the surface).
      canvas.save();
      canvas.clipPath(world);
      canvas.clipRect(Rect.fromLTRB(pb.left - 2, liquidTop - wave - 1.5, pb.right + 2, pb.bottom + 2));
      canvas.transform(m.storage);
      canvas.drawRect(
          Rect.fromLTWH(-w / 2, 0, w, g.len),
          Paint()
            ..shader = ui.Gradient.linear(Offset(-w / 2, 0), Offset(w / 2, 0), const <Color>[
              Color(0x73000000),
              Color(0x1A000000),
              Color(0x4DFFFFFF),
              Color(0x0DFFFFFF),
              Color(0x00000000),
              Color(0x33000000),
              Color(0x80000000),
            ], <double>[0, 0.16, 0.3, 0.42, 0.66, 0.86, 1]));
      canvas.restore();
    }

    // 5. Front glass: rim, specular strips, outline, lip.
    canvas.save();
    canvas.transform(m.storage);
    final double gl = g.glass;
    final Path outer = Path()
      ..moveTo(-w / 2 - gl, 0)
      ..lineTo(-w / 2 - gl, g.len - w / 2)
      ..arcToPoint(Offset(w / 2 + gl, g.len - w / 2), radius: Radius.circular(w / 2 + gl), clockwise: false)
      ..lineTo(w / 2 + gl, 0);
    canvas.drawPath(
        outer,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = gl * 1.1
          ..shader = ui.Gradient.linear(Offset(-w / 2, 0), Offset(w / 2, 0), const <Color>[
            Color(0xCCFFFFFF),
            Color(0x55E9DBFF),
            Color(0x40D7C4FF),
            Color(0x99F4ECFF),
          ], <double>[0, 0.3, 0.7, 1]));
    canvas.drawPath(
        local,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = const Color(0x40FFFFFF));
    // Long specular strip on the left.
    final Rect strip = Rect.fromLTRB(-w * 0.36, g.len * 0.07, -w * 0.2, g.len - w * 0.55);
    canvas.drawRRect(
        RRect.fromRectAndRadius(strip, Radius.circular(w * 0.08)),
        Paint()
          ..shader = ui.Gradient.linear(strip.topCenter, strip.bottomCenter, const <Color>[
            Color(0x00FFFFFF),
            Color(0xB3FFFFFF),
            Color(0x40FFFFFF),
            Color(0x99FFFFFF),
            Color(0x00FFFFFF),
          ], <double>[0, 0.12, 0.5, 0.85, 1]));
    // Thin secondary glint.
    canvas.drawLine(Offset(-w * 0.12, g.len * 0.1), Offset(-w * 0.12, g.len * 0.35),
        Paint()
          ..strokeWidth = w * 0.035
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x55FFFFFF));
    // Right rim light.
    canvas.drawLine(Offset(w * 0.4, g.len * 0.1), Offset(w * 0.4, g.len - w * 0.6),
        Paint()
          ..strokeWidth = w * 0.045
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(Offset(0, g.len * 0.1), Offset(0, g.len), const <Color>[
            Color(0x10FFFFFF),
            Color(0x66E6D2FF),
            Color(0x10FFFFFF),
          ], const <double>[0, 0.5, 1]));
    // Bottom caustic crescent.
    canvas.drawArc(Rect.fromCircle(center: Offset(0, g.len - w / 2), radius: w * 0.34), 0.35, 1.5, false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.06
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x88FFFFFF));
    // Lip.
    final Rect lip = Rect.fromLTRB(-w / 2 - gl * 2.1, -gl * 1.3, w / 2 + gl * 2.1, gl * 1.9);
    canvas.drawRRect(
        RRect.fromRectAndRadius(lip, Radius.circular(gl * 1.6)),
        Paint()
          ..shader = ui.Gradient.linear(lip.topCenter, lip.bottomCenter,
              const <Color>[Color(0x99FFFFFF), Color(0x33D9C6FF), Color(0x66FFFFFF)], const <double>[0, 0.5, 1]));
    canvas.drawRRect(
        RRect.fromRectAndRadius(lip, Radius.circular(gl * 1.6)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = const Color(0xCCFFFFFF));
    canvas.drawLine(Offset(-w * 0.32, -gl * 0.6), Offset(-w * 0.05, -gl * 0.6),
        Paint()
          ..strokeWidth = 1.2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white);
    // 6. Cork.
    if (corkT >= 0) {
      final double k = corkT.clamp(0.0, 1.0);
      final double drop = (1 - _bounce(k)) * g.len * 0.7;
      final double cw = w * 1.18;
      final ui.Image? ci = WsArt.cork;
      final double ch = ci == null ? cw * 0.8 : cw * ci.height / ci.width;
      final Rect cr = Rect.fromCenter(center: Offset(0, -ch * 0.12 - drop), width: cw, height: ch);
      canvas.drawOval(Rect.fromCenter(center: Offset(0, ch * 0.35), width: cw * 0.9, height: ch * 0.25),
          Paint()
            ..color = Colors.black.withValues(alpha: 0.35 * k)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.1));
      if (ci != null) {
        canvas.drawImageRect(ci, Rect.fromLTWH(0, 0, ci.width.toDouble(), ci.height.toDouble()), cr,
            Paint()..filterQuality = FilterQuality.medium);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(cr, Radius.circular(cw * 0.18)), _p..color = const Color(0xFFB07A48));
      }
    }
    canvas.restore();
  }

  static double _bounce(double t) {
    const double n1 = 7.5625;
    const double d1 = 2.75;
    if (t < 1 / d1) return n1 * t * t;
    if (t < 2 / d1) return n1 * (t -= 1.5 / d1) * t + 0.75;
    if (t < 2.5 / d1) return n1 * (t -= 2.25 / d1) * t + 0.9375;
    return n1 * (t -= 2.625 / d1) * t + 0.984375;
  }

  static void _question(Canvas canvas, Offset c, double size) {
    final int key = size.round();
    final TextPainter tp = _q.putIfAbsent(
        key,
        () => TextPainter(
              text: TextSpan(
                  text: '?',
                  style: TextStyle(
                      fontFamily: 'ChakraPetch',
                      fontSize: size,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xCCD8C8FF),
                      shadows: const <Shadow>[Shadow(color: Color(0xFF8B5CFF), blurRadius: 8)])),
              textDirection: TextDirection.ltr,
            )..layout());
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  // ------------------------------------------------------------------ pour stream

  /// Liquid stream from [from] (the lip) to [to] (the surface), drawn between [head] and [tail]
  /// fractions of the curve (0 = lip) so it can extend and detach.
  static void stream(Canvas canvas, Offset from, Offset to, double width, Color c, double t,
      {double head = 1, double tail = 0, double dir = 1}) {
    if (head <= tail) return;
    final Offset ctrl = Offset(from.dx + dir * width * 1.6, from.dy + (to.dy - from.dy) * 0.08);
    final Offset end = Offset(to.dx, to.dy);
    Offset at(double k) {
      final double a = (1 - k) * (1 - k);
      final double b = 2 * (1 - k) * k;
      final double cc = k * k;
      return Offset(from.dx * a + ctrl.dx * b + end.dx * cc, from.dy * a + ctrl.dy * b + end.dy * cc);
    }

    final List<Offset> left = <Offset>[];
    final List<Offset> right = <Offset>[];
    const int n = 22;
    for (int i = 0; i <= n; i++) {
      final double k = tail + (head - tail) * i / n;
      final Offset p = at(k);
      final Offset q = at(math.min(1, k + 0.01));
      Offset d = q - p;
      if (d.distance < 0.001) d = const Offset(0, 1);
      final Offset nrm = Offset(-d.dy, d.dx) / d.distance;
      // Stream narrows as it accelerates, with a slight ripple.
      final double wv = width * (1.0 - 0.45 * k) * (1 + 0.08 * math.sin(k * 26 - t * 30));
      left.add(p + nrm * wv / 2);
      right.add(p - nrm * wv / 2);
    }
    final Path body = Path()..addPolygon(<Offset>[...left, ...right.reversed], true);
    final Offset a0 = at(tail);
    final Offset a1 = at(head);
    canvas.drawPath(
        body,
        Paint()
          ..color = c.withValues(alpha: 0.55)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.9));
    canvas.drawPath(
        body,
        Paint()
          ..shader = ui.Gradient.linear(a0, a1, <Color>[Color.lerp(c, Colors.white, 0.25)!, c, Color.lerp(c, Colors.white, 0.1)!], const <double>[0, 0.5, 1]));
    // Core highlight.
    final Path core = Path();
    for (int i = 0; i <= n; i++) {
      final Offset p = Offset.lerp(left[i], right[i], 0.3)!;
      if (i == 0) {
        core.moveTo(p.dx, p.dy);
      } else {
        core.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
        core,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, width * 0.16)
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.55));
    // Travelling glints.
    for (int i = 0; i < 4; i++) {
      final double k = tail + (head - tail) * (((t * 2.6) + i / 4) % 1.0);
      canvas.drawCircle(Offset.lerp(at(k), at(math.min(1, k + 0.01)), 0.5)!, width * 0.14,
          _p..color = Colors.white.withValues(alpha: 0.7));
    }
  }
}

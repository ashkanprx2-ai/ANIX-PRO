import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ===================== SOLO ART =====================
/// Hand-painted scene pieces shared by the solo boards: skies, stars, skylines, neon
/// lines, glossy materials. Everything is procedural (no bitmaps), deterministic per
/// seed and cheap enough for a 60 fps CustomPainter on a mid-range phone.
/// ===================================================

class SoloArt {
  SoloArt._();

  static final Paint _p = Paint();

  /// Vertical multi-stop sky.
  static void sky(Canvas canvas, Rect r, List<Color> colors, [List<double>? stops]) {
    canvas.drawRect(r, Paint()..shader = ui.Gradient.linear(r.topCenter, r.bottomCenter, colors,
        stops ?? (colors.length == 2 ? null : <double>[for (int i = 0; i < colors.length; i++) i / (colors.length - 1)])));
  }

  /// Twinkling star field; [seed] keeps the layout stable between frames.
  static void stars(Canvas canvas, Rect r, double t, {int count = 70, int seed = 7, double drift = 0, Color color = Colors.white}) {
    final math.Random rnd = math.Random(seed);
    for (int i = 0; i < count; i++) {
      final double x = r.left + ((rnd.nextDouble() * r.width - drift * (0.3 + (i % 5) * 0.15)) % r.width + r.width) % r.width;
      final double y = r.top + rnd.nextDouble() * r.height;
      final double tw = 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * (1.2 + rnd.nextDouble() * 2.5) + i));
      final double s = 0.5 + rnd.nextDouble() * 1.3;
      _p
        ..color = color.withValues(alpha: 0.25 + 0.6 * tw * (s / 1.8))
        ..maskFilter = null;
      canvas.drawCircle(Offset(x, y), s, _p);
      if (s > 1.55) {
        _p.color = color.withValues(alpha: 0.25 * tw);
        canvas.drawLine(Offset(x - s * 3, y), Offset(x + s * 3, y), _p..strokeWidth = 0.6);
        canvas.drawLine(Offset(x, y - s * 3), Offset(x, y + s * 3), _p);
      }
    }
  }

  /// Synthwave sun with horizontal cut stripes, sitting on [horizon].
  static void synthSun(Canvas canvas, Offset c, double r, Color top, Color bottom, double t) {
    paintBloom(canvas, c, r * 2.2, bottom, 0.35);
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(c.dx - r, c.dy - r, c.dx + r, c.dy));
    final Rect box = Rect.fromCircle(center: c, radius: r);
    final Path disc = Path()..addOval(box);
    for (int i = 0; i < 7; i++) {
      final double f = i / 7;
      final double y = c.dy - r * 0.62 + f * r * 0.62 + (t * 6) % (r * 0.09);
      final double h = 1 + f * r * 0.06;
      disc.addRect(Rect.fromLTWH(c.dx - r, y, r * 2, h));
    }
    disc.fillType = PathFillType.evenOdd;
    canvas.drawPath(disc, Paint()..shader = ui.Gradient.linear(box.topCenter, c, <Color>[top, bottom]));
    canvas.restore();
  }

  /// Layered silhouette mountains (two ridges) above [baseY].
  static void mountains(Canvas canvas, Size size, double baseY, Color near, Color far, double scroll, int seed) {
    for (int layer = 0; layer < 2; layer++) {
      final math.Random rnd = math.Random(seed + layer * 31);
      final double amp = size.height * (layer == 0 ? 0.075 : 0.05);
      final double off = scroll * (layer == 0 ? 0.15 : 0.35);
      final Path p = Path()..moveTo(0, baseY);
      const int n = 9;
      final List<double> peaks = List<double>.generate(n + 2, (_) => 0.35 + rnd.nextDouble() * 0.65);
      for (int i = 0; i <= 60; i++) {
        final double x = size.width * i / 60;
        final double u = ((x + off) / size.width * n) % (n + 1);
        final int k = u.floor();
        final double f = u - k;
        final double h = peaks[k] * (1 - f) + peaks[k + 1] * f;
        final double jag = math.sin((x + off) * 0.11 + layer) * 0.08 + math.sin((x + off) * 0.037) * 0.12;
        p.lineTo(x, baseY - amp * (h + jag));
      }
      p
        ..lineTo(size.width, baseY)
        ..close();
      canvas.drawPath(p, Paint()..color = layer == 0 ? far : near);
    }
  }

  /// Neon city skyline with lit windows; [scroll] in pixels drives the parallax.
  static void skyline(Canvas canvas, Size size, double baseY, double scroll, Color body, Color window, int seed,
      {double maxH = 0.22, double speed = 1}) {
    final math.Random rnd = math.Random(seed);
    final List<double> widths = List<double>.generate(24, (_) => 18 + rnd.nextDouble() * 34);
    final List<double> heights = List<double>.generate(24, (_) => 0.25 + rnd.nextDouble() * 0.75);
    final double total = widths.fold(0, (double a, double b) => a + b + 4);
    double x = -((scroll * speed) % total);
    int i = 0;
    final Paint bp = Paint()..color = body;
    final Paint wp = Paint();
    while (x < size.width) {
      final int k = i % 24;
      final double w = widths[k];
      final double h = heights[k] * size.height * maxH;
      final Rect b = Rect.fromLTWH(x, baseY - h, w, h);
      canvas.drawRect(b, bp);
      if (k % 4 == 0) {
        canvas.drawRect(Rect.fromLTWH(x + w * 0.45, baseY - h - 8, 1.5, 8), bp);
      }
      final math.Random wr = math.Random(k * 977 + seed);
      for (double wy = b.top + 5; wy < baseY - 4; wy += 7) {
        for (double wx = b.left + 4; wx < b.right - 4; wx += 6) {
          if (wr.nextDouble() < 0.32) {
            wp.color = window.withValues(alpha: 0.25 + wr.nextDouble() * 0.6);
            canvas.drawRect(Rect.fromLTWH(wx, wy, 2.2, 3), wp);
          }
        }
      }
      x += w + 4;
      i++;
    }
  }

  /// Additive radial bloom.
  static void paintBloom(Canvas canvas, Offset c, double r, Color color, [double a = 0.5]) {
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = ui.Gradient.radial(c, r, <Color>[color.withValues(alpha: a), color.withValues(alpha: a * 0.25), color.withValues(alpha: 0)],
            <double>[0, 0.35, 1]),
    );
  }

  /// Neon stroke with an outer glow.
  static void neonLine(Canvas canvas, Offset a, Offset b, Color c, {double width = 2, double glow = 8, double alpha = 1}) {
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = c.withValues(alpha: 0.45 * alpha)
        ..strokeWidth = width + glow
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow * 0.5),
    );
    canvas.drawLine(
      a,
      b,
      Paint()
        ..color = Color.lerp(c, Colors.white, 0.45)!.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
  }

  static void neonPath(Canvas canvas, Path path, Color c, {double width = 2, double glow = 8, bool fill = false, double alpha = 1}) {
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = c.withValues(alpha: 0.5 * alpha)
        ..strokeWidth = width + glow
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glow * 0.5),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Color.lerp(c, Colors.white, 0.4)!.withValues(alpha: alpha)
        ..strokeWidth = width
        ..strokeJoin = StrokeJoin.round,
    );
  }

  /// Soft drop shadow under any path.
  static void shadowPath(Canvas canvas, Path p, {Offset offset = const Offset(0, 6), double blur = 8, double a = 0.45}) {
    canvas.drawPath(
      p.shift(offset),
      Paint()
        ..color = Colors.black.withValues(alpha: a)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur),
    );
  }

  /// Big stylised score / status label with stroke + glow (for in-field numbers).
  static void bigLabel(Canvas canvas, String s, Offset c, {double size = 30, Color color = Colors.white, Color glow = Colors.cyan, double alpha = 1}) {
    final TextStyle base = TextStyle(
      fontFamily: 'ChakraPetch',
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: size * 0.04,
      height: 1,
    );
    final TextPainter stroke = TextPainter(
      text: TextSpan(
        text: s,
        style: base.copyWith(
          foreground: Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.12
            ..color = Colors.black.withValues(alpha: 0.55 * alpha),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final TextPainter fill = TextPainter(
      text: TextSpan(
        text: s,
        style: base.copyWith(
          color: color.withValues(alpha: alpha),
          shadows: <Shadow>[Shadow(color: glow.withValues(alpha: 0.9 * alpha), blurRadius: size * 0.55)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final Offset o = c - Offset(fill.width / 2, fill.height / 2);
    stroke.paint(canvas, o);
    fill.paint(canvas, o);
  }

  /// Lighter / darker tint of [c].
  static Color tone(Color c, double dl) {
    final HSLColor h = HSLColor.fromColor(c);
    return h.withLightness((h.lightness + dl).clamp(0.0, 1.0)).toColor();
  }

  static Color hue(double degrees, {double s = 0.85, double l = 0.58}) =>
      HSLColor.fromAHSL(1, ((degrees % 360) + 360) % 360, s, l).toColor();

  /// Diagonal hazard stripes clipped to [r].
  static void hazardStripes(Canvas canvas, RRect r, Color a, Color b, {double band = 10, double phase = 0}) {
    canvas.save();
    canvas.clipRRect(r);
    canvas.drawRRect(r, Paint()..color = a);
    final Paint p = Paint()..color = b;
    final Rect o = r.outerRect;
    for (double x = o.left - o.height - band * 2 + phase % (band * 2); x < o.right + band; x += band * 2) {
      final Path s = Path()
        ..moveTo(x, o.bottom)
        ..lineTo(x + band, o.bottom)
        ..lineTo(x + band + o.height, o.top)
        ..lineTo(x + o.height, o.top)
        ..close();
      canvas.drawPath(s, p);
    }
    canvas.restore();
  }

  static double smooth(double t) {
    final double x = t.clamp(0.0, 1.0);
    return x * x * (3 - 2 * x);
  }
}

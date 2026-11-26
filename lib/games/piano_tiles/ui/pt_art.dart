import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// ===================== PIANO TILES · ART =====================
/// Procedural art for the Persian night piano: khatam stars, girih strapwork, bokeh, glass and gold.
/// Static layers (pattern tiles, tile bodies, bokeh sprite) are recorded once per size into GPU
/// images (`toImageSync`) so a frame only blits them.
/// ===============================================================

class PtPalette {
  PtPalette._();
  static const Color skyTop = Color(0xFF2B1B63);
  static const Color skyMid = Color(0xFF4B2C8C);
  static const Color skyLow = Color(0xFF5A3496);
  static const Color skyBottom = Color(0xFF2A1A5E);
  static const Color line = Color(0xFFCDB8FF);
  static const Color gold = Color(0xFFE6C276);
  static const Color goldDeep = Color(0xFF9C7433);
  static const Color goldLight = Color(0xFFFFF0C2);
  static const Color navyTop = Color(0xFF0A0F2E);
  static const Color navyBottom = Color(0xFF1B2766);
  static const Color cyan = Color(0xFF5EE7FF);
  static const Color lilac = Color(0xFFB79CFF);
  static const Color rose = Color(0xFFFF7FC8);
  static const Color red = Color(0xFFFF3B5C);
}

/// 8-point khatam star (two overlapped squares), tips at radius [r].
Path khatamPath(Offset c, double r, {double rot = 0}) {
  final Path p = Path();
  final double inner = r * 0.7654;
  for (int i = 0; i < 16; i++) {
    final double a = rot - math.pi / 2 + i * math.pi / 8;
    final double rr = i.isEven ? r : inner;
    final Offset o = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    if (i == 0) {
      p.moveTo(o.dx, o.dy);
    } else {
      p.lineTo(o.dx, o.dy);
    }
  }
  return p..close();
}

/// n-point rosette star polygon (a shamseh petal ring).
Path rosettePath(Offset c, double r, int n, double innerK, {double rot = 0}) {
  final Path p = Path();
  for (int i = 0; i < n * 2; i++) {
    final double a = rot + i * math.pi / n;
    final double rr = i.isEven ? r : r * innerK;
    final Offset o = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
    i == 0 ? p.moveTo(o.dx, o.dy) : p.lineTo(o.dx, o.dy);
  }
  return p..close();
}

/// An eighth-note glyph centred near its head, about 18 px tall.
final Path kNoteGlyph = () {
  final Path p = Path()
    ..addOval(Rect.fromCenter(center: Offset.zero, width: 8.4, height: 6))
    ..addRect(const Rect.fromLTWH(3.0, -15, 1.5, 15));
  p
    ..moveTo(4.5, -15)
    ..cubicTo(9, -12, 10.5, -9, 8.5, -5)
    ..cubicTo(8.8, -8.5, 7, -10, 4.5, -11)
    ..close();
  return p;
}();

Paint _stroke(Color c, double w) => Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = w
  ..color = c
  ..isAntiAlias = true;

Shader goldShader(Rect r) => const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[PtPalette.goldLight, PtPalette.gold, PtPalette.goldDeep, PtPalette.gold, PtPalette.goldLight],
      stops: <double>[0, 0.28, 0.55, 0.8, 1],
    ).createShader(r);

ui.Image recordImage(Size logical, double dpr, void Function(Canvas c) draw) {
  final ui.PictureRecorder rec = ui.PictureRecorder();
  final Canvas c = Canvas(rec);
  c.scale(dpr);
  draw(c);
  final ui.Picture pic = rec.endRecording();
  final ui.Image img = pic.toImageSync(math.max(1, (logical.width * dpr).ceil()), math.max(1, (logical.height * dpr).ceil()));
  pic.dispose();
  return img;
}

/// One period of the star-and-cross (khatam) girih lattice with interlaced strapwork, [s] px square.
void paintGirihCell(Canvas c, double s, Color color, double alpha) {
  final Paint band = _stroke(color.withValues(alpha: alpha * 0.45), s * 0.05);
  final Paint edge = _stroke(color.withValues(alpha: alpha), s * 0.012);
  final Paint dot = Paint()..color = color.withValues(alpha: alpha * 0.9);
  final List<Offset> centres = <Offset>[Offset.zero, Offset(s, 0), Offset(0, s), Offset(s, s)];
  for (final Offset o in centres) {
    final Path star = khatamPath(o, s * 0.5, rot: math.pi / 8 * 0 + math.pi / 2);
    c.drawPath(star, band);
    c.drawPath(star, edge);
    c.drawPath(khatamPath(o, s * 0.26, rot: math.pi / 8), edge);
    c.drawCircle(o, s * 0.035, dot);
  }
  // The cross between four stars, with a small rosette in its heart.
  final Offset m = Offset(s / 2, s / 2);
  c.drawPath(rosettePath(m, s * 0.13, 4, 0.42, rot: math.pi / 4), edge);
  c.drawCircle(m, s * 0.025, dot);
  for (final Offset o in <Offset>[Offset(s / 2, 0), Offset(0, s / 2), Offset(s, s / 2), Offset(s / 2, s)]) {
    c.drawCircle(o, s * 0.018, dot);
  }
}

/// Soft white disc sprite for additive bokeh (64 px).
ui.Image bokehSprite(double dpr) => recordImage(const Size(64, 64), dpr, (Canvas c) {
      const Offset o = Offset(32, 32);
      c.drawCircle(
        o,
        32,
        Paint()
          ..shader = const RadialGradient(
            colors: <Color>[Color(0xCCFFFFFF), Color(0x88FFFFFF), Color(0x22FFFFFF), Color(0x00FFFFFF)],
            stops: <double>[0, 0.45, 0.8, 1],
          ).createShader(Rect.fromCircle(center: o, radius: 32)),
      );
      c.drawCircle(o, 24, _stroke(const Color(0x33FFFFFF), 1.2));
    });

/// Margin around a cached tile image (room for its shadow and glow).
const double kTileMargin = 16;

/// Draws a dark-navy lacquer tile with gold khatam inlay into [r].
/// [len] > 1 draws the hold rail; [start] draws the cyan start tile.
void paintTileBody(Canvas c, Rect r, {int len = 1, bool start = false, double rowH = 180}) {
  final double rad = math.min(14, r.width * 0.16);
  final RRect rr = RRect.fromRectAndRadius(r, Radius.circular(rad));
  // ground shadow + violet halo
  c.drawRRect(rr.shift(const Offset(0, 5)), Paint()
    ..color = const Color(0xAA05031A)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7));
  c.drawRRect(rr, Paint()
    ..color = (start ? PtPalette.cyan : const Color(0xFF8C6BFF)).withValues(alpha: start ? 0.55 : 0.32)
    ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 9));
  // lacquer body
  c.drawRRect(
    rr,
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: start
            ? const <Color>[Color(0xFF0E3A5E), Color(0xFF13557F), Color(0xFF1C7BA6)]
            : const <Color>[PtPalette.navyTop, Color(0xFF111A48), PtPalette.navyBottom],
        stops: const <double>[0, 0.55, 1],
      ).createShader(r),
  );
  c.save();
  c.clipRRect(rr);
  // faint girih engraving inside the lacquer
  final double s = r.width * 0.5;
  c.save();
  c.translate(r.left, r.top);
  for (double y = -s * 0.5; y < r.height + s; y += s) {
    for (double x = -s * 0.5; x < r.width + s; x += s) {
      c.save();
      c.translate(x, y);
      paintGirihCell(c, s, start ? const Color(0xFFBFF4FF) : PtPalette.lilac, start ? 0.08 : 0.055);
      c.restore();
    }
  }
  c.restore();
  // top sheen and bottom reflected light
  c.drawRect(
    Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.42),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[Colors.white.withValues(alpha: 0.13), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromLTWH(r.left, r.top, r.width, r.height * 0.42)),
  );
  c.drawRect(
    Rect.fromLTWH(r.left, r.bottom - r.height * 0.18, r.width, r.height * 0.18),
    Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[const Color(0xFF7C8CFF).withValues(alpha: 0.22), const Color(0x007C8CFF)],
      ).createShader(Rect.fromLTWH(r.left, r.bottom - r.height * 0.18, r.width, r.height * 0.18)),
  );
  // diagonal glass glint
  final Path glint = Path()
    ..moveTo(r.left + r.width * 0.15, r.top)
    ..lineTo(r.left + r.width * 0.42, r.top)
    ..lineTo(r.left, r.top + r.width * 0.55)
    ..lineTo(r.left, r.top + r.width * 0.25)
    ..close();
  c.drawPath(glint, Paint()..color = Colors.white.withValues(alpha: 0.05));
  c.restore();
  // borders: hairline outer, gold inlay inner
  c.drawRRect(rr, _stroke(const Color(0xFF4A5AA8).withValues(alpha: 0.75), 1));
  final RRect inner = rr.deflate(3.2);
  c.drawRRect(inner, Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.15
    ..shader = goldShader(r));
  // corner filigree: little L brackets and pearls
  final Paint goldFill = Paint()..shader = goldShader(r);
  final double k = math.min(12, r.width * 0.13);
  for (final (double sx, double sy, Offset o) in <(double, double, Offset)>[
    (1, 1, inner.outerRect.topLeft),
    (-1, 1, inner.outerRect.topRight),
    (1, -1, inner.outerRect.bottomLeft),
    (-1, -1, inner.outerRect.bottomRight),
  ]) {
    final Offset a = o + Offset(sx * 5, sy * 5);
    c.drawPath(
        Path()
          ..moveTo(a.dx, a.dy + sy * k)
          ..quadraticBezierTo(a.dx, a.dy, a.dx + sx * k, a.dy),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..shader = goldShader(r));
    c.drawCircle(a + Offset(sx * 2.6, sy * 2.6), 1.4, goldFill);
  }
  // medallion
  final double mr = math.min(r.width * 0.2, 26);
  final Offset mc = len > 1 ? Offset(r.center.dx, r.bottom - rowH * 0.5) : Offset(r.center.dx, r.top + r.height * 0.56);
  paintMedallion(c, mc, mr, start: start);
  if (len > 1) {
    // hold rail: double gold line up to a cap ornament, with diamond studs each row
    final double top = r.top + rowH * 0.32;
    final Paint rail = Paint()
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: <Color>[PtPalette.gold, PtPalette.gold.withValues(alpha: 0.25)],
      ).createShader(Rect.fromLTRB(r.left, top, r.right, mc.dy));
    c.drawLine(Offset(mc.dx - 3, mc.dy - mr * 1.15), Offset(mc.dx - 3, top), rail);
    c.drawLine(Offset(mc.dx + 3, mc.dy - mr * 1.15), Offset(mc.dx + 3, top), rail);
    for (double y = mc.dy - rowH; y > top + 4; y -= rowH) {
      c.drawPath(
          Path()
            ..moveTo(mc.dx, y - 6)
            ..lineTo(mc.dx + 5, y)
            ..lineTo(mc.dx, y + 6)
            ..lineTo(mc.dx - 5, y)
            ..close(),
          goldFill);
    }
    c.drawPath(khatamPath(Offset(mc.dx, top), 7), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = goldShader(r));
    c.drawCircle(Offset(mc.dx, top), 1.8, goldFill);
  }
}

/// Gold khatam medallion: halo, ring of pearls, outlined star, inner star and jewel.
void paintMedallion(Canvas c, Offset o, double r, {bool start = false, double glow = 0}) {
  final Rect b = Rect.fromCircle(center: o, radius: r * 1.4);
  c.drawCircle(
    o,
    r * 1.6,
    Paint()
      ..shader = RadialGradient(colors: <Color>[
        (start ? PtPalette.cyan : PtPalette.gold).withValues(alpha: 0.16 + glow * 0.5),
        const Color(0x00000000),
      ]).createShader(Rect.fromCircle(center: o, radius: r * 1.6)),
  );
  final Paint g = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = math.max(1.2, r * 0.07)
    ..strokeJoin = StrokeJoin.miter
    ..shader = goldShader(b);
  final Path star = khatamPath(o, r);
  c.drawPath(star, Paint()..color = const Color(0xFF0B1135).withValues(alpha: 0.55));
  c.drawPath(star, g);
  c.drawPath(khatamPath(o, r * 0.78), _stroke(PtPalette.gold.withValues(alpha: 0.35), 0.8));
  c.drawPath(khatamPath(o, r * 0.42, rot: math.pi / 8), g..strokeWidth = math.max(0.9, r * 0.045));
  final Paint pearl = Paint()..shader = goldShader(b);
  for (int i = 0; i < 8; i++) {
    final double a = -math.pi / 2 + math.pi / 8 + i * math.pi / 4;
    c.drawCircle(o + Offset(math.cos(a), math.sin(a)) * (r * 1.18), math.max(0.9, r * 0.05), pearl);
  }
  c.drawCircle(o, r * 0.13, Paint()..shader = goldShader(b));
  c.drawCircle(o - Offset(r * 0.04, r * 0.04), r * 0.05, Paint()..color = Colors.white.withValues(alpha: 0.8));
}

/// Cached art for one board size.
class PtArtCache {
  PtArtCache(this.size, this.dpr, this.tile, this.rowH);
  final Size size;
  final double dpr;
  final Size tile; // short tile body size (row minus gaps)
  final double rowH;

  ui.Image? _patternNear, _patternFar, _bokeh;
  final Map<String, ui.Image> _tiles = <String, ui.Image>{};

  double get nearCell => (size.width / 3.2).roundToDouble();
  double get farCell => (size.width / 1.35).roundToDouble();

  ui.Image get patternNear => _patternNear ??= recordImage(Size.square(nearCell), dpr, (Canvas c) {
        paintGirihCell(c, nearCell, PtPalette.line, 0.13);
      });

  ui.Image get patternFar => _patternFar ??= recordImage(Size.square(farCell), dpr, (Canvas c) {
        paintGirihCell(c, farCell, PtPalette.line, 0.07);
      });

  ui.Image get bokeh => _bokeh ??= bokehSprite(dpr);

  ui.Image tileImage(int len, {bool start = false}) => _tiles.putIfAbsent('$len|$start', () {
        final double h = rowH * len - (rowH - tile.height);
        final Size s = Size(tile.width + kTileMargin * 2, h + kTileMargin * 2);
        return recordImage(s, dpr, (Canvas c) {
          paintTileBody(c, Rect.fromLTWH(kTileMargin, kTileMargin, tile.width, h), len: len, start: start, rowH: rowH);
        });
      });

  void dispose() {
    _patternNear?.dispose();
    _patternFar?.dispose();
    _bokeh?.dispose();
    for (final ui.Image i in _tiles.values) {
      i.dispose();
    }
    _tiles.clear();
  }
}

/// Text painter cache (Persian shaping is the expensive part of a frame's text).
class PtText {
  final Map<String, TextPainter> _cache = <String, TextPainter>{};

  TextPainter get(String s, double size,
      {Color color = Colors.white,
      String family = 'Lalezar',
      FontWeight weight = FontWeight.w400,
      bool rtl = true,
      List<Shadow>? shadows,
      Paint? foreground}) {
    final String key = '$s|$size|${color.toARGB32()}|$family|$weight|$rtl|${shadows?.length}|${foreground != null}';
    return _cache.putIfAbsent(key, () {
      if (_cache.length > 160) _cache.clear();
      return TextPainter(
        text: TextSpan(
          text: s,
          style: TextStyle(
            fontFamily: family,
            fontSize: size,
            fontWeight: weight,
            color: foreground == null ? color : null,
            foreground: foreground,
            height: 1.15,
            shadows: shadows,
          ),
        ),
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout(maxWidth: 600);
    });
  }

  void draw(Canvas c, String s, Offset centre, double size,
      {Color color = Colors.white, String family = 'Lalezar', FontWeight weight = FontWeight.w400, bool rtl = true, List<Shadow>? shadows}) {
    final TextPainter tp = get(s, size, color: color, family: family, weight: weight, rtl: rtl, shadows: shadows);
    tp.paint(c, centre - Offset(tp.width / 2, tp.height / 2));
  }
}

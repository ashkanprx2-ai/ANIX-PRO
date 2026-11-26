import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Canvas text with a small layout cache: HUD strings change a few times per race, so each distinct string is laid
/// out once; the running clock is drawn glyph by glyph from ten cached digits (no per-frame layout).
class CrText {
  static const int white = 0;
  static const int gold = 1;

  final Map<int, TextPainter> _cache = <int, TextPainter>{};
  final List<int> _order = <int>[];
  double lastWidth = 0;

  static const String _fa = '۰۱۲۳۴۵۶۷۸۹';

  static bool _rtl(String s) {
    for (final int c in s.codeUnits) {
      if (c >= 0x0621 && c <= 0x06D3) return true;
    }
    return false;
  }

  static String digits(String s, bool fa) {
    if (!fa) return s;
    final StringBuffer b = StringBuffer();
    for (final int c in s.codeUnits) {
      if (c >= 48 && c <= 57) {
        b.write(_fa[c - 48]);
      } else {
        b.writeCharCode(c);
      }
    }
    return b.toString();
  }

  TextPainter _get(String s, double size, int style) {
    final int key = Object.hash(s, (size * 4).round(), style);
    final TextPainter? hit = _cache[key];
    if (hit != null) return hit;
    final Color fill = style == gold ? const Color(0xFFFFD34E) : const Color(0xFFFFFFFF);
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontFamily: 'Lalezar',
          fontSize: size,
          height: 1.1,
          color: fill,
          shadows: const <Shadow>[
            Shadow(color: Color(0xFF1A0E00), offset: Offset(0, 2.5), blurRadius: 0),
            Shadow(color: Color(0xCC1A0E00), offset: Offset(1.5, 0), blurRadius: 0),
            Shadow(color: Color(0xCC1A0E00), offset: Offset(-1.5, 0), blurRadius: 0),
            Shadow(color: Color(0x88000000), offset: Offset(0, 4), blurRadius: 6),
          ],
        ),
      ),
      textDirection: _rtl(s) ? TextDirection.rtl : TextDirection.ltr,
    )..layout();
    _cache[key] = tp;
    _order.add(key);
    if (_order.length > 80) {
      final int old = _order.removeAt(0);
      _cache.remove(old)?.dispose();
    }
    return tp;
  }

  /// align: 0 left, 1 centre, 2 right (x is that edge).
  void draw(ui.Canvas canvas, String s, double x, double y, double size, int style, {int align = 0}) {
    final TextPainter tp = _get(s, size, style);
    lastWidth = tp.width;
    final double dx = align == 0 ? x : (align == 1 ? x - tp.width / 2 : x - tp.width);
    tp.paint(canvas, Offset(dx, y));
  }

  /// Race clock m:ss.cc, right-aligned at [x].
  void clock(ui.Canvas canvas, double seconds, double x, double y, double size, bool fa) {
    final int cs = (seconds * 100).floor().clamp(0, 599999);
    final int m = cs ~/ 6000, s = (cs ~/ 100) % 60, c = cs % 100;
    // glyphs right to left
    double cx = x;
    double put(String g) {
      final TextPainter tp = _get(g, size, white);
      cx -= tp.width;
      tp.paint(canvas, Offset(cx, y));
      return tp.width;
    }

    String d(int v) => fa ? _fa[v] : String.fromCharCode(48 + v);
    put(d(c % 10));
    put(d(c ~/ 10));
    put('.');
    put(d(s % 10));
    put(d(s ~/ 10));
    put(':');
    put(d(m % 10));
  }

  void dispose() {
    for (final TextPainter tp in _cache.values) {
      tp.dispose();
    }
    _cache.clear();
    _order.clear();
  }
}

/// m:ss.cc for menus / results.
String crFormatTime(double seconds, bool fa) {
  final int cs = (seconds * 100).round();
  final int m = cs ~/ 6000, s = (cs ~/ 100) % 60, c = cs % 100;
  return CrText.digits('$m:${s.toString().padLeft(2, '0')}.${c.toString().padLeft(2, '0')}', fa);
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../core/cr_track.dart';

/// Asset folder of the game.
const String kCrDir = 'assets/games/crash_racing/';

/// Character ids in [kCrCharacters] order (`kart_<id>.webp`, `char_<id>.webp`).
const List<String> kCrCharIds = <String>['fox', 'raccoon', 'numbat', 'glider', 'wombat', 'quokka'];

/// Sprite ids inside the atlas.
abstract final class CrSpr {
  static const int kart0 = 0; // 0..5 karts (character order)
  static const int prop0 = 6; // 6..12 props (CrProp order)
  static const int ramp = 13;
  static const int box = 14;
  static const int fruit = 15;
  static const int mask = 16;
  static const int rocket = 17;
  static const int bowlbomb = 18;
  static const int crate = 19;
  static const int nitro = 20;
  static const int shield = 21;
  static const int shadow = 22;
  static const int spark = 23;
  static const int smoke = 24;
  static const int flame = 25;
  static const int count = 26;
}

/// All game sprites packed into ONE texture at load time, so the whole sprite layer of a frame (props, pickups,
/// karts, projectiles, particles) is a single `drawRawAtlas` call. Images are decoded at the size they are drawn
/// at (the `cacheWidth` idea), never at the source resolution.
class CrArt {
  CrArt._();

  static CrArt? _cache;
  static Future<CrArt>? _loading;

  late final ui.Image atlas;

  /// Source rects in the atlas: x, y, w, h per sprite id.
  final List<double> rect = List<double>.filled(CrSpr.count * 4, 0);

  /// Horizon backgrounds by theme (decoded at 1024 px wide).
  final Map<CrTheme, ui.Image> sky = <CrTheme, ui.Image>{};

  static Future<CrArt> load() {
    final CrArt? c = _cache;
    if (c != null) return Future<CrArt>.value(c);
    return _loading ??= _load().then((CrArt a) {
      _cache = a;
      return a;
    });
  }

  static CrArt? get ready => _cache;

  static Future<ui.Image> _decode(String file, int width) async {
    final ByteData data = await rootBundle.load('$kCrDir$file');
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final ui.FrameInfo f = await codec.getNextFrame();
    codec.dispose();
    return f.image;
  }

  static Future<CrArt> _load() async {
    final CrArt a = CrArt._();
    // file, decode width
    final List<(String, int)> files = <(String, int)>[
      for (final String id in kCrCharIds) ('kart_$id.webp', 256),
      ('prop_palm.webp', 200),
      ('prop_statue.webp', 128),
      ('prop_torch.webp', 76),
      ('prop_pillar.webp', 220),
      ('prop_hut.webp', 246),
      ('prop_jtree.webp', 300),
      ('prop_bush.webp', 256),
      ('prop_ramp.webp', 256),
      ('itembox.webp', 128),
      ('fruit.webp', 96),
      ('mask.webp', 128),
      ('item_rocket.webp', 128),
      ('item_bowlbomb.webp', 112),
      ('item_crate.webp', 128),
      ('item_nitro.webp', 128),
      ('item_shield.webp', 160),
    ];
    final List<ui.Image> imgs = await Future.wait(<Future<ui.Image>>[for (final (String, int) f in files) _decode(f.$1, f.$2)]);
    final List<ui.Image> skies = await Future.wait(<Future<ui.Image>>[
      _decode('bg_jungle.webp', 1024),
      _decode('bg_temple.webp', 1024),
      _decode('bg_beach.webp', 1024),
    ]);
    a.sky[CrTheme.jungle] = skies[0];
    a.sky[CrTheme.temple] = skies[1];
    a.sky[CrTheme.beach] = skies[2];

    // Shelf-pack into a 2048-wide atlas (2 px padding).
    const double atlasW = 2048, pad = 2;
    double x = 0, y = 0, rowH = 0;
    final List<double> pos = List<double>.filled(CrSpr.count * 4, 0);
    void place(int id, double w, double h) {
      if (x + w + pad > atlasW) {
        x = 0;
        y += rowH + pad;
        rowH = 0;
      }
      pos[id * 4] = x;
      pos[id * 4 + 1] = y;
      pos[id * 4 + 2] = w;
      pos[id * 4 + 3] = h;
      x += w + pad;
      rowH = math.max(rowH, h);
    }

    for (int i = 0; i < imgs.length; i++) {
      place(i, imgs[i].width.toDouble(), imgs[i].height.toDouble());
    }
    place(CrSpr.shadow, 128, 40);
    place(CrSpr.spark, 32, 32);
    place(CrSpr.smoke, 64, 64);
    place(CrSpr.flame, 48, 96);
    final double atlasH = y + rowH + pad;

    final ui.PictureRecorder rec = ui.PictureRecorder();
    final ui.Canvas c = ui.Canvas(rec);
    final ui.Paint p = ui.Paint()..filterQuality = ui.FilterQuality.medium;
    for (int i = 0; i < imgs.length; i++) {
      c.drawImage(imgs[i], ui.Offset(pos[i * 4], pos[i * 4 + 1]), p);
    }
    // Procedural sprites: contact shadow, spark, smoke puff, exhaust flame (white, tinted at draw time).
    ui.Rect r(int id) => ui.Rect.fromLTWH(pos[id * 4], pos[id * 4 + 1], pos[id * 4 + 2], pos[id * 4 + 3]);
    final ui.Rect sh = r(CrSpr.shadow);
    c.drawOval(
        sh.deflate(2),
        ui.Paint()
          ..shader = ui.Gradient.radial(sh.center, sh.width / 2, const <ui.Color>[ui.Color(0x88000000), ui.Color(0x00000000)]));
    final ui.Rect sp = r(CrSpr.spark);
    c.drawCircle(
        sp.center,
        sp.width / 2,
        ui.Paint()
          ..shader = ui.Gradient.radial(sp.center, sp.width / 2,
              const <ui.Color>[ui.Color(0xFFFFFFFF), ui.Color(0xCCFFFFFF), ui.Color(0x00FFFFFF)], const <double>[0, 0.35, 1]));
    final ui.Rect sm = r(CrSpr.smoke);
    c.drawCircle(
        sm.center,
        sm.width / 2,
        ui.Paint()
          ..shader = ui.Gradient.radial(sm.center, sm.width / 2,
              const <ui.Color>[ui.Color(0xCCFFFFFF), ui.Color(0x88FFFFFF), ui.Color(0x00FFFFFF)], const <double>[0, 0.5, 1]));
    final ui.Rect fl = r(CrSpr.flame);
    final ui.Path flame = ui.Path()
      ..moveTo(fl.center.dx, fl.top + 2)
      ..quadraticBezierTo(fl.right - 2, fl.center.dy, fl.center.dx, fl.bottom - 2)
      ..quadraticBezierTo(fl.left + 2, fl.center.dy, fl.center.dx, fl.top + 2);
    c.drawPath(
        flame,
        ui.Paint()
          ..shader = ui.Gradient.linear(fl.topCenter, fl.bottomCenter,
              const <ui.Color>[ui.Color(0x00FFFFFF), ui.Color(0xDDFFFFFF), ui.Color(0xFFFFFFFF)], const <double>[0, 0.6, 1]));
    final ui.Picture pic = rec.endRecording();
    a.atlas = await pic.toImage(atlasW.toInt(), atlasH.ceil());
    pic.dispose();
    for (final ui.Image i in imgs) {
      i.dispose();
    }
    for (int i = 0; i < pos.length; i++) {
      a.rect[i] = pos[i];
    }
    return a;
  }

  double w(int id) => rect[id * 4 + 2];
  double h(int id) => rect[id * 4 + 3];
}

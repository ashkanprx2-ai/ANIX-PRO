import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Sprites of دونده‌ی تیرانداز (rendered 3D chibi art, assets/games/gate_shooter/*.webp), decoded once and shared
/// by every board. Each sprite has a procedural fallback in the painter, so a missing file never blanks the game.
class GsArt {
  GsArt._();

  static const String dir = 'assets/games/gate_shooter/';
  static const List<String> files = <String>[
    'soldier_run', 'enemy_walk', 'boss', 'barrel', 'crate', 'cactus', 'rocks', 'coin', 'recruit', 'bullet', 'medkit',
    'backdrop',
  ];

  /// Frames in each sprite strip.
  static const Map<String, int> frames = <String, int>{'soldier_run': 4, 'enemy_walk': 4};

  static final Map<String, ui.Image> _img = <String, ui.Image>{};
  static Future<void>? _loading;

  static ui.Image? get(String k) => _img[k];
  static bool get ready => _img.length == files.length;

  static Future<void> load() => _loading ??= _load();

  static Future<void> _load() async {
    await Future.wait(files.map((String f) async {
      try {
        final ByteData d = await rootBundle.load('$dir$f.webp');
        final ui.Codec c = await ui.instantiateImageCodec(d.buffer.asUint8List());
        final ui.FrameInfo fi = await c.getNextFrame();
        _img[f] = fi.image;
      } catch (_) {
        // painter falls back to procedural art
      }
    }));
  }

  /// Source rect of frame [i] of strip [k].
  static ui.Rect frame(String k, int i) {
    final ui.Image im = _img[k]!;
    final int n = frames[k] ?? 1;
    final double w = im.width / n;
    return ui.Rect.fromLTWH(w * (i % n), 0, w, im.height.toDouble());
  }

  static double aspect(String k) {
    final ui.Image? im = _img[k];
    if (im == null) return 0.6;
    final int n = frames[k] ?? 1;
    return im.width / n / im.height;
  }
}

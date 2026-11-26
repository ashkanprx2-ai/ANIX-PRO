import 'dart:math' as math;
import 'dart:typed_data';

/// Crash Racing (کرش ریسینگ) — segment road model (pure Dart, no Flutter imports).
///
/// The track is a ring of [CrTrack.segLen]-long road segments. Each segment carries a curve value (how much the road
/// bends per segment, the classic pseudo-3D "segment road"), its start elevation, an optional ramp flag and up to two
/// roadside props. Pickups (? crates and star-mangos) live in [CrTrack.pickups].
///
/// Units: z along the track in world units, x across the road in road half-widths (-1 = left edge, +1 = right edge),
/// elevation y in world units.

enum CrTheme { jungle, temple, beach }

/// Roadside prop sprites (index into the renderer's prop table).
abstract final class CrProp {
  static const int none = -1;
  static const int palm = 0;
  static const int statue = 1;
  static const int torch = 2;
  static const int pillar = 3;
  static const int hut = 4;
  static const int jtree = 5;
  static const int bush = 6;
  static const int count = 7;
}

enum CrPickupKind { box, fruit }

class CrPickup {
  CrPickup(this.seg, this.x, this.kind);
  final int seg;
  final double x;
  final CrPickupKind kind;

  /// Seconds until it is back (0 = present).
  double respawn = 0;
}

class CrTrackInfo {
  const CrTrackInfo(this.id, this.theme, this.nameFa, this.nameEn, this.descFa);
  final String id;
  final CrTheme theme;
  final String nameFa;
  final String nameEn;
  final String descFa;
}

const List<CrTrackInfo> kCrTracks = <CrTrackInfo>[
  CrTrackInfo('jungle', CrTheme.jungle, 'جنگل انبه', 'Mango Jungle', 'پیچ‌های نرم، تپه‌ها و دو سکوی پرش'),
  CrTrackInfo('temple', CrTheme.temple, 'معبد خورشید', 'Sun Temple', 'پیچ‌های تند و سرازیری‌های بلند'),
  CrTrackInfo('beach', CrTheme.beach, 'ساحل آتشفشان', 'Volcano Beach', 'سرعت بالا کنار دریا و پرش بزرگ'),
];

CrTrackInfo crTrackInfo(String id) => kCrTracks.firstWhere((CrTrackInfo t) => t.id == id, orElse: () => kCrTracks.first);

class CrTrack {
  CrTrack._(this.info, this.n)
      : curve = Float32List(n),
        y = Float64List(n + 1),
        ramp = Uint8List(n),
        propA = Int8List(n)..fillRange(0, n, CrProp.none),
        propAX = Float32List(n),
        propB = Int8List(n)..fillRange(0, n, CrProp.none),
        propBX = Float32List(n),
        mapX = Float32List(n),
        mapY = Float32List(n);

  static const double segLen = 200;

  /// Road half-width in world units.
  static const double roadW = 2000;
  static const int startSeg = 10;
  static const int laps = 3;

  final CrTrackInfo info;
  final int n;
  final Float32List curve;

  /// Elevation at the start of each segment; y[n] == y[0] (closed loop).
  final Float64List y;
  final Uint8List ramp;
  final Int8List propA, propB;
  final Float32List propAX, propBX;
  final List<CrPickup> pickups = <CrPickup>[];

  /// 2D layout for the minimap, normalised to 0..1 (closed loop).
  final Float32List mapX, mapY;

  double get length => n * segLen;
  double get startZ => startSeg * segLen;

  int segIndex(double z) {
    final int i = (z / segLen).floor() % n;
    return i < 0 ? i + n : i;
  }

  /// Road elevation at [z].
  double heightAt(double z) {
    final double zz = wrap(z);
    final int i = (zz / segLen).floor() % n;
    final double t = (zz - i * segLen) / segLen;
    return y[i] + (y[i + 1] - y[i]) * t;
  }

  double curveAt(double z) => curve[segIndex(z)];

  double wrap(double z) {
    final double l = length;
    double r = z % l;
    if (r < 0) r += l;
    return r;
  }

  /// Average curve over the next [segs] segments from [z] (AI racing line / camera).
  double curveAhead(double z, int segs) {
    final int i0 = segIndex(z);
    double s = 0;
    for (int k = 0; k < segs; k++) {
      s += curve[(i0 + k) % n];
    }
    return s / segs;
  }

  static CrTrack build(String id) {
    final CrTrackInfo info = crTrackInfo(id);
    final _Builder b = _Builder();
    switch (info.theme) {
      case CrTheme.jungle:
        b
          ..road(10, 50, 10, 0, 0)
          ..road(30, 60, 30, 2.5, 18)
          ..road(20, 40, 20, 0, -12)
          ..ramp()
          ..road(10, 40, 10, 0, 0)
          ..road(30, 50, 30, -4, 10)
          ..road(20, 30, 20, 0, 16)
          ..road(25, 45, 25, 3.5, -22)
          ..road(15, 20, 15, -3, 0)
          ..road(15, 20, 15, 3, 8)
          ..road(20, 60, 20, 0, -18)
          ..ramp()
          ..road(10, 30, 10, 0, 0)
          ..road(30, 70, 30, -5, 14)
          ..road(20, 40, 20, 2, -14)
          ..road(30, 50, 30, 4.5, 0)
          ..road(15, 50, 15, 0, 0);
      case CrTheme.temple:
        b
          ..road(10, 40, 10, 0, 0)
          ..road(20, 30, 20, -5.5, 24)
          ..road(15, 40, 15, 0, 20)
          ..road(20, 30, 20, 5.5, 0)
          ..road(20, 50, 20, 0, -40)
          ..ramp()
          ..road(10, 20, 10, 0, 0)
          ..road(15, 25, 15, -4, 0)
          ..road(15, 25, 15, 4, 12)
          ..road(15, 25, 15, -4, -12)
          ..road(20, 60, 20, 0, 30)
          ..road(30, 40, 30, 6, -10)
          ..road(20, 40, 20, 0, -20)
          ..ramp()
          ..road(10, 40, 10, 0, 0)
          ..road(25, 50, 25, -5, 10)
          ..road(20, 30, 20, 3.5, 0)
          ..road(15, 40, 15, 0, 0);
      case CrTheme.beach:
        b
          ..road(10, 80, 10, 0, 0)
          ..road(40, 80, 40, 2, 10)
          ..road(20, 60, 20, 0, -10)
          ..road(30, 40, 30, -3.5, 0)
          ..road(15, 50, 15, 0, 26)
          ..ramp()
          ..road(10, 60, 10, 0, -26)
          ..road(30, 60, 30, 3, 0)
          ..road(20, 30, 20, -2.5, 6)
          ..road(20, 30, 20, 2.5, -6)
          ..road(40, 90, 40, -3, 0)
          ..road(20, 70, 20, 0, 0);
    }
    final CrTrack t = CrTrack._(info, b.curves.length);
    for (int i = 0; i < t.n; i++) {
      t.curve[i] = b.curves[i];
      t.y[i] = b.ys[i];
    }
    // Close the loop: spread the leftover height over the last stretch so y[n] == y[0].
    final double err = b.endY - b.ys.first;
    for (int i = 0; i < t.n; i++) {
      t.y[i] -= err * (i / t.n);
    }
    t.y[t.n] = t.y[0];
    for (final int r in b.ramps) {
      if (r >= 0 && r < t.n) t.ramp[r] = 1;
    }
    t._decorate();
    t._buildMap();
    return t;
  }

  void _decorate() {
    final math.Random r = math.Random(info.id.hashCode & 0xffff);
    final List<int> set = switch (info.theme) {
      CrTheme.jungle => const <int>[CrProp.palm, CrProp.jtree, CrProp.bush, CrProp.bush, CrProp.hut, CrProp.palm],
      CrTheme.temple => const <int>[CrProp.pillar, CrProp.statue, CrProp.torch, CrProp.torch, CrProp.bush, CrProp.jtree],
      CrTheme.beach => const <int>[CrProp.palm, CrProp.palm, CrProp.hut, CrProp.bush, CrProp.torch, CrProp.palm],
    };
    for (int i = 0; i < n; i++) {
      if (i % 6 == 0) {
        propA[i] = set[r.nextInt(set.length)];
        propAX[i] = -(1.45 + r.nextDouble() * 1.4);
      }
      if (i % 6 == 3) {
        propB[i] = set[r.nextInt(set.length)];
        propBX[i] = 1.45 + r.nextDouble() * 1.4;
      }
      // Torches line the road edge every 12 segments on the temple track.
      if (info.theme == CrTheme.temple && i % 12 == 0) {
        propB[i] = CrProp.torch;
        propBX[i] = 1.22;
      }
    }
    // ? crate rows (4 across) and star-mango lines.
    final int boxEvery = n ~/ 4;
    for (int k = 0; k < 4; k++) {
      final int s = (startSeg + 60 + k * boxEvery) % n;
      for (final double x in const <double>[-0.6, -0.2, 0.2, 0.6]) {
        pickups.add(CrPickup(s, x, CrPickupKind.box));
      }
    }
    for (int k = 0; k < 6; k++) {
      final int s0 = (startSeg + 30 + k * (n ~/ 6) + n ~/ 12) % n;
      final double lane = (k.isEven ? -0.45 : 0.45);
      for (int j = 0; j < 6; j++) {
        pickups.add(CrPickup((s0 + j * 4) % n, lane, CrPickupKind.fruit));
      }
    }
    // Keep the area around each ramp clear of fruit rows (they would float under the jump).
  }

  void _buildMap() {
    double hx = 0, hy = 0, dir = -math.pi / 2;
    final Float64List xs = Float64List(n + 1), ys = Float64List(n + 1);
    for (int i = 0; i < n; i++) {
      xs[i] = hx;
      ys[i] = hy;
      dir += curve[i] * 0.0105;
      hx += math.cos(dir);
      hy += math.sin(dir);
    }
    xs[n] = hx;
    ys[n] = hy;
    // Close the loop by spreading the endpoint error.
    final double ex = xs[n] - xs[0], ey = ys[n] - ys[0];
    double minX = 1e9, maxX = -1e9, minY = 1e9, maxY = -1e9;
    for (int i = 0; i < n; i++) {
      xs[i] -= ex * i / n;
      ys[i] -= ey * i / n;
      minX = math.min(minX, xs[i]);
      maxX = math.max(maxX, xs[i]);
      minY = math.min(minY, ys[i]);
      maxY = math.max(maxY, ys[i]);
    }
    final double span = math.max(maxX - minX, maxY - minY);
    for (int i = 0; i < n; i++) {
      mapX[i] = (xs[i] - minX + (span - (maxX - minX)) / 2) / span;
      mapY[i] = (ys[i] - minY + (span - (maxY - minY)) / 2) / span;
    }
  }
}

class _Builder {
  final List<double> curves = <double>[];
  final List<double> ys = <double>[];
  final List<int> ramps = <int>[];
  double endY = 0;

  static double _easeIn(double a, double b, double p) => a + (b - a) * math.pow(p, 2);
  static double _easeInOut(double a, double b, double p) => a + (b - a) * ((-math.cos(p * math.pi) / 2) + 0.5);

  void _add(double c, double y) {
    curves.add(c);
    ys.add(endY);
    endY = y;
  }

  void road(int enter, int hold, int leave, double c, double height) {
    final double y0 = endY;
    final double y1 = y0 + height * CrTrack.segLen;
    final int total = enter + hold + leave;
    for (int i = 0; i < enter; i++) {
      _add(_easeIn(0, c, i / enter), _easeInOut(y0, y1, (i + 1) / total));
    }
    for (int i = 0; i < hold; i++) {
      _add(c, _easeInOut(y0, y1, (enter + i + 1) / total));
    }
    for (int i = 0; i < leave; i++) {
      _add(_easeInOut(c, 0, i / leave), _easeInOut(y0, y1, (enter + hold + i + 1) / total));
    }
  }

  /// A launch ramp a few segments into the following flat stretch.
  void ramp() => ramps.add(curves.length + 4);
}

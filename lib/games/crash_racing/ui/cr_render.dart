import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../core/cr_race.dart';
import '../core/cr_track.dart';
import 'cr_art.dart';
import 'cr_text.dart';

class _Theme {
  const _Theme(this.grass1, this.grass2, this.road1, this.road2, this.rumble1, this.rumble2, this.lane, this.haze, this.sky);
  final int grass1, grass2, road1, road2, rumble1, rumble2, lane, haze, sky;
}

const Map<CrTheme, _Theme> _themes = <CrTheme, _Theme>{
  CrTheme.jungle: _Theme(0xFF4DB33B, 0xFF3FA131, 0xFFD2A86E, 0xFFC69C63, 0xFF8A5527, 0xFFF1E2B8, 0xFFB8894F, 0xFFB5E2F5, 0xFF66C3F2),
  CrTheme.temple: _Theme(0xFFB27A42, 0xFFA06C38, 0xFFC4AF90, 0xFFB7A283, 0xFFE3BC52, 0xFF6E4524, 0xFFA48F72, 0xFFF4B070, 0xFFF08A4A),
  CrTheme.beach: _Theme(0xFFF4D99C, 0xFFEACB86, 0xFF8E939C, 0xFF868B94, 0xFFE53935, 0xFFFFFFFF, 0xFFF5F5F5, 0xFFC4EAFF, 0xFF34B8F0),
};

/// Pseudo-3D "segment road" renderer with a behind-the-kart chase camera (Mode-7-era technique used by CTR-like
/// mobile racers). Per frame: one `drawVertices` for the whole road, one `drawRawAtlas` for every sprite and
/// particle, two sky blits and the HUD. All buffers are preallocated.
class CrRenderer {
  CrRenderer(this.race, this.art) : _th = _themes[race.track.info.theme]!;

  final CrRace race;
  final CrArt art;
  final _Theme _th;
  final CrText text = CrText();

  static const int drawDist = 190;
  static const double camH = 1000;
  static const double depth = 0.84;

  // projected points (drawDist + 1)
  final Float64List _px = Float64List(drawDist + 2);
  final Float64List _py = Float64List(drawDist + 2);
  final Float64List _pw = Float64List(drawDist + 2);
  final Float64List _ps = Float64List(drawDist + 2);
  final Float64List _clip = Float64List(drawDist + 2);
  final Uint8List _vis = Uint8List(drawDist + 2);

  // road triangles: up to 14 triangles per segment
  static const int _maxTri = drawDist * 14;
  final Float32List _vPos = Float32List(_maxTri * 6);
  final Int32List _vCol = Int32List(_maxTri * 3);
  int _vn = 0;

  // sprite batch
  static const int _maxSpr = 900;
  final Float32List _sXf = Float32List(_maxSpr * 4);
  final Float32List _sRc = Float32List(_maxSpr * 4);
  final Int32List _sCol = Int32List(_maxSpr);
  int _sn = 0;

  // per-segment buckets for dynamic objects
  final Int32List _head = Int32List(drawDist + 2);
  final Int32List _next = Int32List(512);

  // particles (screen space)
  static const int _maxP = 140;
  final Float32List _pX = Float32List(_maxP), _pY = Float32List(_maxP), _pVx = Float32List(_maxP), _pVy = Float32List(_maxP);
  final Float32List _pLife = Float32List(_maxP), _pMax = Float32List(_maxP), _pSize = Float32List(_maxP);
  final Int32List _pCol = Int32List(_maxP), _pSpr = Int32List(_maxP);
  int _pNext = 0;

  // world-anchored explosions
  final Float64List _bZ = Float64List(6), _bX = Float64List(6), _bAge = Float64List(6);
  int _bNext = 0;

  final math.Random _rnd = math.Random(3);

  // camera
  double camX = 0;
  double camZ = 0;
  double camY = 0;
  double skyOff = 0;
  double shake = 0;
  double _t = 0;

  // layout
  double w = 1, h = 1, horizon = 0, f = 1, playerZ = 1000;

  final Paint _paint = Paint()..filterQuality = FilterQuality.low;
  final Paint _atlasPaint = Paint()..filterQuality = FilterQuality.low;
  final Paint _line = Paint()
    ..color = const Color(0x99FFFFFF)
    ..strokeWidth = 2;
  final Paint _fill = Paint();
  ui.Picture? _mapPic;
  double _mapSize = 0;

  void layout(double width, double height) {
    w = width;
    h = height;
    final bool land = w >= h;
    horizon = h * (land ? 0.40 : 0.44);
    f = w / 2;
    final double bottom = horizon + math.min(h * (land ? 0.46 : 0.20), w * 0.235);
    final double sp = (bottom - horizon) / (camH * f);
    playerZ = depth / sp;
  }

  // ------------------------------------------------------------------ update (camera, particles)
  void update(double dt) {
    _t += dt;
    final CrRacer p = race.player;
    final CrTrack t = race.track;
    camZ = t.wrap(p.z - playerZ);
    final double targetX = p.x * CrTrack.roadW * 0.75 + (p.drifting ? p.driftDir * 160 : 0);
    camX += (targetX - camX) * math.min(1, dt * 7);
    camY = t.heightAt(p.z) + camH + p.air * 0.35;
    skyOff += t.curveAt(p.z) * (p.speed / CrRace.maxSpeed) * dt * 0.018;
    if (shake > 0) shake = math.max(0, shake - dt * 2.5);

    // player particles: drift sparks / smoke, boost flames are drawn directly
    final double spPct = p.speed / CrRace.maxSpeed;
    final double kx = _playerScreenX();
    final double ky = _playerScreenY();
    final double kw = _kartW();
    if (p.drifting && !p.airborne) {
      final int col = _sparkColor(p);
      final bool hot = p.driftMeter >= 0.68;
      final int nSp = hot ? 3 : 2;
      for (int i = 0; i < nSp; i++) {
        final double side = i.isEven ? -1 : 1;
        _emit(kx + side * kw * 0.34, ky - kw * 0.04, (-p.driftDir * 140 + (_rnd.nextDouble() - 0.5) * 160) * (w / 800),
            (-140 - _rnd.nextDouble() * 160) * (h / 360), 0.25 + _rnd.nextDouble() * 0.15, col, CrSpr.spark,
            kw * (hot ? 0.12 : 0.085));
      }
      // tyre smoke: grey, black when the turbo window is open (the classic CTR tell)
      if (_rnd.nextDouble() < 0.7) {
        _emit(kx - p.driftDir * kw * 0.3, ky - kw * 0.05, -p.driftDir * 60 * (w / 800), -40 * (h / 360), 0.5,
            hot ? 0xCC222222 : 0x99DDDDDD, CrSpr.smoke, kw * 0.26);
      }
    } else if (spPct > 0.2 && !p.airborne && p.x.abs() > 1.08 && _rnd.nextDouble() < 0.6) {
      // off-road dust
      _emit(kx + (_rnd.nextDouble() - 0.5) * kw * 0.6, ky, (_rnd.nextDouble() - 0.5) * 80, -60, 0.6, 0xAAC8A46A, CrSpr.smoke,
          kw * 0.3);
    }
    if (p.spin > 0 && _rnd.nextDouble() < 0.5) {
      _emit(kx, ky - kw * 0.4, (_rnd.nextDouble() - 0.5) * 200, -120, 0.6, 0xAA555555, CrSpr.smoke, kw * 0.35);
    }
    for (int i = 0; i < _maxP; i++) {
      if (_pLife[i] <= 0) continue;
      _pLife[i] -= dt;
      _pX[i] += _pVx[i] * dt;
      _pY[i] += _pVy[i] * dt;
      _pVy[i] += 500 * dt * (_pSpr[i] == CrSpr.spark ? 1 : -0.1);
    }
    for (int i = 0; i < 6; i++) {
      if (_bAge[i] >= 0) _bAge[i] += dt;
      if (_bAge[i] > 0.9) _bAge[i] = -1;
    }
  }

  void _emit(double x, double y, double vx, double vy, double life, int col, int spr, double size) {
    final int i = _pNext;
    _pNext = (_pNext + 1) % _maxP;
    _pX[i] = x;
    _pY[i] = y;
    _pVx[i] = vx;
    _pVy[i] = vy;
    _pLife[i] = life;
    _pMax[i] = life;
    _pCol[i] = col;
    _pSpr[i] = spr;
    _pSize[i] = size;
  }

  void boom(double z, double x) {
    final int i = _bNext;
    _bNext = (_bNext + 1) % 6;
    _bZ[i] = z;
    _bX[i] = x;
    _bAge[i] = 0;
  }

  void burst(int color, int count) {
    final double kx = _playerScreenX(), ky = _playerScreenY(), kw = _kartW();
    for (int i = 0; i < count; i++) {
      final double a = _rnd.nextDouble() * math.pi * 2;
      final double s = 120 + _rnd.nextDouble() * 220;
      _emit(kx, ky - kw * 0.3, math.cos(a) * s, math.sin(a) * s - 120, 0.45, color, CrSpr.spark, kw * 0.1);
    }
  }

  int _sparkColor(CrRacer r) {
    switch (r.driftStage) {
      case 0:
        return 0xFF5AB8FF; // blue
      case 1:
        return 0xFFFF9A1E; // orange
      default:
        return 0xFFFF3B2F; // red
    }
  }

  double _kartW() => 860 * (depth / playerZ) * f;
  double _playerScreenX() {
    final CrRacer p = race.player;
    return w / 2 + (depth / playerZ) * (p.x * CrTrack.roadW - camX) * f;
  }

  double _playerScreenY() {
    final CrRacer p = race.player;
    final double s = depth / playerZ;
    return horizon - s * (race.track.heightAt(p.z) + p.air - camY) * f;
  }

  // ------------------------------------------------------------------ render
  void render(Canvas canvas) {
    final CrTrack t = race.track;
    final int n = t.n;
    final double sx = shake > 0 ? math.sin(_t * 70) * shake * 6 : 0;
    canvas.save();
    if (sx != 0) canvas.translate(sx, 0);

    // sky
    _fill.color = Color(_th.sky);
    canvas.drawRect(Rect.fromLTWH(-10, -10, w + 20, h + 20), _fill);
    _drawSky(canvas);

    // project
    final int base = (camZ / CrTrack.segLen).floor() % n;
    final double basePct = (camZ - base * CrTrack.segLen) / CrTrack.segLen;
    double xo = 0;
    double dx = -(t.curve[base] * basePct);
    for (int k = 0; k <= drawDist; k++) {
      final int si = (base + k) % n;
      final double z = (base + k) * CrTrack.segLen - camZ;
      final double zz = z < 1 ? 1 : z;
      final double s = depth / zz;
      _ps[k] = s;
      _px[k] = w / 2 + s * (xo - camX) * f;
      _py[k] = horizon - s * (t.y[si] - camY) * f;
      _pw[k] = s * CrTrack.roadW * f;
      xo += dx;
      dx += t.curve[si];
    }
    double maxy = h;
    for (int k = 0; k < drawDist; k++) {
      _clip[k] = maxy;
      final double z1 = (base + k) * CrTrack.segLen - camZ;
      if (z1 <= depth * 20 || _py[k + 1] >= _py[k] || _py[k + 1] >= maxy) {
        _vis[k] = 0;
        continue;
      }
      _vis[k] = 1;
      maxy = _py[k + 1];
    }

    // road, far to near
    _vn = 0;
    for (int k = drawDist - 1; k >= 0; k--) {
      if (_vis[k] == 0) continue;
      final int si = (base + k) % n;
      _segment(k, si, k / drawDist);
    }
    if (_vn > 0) {
      final ui.Vertices v = ui.Vertices.raw(ui.VertexMode.triangles, Float32List.sublistView(_vPos, 0, _vn * 6),
          colors: Int32List.sublistView(_vCol, 0, _vn * 3));
      canvas.drawVertices(v, BlendMode.dst, _paint);
      v.dispose();
    }

    // sprites, far to near
    _bucket(base, n);
    _sn = 0;
    for (int k = drawDist - 1; k >= 1; k--) {
      final int si = (base + k) % n;
      final double clip = _clip[k];
      // static props
      if (t.propA[si] >= 0) _prop(t.propA[si], t.propAX[si], k, clip);
      if (t.propB[si] >= 0) _prop(t.propB[si], t.propBX[si], k, clip);
      if (t.ramp[si] == 1) {
        _spr(CrSpr.ramp, _px[k], _py[k], _ps[k] * CrTrack.roadW * 1.5 * f, clip, 0, 0xFFFFFFFF);
      }
      int it = _head[k];
      while (it >= 0) {
        _dyn(it, k, clip);
        it = _next[it];
      }
    }
    // player kart last (nearest)
    _kart(race.player, _playerScreenX(), _playerScreenY(), depth / playerZ, h + 10, true);
    // particles
    for (int i = 0; i < _maxP; i++) {
      if (_pLife[i] <= 0) continue;
      final double a = (_pLife[i] / _pMax[i]).clamp(0.0, 1.0);
      final int c = _pCol[i];
      final int alpha = (((c >> 24) & 0xFF) * a).round();
      final double grow = _pSpr[i] == CrSpr.smoke ? (1.6 - a * 0.6) : 1;
      _spr(_pSpr[i], _pX[i], _pY[i] + _pSize[i] * grow / 2, _pSize[i] * grow, h + 10, 0, (alpha << 24) | (c & 0xFFFFFF));
    }
    _flush(canvas);

    // speed lines while boosting
    final CrRacer p = race.player;
    if (p.boostTime > 0 || p.mask > 0) {
      for (int i = 0; i < 10; i++) {
        final double a = (i * 0.618 + _t * 3.1) % 1.0;
        final double side = i.isEven ? 1 : -1;
        final double yy = h * (0.15 + 0.7 * ((i * 0.37) % 1.0));
        final double x0 = w / 2 + side * w * (0.3 + a * 0.25);
        _line.color = Color.fromARGB((120 * (1 - a)).round(), 255, 255, 255);
        canvas.drawLine(Offset(x0, yy), Offset(x0 + side * w * 0.12, yy + (yy - horizon) * 0.12), _line);
      }
    }
    canvas.restore();
  }

  void _drawSky(Canvas canvas) {
    final ui.Image? img = art.sky[race.track.info.theme];
    if (img == null) return;
    final double iw = img.width.toDouble(), ih = img.height.toDouble();
    double dh = horizon + h * 0.06;
    double dw = dh * iw / ih;
    if (dw < w * 0.75) {
      dw = w * 0.75;
      dh = dw * ih / iw;
    }
    final double top = horizon + h * 0.06 - dh;
    final Rect src = Rect.fromLTWH(0, 0, iw, ih);
    double off = (skyOff * w) % (dw * 2);
    if (off < 0) off += dw * 2;
    // mirror tiling: normal, flipped, normal… gives a seamless panorama from a non-tiling image
    for (double x = -off; x < w; x += dw) {
      final int tile = ((x + off) / dw).round();
      if (tile.isOdd) {
        canvas.save();
        canvas.translate(x + dw, 0);
        canvas.scale(-1, 1);
        canvas.drawImageRect(img, src, Rect.fromLTWH(0, top, dw + 1, dh), _paint);
        canvas.restore();
      } else {
        canvas.drawImageRect(img, src, Rect.fromLTWH(x, top, dw + 1, dh), _paint);
      }
    }
  }

  int _haze(int c, double fog) {
    if (fog <= 0) return c;
    final int hz = _th.haze;
    int ch(int sh) {
      final int a = (c >> sh) & 0xFF, b = (hz >> sh) & 0xFF;
      return (a + (b - a) * fog).round();
    }

    return 0xFF000000 | (ch(16) << 16) | (ch(8) << 8) | ch(0);
  }

  void _tri(double ax, double ay, double bx, double by, double cx, double cy, int col) {
    if (_vn >= _maxTri) return;
    final int o = _vn * 6;
    _vPos[o] = ax;
    _vPos[o + 1] = ay;
    _vPos[o + 2] = bx;
    _vPos[o + 3] = by;
    _vPos[o + 4] = cx;
    _vPos[o + 5] = cy;
    final int c = _vn * 3;
    _vCol[c] = col;
    _vCol[c + 1] = col;
    _vCol[c + 2] = col;
    _vn++;
  }

  /// Quad between a near edge (x1 ± w1 at y1) and a far edge (x2 ± w2 at y2).
  void _quad(double x1, double y1, double w1, double x2, double y2, double w2, double off1, double off2, int col) {
    final double l1 = x1 - w1 + off1, r1 = x1 + w1 + off1;
    final double l2 = x2 - w2 + off2, r2 = x2 + w2 + off2;
    _tri(l1, y1, r1, y1, r2, y2, col);
    _tri(l1, y1, r2, y2, l2, y2, col);
  }

  void _segment(int k, int si, double d) {
    final double fog = d < 0.45 ? 0 : math.min(0.7, (d - 0.45) * 1.3);
    final bool alt = (si ~/ 3).isEven;
    final double x1 = _px[k], y1 = _py[k], w1 = _pw[k];
    final double x2 = _px[k + 1], y2 = _py[k + 1], w2 = _pw[k + 1];
    // ground band
    _tri(-20, y1, w + 20, y1, w + 20, y2, _haze(alt ? _th.grass1 : _th.grass2, fog));
    _tri(-20, y1, w + 20, y2, -20, y2, _haze(alt ? _th.grass1 : _th.grass2, fog));
    // rumble strips (outer kerb)
    final int rc = _haze(alt ? _th.rumble1 : _th.rumble2, fog);
    final double r1 = w1 * 0.12, r2 = w2 * 0.12;
    _quad(x1 - w1 - r1 / 2, y1, r1 / 2, x2 - w2 - r2 / 2, y2, r2 / 2, 0, 0, rc);
    _quad(x1 + w1 + r1 / 2, y1, r1 / 2, x2 + w2 + r2 / 2, y2, r2 / 2, 0, 0, rc);
    // road
    _quad(x1, y1, w1, x2, y2, w2, 0, 0, _haze(alt ? _th.road1 : _th.road2, fog));
    // centre marks / tyre grooves
    if (alt) {
      final int lc = _haze(_th.lane, fog);
      final double l1 = w1 * 0.025, l2 = w2 * 0.025;
      if (race.track.info.theme == CrTheme.beach) {
        _quad(x1, y1, l1, x2, y2, l2, 0, 0, lc);
      } else {
        _quad(x1 - w1 * 0.38, y1, l1, x2 - w2 * 0.38, y2, l2, 0, 0, lc);
        _quad(x1 + w1 * 0.38, y1, l1, x2 + w2 * 0.38, y2, l2, 0, 0, lc);
      }
    }
  }

  void _bucket(int base, int n) {
    for (int k = 0; k < drawDist + 2; k++) {
      _head[k] = -1;
    }
    void put(int id, double z) {
      int k = (z / CrTrack.segLen).floor() - base;
      if (k < 0) k += n;
      if (k >= drawDist || k < 1) return;
      _next[id] = _head[k];
      _head[k] = id;
    }

    for (final CrRacer r in race.racers) {
      if (r.isPlayer) continue;
      put(r.index, r.z);
    }
    final List<CrPickup> pk = race.track.pickups;
    for (int i = 0; i < pk.length && i < 180; i++) {
      if (pk[i].respawn > 0) continue;
      put(100 + i, pk[i].seg * CrTrack.segLen + 1);
    }
    for (int i = 0; i < race.projectiles.length; i++) {
      if (race.projectiles[i].active) put(300 + i, race.projectiles[i].z);
    }
    for (int i = 0; i < race.hazards.length; i++) {
      if (race.hazards[i].active) put(400 + i, race.hazards[i].z);
    }
    for (int i = 0; i < 6; i++) {
      if (_bAge[i] >= 0) put(480 + i, _bZ[i]);
    }
  }

  /// Interpolated projection of world z inside drawn segment k: returns scale; sets _ix/_iy (road centre).
  double _ix = 0, _iy = 0;
  double _at(int k, double z) {
    double local = (z % CrTrack.segLen) / CrTrack.segLen;
    if (local < 0) local += 1;
    final double s = _ps[k] + (_ps[k + 1] - _ps[k]) * local;
    _ix = _px[k] + (_px[k + 1] - _px[k]) * local;
    _iy = _py[k] + (_py[k + 1] - _py[k]) * local;
    return s;
  }

  void _dyn(int id, int k, double clip) {
    if (id < 100) {
      final CrRacer r = race.racers[id];
      final double s = _at(k, r.z);
      final double x = _ix + s * r.x * CrTrack.roadW * f;
      _kart(r, x, _iy - s * r.air * f, s, clip, false);
    } else if (id < 300) {
      final CrPickup p = race.track.pickups[id - 100];
      final double s = _ps[k];
      final double x = _px[k] + s * p.x * CrTrack.roadW * f;
      final double bob = math.sin(_t * 4 + p.seg) * 40;
      if (p.kind == CrPickupKind.box) {
        _spr(CrSpr.shadow, x, _py[k], s * 420 * f, clip, 0, 0xFFFFFFFF);
        _spr(CrSpr.box, x, _py[k] - s * (120 + bob) * f, s * 420 * f, clip, math.sin(_t * 2 + p.seg) * 0.12, 0xFFFFFFFF);
      } else {
        _spr(CrSpr.fruit, x, _py[k] - s * (140 + bob) * f, s * 280 * f, clip, math.sin(_t * 3 + p.seg) * 0.25, 0xFFFFFFFF);
      }
    } else if (id < 400) {
      final CrProjectile p = race.projectiles[id - 300];
      final double s = _at(k, p.z);
      final double x = _ix + s * p.x * CrTrack.roadW * f;
      if (p.kind == CrItem.rocket) {
        _spr(CrSpr.flame, x, _iy - s * 60 * f, s * 200 * f, clip, math.pi, 0xFFFF8A1E);
        _spr(CrSpr.rocket, x, _iy - s * 120 * f, s * 420 * f, clip, -math.pi / 2, 0xFFFFFFFF);
      } else {
        _spr(CrSpr.shadow, x, _iy, s * 360 * f, clip, 0, 0xFFFFFFFF);
        _spr(CrSpr.bowlbomb, x, _iy, s * 330 * f, clip, p.age * 9, 0xFFFFFFFF);
      }
    } else if (id < 480) {
      final CrHazard hz = race.hazards[id - 400];
      final double s = _at(k, hz.z);
      final double x = _ix + s * hz.x * CrTrack.roadW * f;
      _spr(CrSpr.shadow, x, _iy, s * 420 * f, clip, 0, 0xFFFFFFFF);
      _spr(CrSpr.crate, x, _iy, s * 400 * f, clip, 0, 0xFFFFFFFF);
    } else {
      final int i = id - 480;
      final double s = _at(k, _bZ[i]);
      final double x = _ix + s * _bX[i] * CrTrack.roadW * f;
      final double a = _bAge[i] / 0.9;
      final int alpha = (255 * (1 - a)).round().clamp(0, 255);
      _spr(CrSpr.smoke, x, _iy, s * (500 + 1400 * a) * f, clip, 0, (alpha << 24) | 0xFF7A1A);
      _spr(CrSpr.spark, x, _iy - s * 200 * f, s * (400 + 900 * a) * f, clip, 0, (alpha << 24) | 0xFFE08A);
    }
  }

  void _prop(int prop, double px, int k, double clip) {
    const List<double> width = <double>[1500, 520, 380, 1100, 1700, 2000, 1500];
    final double s = _ps[k];
    final double x = _px[k] + s * px * CrTrack.roadW * f;
    _spr(CrSpr.prop0 + prop, x, _py[k], s * width[prop] * f, clip, 0, 0xFFFFFFFF);
  }

  void _kart(CrRacer r, double x, double y, double s, double clip, bool me) {
    final double kw = 860 * s * f;
    final double groundY = me ? y + s * r.air * f : y + s * r.air * f;
    // shadow on the road
    final double shScale = 1 / (1 + r.air / 900);
    _spr(CrSpr.shadow, x, groundY + kw * 0.06, kw * 1.05 * shScale, clip, 0, 0xFFFFFFFF);
    double rot = r.steerVis * 0.06;
    double ox = 0;
    if (r.drifting) {
      rot = r.driftDir * 0.16 + math.sin(_t * 30) * 0.012;
      ox = -r.driftDir * kw * 0.05;
    }
    if (r.spin > 0) rot = r.spin * 9;
    final double bounce = r.airborne ? 0 : math.sin(_t * 22 + r.index) * kw * 0.006 * (r.speed / CrRace.maxSpeed);
    // boost flames behind the exhausts
    if (r.boostTime > 0) {
      final int fc = switch (r.boostLevel) {
        1 => 0xFF4FB0FF,
        2 => 0xFFFF9A1E,
        3 => 0xFFFF3B2F,
        _ => 0xFFFFE04A,
      };
      final double fl = kw * (0.22 + 0.05 * math.sin(_t * 40));
      _spr(CrSpr.flame, x + ox - kw * 0.13, y - kw * 0.2 + fl, fl * 0.5, clip, math.pi, fc);
      _spr(CrSpr.flame, x + ox + kw * 0.13, y - kw * 0.2 + fl, fl * 0.5, clip, math.pi, fc);
    }
    final int col = r.hitFlash > 0 && (_t * 20).floor().isEven ? 0xFFFF8080 : 0xFFFFFFFF;
    _spr(CrSpr.kart0 + r.character, x + ox, y + bounce, kw, clip, rot, col);
    // drift sparks for opponents (the player's are particles)
    if (!me && r.drifting && kw > 6) {
      final int sc = _sparkColor(r);
      for (int i = 0; i < 2; i++) {
        _spr(CrSpr.spark, x - kw * 0.32 + i * kw * 0.64 + (_rnd.nextDouble() - 0.5) * kw * 0.1, y - kw * 0.02,
            kw * 0.14 * (0.6 + _rnd.nextDouble() * 0.6), clip, 0, sc);
      }
    }
    if (r.shield > 0) {
      final int a = r.shield < 1.5 && (_t * 10).floor().isEven ? 0x55 : 0xAA;
      _spr(CrSpr.shield, x + ox, y + kw * 0.12, kw * 1.35, clip, 0, (a << 24) | 0xFFFFFF);
    }
    if (r.mask > 0) {
      final double mw = kw * 0.55;
      final double mx = x + ox + kw * 0.55 * math.cos(_t * 5);
      final double my = y - kw * 0.75 + math.sin(_t * 7) * kw * 0.05;
      _spr(CrSpr.spark, mx, my + mw * 0.6, mw * 1.6, clip, 0, 0x88FFE070);
      _spr(CrSpr.mask, mx, my, mw, clip, math.sin(_t * 5) * 0.2, 0xFFFFFFFF);
    }
  }

  /// Queues one atlas sprite: bottom-centre at (x, y), width [dw], cropped at [clip], rotated about its centre.
  void _spr(int id, double x, double y, double dw, double clip, double rot, int color) {
    if (_sn >= _maxSpr || dw < 1) return;
    final double aw = art.rect[id * 4 + 2], ah = art.rect[id * 4 + 3];
    final double scale = dw / aw;
    final double dh = ah * scale;
    final double top = y - dh;
    if (top >= clip || x + dw / 2 < 0 || x - dw / 2 > w || y < 0 && top < -dh) return;
    double srcH = ah;
    if (y > clip) {
      srcH = (clip - top) / scale;
      if (srcH <= 0.5) return;
    }
    final int o = _sn * 4;
    _sRc[o] = art.rect[id * 4];
    _sRc[o + 1] = art.rect[id * 4 + 1];
    _sRc[o + 2] = art.rect[id * 4] + aw;
    _sRc[o + 3] = art.rect[id * 4 + 1] + srcH;
    // RSTransform about the sprite's centre (anchor at aw/2, ah/2 in source space)
    final double sc = math.cos(rot) * scale, ss = math.sin(rot) * scale;
    final double ax = aw / 2, ay = ah / 2;
    final double cx = x, cy = top + dh / 2;
    _sXf[o] = sc;
    _sXf[o + 1] = ss;
    _sXf[o + 2] = cx - sc * ax + ss * ay;
    _sXf[o + 3] = cy - ss * ax - sc * ay;
    _sCol[_sn] = color;
    _sn++;
  }

  void _flush(Canvas canvas) {
    if (_sn == 0) return;
    canvas.drawRawAtlas(art.atlas, Float32List.sublistView(_sXf, 0, _sn * 4), Float32List.sublistView(_sRc, 0, _sn * 4),
        Int32List.sublistView(_sCol, 0, _sn), BlendMode.modulate, null, _atlasPaint);
    _sn = 0;
  }

  // ------------------------------------------------------------------ HUD
  /// Head-up display: position, lap, timer, fruit counter, item slot, drift meter and the minimap.
  void hud(Canvas canvas, {required double padTop, required double padLeft, required double padRight, required bool fa}) {
    final CrRacer p = race.player;
    final double u = math.min(w, h * 1.9) / 800; // unit scale
    // position (top-left, after the pause button)
    final double px0 = padLeft + 64 * u;
    text.draw(canvas, CrText.digits('${p.place}', fa), px0, padTop + 4 * u, 54 * u, CrText.gold, align: 0);
    final double pw = text.lastWidth;
    text.draw(canvas, fa ? '/۶' : '/6', px0 + pw + 4 * u, padTop + 28 * u, 22 * u, CrText.white, align: 0);
    // lap + time (top-right)
    final double rx = w - padRight - 14 * u;
    final int lap = p.lap.clamp(1, CrTrack.laps);
    text.draw(canvas, fa ? 'دور ${CrText.digits('$lap', fa)}/${CrText.digits('${CrTrack.laps}', fa)}' : 'LAP $lap/${CrTrack.laps}', rx,
        padTop + 6 * u, 26 * u, CrText.white,
        align: 2);
    text.clock(canvas, p.finished ? p.finishTime : race.time, rx, padTop + 40 * u, 22 * u, fa);
    // item slot (top-centre)
    final double cx = w / 2, cy = padTop + 40 * u, box = 64 * u;
    final RRect rr = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, cy), width: box, height: box), Radius.circular(14 * u));
    _fill.color = const Color(0x99101830);
    canvas.drawRRect(rr, _fill);
    _fill
      ..color = const Color(0xFFFFD34E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u;
    canvas.drawRRect(rr, _fill);
    _fill.style = PaintingStyle.fill;
    int icon = -1;
    if (p.roulette > 0) {
      const List<int> cyc = <int>[CrSpr.rocket, CrSpr.bowlbomb, CrSpr.crate, CrSpr.nitro, CrSpr.shield, CrSpr.mask];
      icon = cyc[(_t * 14).floor() % cyc.length];
    } else {
      icon = switch (p.item) {
        CrItem.rocket => CrSpr.rocket,
        CrItem.bowlbomb => CrSpr.bowlbomb,
        CrItem.crate => CrSpr.crate,
        CrItem.nitro => CrSpr.nitro,
        CrItem.shield => CrSpr.shield,
        CrItem.mask => CrSpr.mask,
        CrItem.none => -1,
      };
    }
    if (icon >= 0) {
      _spr(icon, cx, cy + box * 0.36, box * 0.78, h + 10, 0, 0xFFFFFFFF);
    }
    // fruit counter (bottom-left above the steering buttons → top-left under the position)
    final double fy = padTop + 70 * u;
    _spr(CrSpr.fruit, px0 + 16 * u, fy + 30 * u, 30 * u, h + 10, 0, 0xFFFFFFFF);
    text.draw(canvas, '× ${CrText.digits('${p.fruit}', fa)}', px0 + 36 * u, fy + 4 * u, 24 * u,
        p.fruit >= 10 ? CrText.gold : CrText.white,
        align: 0);
    _flush(canvas);
    // drift heat meter under the kart while sliding
    if (p.drifting) {
      final double mw = 120 * u, mh = 10 * u;
      final double mx = w / 2 - mw / 2, my = h - 22 * u;
      _fill.color = const Color(0xAA000000);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(mx - 2, my - 2, mw + 4, mh + 4), Radius.circular(mh)), _fill);
      _fill.color = const Color(0x5539FF6A);
      canvas.drawRect(Rect.fromLTWH(mx + mw * 0.68, my, mw * 0.32, mh), _fill);
      _fill.color = Color(_sparkColor(p));
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(mx, my, mw * p.driftMeter.clamp(0.0, 1.0), mh), Radius.circular(mh / 2)), _fill);
      for (int i = 0; i < 3; i++) {
        _fill.color = i < p.driftStage ? const Color(0xFFFFE04A) : const Color(0x55FFFFFF);
        canvas.drawCircle(Offset(mx + mw + 12 * u + i * 12 * u, my + mh / 2), 4 * u, _fill);
      }
    }
    _minimap(canvas, w - padRight - 120 * u, h * 0.30, 104 * u);
  }

  void _minimap(Canvas canvas, double x, double y, double size) {
    final CrTrack t = race.track;
    if (_mapPic == null || (_mapSize - size).abs() > 0.5) {
      _mapPic?.dispose();
      final ui.PictureRecorder rec = ui.PictureRecorder();
      final Canvas c = Canvas(rec);
      final Path path = Path();
      for (int i = 0; i < t.n; i += 2) {
        final double mx = t.mapX[i] * size, my = t.mapY[i] * size;
        if (i == 0) {
          path.moveTo(mx, my);
        } else {
          path.lineTo(mx, my);
        }
      }
      path.close();
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.075
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0x88000000));
      c.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = size * 0.04
            ..strokeJoin = StrokeJoin.round
            ..color = const Color(0xDDFFFFFF));
      final int s0 = CrTrack.startSeg;
      c.drawCircle(Offset(t.mapX[s0] * size, t.mapY[s0] * size), size * 0.04, Paint()..color = const Color(0xFF222222));
      _mapPic = rec.endRecording();
      _mapSize = size;
    }
    canvas.save();
    canvas.translate(x, y);
    canvas.drawPicture(_mapPic!);
    for (int i = race.racers.length - 1; i >= 0; i--) {
      final CrRacer r = race.racers[i];
      final int si = t.segIndex(r.z);
      _fill.color = Color(kCrCharacters[r.character].color);
      final double rad = r.isPlayer ? size * 0.06 : size * 0.042;
      canvas.drawCircle(Offset(t.mapX[si] * size, t.mapY[si] * size), rad, _fill);
      if (r.isPlayer) {
        _fill
          ..color = const Color(0xFFFFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        canvas.drawCircle(Offset(t.mapX[si] * size, t.mapY[si] * size), rad, _fill);
        _fill.style = PaintingStyle.fill;
      }
    }
    canvas.restore();
  }

  void dispose() {
    _mapPic?.dispose();
    text.dispose();
  }
}

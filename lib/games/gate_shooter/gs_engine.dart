import 'dart:math' as math;

import 'gs_meta.dart';

/// ===================== GATE SHOOTER ENGINE =====================
/// Pure, deterministic simulation of دونده‌ی تیرانداز: a squad runs down a desert highway, auto-fires,
/// breaks numbered barrels / crates, guns down enemy squads, picks a side at every +/× gate and meets a boss
/// every third wave. No Flutter here: the board reads the state and the [events] queue for FX and audio.
///
/// World units: x across the road (road half-width [roadHalf]), z ahead of the squad leader (the squad stays
/// at z≈0 and the world scrolls toward it), y height above the asphalt.
/// ===============================================================

enum GsPhase { lobby, run, boss, dying, over }

enum GsKind { barrel, crate, enemy, boss }

enum GateOp { add, sub, mul, power, rate, heal }

enum GsEv {
  shot,
  hit,
  gateHit,
  kill,
  explode,
  smash,
  coin,
  gateGood,
  gateBad,
  soldierLost,
  hurt,
  enemyShot,
  bossIntro,
  bossDown,
  bossShot,
  waveClear,
  dead,
}

class GsEvent {
  GsEvent(this.type, this.x, this.z, {this.y = 0, this.value = 0, this.kind, this.text});
  final GsEv type;
  final double x, z, y;
  final double value;
  final GsKind? kind;
  final String? text;
}

class GsTarget {
  GsTarget(this.kind, this.x, this.z, this.hp, {this.half = 0.9, this.speed = 0})
      : maxHp = hp,
        phase = (x * 7.3 + z * 1.9).abs() % 1;
  final GsKind kind;
  double x, z;
  double hp;
  final double maxHp;
  final double half;
  double speed;
  double flash = 0;
  double wobble = 0;
  double fireCd = 2;
  double phase;
  double stomp = 0;
  bool dead = false;
}

class GsGateSide {
  GsGateSide(this.op, this.value, this.x0, this.x1);
  GateOp op;
  int value;
  final double x0, x1;
  int hits = 0;
  double flash = 0;
  double bump = 0;

  bool get good => op != GateOp.sub;

  double get cx => (x0 + x1) / 2;
}

class GsGate {
  GsGate(this.z, this.sides);
  double z;
  final List<GsGateSide> sides;
  bool passed = false;
  int chosen = -1;
  double fade = 0;
}

class GsBullet {
  GsBullet(this.x, this.z, this.vx, this.vz, this.dmg, {this.y = 1.1, this.enemy = false, this.big = false});
  double x, z, y;
  double vx, vz;
  final double dmg;
  final bool enemy;
  final bool big;
  double life = 0;
  bool dead = false;
}

class GsSoldier {
  GsSoldier(this.x, this.z, this.phase);
  double x, z;
  double phase;
  double flash = 0;
  double pop = 0; // spawn scale-in 0→1
}

/// A side prop (cactus / rocks / post) scrolling past the road.
class GsProp {
  GsProp(this.kind, this.x, this.z, this.scale);
  final int kind; // 0 cactus, 1 rocks, 2 sign post
  final double x;
  double z;
  final double scale;
}

class GsEngine {
  GsEngine({required this.seed, required this.meta}) : rnd = math.Random(seed) {
    reset();
  }

  final int seed;
  final GsMeta meta;
  math.Random rnd;

  static const double roadHalf = 4.0;
  static const double spawnZ = 92;
  static const double bulletRange = 66;
  static const int maxSoldiers = 90;

  GsPhase phase = GsPhase.lobby;
  final List<GsTarget> targets = <GsTarget>[];
  final List<GsGate> gates = <GsGate>[];
  final List<GsBullet> bullets = <GsBullet>[];
  final List<GsSoldier> soldiers = <GsSoldier>[];
  final List<GsProp> props = <GsProp>[];
  final List<GsEvent> events = <GsEvent>[];

  double px = 0; // leader x
  double steer = 0; // requested x
  double speed = 0; // current scroll speed m/s
  double distance = 0; // total meters
  double time = 0; // run seconds
  double health = 100;
  double maxHealth = 100;
  double power = 1;
  double rate = 6;
  int streams = 1;
  int wave = 1;
  double waveStart = 0;
  double waveLen = 260;
  int kills = 0;
  int coins = 0;
  int score = 0;
  int gatesTaken = 0;
  int bossesDown = 0;
  double fireCd = 0;
  int shooterCursor = 0;
  double hurtFlash = 0;
  double dyingT = 0;
  double bannerT = 0;
  String banner = '';
  String bannerEn = '';
  double _nextSpawn = 40;
  double _nextProp = 0;
  int _segment = 0;
  bool bossActive = false;
  GsTarget? boss;
  double _distScoreAcc = 0;
  double statPulse = 0;
  GsStat? pulsed;

  /// Soldier sprite scale: the crowd shrinks a little as it grows so a big squad still fits the road.
  double get unitScale => (1.0 - 0.011 * (soldiers.length - 1)).clamp(0.55, 1.0);
  double get spacing => 0.78 * unitScale;
  double get squadRadius => soldiers.length <= 1 ? 0.55 : spacing * math.sqrt(soldiers.length.toDouble()) * 0.62 + 0.45;
  double get waveProgress => ((distance - waveStart) / waveLen).clamp(0.0, 1.0);
  double get waveMeters => (distance - waveStart).clamp(0, waveLen);
  bool get isBossWave => wave % 3 == 0;
  double get baseSpeed => 9.0 + math.min(5.0, (wave - 1) * 0.45);

  void reset() {
    rnd = math.Random(seed);
    phase = GsPhase.lobby;
    targets.clear();
    gates.clear();
    bullets.clear();
    soldiers.clear();
    props.clear();
    events.clear();
    px = 0;
    steer = 0;
    speed = 0;
    distance = 0;
    time = 0;
    maxHealth = 100;
    health = maxHealth;
    power = meta.basePower;
    rate = meta.baseRate;
    streams = meta.bulletStreams;
    wave = 1;
    waveStart = 0;
    waveLen = 240;
    kills = 0;
    coins = 0;
    score = 0;
    gatesTaken = 0;
    bossesDown = 0;
    fireCd = 0;
    hurtFlash = 0;
    dyingT = 0;
    bannerT = 0;
    _nextSpawn = 34;
    _segment = 0;
    bossActive = false;
    boss = null;
    _distScoreAcc = 0;
    for (int i = 0; i < meta.baseSoldiers; i++) {
      _addSoldier(pop: 1);
    }
    // Pre-populate the side scenery so the lobby view is not empty.
    _nextProp = -4;
    while (_nextProp < spawnZ) {
      _spawnProp(_nextProp);
      _nextProp += 5 + rnd.nextDouble() * 6;
    }
    _nextProp -= distance;
    // A first row of content already visible in the lobby.
    _fillAhead();
  }

  /// Re-reads the upgrade levels while still in the lobby (after a purchase).
  void applyMeta(GsStat s) {
    if (phase != GsPhase.lobby) return;
    power = meta.basePower;
    rate = meta.baseRate;
    streams = meta.bulletStreams;
    while (soldiers.length < meta.baseSoldiers) {
      _addSoldier();
    }
    pulsed = s;
    statPulse = 1;
  }

  void start() {
    if (phase != GsPhase.lobby) return;
    phase = GsPhase.run;
    banner = 'موج ۱';
    bannerEn = 'WAVE 1';
    bannerT = 1.6;
  }

  // ------------------------------------------------------------------ spawning
  void _spawnProp(double z) {
    final bool left = rnd.nextBool();
    final double side = left ? -1 : 1;
    final double r = rnd.nextDouble();
    final int kind = r < 0.55 ? 0 : (r < 0.9 ? 1 : 2);
    final double x = side * (roadHalf + 2.6 + rnd.nextDouble() * (kind == 2 ? 0.4 : 9));
    props.add(GsProp(kind, x, z, 0.75 + rnd.nextDouble() * 0.6));
  }

  void _fillAhead() {
    while (_nextSpawn < spawnZ) {
      _spawnSegment(_nextSpawn);
    }
  }

  double _hpBase() => 7.0 * math.pow(1.34, wave - 1) * (1 + 0.15 * (meta.level(GsStat.power) - 1));

  void _spawnSegment(double z) {
    _segment++;
    final double waveLeft = waveLen - (distance + z - waveStart);
    if (waveLeft < 12) {
      // leave the tail of the wave empty for the checkpoint / boss arena
      _nextSpawn = z + 14;
      return;
    }
    final int pick = _segment % 3 == 0 ? 2 : (rnd.nextDouble() < 0.5 ? 0 : 1);
    switch (pick) {
      case 0: // block row
        final int count = 1 + rnd.nextInt(wave < 2 ? 2 : 3);
        final List<double> xs = count == 1
            ? <double>[(rnd.nextDouble() - 0.5) * 4.4]
            : count == 2
                ? <double>[-1.7 - rnd.nextDouble() * 0.6, 1.7 + rnd.nextDouble() * 0.6]
                : <double>[-2.7, 0, 2.7];
        for (final double x in xs) {
          final bool barrel = rnd.nextDouble() < 0.58;
          final double hp = (_hpBase() * (0.6 + rnd.nextDouble() * 1.4)).roundToDouble().clamp(3, 1e9);
          targets.add(GsTarget(barrel ? GsKind.barrel : GsKind.crate, x, z + rnd.nextDouble() * 2, hp, half: barrel ? 0.78 : 0.95));
        }
        _nextSpawn = z + 20 + rnd.nextDouble() * 8;
      case 1: // enemy squad
        final int n = math.min(14, 3 + wave + rnd.nextInt(3));
        final double cx = (rnd.nextDouble() - 0.5) * 3.6;
        for (int i = 0; i < n; i++) {
          final double a = i * 2.39996;
          final double r = 0.75 * math.sqrt(i.toDouble());
          final double hp = (1.5 + wave * 1.1) * (0.8 + rnd.nextDouble() * 0.5);
          final GsTarget e = GsTarget(GsKind.enemy, (cx + math.cos(a) * r).clamp(-roadHalf + 0.6, roadHalf - 0.6),
              z + math.sin(a) * r + r, hp.roundToDouble(),
              half: 0.48, speed: 1.4 + rnd.nextDouble() * 0.6 + wave * 0.08);
          e.fireCd = 1.2 + rnd.nextDouble() * 3;
          targets.add(e);
        }
        _nextSpawn = z + 24 + rnd.nextDouble() * 6;
      default: // gate pair
        gates.add(GsGate(z, <GsGateSide>[_rollGate(true, -roadHalf, -0.08), _rollGate(false, 0.08, roadHalf)]));
        _nextSpawn = z + 22 + rnd.nextDouble() * 6;
    }
  }

  GsGateSide _rollGate(bool first, double x0, double x1) {
    final double r = rnd.nextDouble();
    // Mostly good gates; one side of roughly a third of the pairs is a red trap.
    if (r < 0.2 && !first) return GsGateSide(GateOp.sub, 2 + rnd.nextInt(3 + wave), x0, x1);
    if (r < 0.3) return GsGateSide(GateOp.mul, 2, x0, x1);
    if (r < 0.6) return GsGateSide(GateOp.add, 2 + rnd.nextInt(3 + wave * 2), x0, x1);
    if (r < 0.74) return GsGateSide(GateOp.power, 1 + rnd.nextInt(3), x0, x1);
    if (r < 0.88) return GsGateSide(GateOp.rate, 1 + rnd.nextInt(3), x0, x1);
    if (r < 0.94 && health < maxHealth) return GsGateSide(GateOp.heal, 2 + rnd.nextInt(3), x0, x1);
    return GsGateSide(GateOp.sub, 1 + rnd.nextInt(2 + wave), x0, x1);
  }

  void _spawnBoss() {
    final int idx = wave ~/ 3;
    final double hp = (_hpBase() * 26 * (1 + 0.35 * (idx - 1))).roundToDouble();
    final GsTarget b = GsTarget(GsKind.boss, 0, 40, hp, half: 1.9, speed: 1.1 + idx * 0.15);
    b.fireCd = 2.4;
    targets.add(b);
    boss = b;
    bossActive = true;
    phase = GsPhase.boss;
    banner = 'غول آخر!';
    bannerEn = 'BOSS!';
    bannerT = 1.8;
    events.add(GsEvent(GsEv.bossIntro, 0, 40));
  }

  // ------------------------------------------------------------------ squad
  void _addSoldier({double pop = 0}) {
    if (soldiers.length >= maxSoldiers) {
      power += 0.05;
      return;
    }
    final int i = soldiers.length;
    final (double ox, double oz) = slot(i);
    soldiers.add(GsSoldier(px + ox, oz - 0.6, rnd.nextDouble())..pop = pop);
  }

  void _removeSoldier() {
    if (soldiers.length <= 1) return;
    final GsSoldier s = soldiers.removeLast();
    events.add(GsEvent(GsEv.soldierLost, s.x, s.z));
  }

  /// Formation offset of soldier [i] (sunflower packing, slightly flattened in depth).
  (double, double) slot(int i) {
    if (i == 0) return (0, 0);
    final double a = i * 2.39996323;
    final double r = spacing * math.sqrt(i.toDouble()) * 0.62;
    return (math.cos(a) * r, math.sin(a) * r * 0.75);
  }

  // ------------------------------------------------------------------ update
  void update(double dt) {
    if (phase == GsPhase.over) return;
    if (phase == GsPhase.dying) {
      dyingT += dt;
      _updateBullets(dt * 0.25);
      if (dyingT > 1.1) phase = GsPhase.over;
      return;
    }
    statPulse = math.max(0, statPulse - dt * 2.2);
    bannerT = math.max(0, bannerT - dt);
    hurtFlash = math.max(0, hurtFlash - dt * 2.5);

    // steering (also in the lobby so the drag-to-start feels alive)
    final double lim = roadHalf - math.min(roadHalf - 0.6, squadRadius * 0.95) - 0.35;
    steer = steer.clamp(-lim, lim);
    px += (steer - px) * math.min(1, dt * 14);
    _updateSquad(dt);
    if (phase == GsPhase.lobby) {
      for (final GsTarget t in targets) {
        t.phase += dt;
      }
      return;
    }

    time += dt;
    final double want = phase == GsPhase.boss ? 0 : baseSpeed;
    speed += (want - speed) * math.min(1, dt * (phase == GsPhase.boss ? 2.2 : 1.4));
    final double dz = speed * dt;
    distance += dz;
    _distScoreAcc += dz;
    if (_distScoreAcc >= 1) {
      final int m = _distScoreAcc.floor();
      score += m;
      _distScoreAcc -= m;
    }

    for (final GsProp p in props) {
      p.z -= dz;
    }
    props.removeWhere((GsProp p) => p.z < -8);
    _nextProp -= dz;
    while (_nextProp < spawnZ) {
      _spawnProp(_nextProp);
      _nextProp += 4 + rnd.nextDouble() * 7;
    }

    for (final GsGate g in gates) {
      g.z -= dz;
    }
    for (final GsTarget t in targets) {
      t.z -= dz;
    }
    _nextSpawn -= dz;
    if (phase == GsPhase.run) _fillAhead();

    _updateTargets(dt);
    _updateGates(dt);
    _fire(dt);
    _updateBullets(dt);

    // wave end
    if (phase == GsPhase.run && distance - waveStart >= waveLen) {
      if (isBossWave && !bossActive) {
        _spawnBoss();
      } else if (!isBossWave) {
        _nextWave();
      }
    }
    if (health <= 0) _die();
  }

  void _nextWave() {
    events.add(GsEvent(GsEv.waveClear, px, 2, value: wave.toDouble()));
    final int bonus = 10 + wave * 5;
    coins += bonus;
    score += 50 * wave;
    wave++;
    waveStart = distance;
    waveLen = 240.0 + math.min(200, wave * 22);
    banner = 'موج ${gsFa(wave)}';
    bannerEn = 'WAVE $wave';
    bannerT = 1.8;
  }

  void _updateSquad(double dt) {
    for (int i = 0; i < soldiers.length; i++) {
      final GsSoldier s = soldiers[i];
      final (double ox, double oz) = slot(i);
      final double k = math.min(1, dt * (i == 0 ? 16 : 9));
      s.x += (px + ox - s.x) * k;
      s.z += (oz - s.z) * k;
      s.phase += dt * (phase == GsPhase.lobby ? 0.0 : (1.6 + speed * 0.12));
      s.flash = math.max(0, s.flash - dt * 9);
      s.pop = math.min(1, s.pop + dt * 4);
    }
  }

  void _fire(double dt) {
    if (soldiers.isEmpty) return;
    fireCd -= dt;
    final int shooters = math.min(soldiers.length, 7);
    final double interval = 1 / (rate * shooters);
    final double perBullet = power * math.max(1, soldiers.length / shooters) * (phase == GsPhase.boss ? 1 : 1);
    int guard = 0;
    while (fireCd <= 0 && guard < 6) {
      guard++;
      fireCd += interval;
      if (bullets.length > 170) continue;
      shooterCursor = (shooterCursor + 1) % shooters;
      // Shooters rotate through the front of the squad (lowest index = front/centre of the blob).
      final GsSoldier s = soldiers[(shooterCursor * 7919) % math.min(soldiers.length, 24)];
      s.flash = 1;
      final double mx = s.x + 0.34 * unitScale;
      final double mz = s.z + 0.4;
      for (int k = 0; k < streams; k++) {
        final double off = (k - (streams - 1) / 2) * 0.32;
        final double spread = (k - (streams - 1) / 2) * 0.9;
        bullets.add(GsBullet(mx + off, mz, spread, 72, perBullet / math.sqrt(streams.toDouble()) * (1 + 0.25 * (streams - 1))));
      }
      events.add(GsEvent(GsEv.shot, mx, mz));
    }
  }

  void _updateBullets(double dt) {
    for (final GsBullet b in bullets) {
      if (b.dead) continue;
      final double oz = b.z;
      b.x += b.vx * dt;
      b.z += b.vz * dt;
      b.life += dt;
      if (!b.enemy) {
        b.z -= speed * dt * 0; // bullets already outrun the scroll
        if (b.z > bulletRange || b.x.abs() > roadHalf + 1) {
          b.dead = true;
          continue;
        }
        // gates absorb bullets (and grow their number)
        for (final GsGate g in gates) {
          if (g.passed) continue;
          if (g.z >= oz && g.z <= b.z + 0.2) {
            for (final GsGateSide sd in g.sides) {
              if (b.x >= sd.x0 && b.x <= sd.x1) {
                b.dead = true;
                _gateHit(g, sd);
              }
            }
          }
          if (b.dead) break;
        }
        if (b.dead) continue;
        for (final GsTarget t in targets) {
          if (t.dead) continue;
          final double depth = t.kind == GsKind.boss ? 1.2 : 0.6;
          if ((b.x - t.x).abs() <= t.half && t.z + depth >= oz && t.z - depth <= b.z) {
            b.dead = true;
            _damage(t, b.dmg, b.x);
            break;
          }
        }
      } else {
        b.z -= speed * dt;
        if (b.z < -3 || b.life > 4) {
          b.dead = true;
          continue;
        }
        if (phase != GsPhase.dying && b.z <= 0.6 && b.z >= -0.8 && (b.x - px).abs() <= squadRadius + 0.2) {
          b.dead = true;
          _hurt(b.big ? 9 : 5, b.x, 0.3);
        }
      }
    }
    bullets.removeWhere((GsBullet b) => b.dead);
  }

  void _gateHit(GsGate g, GsGateSide sd) {
    sd.hits++;
    sd.flash = 1;
    events.add(GsEvent(GsEv.gateHit, sd.cx, g.z));
    final int need = switch (sd.op) {
      GateOp.mul => 1 << 30,
      GateOp.sub => 3,
      GateOp.add => 4 + sd.value ~/ 3,
      GateOp.power || GateOp.rate || GateOp.heal => 10 + sd.value * 4,
    };
    if (sd.hits >= need) {
      sd.hits = 0;
      sd.bump = 1;
      if (sd.op == GateOp.sub) {
        sd.value--;
        if (sd.value <= 0) {
          sd.op = GateOp.add;
          sd.value = 1;
        }
      } else {
        sd.value++;
      }
    }
  }

  void _damage(GsTarget t, double dmg, double hx) {
    t.hp -= dmg;
    t.flash = 1;
    t.wobble = 1;
    if (t.kind == GsKind.enemy) t.z += 0.05; // knock-back
    events.add(GsEvent(GsEv.hit, hx, t.z, y: t.kind == GsKind.boss ? 2.5 : 1.0, kind: t.kind));
    if (t.hp <= 0) _kill(t);
  }

  void _kill(GsTarget t) {
    if (t.dead) return;
    t.dead = true;
    kills++;
    switch (t.kind) {
      case GsKind.barrel:
        final int c = 1 + (t.maxHp / 8).round();
        coins += c;
        score += (t.maxHp * 2).round();
        events.add(GsEvent(GsEv.explode, t.x, t.z, value: c.toDouble(), kind: t.kind));
        // chain reaction: barrels splash the neighbourhood
        for (final GsTarget o in targets) {
          if (o.dead || identical(o, t) || o.kind == GsKind.boss) continue;
          final double dx = o.x - t.x, dz = o.z - t.z;
          if (dx * dx + dz * dz < 2.8 * 2.8) {
            o.hp -= math.max(t.maxHp * 0.5, power * 6);
            o.flash = 1;
            if (o.hp <= 0) _kill(o);
          }
        }
      case GsKind.crate:
        final int c = 1 + (t.maxHp / 6).round();
        coins += c;
        score += (t.maxHp * 2).round();
        events.add(GsEvent(GsEv.smash, t.x, t.z, value: c.toDouble(), kind: t.kind));
      case GsKind.enemy:
        coins += 1;
        score += 10 + wave * 2;
        events.add(GsEvent(GsEv.kill, t.x, t.z, value: 1, kind: t.kind));
      case GsKind.boss:
        final int c = 60 + 40 * (wave ~/ 3);
        coins += c;
        score += 500 * (wave ~/ 3);
        bossesDown++;
        events.add(GsEvent(GsEv.bossDown, t.x, t.z, value: c.toDouble(), kind: t.kind));
        bossActive = false;
        boss = null;
        phase = GsPhase.run;
        _nextWave();
        banner = 'غول نابود شد!';
        bannerEn = 'BOSS DOWN!';
        bannerT = 2.0;
    }
  }

  void _updateTargets(double dt) {
    for (final GsTarget t in targets) {
      if (t.dead) continue;
      t.flash = math.max(0, t.flash - dt * 7);
      t.wobble = math.max(0, t.wobble - dt * 5);
      t.phase += dt;
      switch (t.kind) {
        case GsKind.enemy:
          t.z -= t.speed * dt;
          // drift toward the squad once close
          if (t.z < 26) t.x += ((px - t.x).sign * math.min(1.2, (px - t.x).abs())) * dt * 0.8;
          t.fireCd -= dt;
          if (t.fireCd <= 0 && t.z < 42 && t.z > 6) {
            t.fireCd = 2.4 + rnd.nextDouble() * 2.6 - math.min(1.2, wave * 0.1);
            final double dx = px - t.x;
            final double tt = t.z / 20;
            bullets.add(GsBullet(t.x, t.z - 0.3, dx / tt * 0.9, -20 + speed * 0, 1, enemy: true, y: 1.0));
            events.add(GsEvent(GsEv.enemyShot, t.x, t.z));
          }
          if (t.z < 0.7 && t.z > -1.2 && (t.x - px).abs() < squadRadius + 0.4) {
            t.dead = true;
            events.add(GsEvent(GsEv.kill, t.x, t.z, value: 0, kind: t.kind));
            if (soldiers.length > 1) {
              _removeSoldier();
              _hurt(1, t.x, 0);
            } else {
              _hurt(11 + wave.toDouble(), t.x, 0.6);
            }
          }
        case GsKind.barrel:
        case GsKind.crate:
          if (t.z < 0.6 && t.z > -0.9 && (t.x - px).abs() < squadRadius + t.half * 0.8) {
            // crash: the squad pays with soldiers first, health after
            final int lose = math.min(soldiers.length - 1, math.max(1, (t.hp / (power * 3)).ceil()));
            for (int i = 0; i < lose; i++) {
              _removeSoldier();
            }
            _hurt(soldiers.length > 1 ? 4 : 14 + wave * 1.5, t.x, 0.8);
            t.hp = 0;
            t.dead = true;
            events.add(GsEvent(t.kind == GsKind.barrel ? GsEv.explode : GsEv.smash, t.x, t.z, value: 0, kind: t.kind));
          }
        case GsKind.boss:
          if (t.z > 7) {
            t.z -= t.speed * dt;
          } else {
            t.stomp -= dt;
            if (t.stomp <= 0) {
              t.stomp = 1.3;
              if (soldiers.length > 1) {
                for (int i = 0; i < math.max(1, soldiers.length ~/ 6); i++) {
                  _removeSoldier();
                }
              }
              _hurt(16, t.x, 1.0);
            }
          }
          t.x += (px * 0.6 - t.x) * dt * 0.5;
          t.fireCd -= dt;
          if (t.fireCd <= 0) {
            t.fireCd = math.max(1.2, 2.6 - (wave ~/ 3) * 0.2);
            final int n = 5 + (wave ~/ 3);
            for (int i = 0; i < n; i++) {
              final double a = (i - (n - 1) / 2) * 0.55;
              bullets.add(GsBullet(t.x + 0.8, t.z - 1, a * 1.6 + (px - t.x) / math.max(1, t.z / 16), -16, 1, enemy: true, y: 1.8, big: true));
            }
            events.add(GsEvent(GsEv.bossShot, t.x, t.z));
          }
      }
    }
    // targets that slipped past without contact
    for (final GsTarget t in targets) {
      if (!t.dead && t.z < -3) t.dead = true;
    }
    targets.removeWhere((GsTarget t) => t.dead);
  }

  void _updateGates(double dt) {
    for (final GsGate g in gates) {
      for (final GsGateSide s in g.sides) {
        s.flash = math.max(0, s.flash - dt * 6);
        s.bump = math.max(0, s.bump - dt * 4);
      }
      if (g.passed) {
        g.fade = math.min(1, g.fade + dt * 3);
        continue;
      }
      if (g.z <= 0.2) {
        g.passed = true;
        final int idx = px < 0 ? 0 : 1;
        g.chosen = idx;
        _applyGate(g.sides[idx], g.z);
      }
    }
    gates.removeWhere((GsGate g) => g.z < -6);
  }

  void _applyGate(GsGateSide s, double z) {
    gatesTaken++;
    score += 5;
    final bool good = s.good;
    switch (s.op) {
      case GateOp.add:
        for (int i = 0; i < s.value; i++) {
          _addSoldier();
        }
        pulsed = GsStat.soldiers;
      case GateOp.mul:
        final int add = soldiers.length * (s.value - 1);
        for (int i = 0; i < add; i++) {
          _addSoldier();
        }
        pulsed = GsStat.soldiers;
      case GateOp.sub:
        if (s.value >= soldiers.length) {
          final int lost = soldiers.length - 1;
          for (int i = 0; i < lost; i++) {
            _removeSoldier();
          }
          _hurt(8.0 * (s.value - lost), px, 0.6);
        } else {
          for (int i = 0; i < s.value; i++) {
            _removeSoldier();
          }
        }
        pulsed = GsStat.soldiers;
      case GateOp.power:
        power *= 1 + 0.15 * s.value;
        pulsed = GsStat.power;
      case GateOp.rate:
        rate *= 1 + 0.1 * s.value;
        pulsed = GsStat.rate;
      case GateOp.heal:
        health = math.min(maxHealth, health + s.value * 10);
    }
    statPulse = 1;
    events.add(GsEvent(good ? GsEv.gateGood : GsEv.gateBad, s.cx, z, value: s.value.toDouble(), text: gateLabel(s)));
  }

  void _hurt(double amount, double x, double shake) {
    if (phase == GsPhase.dying || phase == GsPhase.over) return;
    health = math.max(0, health - amount);
    hurtFlash = math.max(hurtFlash, 0.4 + shake * 0.6);
    events.add(GsEvent(GsEv.hurt, x, 0, value: amount));
  }

  void _die() {
    if (phase == GsPhase.dying || phase == GsPhase.over) return;
    phase = GsPhase.dying;
    dyingT = 0;
    events.add(GsEvent(GsEv.dead, px, 0));
  }

  /// Gate caption (+5, ×2, −3, +2 قدرت …).
  static String gateLabel(GsGateSide s) => switch (s.op) {
        GateOp.add => '+${gsFa(s.value)}',
        GateOp.sub => '−${gsFa(s.value)}',
        GateOp.mul => '×${gsFa(s.value)}',
        GateOp.power => '+${gsFa(s.value * 15)}٪',
        GateOp.rate => '+${gsFa(s.value * 10)}٪',
        GateOp.heal => '+${gsFa(s.value * 10)}',
      };
}

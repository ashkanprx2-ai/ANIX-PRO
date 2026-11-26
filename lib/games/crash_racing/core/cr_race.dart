import 'dart:math' as math;

import 'cr_track.dart';

/// Crash Racing race simulation (pure Dart, deterministic for a given seed and input stream).
///
/// CTR-style handling: auto-accelerate, centrifugal push in curves that plain steering cannot fully hold at top
/// speed, the power-slide (hop + slide, a heat meter that fills while sliding, a timed TURBO tap in the meter's
/// window gives a blue → orange → red boost, three per slide), ramp hang-time boosts, ? crates with items, star-mango
/// fruit (10 = higher top speed) and the guardian mask (invincibility).

enum CrItem { none, rocket, bowlbomb, crate, nitro, shield, mask }

class CrCharacter {
  const CrCharacter(this.id, this.nameFa, this.nameEn, this.classFa, this.speed, this.accel, this.turn, this.color);
  final String id;
  final String nameFa;
  final String nameEn;
  final String classFa;

  /// 1..5 stat bars.
  final int speed, accel, turn;
  final int color;
}

const List<CrCharacter> kCrCharacters = <CrCharacter>[
  CrCharacter('fox', 'فِنی روباه', 'Fenny Fox', 'متعادل', 3, 3, 3, 0xFFFF8A1E),
  CrCharacter('raccoon', 'راکی راکون', 'Rocky Raccoon', 'سرعتی', 4, 2, 3, 0xFF2F6BFF),
  CrCharacter('numbat', 'نامبو', 'Numbo', 'فرمان‌پذیر', 2, 3, 5, 0xFF7BD63A),
  CrCharacter('glider', 'گِلی پرنده', 'Gliddy', 'شتاب‌دار', 2, 5, 3, 0xFFE04FD0),
  CrCharacter('wombat', 'وامبی', 'Wombo', 'سنگین‌وزن', 5, 2, 2, 0xFFFFC21A),
  CrCharacter('quokka', 'کوکی', 'Kooky', 'شتاب‌دار', 3, 4, 3, 0xFFE53935),
];

/// Simulation events for sound / effects (consumed by the UI each frame).
abstract final class CrEv {
  static const int hop = 1;
  static const int boost1 = 2;
  static const int boost2 = 3;
  static const int boost3 = 4;
  static const int driftFail = 5;
  static const int box = 6;
  static const int fruit = 7;
  static const int hit = 8;
  static const int shieldPop = 9;
  static const int fire = 10;
  static const int land = 11;
  static const int jumpBoost = 12;
  static const int lap = 13;
  static const int finish = 14;
  static const int explode = 15;
  static const int itemReady = 16;
  static const int bump = 17;
}

class CrRacer {
  CrRacer(this.index, this.character, {required this.isPlayer});
  final int index;
  final int character;
  final bool isPlayer;

  // track position
  double z = 0;
  double x = 0;
  double dist = 0; // race progress (0 at the start line, 3 × track length at the finish)
  double speed = 0;
  int lap = 1;
  int place = 1;

  // handling
  double steer = 0; // current input -1..1
  double steerVis = 0; // smoothed, for the sprite lean
  bool drifting = false;
  int driftDir = 0;
  double driftMeter = 0;
  int driftStage = 0;
  double driftRelease = -1; // grace while the drift button is re-tapped
  double driftTime = 0;
  bool driftHeld = false;
  bool wantDrift = false; // drift was pressed: slide starts on landing from the hop

  double boostTime = 0;
  double boostPower = 1;
  int boostLevel = 0; // 1 blue, 2 orange, 3 red / ramp, 4 nitro, for the flame colour

  double air = 0;
  double vy = 0;
  double airTime = 0;
  bool bigJump = false;

  double spin = 0;
  double shield = 0;
  double mask = 0;
  double hitFlash = 0;
  int fruit = 0;
  CrItem item = CrItem.none;
  double roulette = 0;
  bool itemUsed = false;

  // timing
  double lapStart = 0;
  double bestLap = 0;
  double lastLap = 0;
  bool finished = false;
  double finishTime = 0;

  // AI
  double skill = 0.9;
  double laneBias = 0;
  double aiItemTimer = 0;
  double aiDriftBoostCd = 0;

  bool get airborne => air > 0;
  bool get invincible => mask > 0;
}

class CrProjectile {
  bool active = false;
  CrItem kind = CrItem.none;
  int owner = -1;
  int target = -1;
  double z = 0, x = 0, speed = 0, life = 0, age = 0;
}

class CrHazard {
  bool active = false;
  int owner = -1;
  double z = 0, x = 0, life = 0, age = 0;
}

class CrRace {
  CrRace({
    required this.track,
    required int playerCharacter,
    int seed = 1,
    double botSkill = 0.9,
  }) : rnd = math.Random(seed) {
    // Five opponents get the other characters.
    final List<int> others = <int>[for (int i = 0; i < kCrCharacters.length; i++) if (i != playerCharacter) i];
    // Grid: 3 rows × 2 columns behind the start line; the player starts 5th (CTR style, from the back half).
    const List<int> gridOrder = <int>[1, 2, 3, 4, 0, 5];
    for (int i = 0; i < 6; i++) {
      final bool me = i == 0;
      racers.add(CrRacer(i, me ? playerCharacter : others[i - 1], isPlayer: me));
    }
    for (int slot = 0; slot < 6; slot++) {
      final CrRacer r = racers[gridOrder[slot]];
      final int row = slot ~/ 2;
      r.z = track.startZ - 300 - row * 650;
      r.x = slot.isEven ? -0.38 : 0.38;
      r.dist = r.z - track.startZ;
      r.lap = 1;
    }
    for (final CrRacer r in racers) {
      if (r.isPlayer) continue;
      r.skill = (botSkill + (rnd.nextDouble() - 0.5) * 0.06).clamp(0.78, 1.0);
      r.laneBias = (rnd.nextDouble() - 0.5) * 0.5;
      r.aiItemTimer = 1 + rnd.nextDouble() * 2;
    }
    for (int i = 0; i < projectiles.length; i++) {
      projectiles[i] = CrProjectile();
    }
    for (int i = 0; i < hazards.length; i++) {
      hazards[i] = CrHazard();
    }
    _updatePlaces();
  }

  final CrTrack track;
  final math.Random rnd;
  final List<CrRacer> racers = <CrRacer>[];
  final List<CrProjectile> projectiles = List<CrProjectile>.filled(16, CrProjectile(), growable: false);
  final List<CrHazard> hazards = List<CrHazard>.filled(16, CrHazard(), growable: false);

  /// Racer indexes by place (best first). Reused every frame.
  final List<int> order = <int>[0, 1, 2, 3, 4, 5];
  final List<int> finishOrder = <int>[];

  /// Event stream: pairs (event, racer). Cleared by the consumer.
  final List<int> events = <int>[];

  static const double maxSpeed = 11000;
  static const double offroadMax = maxSpeed * 0.45;
  static const double gravity = 5200;

  double countdown = 3.6;
  double time = 0; // race clock (starts at GO)
  bool get started => countdown <= 0;
  bool autopilotPlayer = false;

  CrRacer get player => racers[0];
  double get raceLength => CrTrack.laps * track.length;

  // ---------------------------------------------------------------- input (player)
  bool _driftPrev = false;

  /// Applies the player's controls for this frame. [turbo] is an edge (tap).
  void input({required double steer, required bool drift, bool turbo = false, bool useItem = false}) {
    final CrRacer p = player;
    if (p.finished || autopilotPlayer) return;
    p.steer = steer.clamp(-1.0, 1.0);
    final bool pressed = drift && !_driftPrev;
    _driftPrev = drift;
    p.driftHeld = drift;
    if (pressed) {
      if (p.drifting && p.driftRelease >= 0) {
        // Re-tapped the drift button inside the grace window: a turbo tap, the slide continues.
        p.driftRelease = -1;
        _turboTap(p);
      } else if (!p.drifting) {
        _hop(p);
      }
    }
    if (turbo) _turboTap(p);
    if (useItem) fireItem(p);
  }

  void _hop(CrRacer r) {
    if (r.airborne || r.spin > 0 || !started) return;
    r.vy = 900;
    r.air = 0.01;
    r.wantDrift = true;
    _ev(CrEv.hop, r);
  }

  void _turboTap(CrRacer r) {
    if (!r.drifting || r.driftStage >= 3) return;
    if (r.driftMeter >= 0.68) {
      r.driftStage++;
      const List<double> power = <double>[1, 1.16, 1.23, 1.32];
      const List<double> dur = <double>[0, 0.75, 0.95, 1.25];
      _boost(r, power[r.driftStage], dur[r.driftStage], r.driftStage);
      r.driftMeter = 0;
      _ev(CrEv.boost1 + r.driftStage - 1, r);
    } else {
      // Too early: the slide's heat is lost.
      r.driftMeter = 0;
      _ev(CrEv.driftFail, r);
    }
  }

  void _boost(CrRacer r, double power, double dur, int level) {
    r.boostPower = math.max(r.boostTime > 0 ? r.boostPower : 1, power);
    r.boostTime = math.max(r.boostTime, dur);
    r.boostLevel = level;
    r.speed = math.max(r.speed, maxSpeed * 0.9);
  }

  // ---------------------------------------------------------------- items
  CrItem _rollItem(CrRacer r) {
    final int p = r.place;
    final double u = rnd.nextDouble();
    if (p >= 5 && u < 0.18) return CrItem.mask;
    if (p >= 4 && u < 0.45) return CrItem.rocket;
    if (p == 1) {
      if (u < 0.45) return CrItem.crate;
      if (u < 0.75) return CrItem.shield;
      return CrItem.bowlbomb;
    }
    const List<CrItem> pool = <CrItem>[CrItem.rocket, CrItem.bowlbomb, CrItem.crate, CrItem.nitro, CrItem.shield];
    return pool[rnd.nextInt(pool.length)];
  }

  void fireItem(CrRacer r) {
    if (r.item == CrItem.none || r.roulette > 0 || r.spin > 0 || !started) return;
    final CrItem it = r.item;
    final bool juiced = r.fruit >= 10;
    switch (it) {
      case CrItem.rocket:
        final CrProjectile? p = _freeProjectile();
        if (p == null) return;
        p
          ..active = true
          ..kind = CrItem.rocket
          ..owner = r.index
          ..target = _racerAhead(r)
          ..z = r.z + 500
          ..x = r.x
          ..speed = math.max(r.speed, maxSpeed * 0.8) + (juiced ? 7000 : 5500)
          ..life = 7
          ..age = 0;
      case CrItem.bowlbomb:
        final CrProjectile? p = _freeProjectile();
        if (p == null) return;
        p
          ..active = true
          ..kind = CrItem.bowlbomb
          ..owner = r.index
          ..target = -1
          ..z = r.z + 500
          ..x = r.x
          ..speed = math.max(r.speed, maxSpeed * 0.8) + 4500
          ..life = juiced ? 3.2 : 2.4
          ..age = 0;
      case CrItem.crate:
        final CrHazard? h = _freeHazard();
        if (h == null) return;
        h
          ..active = true
          ..owner = r.index
          ..z = track.wrap(r.z - 450)
          ..x = r.x
          ..life = 45
          ..age = 0;
      case CrItem.nitro:
        _boost(r, juiced ? 1.4 : 1.32, juiced ? 2.0 : 1.5, 4);
      case CrItem.shield:
        r.shield = juiced ? 14 : 9;
      case CrItem.mask:
        r.mask = juiced ? 8 : 6;
        _boost(r, 1.2, 0.6, 4);
      case CrItem.none:
        return;
    }
    r.item = CrItem.none;
    _ev(CrEv.fire, r);
  }

  CrProjectile? _freeProjectile() {
    for (final CrProjectile p in projectiles) {
      if (!p.active) return p;
    }
    return null;
  }

  CrHazard? _freeHazard() {
    for (final CrHazard h in hazards) {
      if (!h.active) return h;
    }
    CrHazard oldest = hazards[0];
    for (final CrHazard h in hazards) {
      if (h.age > oldest.age) oldest = h;
    }
    return oldest;
  }

  int _racerAhead(CrRacer r) {
    if (r.place <= 1) return -1;
    return order[r.place - 2];
  }

  // ---------------------------------------------------------------- step
  void step(double dt) {
    if (dt <= 0) return;
    if (countdown > 0) {
      countdown -= dt;
      if (countdown > 0) return;
      dt = -countdown;
      countdown = 0;
    }
    time += dt;
    for (final CrRacer r in racers) {
      if (!r.isPlayer || autopilotPlayer || r.finished) {
        if (!r.isPlayer || autopilotPlayer || r.finished) _ai(r, dt);
      }
      _physics(r, dt);
    }
    _collideKarts();
    _projectiles(dt);
    _pickups(dt);
    _updatePlaces();
  }

  void _physics(CrRacer r, double dt) {
    final double speedPct = r.speed / maxSpeed;
    final double c = track.curveAt(r.z);
    final CrCharacter ch = kCrCharacters[r.character];
    final double top = maxSpeed * (0.96 + ch.speed * 0.012) * (r.fruit >= 10 ? 1.06 : 1) * (r.isPlayer ? 1 : r.skill);
    final double accel = maxSpeed / (3.6 - ch.accel * 0.3);
    final double turnK = 0.88 + ch.turn * 0.06;

    // timers
    if (r.boostTime > 0) {
      r.boostTime -= dt;
      if (r.boostTime <= 0) {
        r.boostPower = 1;
        r.boostLevel = 0;
      }
    }
    if (r.shield > 0) r.shield -= dt;
    if (r.mask > 0) r.mask -= dt;
    if (r.hitFlash > 0) r.hitFlash -= dt;
    if (r.roulette > 0) {
      r.roulette -= dt;
      if (r.roulette <= 0) {
        r.roulette = 0;
        _ev(CrEv.itemReady, r);
      }
    }

    // speed
    final bool offroad = r.x.abs() > 1.08;
    double cap = top * r.boostPower * (r.mask > 0 ? 1.1 : 1);
    if (r.drifting) cap *= 0.97;
    if (offroad && r.boostTime <= 0 && r.mask <= 0) cap = math.min(cap, offroadMax);
    if (!started) cap = 0;
    if (r.spin > 0) {
      r.spin -= dt;
      r.speed = math.max(0, r.speed - maxSpeed * 1.2 * dt);
      if (r.spin <= 0) r.spin = 0;
    } else if (r.speed < cap) {
      r.speed = math.min(cap, r.speed + accel * (r.boostTime > 0 ? 3 : 1) * dt);
    } else {
      r.speed = math.max(cap, r.speed - maxSpeed * (offroad ? 1.6 : 0.6) * dt);
    }

    // air / hops / ramps
    if (r.air > 0) {
      r.airTime += dt;
      r.vy -= gravity * dt;
      r.air += r.vy * dt;
      if (r.air <= 0) {
        r.air = 0;
        r.vy = 0;
        if (r.airTime > 0.55 && r.bigJump) {
          final double hang = r.airTime;
          _boost(r, hang > 0.95 ? 1.26 : 1.16, hang > 0.95 ? 1.0 : 0.6, 3);
          _ev(CrEv.jumpBoost, r);
        }
        r.bigJump = false;
        r.airTime = 0;
        _ev(CrEv.land, r);
        if (r.wantDrift) {
          r.wantDrift = false;
          final int d = r.steer > 0.2 ? 1 : (r.steer < -0.2 ? -1 : 0);
          if (r.driftHeld && d != 0 && r.speed > maxSpeed * 0.4) {
            r.drifting = true;
            r.driftDir = d;
            r.driftMeter = 0;
            r.driftStage = 0;
            r.driftTime = 0;
            r.driftRelease = -1;
          }
        }
      }
    } else if (track.ramp[track.segIndex(r.z)] == 1 && r.x.abs() < 0.95 && r.speed > maxSpeed * 0.3) {
      r.vy = 1100 + 1500 * speedPct;
      r.air = 0.01;
      r.airTime = 0;
      r.bigJump = true;
      r.wantDrift = false;
      if (r.drifting) _endDrift(r);
    }

    // power-slide
    if (r.drifting) {
      r.driftTime += dt;
      if (!r.driftHeld) {
        if (r.driftRelease < 0) r.driftRelease = 0;
        r.driftRelease += dt;
        if (r.driftRelease > 0.2) _endDrift(r);
      }
      if (r.drifting) {
        r.driftMeter += dt * 1.05;
        if (r.driftMeter >= 1.0) {
          // Overheated: waited too long.
          r.driftMeter = 0;
          _ev(CrEv.driftFail, r);
        }
        if (r.speed < maxSpeed * 0.3 || r.spin > 0) _endDrift(r);
      }
    }

    // lateral
    final double dx = dt * 2.0 * speedPct;
    if (r.spin <= 0) {
      final double air = r.airborne ? 0.55 : 1;
      if (r.drifting) {
        final double tight = 0.95 + 0.62 * (r.steer * r.driftDir);
        r.x += r.driftDir * dx * tight * turnK * air;
        r.x -= dx * speedPct * c * 0.30 * 0.72;
      } else {
        r.x += r.steer * dx * turnK * air;
        r.x -= dx * speedPct * c * 0.30;
      }
    } else {
      r.x -= dx * speedPct * c * 0.2;
    }
    r.x = r.x.clamp(-2.2, 2.2);
    r.steerVis += ((r.drifting ? r.driftDir * 1.0 : r.steer) - r.steerVis) * math.min(1, dt * 8);

    // advance
    final double dz = r.speed * dt;
    final int lapBefore = r.lap;
    r.z = track.wrap(r.z + dz);
    if (!r.finished) {
      r.dist += dz;
      final int lap = (r.dist / track.length).floor() + 1;
      if (lap > lapBefore && r.dist > 0) {
        final double lt = time - r.lapStart;
        r.lastLap = lt;
        if (r.bestLap <= 0 || lt < r.bestLap) r.bestLap = lt;
        r.lapStart = time;
        if (lap > CrTrack.laps) {
          r.finished = true;
          r.finishTime = time;
          r.lap = CrTrack.laps;
          finishOrder.add(r.index);
          _ev(CrEv.finish, r);
        } else {
          r.lap = lap;
          _ev(CrEv.lap, r);
        }
      }
    }
  }

  void _endDrift(CrRacer r) {
    r.drifting = false;
    r.driftDir = 0;
    r.driftMeter = 0;
    r.driftStage = 0;
    r.driftRelease = -1;
  }

  // ---------------------------------------------------------------- AI
  void _ai(CrRacer r, double dt) {
    if (!started) return;
    final double cAhead = track.curveAhead(r.z, 22);
    // Racing line: hug the inside of the coming curve, steer at ? crates when the item slot is empty.
    double target = (-cAhead.sign) * math.min(0.45, cAhead.abs() * 0.12) * -1 + r.laneBias * 0.6;
    target = target.clamp(-0.75, 0.75);
    if (r.item == CrItem.none && r.roulette <= 0) {
      final int s0 = track.segIndex(r.z);
      for (final CrPickup p in track.pickups) {
        if (p.kind != CrPickupKind.box || p.respawn > 0) continue;
        int d = p.seg - s0;
        if (d < 0) d += track.n;
        if (d > 4 && d < 45) {
          target = p.x + (r.laneBias > 0 ? 0.02 : -0.02);
          break;
        }
      }
    }
    // Avoid hazards right ahead.
    for (final CrHazard h in hazards) {
      if (!h.active) continue;
      double d = h.z - r.z;
      if (d < -track.length / 2) d += track.length;
      if (d > 0 && d < 3500 && (h.x - target).abs() < 0.3) target = h.x > 0 ? h.x - 0.45 : h.x + 0.45;
    }
    // The AI compensates the curve's pull itself (it drives the line, not the stick).
    final double c = track.curveAt(r.z);
    final double speedPct = r.speed / maxSpeed;
    final double want = (target - r.x) * 3.0 + speedPct * c * 0.30;
    r.steer = want.clamp(-1.0, 1.0);
    if (r.drifting) {
      r.steer = ((target - r.x) * 2.5).clamp(-1.0, 1.0) * r.driftDir;
      r.x += ((target - r.x) * 1.6 * dt);
    }
    r.driftHeld = false;

    // Visible power-slides through the bigger curves, with skill-based turbo boosts.
    final double cNow = c.abs();
    if (!r.drifting && cNow > 2.6 && r.speed > maxSpeed * 0.6 && !r.airborne) {
      r.drifting = true;
      r.driftDir = c > 0 ? 1 : -1;
      r.driftMeter = 0;
      r.driftStage = 0;
      r.driftRelease = -1;
    }
    if (r.drifting) {
      r.driftHeld = cNow > 1.2;
      r.aiDriftBoostCd -= dt;
      if (r.driftMeter > 0.72 + rnd.nextDouble() * 0.2 && r.aiDriftBoostCd <= 0) {
        if (rnd.nextDouble() < r.skill * 0.8) {
          _turboTap(r);
        } else {
          r.driftMeter = 0;
        }
        r.aiDriftBoostCd = 0.3;
      }
    }

    // Rubber-banding against the player.
    final double gap = player.dist - r.dist;
    double band = 1;
    if (!player.finished) {
      band = gap > 0 ? 1 + math.min(0.14, gap / 40000 * 0.14) : 1 - math.min(0.1, -gap / 60000 * 0.1);
    }
    final CrCharacter ch = kCrCharacters[r.character];
    final double top = maxSpeed * (0.96 + ch.speed * 0.012) * r.skill * band * (1 - 0.018 * cNow);
    if (r.boostTime <= 0 && r.spin <= 0 && r.speed > top) r.speed = math.max(top, r.speed - maxSpeed * dt);

    // Items.
    if (r.item != CrItem.none && r.roulette <= 0) {
      r.aiItemTimer -= dt;
      if (r.aiItemTimer <= 0) {
        bool use = false;
        switch (r.item) {
          case CrItem.rocket:
          case CrItem.bowlbomb:
            final int a = _racerAhead(r);
            use = a >= 0 && (racers[a].dist - r.dist) < 9000 || r.aiItemTimer < -8;
          case CrItem.crate:
            final int b = r.place < 6 ? order[r.place] : -1;
            use = (b >= 0 && (r.dist - racers[b].dist) < 4000) || r.aiItemTimer < -6;
          case CrItem.nitro:
          case CrItem.shield:
          case CrItem.mask:
            use = true;
          case CrItem.none:
            use = false;
        }
        if (use) {
          fireItem(r);
          r.aiItemTimer = 0.8 + rnd.nextDouble() * 2.5;
        }
      }
    }
  }

  // ---------------------------------------------------------------- interactions
  double _dz(double a, double b) {
    double d = a - b;
    final double l = track.length;
    if (d > l / 2) d -= l;
    if (d < -l / 2) d += l;
    return d;
  }

  void hit(CrRacer r, {bool big = false}) {
    if (r.invincible || r.finished && !r.isPlayer) return;
    if (r.shield > 0) {
      r.shield = 0;
      _ev(CrEv.shieldPop, r);
      return;
    }
    r.spin = big ? 1.6 : 1.25;
    r.speed *= 0.35;
    r.fruit = math.max(0, r.fruit - 3);
    r.boostTime = 0;
    r.boostPower = 1;
    r.hitFlash = 0.5;
    if (r.drifting) _endDrift(r);
    _ev(CrEv.hit, r);
  }

  void _collideKarts() {
    for (int i = 0; i < racers.length; i++) {
      final CrRacer a = racers[i];
      for (int j = i + 1; j < racers.length; j++) {
        final CrRacer b = racers[j];
        final double dz = _dz(a.z, b.z);
        if (dz.abs() > 280) continue;
        final double dx = a.x - b.x;
        if (dx.abs() > 0.3 || (a.air - b.air).abs() > 250) continue;
        if (a.invincible && !b.invincible) {
          hit(b);
          continue;
        }
        if (b.invincible && !a.invincible) {
          hit(a);
          continue;
        }
        final double push = (0.3 - dx.abs()) * 0.5 + 0.02;
        final double s = dx >= 0 ? 1 : -1;
        a.x += s * push;
        b.x -= s * push;
        final CrRacer rear = dz < 0 ? a : b;
        rear.speed *= 0.93;
        if (a.isPlayer || b.isPlayer) _ev(CrEv.bump, a.isPlayer ? a : b);
      }
    }
  }

  void _projectiles(double dt) {
    for (final CrProjectile p in projectiles) {
      if (!p.active) continue;
      p.age += dt;
      p.life -= dt;
      p.z = track.wrap(p.z + p.speed * dt);
      if (p.kind == CrItem.rocket && p.target >= 0) {
        final CrRacer t = racers[p.target];
        p.x += (t.x - p.x).clamp(-2.4 * dt, 2.4 * dt);
      }
      bool boom = p.life <= 0;
      for (final CrRacer r in racers) {
        if (r.index == p.owner && p.age < 0.6) continue;
        if (r.finished && !r.isPlayer) continue;
        final double dz = _dz(r.z, p.z);
        if (dz.abs() < 380 && (r.x - p.x).abs() < 0.32 && r.air < 400) {
          hit(r, big: p.kind == CrItem.bowlbomb);
          boom = true;
          break;
        }
      }
      // Projectiles break dropped crates too.
      for (final CrHazard h in hazards) {
        if (!h.active) continue;
        if (_dz(h.z, p.z).abs() < 300 && (h.x - p.x).abs() < 0.3) {
          h.active = false;
          boom = true;
        }
      }
      if (boom) {
        if (p.kind == CrItem.bowlbomb) {
          for (final CrRacer r in racers) {
            if (r.spin > 0) continue;
            if (_dz(r.z, p.z).abs() < 900 && (r.x - p.x).abs() < 0.6) hit(r, big: true);
          }
        }
        p.active = false;
        events
          ..add(CrEv.explode)
          ..add(p.owner);
        _lastBoomZ = p.z;
        _lastBoomX = p.x;
      }
    }
    for (final CrHazard h in hazards) {
      if (!h.active) continue;
      h.age += dt;
      h.life -= dt;
      if (h.life <= 0) {
        h.active = false;
        continue;
      }
      for (final CrRacer r in racers) {
        if (r.index == h.owner && h.age < 0.8) continue;
        if (r.air > 250) continue;
        if (_dz(r.z, h.z).abs() < 260 && (r.x - h.x).abs() < 0.26) {
          hit(r);
          h.active = false;
          events
            ..add(CrEv.explode)
            ..add(r.index);
          _lastBoomZ = h.z;
          _lastBoomX = h.x;
          break;
        }
      }
    }
  }

  double _lastBoomZ = 0, _lastBoomX = 0;
  double get lastBoomZ => _lastBoomZ;
  double get lastBoomX => _lastBoomX;

  void _pickups(double dt) {
    for (final CrPickup p in track.pickups) {
      if (p.respawn > 0) {
        p.respawn -= dt;
        if (p.respawn < 0) p.respawn = 0;
        continue;
      }
      final double pz = p.seg * CrTrack.segLen;
      for (final CrRacer r in racers) {
        if (r.air > 350) continue;
        if (_dz(r.z, pz).abs() > 260 || (r.x - p.x).abs() > 0.24) continue;
        if (p.kind == CrPickupKind.box) {
          p.respawn = 3;
          if (r.item == CrItem.none && r.roulette <= 0) {
            r.item = _rollItem(r);
            r.roulette = r.isPlayer ? 1.1 : 0.8;
          }
          _ev(CrEv.box, r);
        } else {
          p.respawn = 10;
          if (r.fruit < 10) r.fruit++;
          _ev(CrEv.fruit, r);
        }
        break;
      }
    }
  }

  void _updatePlaces() {
    // Insertion sort on the reused list (no allocation): finished racers by finish order, then by distance.
    for (int i = 1; i < order.length; i++) {
      final int v = order[i];
      int j = i - 1;
      while (j >= 0 && _ahead(v, order[j])) {
        order[j + 1] = order[j];
        j--;
      }
      order[j + 1] = v;
    }
    for (int i = 0; i < order.length; i++) {
      racers[order[i]].place = i + 1;
    }
  }

  bool _ahead(int a, int b) {
    final CrRacer ra = racers[a], rb = racers[b];
    if (ra.finished && rb.finished) return ra.finishTime < rb.finishTime;
    if (ra.finished != rb.finished) return ra.finished;
    return ra.dist > rb.dist;
  }

  void _ev(int e, CrRacer r) {
    events
      ..add(e)
      ..add(r.index);
  }

  /// After the player finished: estimate the remaining racers' finishing times from their recent pace.
  void simulateToEnd() {
    final List<CrRacer> rest = racers.where((CrRacer r) => !r.finished).toList()
      ..sort((CrRacer a, CrRacer b) => b.dist.compareTo(a.dist));
    for (final CrRacer r in rest) {
      final double pace = math.max(maxSpeed * 0.75, r.speed);
      final double remain = math.max(0, raceLength - r.dist);
      r.finishTime = time + remain / pace;
      if (finishOrder.isNotEmpty) {
        final double lastT = racers[finishOrder.last].finishTime;
        if (r.finishTime <= lastT) r.finishTime = lastT + 0.35;
      }
      if (r.bestLap <= 0) r.bestLap = (r.finishTime / CrTrack.laps);
      r.finished = true;
      r.dist = raceLength;
      finishOrder.add(r.index);
    }
    _updatePlaces();
  }
}

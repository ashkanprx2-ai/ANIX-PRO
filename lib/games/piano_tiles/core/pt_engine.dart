/// ===================== PIANO TILES · ENGINE =====================
/// Pure-Dart simulation (no Flutter imports, deterministic for a seed, unit-tested).
///
/// World space is measured in rows. A tile at `row` with `len` occupies rows [row, row+len).
/// The playfield shows rows [scroll, scroll + visibleRows); a tile's bottom sits on the
/// screen bottom when `row == scroll`. The next untapped tile must be tapped before its
/// bottom leaves the screen, taps on empty lane space end the run, and the song repeats
/// endlessly (faster every loop) once it is finished.
/// =================================================================
library;

import 'dart:math' as math;

import 'pt_songs.dart';

class PtTile {
  PtTile({
    required this.id,
    required this.row,
    required this.len,
    required this.lane,
    required this.pitch,
    required this.group,
    required this.loop,
    required this.index,
    this.isStart = false,
    this.isDouble = false,
  });

  final int id;
  final double row;
  final int len;
  final int lane;
  final int pitch;

  /// Tiles of one double share a group (and a row).
  final int group;

  /// Which pass through the song spawned this tile, and its note index in the song.
  final int loop;
  final int index;
  final bool isStart;
  final bool isDouble;

  bool hit = false;

  /// Hold tiles: filled rows (0..len), finger still down, completed.
  double fill = 0;
  bool holding = false;
  bool holdDone = false;
  int? pointer;
  double pressScroll = 0;
  int holdScored = 0;

  /// Engine clock when it was hit (for the glass fade).
  double hitAt = -1;
  bool perfect = false;

  bool get isHold => len > 1;
  double get top => row + len;
}

enum PtEventKind { hit, holdStart, holdTick, holdDone, star, songDone, miss }

class PtEvent {
  const PtEvent(this.kind, {this.tile, this.lane = -1, this.row = 0, this.value = 0});
  final PtEventKind kind;
  final PtTile? tile;
  final int lane;
  final double row;
  final int value;
}

enum PtTap { hit, ghost, ignored, miss }

class PtEngine {
  PtEngine(this.song, {int seed = 1, this.lanes = 4}) : _rng = math.Random(seed) {
    _notes = song.notes;
    _fill();
  }

  final PtSong song;
  final int lanes;
  final math.Random _rng;
  late final List<PtNote> _notes;

  final List<PtTile> tiles = <PtTile>[];
  final List<PtEvent> events = <PtEvent>[];

  double scroll = 0;
  double clock = 0;
  bool started = false;
  bool over = false;

  int score = 0;
  int combo = 0;
  int bestCombo = 0;

  /// Completed passes through the song (0 while playing the song the first time).
  int loops = 0;

  /// Stars earned on the first pass (0..3); each later pass is a crown.
  int stars = 0;

  /// The tile (or empty cell) that ended the run.
  PtTile? missTile;
  int missLane = -1;
  double missRow = 0;

  int _nextId = 0;
  int _group = 0;
  int _genIndex = 0;
  int _genLoop = 0;
  double _genRow = 1;
  int _lastLane = -1;
  int _prevLane = -1;
  final Map<int, int> _clearedPerLoop = <int, int>{};

  int get songLength => _notes.length;

  /// Rows per second right now: the song's base, +18% across a pass, x1.12 per completed loop.
  double get speed {
    final double inLoop = (_clearedPerLoop[loops] ?? 0) / songLength;
    return song.speed * (1 + 0.18 * inLoop) * math.pow(1.12, loops).toDouble();
  }

  /// Progress through the current pass (0..1).
  double get progress => ((_clearedPerLoop[loops] ?? 0) / songLength).clamp(0.0, 1.0);

  bool get endless => loops > 0;

  void _fill() {
    while (_genRow < scroll + 12) {
      _spawn();
    }
  }

  int _pickLane(Set<int> avoid) {
    final List<int> free = <int>[for (int l = 0; l < lanes; l++) if (!avoid.contains(l)) l];
    return free[_rng.nextInt(free.length)];
  }

  void _spawn() {
    final PtNote n = _notes[_genIndex];
    final bool first = tiles.isEmpty && _genLoop == 0 && _genIndex == 0;
    final int g = _group++;
    // The very first note is always the single «start» tile, even when the chart opens on a chord.
    final bool dbl = n.isDouble && !first;
    if (dbl) {
      final int a = _pickLane(<int>{_lastLane});
      final int b = _pickLane(<int>{_lastLane, a});
      for (int i = 0; i < 2; i++) {
        tiles.add(PtTile(
          id: _nextId++,
          row: _genRow,
          len: 1,
          lane: i == 0 ? a : b,
          pitch: n.pitches[i],
          group: g,
          loop: _genLoop,
          index: _genIndex,
          isDouble: true,
        ));
      }
      _prevLane = _lastLane;
      _lastLane = -1; // any lane may follow a double
    } else {
      // Avoid the same lane twice in a row and a flat zig-zag between two lanes.
      final Set<int> avoid = <int>{if (_lastLane >= 0) _lastLane, if (_prevLane >= 0 && _rng.nextDouble() < 0.6) _prevLane};
      if (avoid.length >= lanes) avoid.remove(_prevLane);
      final int lane = first ? 1 + _rng.nextInt(2) : _pickLane(avoid);
      tiles.add(PtTile(
        id: _nextId++,
        row: _genRow,
        len: first ? 1 : n.len,
        lane: lane,
        pitch: n.pitches.first,
        group: g,
        loop: _genLoop,
        index: _genIndex,
        isStart: first,
      ));
      _prevLane = _lastLane;
      _lastLane = lane;
    }
    _genRow += (dbl || first) ? 1 : n.len;
    _genIndex++;
    if (_genIndex >= _notes.length) {
      _genIndex = 0;
      _genLoop++;
    }
  }

  /// The tiles that must be tapped next (two for a double).
  List<PtTile> get next {
    PtTile? low;
    for (final PtTile t in tiles) {
      if (!t.hit && (low == null || t.row < low.row)) low = t;
    }
    if (low == null) return const <PtTile>[];
    if (!low.isDouble) return <PtTile>[low];
    return <PtTile>[for (final PtTile t in tiles) if (!t.hit && t.group == low.group) t];
  }

  void step(double dt) {
    clock += dt;
    if (!started || over) return;
    scroll += speed * dt;
    for (final PtTile t in tiles) {
      if (t.holding) _advanceHold(t);
    }
    final List<PtTile> n = next;
    if (n.isNotEmpty && n.first.row - scroll < -0.06) {
      _miss(n.first, n.first.lane, n.first.row);
      return;
    }
    tiles.removeWhere((PtTile t) => t.hit && !t.holding && t.top < scroll - 1.5);
    _fill();
  }

  void _advanceHold(PtTile t) {
    t.fill = math.min(t.len.toDouble(), 0.35 + (scroll - t.pressScroll));
    final int rows = t.fill.floor();
    while (t.holdScored < rows && t.holdScored < t.len - 1) {
      t.holdScored++;
      score++;
      events.add(PtEvent(PtEventKind.holdTick, tile: t, lane: t.lane, value: t.holdScored));
    }
    if (t.fill >= t.len - 0.02) {
      t.holding = false;
      t.holdDone = true;
      t.fill = t.len.toDouble();
      score++;
      events.add(PtEvent(PtEventKind.holdDone, tile: t, lane: t.lane));
    }
  }

  /// Press at [lane] / world [row] with finger [pointer].
  PtTap press(int lane, double row, {int pointer = 0}) {
    if (over) return PtTap.ignored;
    final List<PtTile> n = next;
    for (final PtTile t in n) {
      // Generous: anywhere in the tile's lane at or below its top (plus a little slack above).
      if (t.lane == lane && row <= t.top + 0.25 && row >= t.row - 1.2) {
        _hit(t, pointer);
        return PtTap.hit;
      }
    }
    for (final PtTile t in tiles) {
      if (t.lane != lane) continue;
      if (row >= t.row - 0.15 && row <= t.top + 0.15) {
        // A tile already played (double-tap on glass) or one further up the chart: forgiven.
        return t.hit ? PtTap.ghost : PtTap.ignored;
      }
    }
    if (!started) return PtTap.ignored;
    _miss(null, lane, row);
    return PtTap.miss;
  }

  void release(int pointer) {
    for (final PtTile t in tiles) {
      if (t.holding && t.pointer == pointer) {
        t.holding = false;
        t.pointer = null;
      }
    }
  }

  void _hit(PtTile t, int pointer) {
    started = true;
    t.hit = true;
    t.hitAt = clock;
    t.perfect = t.row - scroll < 1.7;
    combo++;
    bestCombo = math.max(bestCombo, combo);
    score++;
    if (t.isHold) {
      t.holding = true;
      t.pointer = pointer;
      t.pressScroll = scroll;
      t.fill = 0.35;
      events.add(PtEvent(PtEventKind.holdStart, tile: t, lane: t.lane));
    } else {
      events.add(PtEvent(PtEventKind.hit, tile: t, lane: t.lane));
    }
    // A note (both halves of a double) is cleared once every tile of its group is hit.
    final bool groupDone = !tiles.any((PtTile o) => o.group == t.group && !o.hit);
    if (!groupDone) return;
    final int c = (_clearedPerLoop[t.loop] ?? 0) + 1;
    _clearedPerLoop[t.loop] = c;
    if (t.loop == 0) {
      final int s = c >= songLength ? 3 : (c * 3 ~/ songLength);
      while (stars < s) {
        stars++;
        events.add(PtEvent(PtEventKind.star, value: stars));
      }
    }
    if (c >= songLength) {
      loops = t.loop + 1;
      events.add(PtEvent(PtEventKind.songDone, value: loops));
    }
  }

  void _miss(PtTile? t, int lane, double row) {
    over = true;
    missTile = t;
    missLane = lane;
    missRow = t?.row ?? (row.floorToDouble());
    if (t == null) {
      // Snap the red cell onto the row grid of the tile that was due.
      final List<PtTile> n = next;
      if (n.isNotEmpty) missRow = n.first.row + ((row - n.first.row) / 1).floorToDouble();
    }
    combo = 0;
    events.add(PtEvent(PtEventKind.miss, tile: t, lane: lane, row: missRow));
  }

  /// Rows the board scrolls back after a tile slipped off the bottom, so the player sees it.
  double get rewind => missTile == null ? 0 : math.max(0, scroll - missTile!.row + 0.55);
}

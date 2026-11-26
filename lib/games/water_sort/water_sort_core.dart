import 'dart:collection';
import 'dart:math' as math;

/// ===================== WATER SORT — RULES =====================
/// Pure game logic (no Flutter): tubes, the pour rule, a bounded solver, and a seeded
/// level generator that only ever ships solvable boards.
///
///  * A tube holds up to [kWsCapacity] units, bottom → top. Each unit is a colour index.
///  * A pour moves the top run of one colour from A to B when B is empty or B's top has
///    the same colour, and B has room. As much of the run as fits moves.
///  * A level is solved when every tube is empty or full of a single colour.
///  * Levels are deterministic: level N is the same board on every phone.
/// ===============================================================

const int kWsCapacity = 4;

/// One pour, for undo and the pour animation.
class WsMove {
  const WsMove(this.from, this.to, this.color, this.amount, {this.revealed = const <int>[]});
  final int from;
  final int to;
  final int color;
  final int amount;

  /// Indices (in [from]) of hidden layers this pour uncovered (undo hides them again).
  final List<int> revealed;
}

class WsTube {
  WsTube(List<int> units, [List<bool>? hidden])
      : units = List<int>.of(units),
        hidden = hidden == null ? List<bool>.filled(units.length, false, growable: true) : List<bool>.of(hidden);

  final List<int> units;

  /// Parallel to [units]: a mystery layer shows as "?" until it is the top of the tube.
  final List<bool> hidden;

  bool get isEmpty => units.isEmpty;
  bool get isFull => units.length >= kWsCapacity;
  int get space => kWsCapacity - units.length;
  int? get top => units.isEmpty ? null : units.last;

  /// Length of the same-colour run on top.
  int get topRun {
    if (units.isEmpty) return 0;
    final int c = units.last;
    int n = 0;
    for (int i = units.length - 1; i >= 0 && units[i] == c && !hidden[i]; i--) {
      n++;
    }
    return n;
  }

  /// Full of a single colour (sealed with a cork in the UI).
  bool get complete => units.length == kWsCapacity && units.every((int c) => c == units.first) && !hidden.contains(true);

  WsTube copy() => WsTube(units, hidden);
}

class WsLevelSpec {
  const WsLevelSpec({required this.level, required this.colors, required this.empty, required this.mystery});
  final int level;
  final int colors;
  final int empty;

  /// Whether lower layers start hidden.
  final bool mystery;

  /// Difficulty curve: 2 colours on level 1, then a gentle square-root ramp to 12 colours (≈ level 60).
  /// Mystery layers appear from level 25 on every third level, and on most levels after 120.
  factory WsLevelSpec.of(int level) {
    final int l = math.max(1, level);
    final int colors = l == 1 ? 2 : math.min(12, 3 + math.sqrt((l - 2) * 1.6).floor());
    final int empty = l == 1 ? 1 : 2;
    final bool mystery = (l >= 25 && l % 3 == 0) || (l > 120 && l % 4 != 1);
    return WsLevelSpec(level: l, colors: colors, empty: empty, mystery: mystery);
  }
}

class WsBoard {
  WsBoard(this.tubes);
  final List<WsTube> tubes;
  final List<WsMove> history = <WsMove>[];

  WsBoard copy() => WsBoard(<WsTube>[for (final WsTube t in tubes) t.copy()]);

  bool canPour(int a, int b) {
    if (a == b || a < 0 || b < 0 || a >= tubes.length || b >= tubes.length) return false;
    final WsTube s = tubes[a];
    final WsTube d = tubes[b];
    if (s.isEmpty || d.isFull || s.complete) return false;
    if (s.hidden.last) return false;
    return d.isEmpty || d.top == s.top;
  }

  int pourAmount(int a, int b) => canPour(a, b) ? math.min(tubes[a].topRun, tubes[b].space) : 0;

  /// Applies a pour and returns it (null if illegal).
  WsMove? pour(int a, int b) {
    final int n = pourAmount(a, b);
    if (n <= 0) return null;
    final WsTube s = tubes[a];
    final WsTube d = tubes[b];
    final int c = s.top!;
    for (int i = 0; i < n; i++) {
      s.units.removeLast();
      s.hidden.removeLast();
      d.units.add(c);
      d.hidden.add(false);
    }
    final List<int> revealed = <int>[];
    if (s.units.isNotEmpty && s.hidden.last) {
      // Uncover the new top run.
      final int tc = s.units.last;
      for (int i = s.units.length - 1; i >= 0 && s.hidden[i] && s.units[i] == tc; i--) {
        s.hidden[i] = false;
        revealed.add(i);
      }
    }
    final WsMove m = WsMove(a, b, c, n, revealed: revealed);
    history.add(m);
    return m;
  }

  /// Reverts the last pour.
  WsMove? undo() {
    if (history.isEmpty) return null;
    final WsMove m = history.removeLast();
    final WsTube s = tubes[m.from];
    final WsTube d = tubes[m.to];
    for (final int i in m.revealed) {
      s.hidden[i] = true;
    }
    for (int i = 0; i < m.amount; i++) {
      d.units.removeLast();
      d.hidden.removeLast();
      s.units.add(m.color);
      s.hidden.add(false);
    }
    return m;
  }

  bool get solved => tubes.every((WsTube t) => t.isEmpty || t.complete);

  bool get hasMove {
    for (int a = 0; a < tubes.length; a++) {
      for (int b = 0; b < tubes.length; b++) {
        if (canPour(a, b) && !_pointless(a, b)) return true;
      }
    }
    return false;
  }

  /// Moving a whole single-colour tube into an empty tube changes nothing.
  bool _pointless(int a, int b) {
    final WsTube s = tubes[a];
    return tubes[b].isEmpty && s.topRun == s.units.length;
  }

  String key() {
    final List<String> parts = <String>[for (final WsTube t in tubes) t.units.join(',')]..sort();
    return parts.join('|');
  }

  /// Bounded depth-first solve from the current state (ignores mystery: the solver knows the truth).
  /// Returns the move list, or null when no solution is found within [limit] explored states.
  List<List<int>>? solve({int limit = 40000}) {
    final WsBoard b = copy();
    for (final WsTube t in b.tubes) {
      for (int i = 0; i < t.hidden.length; i++) {
        t.hidden[i] = false;
      }
    }
    final HashSet<String> seen = HashSet<String>();
    final List<List<int>> path = <List<int>>[];
    int budget = limit;

    bool dfs() {
      if (b.solved) return true;
      if (budget-- <= 0) return false;
      if (!seen.add(b.key())) return false;
      final List<List<int>> cand = <List<int>>[];
      for (int x = 0; x < b.tubes.length; x++) {
        final WsTube s = b.tubes[x];
        if (s.isEmpty || s.complete) continue;
        bool triedEmpty = false;
        for (int y = 0; y < b.tubes.length; y++) {
          if (!b.canPour(x, y)) continue;
          final WsTube d = b.tubes[y];
          if (d.isEmpty) {
            if (s.topRun == s.units.length || triedEmpty) continue;
            triedEmpty = true;
          }
          // Prefer moves that build on a same colour stack and fully move the run.
          final int score = (d.isEmpty ? 0 : 10) + (s.topRun <= d.space ? 5 : 0) + d.units.length;
          cand.add(<int>[x, y, score]);
        }
      }
      cand.sort((List<int> p, List<int> q) => q[2] - p[2]);
      for (final List<int> c in cand) {
        b.pour(c[0], c[1]);
        path.add(<int>[c[0], c[1]]);
        if (dfs()) return true;
        path.removeLast();
        b.undo();
      }
      return false;
    }

    return dfs() ? path : null;
  }
}

/// Generated level: the board plus the solver's reference solution length (for stars).
class WsLevel {
  WsLevel(this.spec, this.board, this.par);
  final WsLevelSpec spec;
  final WsBoard board;
  final int par;

  /// Builds level [level] deterministically. Shuffles the colour units, rejects boards that already
  /// contain a finished tube or that the solver cannot crack, and retries with the next seed.
  static WsLevel generate(int level) {
    final WsLevelSpec spec = WsLevelSpec.of(level);
    for (int attempt = 0; attempt < 400; attempt++) {
      final math.Random rnd = math.Random(level * 7919 + attempt * 104729 + 17);
      final List<int> pool = <int>[
        for (int c = 0; c < spec.colors; c++)
          for (int k = 0; k < kWsCapacity; k++) c,
      ]..shuffle(rnd);
      final List<WsTube> tubes = <WsTube>[];
      for (int t = 0; t < spec.colors; t++) {
        final List<int> u = pool.sublist(t * kWsCapacity, (t + 1) * kWsCapacity);
        tubes.add(WsTube(u, spec.mystery ? <bool>[true, true, true, false] : null));
      }
      // Too easy: a finished tube, or a tube with three of one colour on the bottom.
      bool bad = false;
      for (final WsTube t in tubes) {
        if (t.units.toSet().length == 1) bad = true;
        if (spec.colors > 3 && t.units[0] == t.units[1] && t.units[1] == t.units[2]) bad = true;
      }
      if (bad) continue;
      for (int e = 0; e < spec.empty; e++) {
        tubes.add(WsTube(<int>[]));
      }
      final WsBoard b = WsBoard(tubes);
      final List<List<int>>? sol = b.solve(limit: 30000);
      if (sol == null) continue;
      // Later levels must not collapse into a handful of obvious pours.
      if (level > 40 && attempt < 200 && sol.length < spec.colors * 3) continue;
      return WsLevel(spec, b, sol.length);
    }
    // Fallback that is always solvable: pre-sorted columns with the top two layers swapped around.
    final List<WsTube> tubes = <WsTube>[
      for (int c = 0; c < spec.colors; c++) WsTube(<int>[c, c, c, (c + 1) % spec.colors]),
      for (int e = 0; e < spec.empty; e++) WsTube(<int>[]),
    ];
    return WsLevel(spec, WsBoard(tubes), spec.colors * 2);
  }

  /// Stars for a cleared level: 3 for clean play near par, fewer with boosters / many moves.
  static int stars({required int moves, required int par, required int boostersUsed}) {
    int s = 3;
    if (moves > par * 1.6 + 2) s--;
    if (boostersUsed > 0) s--;
    if (boostersUsed > 2) s--;
    return math.max(1, s);
  }

  /// Points for a cleared level.
  static int points(WsLevelSpec spec, int stars) => 100 + spec.colors * 20 + (spec.mystery ? 60 : 0) + stars * 30;
}

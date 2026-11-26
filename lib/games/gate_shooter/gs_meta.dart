import 'dart:math' as math;

import '../../core/storage/local_store.dart';

/// Persistent progression of دونده‌ی تیرانداز (Gate Shooter): coin bank + four upgrade tracks bought between runs.
enum GsStat { power, soldiers, bullets, rate }

class GsMeta {
  GsMeta({this.coins = 0, Map<GsStat, int>? levels}) : levels = levels ?? <GsStat, int>{for (final GsStat s in GsStat.values) s: 1};

  static const String _key = 'gate_shooter.meta.v1';

  int coins;
  final Map<GsStat, int> levels;

  static const Map<GsStat, int> maxLevel = <GsStat, int>{
    GsStat.power: 40,
    GsStat.soldiers: 25,
    GsStat.bullets: 5,
    GsStat.rate: 25,
  };

  int level(GsStat s) => levels[s] ?? 1;
  bool maxed(GsStat s) => level(s) >= maxLevel[s]!;

  /// Price of the next level of [s] in coins.
  int cost(GsStat s) {
    final int l = level(s);
    final double base = switch (s) {
      GsStat.power => 30,
      GsStat.soldiers => 45,
      GsStat.bullets => 260,
      GsStat.rate => 35,
    };
    final double grow = s == GsStat.bullets ? 2.4 : 1.32;
    final double c = base * math.pow(grow, l - 1);
    return (c / 5).round() * 5;
  }

  bool canBuy(GsStat s) => !maxed(s) && coins >= cost(s);

  bool buy(GsStat s) {
    if (!canBuy(s)) return false;
    coins -= cost(s);
    levels[s] = level(s) + 1;
    save();
    return true;
  }

  // ---- derived run stats ----
  /// Damage of one bullet at the start of a run.
  double get basePower => 1 + 0.4 * (level(GsStat.power) - 1);
  int get baseSoldiers => level(GsStat.soldiers);
  int get bulletStreams => level(GsStat.bullets);

  /// Shots per second of one soldier.
  double get baseRate => 6.0 + 0.4 * (level(GsStat.rate) - 1);

  static GsMeta load() {
    try {
      final Map<String, dynamic>? j = LocalStore.instance.getJson(_key);
      if (j == null) return GsMeta();
      final Map<GsStat, int> lv = <GsStat, int>{
        for (final GsStat s in GsStat.values) s: ((j[s.name] as num?)?.toInt() ?? 1).clamp(1, maxLevel[s]!),
      };
      return GsMeta(coins: (j['coins'] as num?)?.toInt() ?? 0, levels: lv);
    } catch (_) {
      return GsMeta();
    }
  }

  void save() {
    try {
      LocalStore.instance.setJson(_key, <String, Object>{
        'coins': coins,
        for (final GsStat s in GsStat.values) s.name: level(s),
      });
    } catch (_) {}
  }
}

/// ASCII digits → Persian digits.
String gsFa(Object n) {
  const String d = '۰۱۲۳۴۵۶۷۸۹';
  return n.toString().split('').map((String c) {
    final int i = c.codeUnitAt(0) - 48;
    if (i >= 0 && i <= 9) return d[i];
    if (c == '.') return '٫';
    return c;
  }).join();
}

/// Compact number: 1234 → 1.2K.
String gsCompact(num v) {
  if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(v >= 10000000 ? 0 : 1)}M';
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(0)}K';
  if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
  return v.round().toString();
}

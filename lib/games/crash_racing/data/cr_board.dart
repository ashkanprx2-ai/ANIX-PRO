import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/online/online_service.dart';

/// One leaderboard row (games project, `crash_racing_board` RPC).
class CrBoardRow {
  const CrBoardRow({required this.rank, required this.name, required this.ms, required this.character, required this.mine});
  final int rank;
  final String name;
  final int ms;
  final String character;
  final bool mine;
}

/// Crash Racing times: local personal bests (always) and the global per-track board on the games project
/// (`public.crash_racing_times`, RLS: a signed-in player inserts only their own rows, everyone reads).
class CrBoard {
  const CrBoard._();

  static SupabaseClient? get _games => OnlineService.current?.games;
  static String? get _uid => OnlineService.current?.uid;

  static String _k(String track, bool lap) => 'crash_racing.best.${lap ? 'lap' : 'race'}.$track';

  /// Personal best in ms (0 = none).
  static Future<int> localBest(String track, {bool lap = false}) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      return p.getInt(_k(track, lap)) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Stores the run locally; returns (newRaceBest, newLapBest).
  static Future<(bool, bool)> saveLocal(String track, int raceMs, int lapMs) async {
    try {
      final SharedPreferences p = await SharedPreferences.getInstance();
      final int br = p.getInt(_k(track, false)) ?? 0;
      final int bl = p.getInt(_k(track, true)) ?? 0;
      final bool nr = raceMs > 0 && (br == 0 || raceMs < br);
      final bool nl = lapMs > 0 && (bl == 0 || lapMs < bl);
      if (nr) await p.setInt(_k(track, false), raceMs);
      if (nl) await p.setInt(_k(track, true), lapMs);
      return (nr, nl);
    } catch (_) {
      return (false, false);
    }
  }

  /// Submits a finished race (signed-in players only; silently skipped offline).
  static Future<bool> submit({
    required String track,
    required String character,
    required int raceMs,
    required int bestLapMs,
    required int place,
  }) async {
    final SupabaseClient? c = _games;
    final String? uid = _uid;
    if (c == null || uid == null) return false;
    try {
      await c.from('crash_racing_times').insert(<String, dynamic>{
        'player_id': uid,
        'track': track,
        'character': character,
        'race_ms': raceMs,
        'best_lap_ms': bestLapMs,
        'place': place,
      });
      return true;
    } catch (e) {
      debugPrint('crash_racing submit: $e');
      return false;
    }
  }

  /// Top [limit] players on [track] by best race time (or best lap with [lap]).
  static Future<List<CrBoardRow>?> top(String track, {bool lap = false, int limit = 20}) async {
    final SupabaseClient? c = _games;
    if (c == null) return null;
    try {
      final dynamic rows = await c.rpc('crash_racing_board',
          params: <String, dynamic>{'p_track': track, 'p_kind': lap ? 'lap' : 'race', 'p_limit': limit});
      final String? me = _uid;
      final List<CrBoardRow> out = <CrBoardRow>[];
      if (rows is List) {
        for (final dynamic r in rows) {
          if (r is! Map) continue;
          out.add(CrBoardRow(
            rank: (r['rank'] as num?)?.toInt() ?? out.length + 1,
            name: '${r['username'] ?? '—'}',
            ms: (r['ms'] as num?)?.toInt() ?? 0,
            character: '${r['character'] ?? 'fox'}',
            mine: me != null && r['player_id'] == me,
          ));
        }
      }
      return out;
    } catch (e) {
      debugPrint('crash_racing board: $e');
      return null;
    }
  }
}

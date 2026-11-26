import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../games/game_registry.dart';
import '../settings/app_settings.dart';
import '../storage/local_store.dart';
import '../../ui/kit/station_compat.dart';
import 'online_service.dart';

/// The online match this phone was last playing, kept on the device so the player can get back into it after the app
/// was killed (swiped away, crashed, rebooted). Written when a match page opens a live match, cleared when the match
/// ends (or the player leaves it).
@immutable
class ActiveMatchRecord {
  const ActiveMatchRecord({
    required this.matchId,
    required this.gameId,
    required this.uid,
    this.tournamentMatchId,
    this.savedAt,
  });

  final String matchId;
  final String gameId;

  /// The account that played it: another account signed in on the same phone is never offered this match.
  final String uid;
  final String? tournamentMatchId;
  final DateTime? savedAt;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'match': matchId,
        'game': gameId,
        'uid': uid,
        if (tournamentMatchId != null) 't': tournamentMatchId,
        'at': (savedAt ?? DateTime.now()).toUtc().toIso8601String(),
      };

  static ActiveMatchRecord? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    final Object? match = j['match'];
    final Object? game = j['game'];
    final Object? uid = j['uid'];
    if (match is! String || match.isEmpty || game is! String || game.isEmpty || uid is! String || uid.isEmpty) {
      return null;
    }
    final Object? t = j['t'];
    final Object? at = j['at'];
    return ActiveMatchRecord(
      matchId: match,
      gameId: game,
      uid: uid,
      tournamentMatchId: t is String && t.isNotEmpty ? t : null,
      savedAt: at is String ? DateTime.tryParse(at) : null,
    );
  }
}

/// Local persistence of [ActiveMatchRecord] (one slot: a player is in at most one online match at a time).
class ActiveMatchStore {
  ActiveMatchStore(this._store);
  final LocalStore _store;

  static const String key = 'online.active_match.v1';

  /// The app-wide store, or null before LocalStore.init() (tests / very early start-up).
  static ActiveMatchStore? get maybeInstance {
    try {
      return ActiveMatchStore(LocalStore.instance);
    } catch (_) {
      return null;
    }
  }

  ActiveMatchRecord? read() => ActiveMatchRecord.fromJson(_store.getJson(key));

  Future<void> save(ActiveMatchRecord r) => _store.setJson(key, r.toJson());

  /// Clears the slot; with [matchId] only when it still holds that match (a newer match is never wiped by an old page).
  Future<void> clear({String? matchId}) async {
    if (matchId != null) {
      final ActiveMatchRecord? cur = read();
      if (cur != null && cur.matchId != matchId) return;
    }
    await _store.remove(key);
  }
}

/// What to offer the player on start-up.
@immutable
class ResumeOffer {
  const ResumeOffer({required this.matchId, required this.gameId, this.tournamentMatchId});
  final String matchId;
  final String gameId;
  final String? tournamentMatchId;

  /// The in-app route of the match page (see router.dart '/match/:id').
  String get route => Uri(path: '/match/$matchId', queryParameters: <String, String>{
        'game': gameId,
        if (tournamentMatchId != null) 't': tournamentMatchId!,
      }).toString();
}

/// Outcome of comparing the local record with the server's answer.
@immutable
class ResumeDecision {
  const ResumeDecision({this.offer, this.clearLocal = false});
  final ResumeOffer? offer;
  final bool clearLocal;
}

/// Pure decision (unit-tested): [local] is what this phone saved, [server] the row of nx_my_active_match for the
/// signed-in [uid] (null = the server has no live match for this player, e.g. it ended, was forfeited or abandoned).
///
/// * no live match on the server → nothing to offer; a local record is stale and is cleared;
/// * a live match on the server → offer it. The local record supplies the tournament match id when it is the same
///   match; a record of another match (or another account) is replaced.
ResumeDecision decideResume({
  required ActiveMatchRecord? local,
  required Map<String, dynamic>? server,
  required String uid,
  String? serverTournamentMatchId,
}) {
  final Object? id = server?['match_id'];
  final Object? game = server?['game'];
  if (id is! String || id.isEmpty || game is! String || game.isEmpty) {
    return ResumeDecision(clearLocal: local != null);
  }
  final ActiveMatchRecord? mine = local != null && local.uid == uid && local.matchId == id ? local : null;
  return ResumeDecision(
    offer: ResumeOffer(
      matchId: id,
      gameId: game,
      tournamentMatchId: mine?.tournamentMatchId ?? serverTournamentMatchId,
    ),
    clearLocal: local != null && mine == null,
  );
}

/// The match page currently on screen (so start-up never offers the match the player is already in).
class OpenMatchTracker {
  OpenMatchTracker._();
  static final ValueNotifier<String?> openMatchId = ValueNotifier<String?>(null);
}

/// On start-up (and when an account signs in) asks the games server whether this player still has a live online match
/// and offers to go back into it. Runs once per signed-in account per app run.
class MatchResumeWatcher {
  MatchResumeWatcher(this._ref, this._messenger, this._open);

  final WidgetRef _ref;
  final GlobalKey<ScaffoldMessengerState> _messenger;
  final void Function(String route) _open;

  String? _checkedFor;
  bool _disposed = false;

  void sync() {
    final OnlineService o = _ref.read(onlineProvider);
    final String? uid = o.isOnline ? o.uid : null;
    final SupabaseClient? c = o.games;
    if (uid == null || c == null || uid == _checkedFor) return;
    _checkedFor = uid;
    unawaited(_check(c, uid));
  }

  Future<void> _check(SupabaseClient c, String uid) async {
    final ActiveMatchStore? store = ActiveMatchStore.maybeInstance;
    final ActiveMatchRecord? local = store?.read();
    Map<String, dynamic>? server;
    String? tmatch;
    try {
      final dynamic rows = await c.rpc('nx_my_active_match');
      if (rows is List && rows.isNotEmpty && rows.first is Map) {
        server = Map<String, dynamic>.from(rows.first as Map);
      } else if (rows is Map) {
        server = Map<String, dynamic>.from(rows);
      }
      if (server != null && server['tournament'] == true) {
        final Map<String, dynamic>? m =
            await c.from('nx_matches').select('settings').eq('id', '${server['match_id']}').maybeSingle();
        final Object? s = m?['settings'];
        if (s is Map && s['tmatch'] is String) tmatch = s['tmatch'] as String;
      }
    } catch (e) {
      // Server unreachable: keep the local record for the next start, offer nothing now.
      debugPrint('match resume check failed: $e');
      _checkedFor = null;
      return;
    }
    if (_disposed) return;
    final ResumeDecision d =
        decideResume(local: local, server: server, uid: uid, serverTournamentMatchId: tmatch);
    if (d.clearLocal) await store?.clear();
    final ResumeOffer? offer = d.offer;
    if (offer == null || _disposed) return;
    if (OpenMatchTracker.openMatchId.value == offer.matchId) return;
    if (store != null && local?.matchId != offer.matchId) {
      await store.save(ActiveMatchRecord(
          matchId: offer.matchId, gameId: offer.gameId, uid: uid, tournamentMatchId: offer.tournamentMatchId));
    }
    _show(offer);
  }

  void _show(ResumeOffer offer) {
    final ScaffoldMessengerState? m = _messenger.currentState;
    if (m == null) return;
    final bool fa = _ref.read(settingsProvider).isFa;
    final GameInfo? g = gameById(offer.gameId);
    final String name = g == null ? offer.gameId : (fa ? g.nameFa : g.nameEn);
    luxeToastState(
      m,
      fa ? 'بازی آنلاین $name هنوز ادامه دارد' : 'Your online $name match is still on',
      icon: Icons.sports_esports_rounded,
      actionLabel: fa ? 'بازگشت به بازی' : 'Return to game',
      onAction: () {
        if (OpenMatchTracker.openMatchId.value != offer.matchId) _open(offer.route);
      },
      duration: const Duration(seconds: 20),
    );
  }

  void dispose() => _disposed = true;
}

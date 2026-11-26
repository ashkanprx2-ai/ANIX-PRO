import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../online/online_service.dart';

/// Which balance a ledger row moved.
enum WalletCurrency { coins, gems }

/// One row of the server's append-only coin / gem ledger (public.nx_wallet_ledger, read via nx_wallet_history).
/// The server is the only writer; the app only shows the history.
@immutable
class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.currency,
    required this.delta,
    required this.balanceAfter,
    required this.reason,
    this.ref,
    this.createdAt,
  });

  /// Parses one element of the nx_wallet_history answer. Returns null for a malformed row.
  static WalletLedgerEntry? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final Map<String, dynamic> m = Map<String, dynamic>.from(raw);
    final int? id = (m['id'] as num?)?.toInt();
    final WalletCurrency? cur = switch (m['currency']) {
      'coins' => WalletCurrency.coins,
      'gems' => WalletCurrency.gems,
      _ => null,
    };
    final int? delta = (m['delta'] as num?)?.toInt();
    if (id == null || cur == null || delta == null) return null;
    return WalletLedgerEntry(
      id: id,
      currency: cur,
      delta: delta,
      balanceAfter: (m['balance_after'] as num?)?.toInt() ?? 0,
      reason: '${m['reason'] ?? ''}',
      ref: m['ref'] as String?,
      createdAt: m['created_at'] is String ? DateTime.tryParse(m['created_at'] as String) : null,
    );
  }

  final int id;
  final WalletCurrency currency;
  final int delta;
  final int balanceAfter;
  final String reason;
  final String? ref;
  final DateTime? createdAt;

  bool get isCredit => delta > 0;

  /// Broad category of [reason] for icons / labels.
  WalletReasonKind get kind => walletReasonKind(reason);
}

enum WalletReasonKind { opening, purchase, iap, iapRefund, reward, tournament, cosmetic, admin, games, other }

/// Maps a server ledger reason (e.g. 'shop:coins', 'award:daily', 'games:tournament_entry_fee', 'iap:bazaar')
/// to a category.
WalletReasonKind walletReasonKind(String reason) {
  final String r = reason.toLowerCase();
  if (r == 'opening_balance' || r == 'signup') return WalletReasonKind.opening;
  if (r.startsWith('iap_refund')) return WalletReasonKind.iapRefund;
  if (r.startsWith('iap:')) return WalletReasonKind.iap;
  if (r.startsWith('shop:')) return WalletReasonKind.purchase;
  if (r.startsWith('award:') || r == 'daily_gems' || r == 'welcome_gems' || r == 'wheel_daily') return WalletReasonKind.reward;
  if (r.startsWith('admin') || r.startsWith('owner_grant')) return WalletReasonKind.admin;
  if (r.startsWith('games:cosmetic')) return WalletReasonKind.cosmetic;
  if (r.startsWith('games:tournament')) return WalletReasonKind.tournament;
  if (r.startsWith('games:')) return WalletReasonKind.games;
  return WalletReasonKind.other;
}

/// Persian / English label for a ledger reason.
String walletReasonText(String reason, bool fa) => switch (walletReasonKind(reason)) {
      WalletReasonKind.opening => fa ? 'موجودی اولیه' : 'Opening balance',
      WalletReasonKind.purchase => fa ? 'خرید از فروشگاه' : 'Shop purchase',
      WalletReasonKind.iap => fa ? 'خرید بسته' : 'Pack purchase',
      WalletReasonKind.iapRefund => fa ? 'بازگشت وجه خرید' : 'Purchase refunded',
      WalletReasonKind.reward => fa ? 'جایزه' : 'Reward',
      WalletReasonKind.tournament => fa ? 'تورنمنت' : 'Tournament',
      WalletReasonKind.cosmetic => fa ? 'آیتم ظاهری' : 'Cosmetic',
      WalletReasonKind.admin => fa ? 'تنظیم مدیر' : 'Admin adjustment',
      WalletReasonKind.games => fa ? 'بازی' : 'Game',
      WalletReasonKind.other => fa ? 'تراکنش' : 'Transaction',
    };

/// Parses a whole nx_wallet_history answer, newest first, skipping malformed rows.
List<WalletLedgerEntry> parseWalletHistory(Object? data) {
  if (data is! List) return const <WalletLedgerEntry>[];
  final List<WalletLedgerEntry> out = <WalletLedgerEntry>[];
  for (final Object? e in data) {
    final WalletLedgerEntry? x = WalletLedgerEntry.fromJson(e);
    if (x != null) out.add(x);
  }
  out.sort((WalletLedgerEntry a, WalletLedgerEntry b) => b.id.compareTo(a.id));
  return out;
}

/// Reads the signed-in player's ledger from the core project.
class WalletLedger {
  const WalletLedger._();

  /// Up to [limit] rows older than [before] (an entry id), newest first. Empty when offline / signed out.
  static Future<List<WalletLedgerEntry>> fetch({int limit = 50, int? before}) async {
    final SupabaseClient? c = OnlineService.current?.client;
    if (c == null || c.auth.currentSession == null) return const <WalletLedgerEntry>[];
    try {
      final dynamic r = await c.rpc('nx_wallet_history', params: <String, dynamic>{'p_limit': limit, 'p_before': before});
      return parseWalletHistory(r);
    } catch (e) {
      debugPrint('nx_wallet_history: $e');
      return const <WalletLedgerEntry>[];
    }
  }
}

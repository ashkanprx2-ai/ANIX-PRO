import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../games/shared/wood_pieces.dart';
import '../online/online_service.dart';
import '../profile/profile_service.dart';
import '../storage/local_store.dart';

/// Carrom cosmetics sold for COINS (never gems): boards and piece sets.
///
/// Server: games project, supabase/games/migrations/20261125110000_g_cosmetics_shop.sql (catalog nx_cosmetics with the
/// same ids and prices as [kCarromCosmetics], RPCs buy_cosmetic / equip_cosmetic / my_cosmetics). The coins come out
/// of the player's one real balance (auth profiles.coins, via the games-project mirror + wallet bridge).
/// Guests (no account) buy locally from their local wallet, like the rest of the offline economy.
enum CosmeticKind { board, pieces }

class CarromCosmetic {
  const CarromCosmetic({
    required this.id,
    required this.kind,
    required this.nameFa,
    required this.nameEn,
    required this.price,
    required this.preview,
    this.boardAsset,
    this.pockets,
    this.piecePrefix,
    this.woodSet,
    this.rarity = 'common',
  });

  /// Catalog id: `carrom_board:<slug>` / `carrom_pieces:<slug>`.
  final String id;
  final CosmeticKind kind;
  final String nameFa, nameEn;

  /// Price in coins; 0 = free (always owned).
  final int price;

  /// Thumbnail shown in the shop.
  final String preview;

  /// Board art and its pocket centres as image fractions (left x, top y, right x, bottom y).
  final String? boardAsset;
  final List<double>? pockets;

  /// NX piece sets: `<prefix>_white|black|queen|striker0|striker1.webp` (round, rim = sprite edge).
  final String? piecePrefix;

  /// The ANIX wooden pucks (kWoodPieceSets) for the free classic sets.
  final WoodPieceSet? woodSet;
  final String rarity;

  bool get free => price <= 0;
  String get slug => id.substring(id.indexOf(':') + 1);
  String? pieceAsset(String role) => piecePrefix == null ? null : '${piecePrefix}_$role.webp';
  bool get hasStrikers => piecePrefix != null;
}

const String _nx = 'assets/games/carrom/nx/';

CarromCosmetic _board(String slug, String fa, String en, int price, String asset, List<double>? pockets,
        {String r = 'common'}) =>
    CarromCosmetic(
        id: 'carrom_board:$slug',
        kind: CosmeticKind.board,
        nameFa: fa,
        nameEn: en,
        price: price,
        preview: asset,
        boardAsset: asset,
        pockets: pockets,
        rarity: r);

CarromCosmetic _pieces(String slug, String fa, String en, int price, {String r = 'rare'}) => CarromCosmetic(
    id: 'carrom_pieces:$slug',
    kind: CosmeticKind.pieces,
    nameFa: fa,
    nameEn: en,
    price: price,
    preview: '${_nx}pieces_${slug}_queen.webp',
    piecePrefix: '${_nx}pieces_$slug',
    rarity: r);

/// Boards: the owner's classic black/gold board is the free default; the four NX2 boards stay free; the navy classic
/// and the neon boards are sold for coins (800..5000). Pocket fractions measured on the art with PIL
/// (tool/nx_kit_export*.py).
final List<CarromCosmetic> kCarromBoards = <CarromCosmetic>[
  _board('classic_black', 'کلاسیک مشکی طلایی', 'Classic Black & Gold', 0, '${_nx}board_classic_black.webp',
      <double>[0.0966, 0.1023, 0.9023, 0.8919]),
  _board('wood', 'چوبی', 'Wood', 0, 'assets/ui/nx2/boards/carrom_wood.webp', <double>[0.0741, 0.0795, 0.9200, 0.9179]),
  _board('green', 'مشکی سبز', 'Black & green', 0, 'assets/ui/nx2/boards/carrom_green.webp',
      <double>[0.1015, 0.1055, 0.9157, 0.9203]),
  _board('silver', 'نقره‌ای', 'Silver', 0, 'assets/ui/nx2/boards/carrom_silver.webp',
      <double>[0.0782, 0.0989, 0.8998, 0.8915]),
  _board('black_gold', 'مشکی طلایی', 'Black & gold', 0, 'assets/games/carrom/board_nx_black_gold.webp', null),
  _board('classic_navy', 'کلاسیک سرمه‌ای طلایی', 'Classic Navy & Gold', 800, '${_nx}board_classic_navy.webp',
      <double>[0.1044, 0.1064, 0.8941, 0.8839], r: 'rare'),
  _board('neon_blue', 'نئون آبی', 'Neon Blue', 1500, '${_nx}board_neon_blue.webp',
      <double>[0.0745, 0.0724, 0.9241, 0.9208], r: 'rare'),
  _board('neon_magenta', 'نئون سرخابی', 'Neon Magenta', 2500, '${_nx}board_neon_magenta.webp',
      <double>[0.0745, 0.0724, 0.9241, 0.9208], r: 'epic'),
  _board('neon_emerald', 'نئون زمردی', 'Neon Emerald', 3000, '${_nx}board_neon_emerald.webp',
      <double>[0.0745, 0.0724, 0.9241, 0.9208], r: 'epic'),
  _board('neon_gold', 'نئون طلایی', 'Neon Gold', 5000, '${_nx}board_neon_gold.webp',
      <double>[0.0745, 0.0724, 0.9241, 0.9208], r: 'legendary'),
];

/// Piece sets: the six ANIX wooden sets stay free; the NX sets are sold for coins (500..5000).
final List<CarromCosmetic> kCarromPieceSets = <CarromCosmetic>[
  for (final WoodPieceSet w in kWoodPieceSets)
    CarromCosmetic(
        id: 'carrom_pieces:${w.id}',
        kind: CosmeticKind.pieces,
        nameFa: w.nameFa,
        nameEn: w.nameEn,
        price: 0,
        preview: w.dark,
        woodSet: w),
  _pieces('neon_star', 'ستاره‌ی نئون', 'Neon Star', 500, r: 'common'),
  _pieces('frost_night', 'یخ و شب', 'Frost & Night', 800),
  _pieces('gem_duel', 'دوئل جواهر', 'Gem Duel', 1200),
  _pieces('classic_chips', 'ژتون کلاسیک', 'Classic Chips', 1500),
  _pieces('casino_suits', 'خال‌های ورق', 'Card Suits', 2000, r: 'epic'),
  _pieces('crown_royale', 'تاج سلطنتی', 'Crown Royale', 2500, r: 'epic'),
  _pieces('elements', 'عناصر', 'Elements', 3500, r: 'epic'),
  _pieces('beasts', 'جانوران', 'Beasts', 4000, r: 'legendary'),
  _pieces('car_club', 'باشگاه خودرو', 'Car Club', 5000, r: 'legendary'),
];

List<CarromCosmetic> get kCarromCosmetics => <CarromCosmetic>[...kCarromBoards, ...kCarromPieceSets];

CarromCosmetic? carromCosmetic(String id) {
  for (final CarromCosmetic c in kCarromCosmetics) {
    if (c.id == id) return c;
  }
  return null;
}

/// Result of a cosmetic purchase.
class CosmeticBuyResult {
  const CosmeticBuyResult(this.ok, {this.error, this.coins});
  final bool ok;
  final String? error; // insufficient_coins | not_for_sale | network | busy | ...
  final int? coins;
}

/// Ownership / equip / purchase of carrom cosmetics. Local cache: ProfileService.inventory (owned ids) and LocalStore
/// (`carrom.board_item`, `carrom.pieces_item`); signed-in players are synced from / to the games project.
class CarromCosmetics extends ChangeNotifier {
  CarromCosmetics._();
  static final CarromCosmetics instance = CarromCosmetics._();

  static const String kBoardKey = 'carrom.board_item', kPiecesKey = 'carrom.pieces_item';
  bool busy = false;
  final Map<String, int> _serverPrices = <String, int>{};
  final Set<String> _inactive = <String>{};

  ProfileService? get _p => ProfileService.current;
  OnlineService? get _o => OnlineService.current;
  bool get _signedIn => _o?.client?.auth.currentSession != null;

  int priceOf(CarromCosmetic c) => _serverPrices[c.id] ?? c.price;
  bool forSale(CarromCosmetic c) => !_inactive.contains(c.id);

  bool owns(CarromCosmetic c) => priceOf(c) <= 0 || (_p?.owns(c.id) ?? false);

  CarromCosmetic _equipped(List<CarromCosmetic> list, String key, int legacy) {
    String? id;
    try {
      id = LocalStore.instance.getString(key);
    } catch (_) {}
    if (id != null) {
      for (final CarromCosmetic c in list) {
        if (c.id == id && owns(c)) return c;
      }
    }
    return list[legacy.clamp(0, list.length - 1)];
  }

  /// Equipped board (default: the free classic black & gold board).
  CarromCosmetic get board => _equipped(kCarromBoards, kBoardKey, 0);

  /// Equipped piece set (default: the wooden set picked before this shop existed).
  CarromCosmetic get pieces {
    int legacy = 0;
    try {
      legacy = woodPieceIndex('carrom');
    } catch (_) {}
    return _equipped(kCarromPieceSets, kPiecesKey, legacy);
  }

  bool isEquipped(CarromCosmetic c) => (c.kind == CosmeticKind.board ? board : pieces).id == c.id;

  /// Equips an owned item (locally at once; on the server when signed in).
  Future<bool> equip(CarromCosmetic c) async {
    if (!owns(c)) return false;
    try {
      await LocalStore.instance.setString(c.kind == CosmeticKind.board ? kBoardKey : kPiecesKey, c.id);
    } catch (_) {}
    notifyListeners();
    if (_signedIn) {
      unawaited(_rpc('equip_cosmetic', <String, dynamic>{'p_item': c.id}).catchError((Object e) {
        debugPrint('equip_cosmetic: $e');
        return null;
      }));
    }
    return true;
  }

  Future<dynamic> _rpc(String fn, Map<String, dynamic>? params) async {
    final OnlineService? o = _o;
    if (o == null) return null;
    return o.grpc(fn, params);
  }

  /// Buys [c] with coins. Signed in: the games-project RPC checks the catalog price and the balance and deducts
  /// atomically. Guest: the local wallet. Never charges twice; equips on success.
  Future<CosmeticBuyResult> buy(CarromCosmetic c) async {
    final ProfileService? p = _p;
    if (owns(c)) {
      await equip(c);
      return CosmeticBuyResult(true, coins: p?.coins);
    }
    if (!forSale(c)) return const CosmeticBuyResult(false, error: 'not_for_sale');
    if (busy) return const CosmeticBuyResult(false, error: 'busy');
    final int price = priceOf(c);
    busy = true;
    notifyListeners();
    try {
      if (!_signedIn) {
        if (p == null) return const CosmeticBuyResult(false, error: 'offline');
        if (p.coins < price) return CosmeticBuyResult(false, error: 'insufficient_coins', coins: p.coins);
        final bool ok = p.purchaseLocal(c.id, price, nameFa: c.nameFa, nameEn: c.nameEn);
        if (!ok) return CosmeticBuyResult(false, error: 'insufficient_coins', coins: p.coins);
        await equip(c);
        return CosmeticBuyResult(true, coins: p.coins);
      }
      final dynamic r = await _rpc('buy_cosmetic', <String, dynamic>{'p_item': c.id});
      if (r is! Map) return const CosmeticBuyResult(false, error: 'network');
      final int? coins = (r['coins'] as num?)?.toInt();
      if (coins != null) p?.applyWallet(coins: coins);
      if (r['ok'] == true) {
        p?.grantItem(c.id);
        await equip(c);
        return CosmeticBuyResult(true, coins: coins);
      }
      return CosmeticBuyResult(false, error: '${r['error'] ?? 'failed'}', coins: coins);
    } catch (e) {
      debugPrint('buy_cosmetic: $e');
      return const CosmeticBuyResult(false, error: 'network');
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  /// Pulls owned / equipped items and live prices from the games project (signed-in players). Never throws.
  Future<void> refresh() async {
    if (!_signedIn) return;
    try {
      final dynamic r = await _rpc('my_cosmetics', null);
      if (r is Map && r['ok'] == true) {
        final ProfileService? p = _p;
        for (final dynamic id in (r['owned'] as List?) ?? const <dynamic>[]) {
          if (p != null && !p.owns('$id')) p.grantItem('$id');
        }
        final dynamic eq = r['equipped'];
        if (eq is Map) {
          final dynamic b = eq['carrom.board'], pc = eq['carrom.pieces'];
          if (b is String) await LocalStore.instance.setString(kBoardKey, b);
          if (pc is String) await LocalStore.instance.setString(kPiecesKey, pc);
        }
        final int? coins = (r['coins'] as num?)?.toInt();
        if (coins != null) p?.applyWallet(coins: coins);
      }
      final OnlineService? o = _o;
      final dynamic rows = await o?.games?.from('nx_cosmetics').select('item_id, price_coins, active').eq('game', 'carrom');
      if (rows is List) {
        _serverPrices.clear();
        _inactive.clear();
        for (final dynamic e in rows) {
          final Map<dynamic, dynamic> m = e as Map<dynamic, dynamic>;
          _serverPrices['${m['item_id']}'] = (m['price_coins'] as num?)?.toInt() ?? 0;
          if (m['active'] == false) _inactive.add('${m['item_id']}');
        }
      }
    } catch (e) {
      debugPrint('my_cosmetics: $e');
    }
    notifyListeners();
  }
}

/// Persian / English text for a cosmetic-shop error.
String cosmeticErrorText(String? e, bool fa) => switch (e) {
      'insufficient_coins' => fa ? 'سکه‌ی کافی نداری' : 'Not enough coins',
      'not_for_sale' => fa ? 'این آیتم فعلاً فروشی نیست' : 'Not for sale right now',
      'network' || 'offline' => fa ? 'اتصال برقرار نیست' : 'No connection',
      'no_profile' || 'not_signed_in' => fa ? 'دوباره وارد حساب شو' : 'Please sign in again',
      'busy' => fa ? 'یک لحظه صبر کن' : 'One moment',
      _ => fa ? 'خرید انجام نشد' : 'Purchase failed',
    };

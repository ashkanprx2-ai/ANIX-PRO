import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalog/catalog.dart';
import '../../core/economy/carrom_shop_view.dart';
import '../../core/economy/bazaar_store.dart';
import '../../core/economy/gem_shop.dart';
import '../../core/economy/victory_fx.dart';
import '../../core/economy/wallet_ledger.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../../games/finger_soccer/core/bm_data.dart';
import '../../games/finger_soccer/core/bm_engine.dart';
import '../../worlds/nexora_exchange/core/exchange_rules.dart';
import '../../worlds/nexora_exchange/core/exchange_service.dart';
import '../kit/station_kit.dart';

// =====================================================================================================================
// SHOP world: SHOP (the real coin catalogue + carrom cosmetics), gems & finger-soccer teams, THEMES (app skin),
// FRAMES (profile frames) — `SHOP(x)` / `THEMEP` of nexora-screens.js.
// =====================================================================================================================

int _rarity(String r) => switch (r) {
      'legendary' => 4,
      'epic' => 3,
      'rare' => 2,
      _ => 1,
    };

String _catName(BuildContext context, ItemCategory c) => switch (c) {
      ItemCategory.avatarGear => stx(context, 'پوشش آواتار', 'Avatar gear'),
      ItemCategory.decor => stx(context, 'دکور', 'Decor'),
      ItemCategory.puck => stx(context, 'مهره', 'Pucks'),
      ItemCategory.striker => stx(context, 'استرایکر', 'Strikers'),
      ItemCategory.cue => stx(context, 'چوب بیلیارد', 'Cues'),
      ItemCategory.theme => stx(context, 'فضای من', 'Space themes'),
      ItemCategory.frame => stx(context, 'قاب', 'Frames'),
      ItemCategory.badge => stx(context, 'نشان', 'Badges'),
    };

String purchaseError(BuildContext context, PurchaseStatus s) => switch (s) {
      PurchaseStatus.ok => stx(context, 'خرید انجام شد', 'Purchased'),
      PurchaseStatus.alreadyOwned => stx(context, 'قبلاً خریده‌ای', 'Already owned'),
      PurchaseStatus.levelLocked => stx(context, 'سطحت هنوز کافی نیست', 'Your level is too low'),
      PurchaseStatus.notEnoughCoins => stx(context, 'موجودی کافی نیست', 'Not enough coins'),
      PurchaseStatus.unknownItem => stx(context, 'این آیتم پیدا نشد', 'Item not found'),
    };

/// One catalogue tile: art, name, price / owned / equipped, buy then equip.
class _ItemTile extends ConsumerWidget {
  const _ItemTile(this.item);
  final CatalogItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileService p = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    final bool owned = p.owns(item.id) || item.price == 0;
    final bool eq = ExchangeService.isEquipped(p, item);
    final bool locked = p.level < item.minLevel && !owned;
    return StationTile(
      image: Image.asset(item.asset, width: 54, height: 48, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const StationIcon('r4c1', size: 46)),
      title: fa ? item.nameFa : item.nameEn,
      on: eq,
      locked: locked,
      subtitle: locked ? '${stx(context, 'سطح', 'Level')} ${nxNum(context, item.minLevel)}' : null,
      footer: Column(children: <Widget>[
        StationRarity(_rarity(item.rarity)),
        const SizedBox(height: 6),
        StationButton(
          small: true,
          expand: false,
          ghost: owned,
          label: eq ? stx(context, 'فعال', 'Active') : owned ? stx(context, 'انتخاب', 'Use') : '🪙 ${nxNum(context, item.price)}',
          onTap: eq
              ? null
              : () async {
                  if (!owned) {
                    final bool ok = await showStationConfirm(context,
                        title: fa ? item.nameFa : item.nameEn,
                        message: fa ? 'خرید با ${nxNum(context, item.price)} سکه؟' : 'Buy for ${item.price} coins?',
                        confirm: stx(context, 'خرید', 'Buy'));
                    if (!ok || !context.mounted) return;
                    final PurchaseStatus s = ExchangeService.buy(p, item);
                    if (s != PurchaseStatus.ok) {
                      stationToast(context, purchaseError(context, s), error: true);
                      return;
                    }
                    await showStationModal(context, big: '✨', title: stx(context, 'خرید انجام شد', 'Purchased'), text: fa ? item.nameFa : item.nameEn);
                  }
                  ExchangeService.equip(p, item);
                },
        ),
      ]),
    );
  }
}

/// `SHOP(Shop)` — the coin catalogue by category, plus carrom cosmetics.
class StationShopScreen extends ConsumerStatefulWidget {
  const StationShopScreen({super.key, this.only});
  final ItemCategory? only;

  @override
  ConsumerState<StationShopScreen> createState() => _StationShopScreenState();
}

class _StationShopScreenState extends ConsumerState<StationShopScreen> {
  int _cat = 0;

  @override
  Widget build(BuildContext context) {
    ref.watch(profileProvider);
    final List<ItemCategory> cats = widget.only != null
        ? <ItemCategory>[widget.only!]
        : ItemCategory.values.where((ItemCategory c) => kCatalog.any((CatalogItem i) => i.category == c)).toList();
    final ItemCategory c = cats[_cat.clamp(0, cats.length - 1)];
    final List<CatalogItem> items = kCatalog.where((CatalogItem i) => i.category == c).toList();
    return StationScreen(
      title: widget.only == ItemCategory.frame ? stx(context, 'قاب‌ها', 'Frames') : stx(context, 'فروشگاه', 'Shop'),
      latin: 'SHOP',
      children: <Widget>[
        if (cats.length > 1) StationSeg(labels: <String>[for (final ItemCategory x in cats) _catName(context, x)], index: _cat, onChanged: (int i) => setState(() => _cat = i)),
        if (widget.only == null) ...<Widget>[
          StationTitle(stx(context, 'بسته‌های ویژه', 'Special packs')),
          StationGrid(children: <Widget>[
            StationTile(icon: 'r3c6', title: stx(context, 'جم و تیم‌ها', 'Gems & teams'), subtitle: stx(context, 'تیم‌های فوتبال انگشتی', 'Finger-soccer teams'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StationGemsScreen()))),
            StationTile(icon: 'g_carrom', title: stx(context, 'لوازم کارم', 'Carrom gear'), subtitle: stx(context, 'تخته و استرایکر', 'Boards & strikers'),
                onTap: () => showCarromShop(context, isFa: stationFa(context))),
          ]),
          StationTitle(_catName(context, c)),
        ],
        StationGrid(children: <Widget>[for (final CatalogItem i in items) _ItemTile(i)]),
      ],
    );
  }
}

/// Gems: daily free gems and the finger-soccer teams sold for gems (server prices, server purchase).
class StationGemsScreen extends ConsumerStatefulWidget {
  const StationGemsScreen({super.key});

  @override
  ConsumerState<StationGemsScreen> createState() => _StationGemsScreenState();
}

class _StationGemsScreenState extends ConsumerState<StationGemsScreen> {
  final GemShop shop = GemShop.instance;
  final BazaarStore store = BazaarStore.instance;
  int _cat = 0;

  String _toman(BuildContext context, int v) {
    final String s = v.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (Match m) => '${m[1]},');
    return stationFa(context) ? '${nxNum(context, v)} تومان' : '$s toman';
  }

  Future<void> _buyPack(IapPack pack) async {
    final bool fa = stationFa(context);
    final IapResult r = await store.buy(pack);
    if (!mounted) return;
    if (r.ok) {
      final String what = r.grantedGems > 0
          ? (fa ? '${nxNum(context, r.grantedGems)} جم' : '${r.grantedGems} gems')
          : (fa ? '${nxNum(context, r.grantedCoins)} سکه' : '${r.grantedCoins} coins');
      await showStationModal(context, big: r.grantedGems > 0 ? '💎' : '🪙', title: stx(context, 'خرید موفق', 'Purchase complete'), text: fa ? '$what به حسابت اضافه شد ✓' : '$what added ✓');
    } else if (r.error != 'cancelled') {
      stationToast(context, iapErrorText(r.error, fa), error: true);
    }
  }

  @override
  void initState() {
    super.initState();
    shop.addListener(_on);
    store.addListener(_on);
    if (!shop.loaded) unawaited(shop.refresh());
    if (!store.loaded) unawaited(store.load());
  }

  @override
  void dispose() {
    shop.removeListener(_on);
    store.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  Future<void> _buy(BmTeam t) async {
    final ProfileService p = ref.read(profileProvider);
    final int price = shop.teamPrice(t.id);
    final bool fa = stationFa(context);
    final bool ok = await showStationConfirm(context,
        title: fa ? t.faName : t.name,
        message: fa ? 'خرید با ${nxNum(context, price)} جم؟\nموجودی بعد از خرید: ${nxNum(context, p.gems - price)}' : 'Buy for $price gems?\nBalance after: ${p.gems - price}',
        confirm: stx(context, 'خرید', 'Buy'));
    if (!ok) return;
    final GemBuyResult r = await shop.buyTeam(t.id);
    if (!mounted) return;
    stationToast(context, r.ok ? (fa ? '${t.faName} باز شد ✓' : '${t.name} unlocked ✓') : gemErrorText(r.error, fa), error: !r.ok);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(profileProvider);
    final bool fa = stationFa(context);
    final List<List<Object>> cats = kBmCats.where((List<Object> c) => c[0] != 'custom').toList();
    final List<BmTeam> teams = kBmTeams.where((BmTeam t) => t.cat == cats[_cat][0]).toList()
      ..sort((BmTeam a, BmTeam b) => shop.teamPrice(a.id).compareTo(shop.teamPrice(b.id)));
    return StationScreen(
      title: stx(context, 'جم و تیم‌ها', 'Gems & teams'),
      children: <Widget>[
        StationCard(
          hero: true,
          child: Column(children: <Widget>[
            const StationIcon('r3c6', size: 70),
            const SizedBox(height: 6),
            Text(stx(context, 'جم روزانه‌ی رایگان', 'Free daily gems'), style: const TextStyle(fontSize: 18)),
            StationButton(
              label: stx(context, 'دریافت', 'Claim'),
              small: true,
              expand: false,
              onTap: shop.online
                  ? () async {
                      final int g = await shop.claimDaily();
                      if (context.mounted) {
                        stationToast(context, g > 0 ? (fa ? 'جم روزانه: +${nxNum(context, g)}' : 'Daily gems: +$g') : stx(context, 'امروز گرفته‌ای', 'Already claimed today'));
                      }
                    }
                  : () => stationToast(context, stx(context, 'جم‌ها به حساب آنلاین نیاز دارند', 'Gems need an online account')),
              margin: const EdgeInsets.only(top: 10),
            ),
          ]),
        ),
        // Coin & gem packs paid in rials through Cafe Bazaar (contents + prices from nx_iap_products; the server verifies
        // the purchase token and credits through the wallet ledger).
        StationTitle(stx(context, 'بسته‌های سکه و جم · کافه‌بازار', 'Coin & gem packs · Cafe Bazaar')),
        if (!store.configured)
          StationEmpty(text: iapErrorText('not_configured', fa), icon: 'r3c6')
        else if (store.packs.isEmpty && !store.loaded)
          const StationEmpty(text: '…', loading: true)
        else
          StationRows(children: <Widget>[
            for (int i = 0; i < store.packs.length; i++)
              StationRow(
                first: i == 0,
                leading: store.packs[i].gems > 0 ? const StationGem(size: 26) : const StationCoin(size: 26),
                title: fa ? store.packs[i].titleFa : store.packs[i].titleEn,
                subtitle: fa ? store.packs[i].badgeFa : null,
                trailing: StationButton(
                  small: true,
                  expand: false,
                  label: _toman(context, store.packs[i].priceToman),
                  onTap: store.busy ? null : () => _buyPack(store.packs[i]),
                ),
              ),
          ]),
        // Victory effects: the gem item for every online game (bought through nx_buy_with_gems, equipped in slot win_fx).
        StationTitle(stx(context, 'افکت پیروزی · همه بازی‌ها', 'Victory effects · every game')),
        StationTile(
          icon: 'r5c6',
          title: equippedVictoryFx(ref.read(profileProvider)) == null
              ? stx(context, 'افکت پیروزی', 'Victory effects')
              : (fa ? equippedVictoryFx(ref.read(profileProvider))!.nameFa : equippedVictoryFx(ref.read(profileProvider))!.nameEn),
          subtitle: stx(context, 'بعد از هر برد آنلاین', 'After every online win'),
          onTap: () => showVictoryFxShop(context, fa: fa),
        ),
        StationTile(
          icon: 'r2c6',
          title: stx(context, 'تاریخچه‌ی کیف پول', 'Wallet history'),
          subtitle: stx(context, 'همه‌ی تراکنش‌های سکه و جم', 'Every coin & gem change'),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const StationWalletHistoryScreen())),
        ),
        StationTitle(stx(context, 'تیم‌های فوتبال انگشتی', 'Finger-soccer teams')),
        StationSeg(labels: <String>[for (final List<Object> c in cats) fa ? '${c[2]}' : '${c[1]}'], index: _cat, onChanged: (int i) => setState(() => _cat = i)),
        StationGrid(columns: 3, gap: 10, children: <Widget>[
          for (final BmTeam t in teams)
            Builder(builder: (BuildContext context) {
              final bool own = shop.ownsTeam(t.id);
              return StationTile(
                image: Image.asset(t.asset, width: 52, height: 52, cacheWidth: 160),
                title: fa ? t.faName : t.name,
                subtitle: '⚡${nxNum(context, t.power)} 🎯${nxNum(context, t.accuracy)}',
                footer: StationButton(
                  small: true,
                  expand: false,
                  ghost: own,
                  label: own ? stx(context, 'داری', 'Owned') : '💎 ${nxNum(context, shop.teamPrice(t.id))}',
                  onTap: own || !shop.teamForSale(t.id) ? null : () => _buy(t),
                ),
              );
            }),
        ]),
      ],
    );
  }
}

/// Wallet history: the signed-in player's append-only coin / gem ledger (nx_wallet_history), newest first.
class StationWalletHistoryScreen extends StatefulWidget {
  const StationWalletHistoryScreen({super.key});

  @override
  State<StationWalletHistoryScreen> createState() => _StationWalletHistoryScreenState();
}

class _StationWalletHistoryScreenState extends State<StationWalletHistoryScreen> {
  List<WalletLedgerEntry>? _rows;

  @override
  void initState() {
    super.initState();
    unawaited(WalletLedger.fetch(limit: 100).then((List<WalletLedgerEntry> r) {
      if (mounted) setState(() => _rows = r);
    }));
  }

  @override
  Widget build(BuildContext context) {
    final bool fa = stationFa(context);
    final List<WalletLedgerEntry>? rows = _rows;
    return StationScreen(
      title: stx(context, 'تاریخچه‌ی کیف پول', 'Wallet history'),
      latin: 'LEDGER',
      children: <Widget>[
        if (rows == null)
          const StationEmpty(text: '…', loading: true)
        else if (rows.isEmpty)
          StationEmpty(text: stx(context, 'هنوز تراکنشی نیست (یا آفلاینی)', 'No transactions yet (or offline)'))
        else
          StationRows(children: <Widget>[
            for (int i = 0; i < rows.length; i++)
              StationRow(
                first: i == 0,
                leading: rows[i].currency == WalletCurrency.gems ? const StationGem(size: 26) : const StationCoin(size: 26),
                title: walletReasonText(rows[i].reason, fa),
                subtitle: rows[i].createdAt == null
                    ? null
                    : '${nxNum(context, rows[i].createdAt!.toLocal().month, group: false)}/${nxNum(context, rows[i].createdAt!.toLocal().day, group: false)} · ${stx(context, 'مانده', 'balance')} ${nxNum(context, rows[i].balanceAfter)}',
                trailing: Text('${rows[i].delta > 0 ? '+' : '−'}${nxNum(context, rows[i].delta.abs())}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: rows[i].delta > 0 ? const Color(0xFF4DFF88) : const Color(0xFFFF6B6B))),
              ),
          ]),
      ],
    );
  }
}

/// `THEMEP` — choose the app theme: «نارنجی ـ سرمه‌ای» (neon) or «سفید» (white).
class StationThemesScreen extends ConsumerWidget {
  const StationThemesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final StationPalette p = StationPalette.of(context);
    Widget opt(StationSkin k, String t, String d, Gradient g) {
      final bool sel = s.stationSkin == k;
      return StationCard(
        glow: sel ? p.gold : null,
        onTap: () {
          s.stationSkin = k;
          stationToast(context, k == StationSkin.white ? stx(context, 'تم سفید فعال شد', 'White theme on') : stx(context, 'تم نارنجی ـ سرمه‌ای فعال شد', 'Neon theme on'));
        },
        child: Row(children: <Widget>[
          Container(width: 64, height: 64, decoration: BoxDecoration(gradient: g, borderRadius: BorderRadius.circular(20), boxShadow: <BoxShadow>[BoxShadow(color: p.gold.withValues(alpha: .4), blurRadius: 24, spreadRadius: -6)])),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
              Text(d, style: TextStyle(fontSize: 11.5, color: p.mute)),
            ]),
          ),
          Text(sel ? 'ACTIVE' : 'SELECT', style: StationText.lat(context, size: 10)),
        ]),
      );
    }

    return StationScreen(
      title: stx(context, 'پوسته‌ها', 'Themes'),
      children: <Widget>[
        StationTitle(stx(context, 'انتخاب تم برنامه', 'Choose the app theme')),
        opt(StationSkin.neon, stx(context, 'نارنجی ـ سرمه‌ای', 'Neon orange · navy'), stx(context, 'تم تیره‌ی نئونی با کهکشان', 'Dark neon galaxy theme'),
            const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Color(0xFFFF9A3D), Color(0xFFFF4F8B), Color(0xFF1A1450)], stops: <double>[0, .45, 1])),
        opt(StationSkin.white, stx(context, 'سفید', 'White'), stx(context, 'تم روشن با کریستال و قاب طلایی', 'Light crystal theme with gold frames'),
            const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: <Color>[Colors.white, Color(0xFF9CC0FF), Color(0xFFD19A22)], stops: <double>[0, .55, 1])),
        StationTitle(stx(context, 'تم فضای من', 'My-space themes')),
        StationGrid(children: <Widget>[for (final CatalogItem i in kCatalog.where((CatalogItem i) => i.category == ItemCategory.theme)) _ItemTile(i)]),
      ],
    );
  }
}

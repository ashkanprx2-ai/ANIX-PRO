import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalog/catalog.dart';
import '../../core/economy/carrom_shop_view.dart';
import '../../core/economy/gem_shop.dart';
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
  int _cat = 0;

  @override
  void initState() {
    super.initState();
    shop.addListener(_on);
    if (!shop.loaded) unawaited(shop.refresh());
  }

  @override
  void dispose() {
    shop.removeListener(_on);
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

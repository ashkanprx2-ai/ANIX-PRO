import 'dart:async';

import 'package:flutter/material.dart';

import '../profile/profile_service.dart';
import '../ui2/nx_kit.dart';
import 'carrom_cosmetics.dart';

const Color _kGold = Color(0xFFFFD27A);
const Color _kInk = Color(0xFF0E1226);

String _faNum(String s, bool fa) {
  if (!fa) return s;
  const String d = '۰۱۲۳۴۵۶۷۸۹';
  return s.split('').map((String c) {
    final int? n = int.tryParse(c);
    return n == null ? c : d[n];
  }).join();
}

/// Carrom boards + piece sets for COINS: buy (confirm first), equip. Used as the Exchange "Carrom" tab and as the
/// in-game sheet (carrom HUD). [slivers] wraps the grid for a NestedScrollView tab.
class CarromShopPanel extends StatefulWidget {
  const CarromShopPanel({super.key, required this.isFa, this.onChanged, this.header, this.scrollHeader});
  final bool isFa;

  /// Called after an equip / purchase (the carrom view reloads its art).
  final VoidCallback? onChanged;
  final Widget? header;

  /// Slivers inserted before the content (Exchange: the NestedScrollView overlap injector).
  final List<Widget> Function(BuildContext context)? scrollHeader;

  @override
  State<CarromShopPanel> createState() => _CarromShopPanelState();
}

class _CarromShopPanelState extends State<CarromShopPanel> {
  final CarromCosmetics shop = CarromCosmetics.instance;
  int _tab = 0;

  String tx(String fa, String en) => widget.isFa ? fa : en;

  @override
  void initState() {
    super.initState();
    shop.addListener(_on);
    ProfileService.current?.addListener(_on);
    unawaited(shop.refresh());
  }

  @override
  void dispose() {
    shop.removeListener(_on);
    ProfileService.current?.removeListener(_on);
    super.dispose();
  }

  void _on() {
    if (mounted) setState(() {});
  }

  Future<void> _tap(CarromCosmetic c) async {
    if (shop.owns(c)) {
      await shop.equip(c);
      widget.onChanged?.call();
      return;
    }
    final int price = shop.priceOf(c);
    final int coins = ProfileService.current?.coins ?? 0;
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => Directionality(
        textDirection: widget.isFa ? TextDirection.rtl : TextDirection.ltr,
        child: AlertDialog(
          backgroundColor: _kInk,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _kGold, width: 1.2)),
          title: Row(children: <Widget>[
            NxKitImage(NxKit.rarityEmblem(c.rarity), size: 30),
            const SizedBox(width: 8),
            Expanded(
                child: Text(tx(c.nameFa, c.nameEn),
                    style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900))),
          ]),
          content: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
            SizedBox(height: 120, child: _Preview(c)),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              const NxCoinIcon(size: 22),
              const SizedBox(width: 6),
              Text(_faNum('$price', widget.isFa),
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 6),
            Text(
                tx('موجودی بعد از خرید: ${_faNum('${coins - price}', true)} سکه',
                    'Balance after purchase: ${coins - price} coins'),
                style: TextStyle(color: coins >= price ? Colors.white70 : const Color(0xFFFF6B81), fontSize: 13)),
          ]),
          actions: <Widget>[
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tx('انصراف', 'Cancel'))),
            FilledButton.icon(
                onPressed: coins >= price ? () => Navigator.pop(ctx, true) : null,
                icon: const NxCoinIcon(size: 18),
                label: Text(tx('خرید', 'Buy'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final CosmeticBuyResult r = await shop.buy(c);
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(r.ok
            ? tx('«${c.nameFa}» خریده و انتخاب شد ✓', '"${c.nameEn}" bought and equipped ✓')
            : cosmeticErrorText(r.error, widget.isFa))));
    if (r.ok) widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final List<CarromCosmetic> items = _tab == 0 ? kCarromBoards : kCarromPieceSets;
    final int coins = ProfileService.current?.coins ?? 0;
    final Widget top = Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Column(mainAxisSize: MainAxisSize.min, children: <Widget>[
        if (widget.header != null) widget.header!,
        Row(children: <Widget>[
          const NxKitImage(NxKit.chest, size: 40, fallback: Icons.inventory_2_rounded),
          const SizedBox(width: 8),
          Expanded(
            child: Text(tx('فروشگاه کارم · فقط با سکه', 'Carrom shop · coins only'),
                style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 15)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: const Color(0x33FFC94A),
                border: Border.all(color: const Color(0x88FFC94A))),
            child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
              const NxCoinIcon(size: 18),
              const SizedBox(width: 5),
              Text(_faNum('$coins', widget.isFa),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
            ]),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: <Widget>[
          for (int i = 0; i < 2; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: ChoiceChip(
                  selected: _tab == i,
                  onSelected: (_) => setState(() => _tab = i),
                  label: SizedBox(
                      width: double.infinity,
                      child: Text(i == 0 ? tx('صفحه‌ها', 'Boards') : tx('مهره‌ها', 'Pieces'),
                          textAlign: TextAlign.center)),
                ),
              ),
            ),
        ]),
      ]),
    );
    final Widget grid = SliverPadding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 190, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 0.74),
        delegate: SliverChildBuilderDelegate(
          (BuildContext c, int i) => _Card(
              item: items[i],
              owned: shop.owns(items[i]),
              equipped: shop.isEquipped(items[i]),
              price: shop.priceOf(items[i]),
              isFa: widget.isFa,
              onTap: () => _tap(items[i])),
          childCount: items.length,
        ),
      ),
    );
    return Directionality(
      textDirection: widget.isFa ? TextDirection.rtl : TextDirection.ltr,
      child: Builder(
        builder: (BuildContext ctx) => CustomScrollView(
          key: const PageStorageKey<String>('carrom.shop'),
          slivers: <Widget>[
            ...?widget.scrollHeader?.call(ctx),
            SliverToBoxAdapter(child: top),
            grid,
          ],
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview(this.c);
  final CarromCosmetic c;

  @override
  Widget build(BuildContext context) {
    if (c.kind == CosmeticKind.board) {
      return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: NxKitImage(c.preview, size: 120, fallback: Icons.grid_on_rounded));
    }
    final String? w = c.woodSet?.light ?? c.pieceAsset('white');
    final String? b = c.woodSet?.dark ?? c.pieceAsset('black');
    final String? q = c.pieceAsset('queen');
    final String? s = c.pieceAsset('striker0');
    return LayoutBuilder(builder: (BuildContext ctx, BoxConstraints k) {
      final double u = (k.maxHeight.isFinite ? k.maxHeight : 120) * 0.42;
      return Stack(alignment: Alignment.center, children: <Widget>[
        if (s != null) Positioned(top: 0, child: NxKitImage(s, size: u * 1.1)),
        if (w != null) Positioned(left: 0, bottom: 4, child: NxKitImage(w, size: u)),
        if (b != null) Positioned(right: 0, bottom: 4, child: NxKitImage(b, size: u)),
        if (q != null) Positioned(bottom: 0, child: NxKitImage(q, size: u * 0.9)),
      ]);
    });
  }
}

class _Card extends StatelessWidget {
  const _Card(
      {required this.item,
      required this.owned,
      required this.equipped,
      required this.price,
      required this.isFa,
      required this.onTap});
  final CarromCosmetic item;
  final bool owned, equipped, isFa;
  final int price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color edge = equipped ? const Color(0xFF3BFFB0) : (owned ? const Color(0x88FFFFFF) : _kGold);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[Color(0xFF1B1F3A), _kInk]),
          border: Border.all(color: edge, width: equipped ? 2 : 1),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(children: <Widget>[
          Row(children: <Widget>[
            NxKitImage(NxKit.rarityBadge(item.rarity), size: 20, fallback: Icons.shield_rounded),
            const Spacer(),
            if (equipped) const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF3BFFB0)),
          ]),
          Expanded(child: Padding(padding: const EdgeInsets.all(4), child: _Preview(item))),
          Text(isFa ? item.nameFa : item.nameEn,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(height: 4),
          if (owned)
            Text(
                equipped
                    ? (isFa ? 'انتخاب‌شده' : 'Equipped')
                    : (price == 0 ? (isFa ? 'رایگان · انتخاب' : 'Free · equip') : (isFa ? 'خریده‌شده · انتخاب' : 'Owned · equip')),
                style: TextStyle(
                    color: equipped ? const Color(0xFF3BFFB0) : Colors.white70,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700))
          else
            Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              const NxCoinIcon(size: 16),
              const SizedBox(width: 4),
              Text(_faNum('$price', isFa),
                  style: const TextStyle(color: _kGold, fontWeight: FontWeight.w900, fontSize: 14)),
            ]),
        ]),
      ),
    );
  }
}

/// In-game sheet (carrom HUD): the shop with gold ornament corners.
Future<void> showCarromShop(BuildContext context, {required bool isFa, VoidCallback? onChanged}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) => FractionallySizedBox(
      heightFactor: 0.82,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
        child: NxOrnateFrame(
          corner: 40,
          child: Container(
            decoration: BoxDecoration(
              color: _kInk,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
              border: Border.all(color: _kGold.withValues(alpha: 0.7)),
            ),
            child: Column(children: <Widget>[
              Align(
                alignment: AlignmentDirectional.topEnd,
                child: IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const NxKitImage(NxKit.close, size: 28, fallback: Icons.close_rounded),
                ),
              ),
              Expanded(
                child: CarromShopPanel(
                  isFa: isFa,
                  onChanged: onChanged,
                  header: NxOrnateHeader(title: isFa ? 'کارم' : 'CARROM'),
                ),
              ),
            ]),
          ),
        ),
      ),
    ),
  );
}

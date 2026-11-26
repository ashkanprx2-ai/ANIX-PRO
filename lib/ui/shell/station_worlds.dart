import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../games/game_registry.dart';
import '../screens/game_icons.dart';

/// One destination in a Station world (`it` entries of `W` in NEXORA_Station_Luxe.html).
/// Every item opens a real screen of the app; none is a "coming soon" placeholder.
class StationItem {
  const StationItem({
    required this.fa,
    required this.en,
    required this.tab,
    required this.rarity,
    required this.icon,
    required this.route,
  });

  final String fa;
  final String en;

  /// 1-based tab like the reference (0 = shown only under «همه»).
  final int tab;
  final int rarity;
  final String icon;

  /// go_router location the item opens (`/s/...` = a Station screen, see router).
  final String route;

  void open(BuildContext context) => context.push(route);
}

/// A world of the hub carousel (`W` in the reference): name, latin caption, icon, accent, tagline, tabs and items.
class StationWorld {
  const StationWorld({
    required this.k,
    required this.fa,
    required this.en,
    required this.icon,
    required this.tagFa,
    required this.tagEn,
    required this.tabsFa,
    required this.tabsEn,
    required this.items,
  });
  final String k;
  final String fa;
  final String en;
  final String icon;
  final String tagFa;
  final String tagEn;
  final List<String> tabsFa;
  final List<String> tabsEn;
  final List<StationItem> items;
}

const List<String> _sport = <String>['finger_soccer', 'basketball_battle', 'mini_golf', 'kart_racing', 'obstacle_race', 'bomb_arena'];
const List<String> _table = <String>['billiards', 'pool8', 'backgammon', 'ludo', 'snakes_ladders', 'carrom'];
const List<String> _cards = <String>['uno', 'mafia', 'spy_mafia', 'quiz'];

List<StationItem> _games() {
  final List<StationItem> out = <StationItem>[];
  final Set<String> placed = <String>{};
  void add(List<String> ids, int tab) {
    for (final String id in ids) {
      final GameInfo? g = gameById(id);
      if (g == null) continue;
      placed.add(id);
      out.add(StationItem(fa: g.nameFa, en: g.nameEn, tab: tab, rarity: g.supportsOnline ? 4 : 3, icon: stationGameIcon(id), route: '/arcade/$id'));
    }
  }

  add(_sport, 1);
  add(_table, 2);
  add(_cards, 3);
  // Solo arcade games — and any game registered later — land in «آرکید» (never silently dropped).
  for (final GameInfo g in kGames) {
    if (placed.contains(g.id)) continue;
    out.add(StationItem(fa: g.nameFa, en: g.nameEn, tab: 4, rarity: g.solo ? 2 : 3, icon: stationGameIcon(g.id), route: '/arcade/${g.id}'));
  }
  return out;
}

/// The eight worlds, in the reference order.
List<StationWorld> buildStationWorlds() => <StationWorld>[
      StationWorld(
        k: 'arcade',
        fa: 'بازی‌ها',
        en: 'GAMES',
        icon: 'r4c5',
        tagFa: 'همه‌ی بازی‌ها در یک جا',
        tagEn: 'Every game in one place',
        tabsFa: const <String>['ورزشی', 'میزی', 'کارتی', 'آرکید'],
        tabsEn: const <String>['Sports', 'Table', 'Cards', 'Arcade'],
        items: _games(),
      ),
      const StationWorld(
        k: 'orbit',
        fa: 'رویدادها',
        en: 'EVENTS',
        icon: 'r3c5',
        tagFa: 'ماموریت‌ها و رویدادهای ویژه',
        tagEn: 'Missions and special events',
        tabsFa: <String>['ماموریت', 'رویداد'],
        tabsEn: <String>['Missions', 'Events'],
        items: <StationItem>[
          StationItem(fa: 'ماموریت روزانه', en: 'Daily mission', tab: 1, rarity: 2, icon: 'r5c2', route: '/s/missions/daily'),
          StationItem(fa: 'ماموریت هفتگی', en: 'Weekly mission', tab: 1, rarity: 3, icon: 'r5c1', route: '/s/missions/weekly'),
          StationItem(fa: 'اطلاعیه‌ها', en: 'News', tab: 2, rarity: 2, icon: 'r5c3', route: '/s/news'),
          StationItem(fa: 'تقویم رویدادها', en: 'Calendar', tab: 2, rarity: 3, icon: 'r3c5', route: '/s/calendar'),
          StationItem(fa: 'جامعه‌ها', en: 'Communities', tab: 2, rarity: 3, icon: 'r3c4', route: '/world/social_station'),
        ],
      ),
      const StationWorld(
        k: 'nova',
        fa: 'جایزه‌ها',
        en: 'REWARDS',
        icon: 'r3c6',
        tagFa: 'هدیه، جایزه و مدال',
        tagEn: 'Gifts, prizes and medals',
        tabsFa: <String>['جایزه', 'مبارزه'],
        tabsEn: <String>['Rewards', 'Battle'],
        items: <StationItem>[
          StationItem(fa: 'صندوق هدیه', en: 'Gift box', tab: 1, rarity: 4, icon: 'r3c6', route: '/s/gift'),
          StationItem(fa: 'چرخ شانس', en: 'Lucky wheel', tab: 1, rarity: 3, icon: 'r5c6', route: '/s/wheel'),
          StationItem(fa: 'مدال‌ها', en: 'Medals', tab: 1, rarity: 3, icon: 'r4c3', route: '/s/medals'),
          StationItem(fa: 'مبارزه', en: 'Duel', tab: 2, rarity: 3, icon: 'r4c6', route: '/s/event/duel'),
          StationItem(fa: 'جام', en: 'Cup', tab: 2, rarity: 4, icon: 'r5c4', route: '/s/event/cup'),
        ],
      ),
      const StationWorld(
        k: 'oracle',
        fa: 'هوش مصنوعی',
        en: 'AI',
        icon: 'r5c2',
        tagFa: 'اوراکل و لونا · تحلیل و پیش‌بینی بازی',
        tagEn: 'ORACLE & LUNA · analysis and forecasts',
        tabsFa: <String>['دستیار', 'تحلیل', 'رتبه'],
        tabsEn: <String>['Assistant', 'Analysis', 'Rank'],
        items: <StationItem>[
          StationItem(fa: 'دستیار هوشمند', en: 'AI companion', tab: 1, rarity: 4, icon: 'r5c2', route: '/oracle'),
          StationItem(fa: 'پیش‌بینی بازی', en: 'Forecast', tab: 2, rarity: 3, icon: 'r5c2', route: '/s/forecast'),
          StationItem(fa: 'تحلیل تیم', en: 'Team analysis', tab: 2, rarity: 2, icon: 'r1c6', route: '/s/analysis'),
          StationItem(fa: 'پیشنهاد هوشمند', en: 'Smart tips', tab: 2, rarity: 2, icon: 'r5c6', route: '/s/tips'),
          StationItem(fa: 'برترین‌ها', en: 'Leaderboard', tab: 3, rarity: 4, icon: 'r2c6', route: '/leaderboard'),
        ],
      ),
      const StationWorld(
        k: 'social',
        fa: 'چت',
        en: 'CHAT',
        icon: 'r3c3',
        tagFa: 'دوستان و گفتگو',
        tagEn: 'Friends and talk',
        tabsFa: <String>['دوستان', 'صدا', 'رسانه'],
        tabsEn: <String>['Friends', 'Voice', 'Media'],
        items: <StationItem>[
          StationItem(fa: 'دوستان', en: 'Friends', tab: 1, rarity: 2, icon: 'r3c4', route: '/s/friends'),
          StationItem(fa: 'پیام‌ها', en: 'Messages', tab: 1, rarity: 2, icon: 'r3c3', route: '/social'),
          StationItem(fa: 'ارسال هدیه', en: 'Send gift', tab: 1, rarity: 3, icon: 'r3c6', route: '/s/send-gift'),
          StationItem(fa: 'اتاق صوتی', en: 'Voice room', tab: 2, rarity: 3, icon: 'r3c1', route: '/rooms'),
          StationItem(fa: 'گوش دادن', en: 'Listen', tab: 2, rarity: 2, icon: 'r3c2', route: '/s/listen'),
          StationItem(fa: 'پست و استوری', en: 'Posts & stories', tab: 3, rarity: 3, icon: 'r5c3', route: '/world/nova_gallery'),
          StationItem(fa: 'تماس‌ها و مخاطبین', en: 'Calls & contacts', tab: 3, rarity: 2, icon: 'r3c2', route: '/world/orbit_network'),
        ],
      ),
      const StationWorld(
        k: 'exch',
        fa: 'فروشگاه',
        en: 'SHOP',
        icon: 'r4c1',
        tagFa: 'خرید، هدیه و ظاهر',
        tagEn: 'Shop, gifts and looks',
        tabsFa: <String>['خرید', 'ظاهر'],
        tabsEn: <String>['Buy', 'Looks'],
        items: <StationItem>[
          StationItem(fa: 'فروشگاه', en: 'Shop', tab: 1, rarity: 4, icon: 'r4c1', route: '/s/shop'),
          StationItem(fa: 'صندوق هدیه', en: 'Gift box', tab: 1, rarity: 3, icon: 'r3c6', route: '/s/gift'),
          StationItem(fa: 'چرخ شانس', en: 'Lucky wheel', tab: 1, rarity: 2, icon: 'r5c6', route: '/s/wheel'),
          StationItem(fa: 'جم و بسته‌ها', en: 'Gems & packs', tab: 1, rarity: 3, icon: 'r3c6', route: '/s/gems'),
          StationItem(fa: 'قاب', en: 'Frames', tab: 2, rarity: 3, icon: 'r4c4', route: '/s/frames'),
          StationItem(fa: 'پوسته‌ها', en: 'Themes', tab: 2, rarity: 3, icon: 'r4c2', route: '/s/themes'),
          StationItem(fa: 'مدال', en: 'Medal', tab: 2, rarity: 2, icon: 'r4c3', route: '/s/medals'),
        ],
      ),
      const StationWorld(
        k: 'personal',
        fa: 'پروفایل',
        en: 'PROFILE',
        icon: 'r4c4',
        tagFa: 'حساب، جام‌ها و رده‌بندی',
        tagEn: 'Account, trophies and ranking',
        tabsFa: <String>['حساب', 'دستاورد'],
        tabsEn: <String>['Account', 'Achievements'],
        items: <StationItem>[
          StationItem(fa: 'حساب من', en: 'My account', tab: 1, rarity: 2, icon: 'r4c4', route: '/s/profile'),
          StationItem(fa: 'تنظیمات', en: 'Settings', tab: 1, rarity: 1, icon: 'r4c2', route: '/settings'),
          StationItem(fa: 'کنترلر', en: 'Controller', tab: 1, rarity: 2, icon: 'r4c5', route: '/s/controller'),
          StationItem(fa: 'فضای من', en: 'My space', tab: 1, rarity: 3, icon: 'r5c1', route: '/world/personal_orbit'),
          StationItem(fa: 'جام‌ها', en: 'Trophies', tab: 2, rarity: 4, icon: 'r2c5', route: '/s/trophies'),
          StationItem(fa: 'رده‌بندی', en: 'Ranking', tab: 2, rarity: 3, icon: 'r2c6', route: '/leaderboard'),
          StationItem(fa: 'مدال‌ها', en: 'Medals', tab: 2, rarity: 3, icon: 'r4c3', route: '/s/medals'),
          StationItem(fa: 'نبردها', en: 'Battles', tab: 2, rarity: 2, icon: 'r4c6', route: '/s/history'),
        ],
      ),
      const StationWorld(
        k: 'tourn',
        fa: 'تورنمنت‌ها',
        en: 'TOURNAMENTS',
        icon: 'r2c5',
        tagFa: 'مسابقه‌ها و لیگ‌ها',
        tagEn: 'Cups and leagues',
        tabsFa: <String>['فعال', 'نتایج'],
        tabsEn: <String>['Active', 'Results'],
        items: <StationItem>[
          StationItem(fa: 'تورنمنت روزانه', en: 'Daily cup', tab: 1, rarity: 3, icon: 'r2c5', route: '/s/event/daily'),
          StationItem(fa: 'لیگ هفتگی', en: 'Weekly league', tab: 1, rarity: 4, icon: 'r5c4', route: '/s/event/league'),
          StationItem(fa: 'مسابقه ویژه', en: 'Special match', tab: 1, rarity: 3, icon: 'r4c6', route: '/s/event/special'),
          StationItem(fa: 'همه‌ی تورنمنت‌ها', en: 'All tournaments', tab: 1, rarity: 4, icon: 'r2c5', route: '/tournaments'),
          StationItem(fa: 'جدول رده‌بندی', en: 'Standings', tab: 2, rarity: 4, icon: 'r2c6', route: '/leaderboard'),
          StationItem(fa: 'تاریخچه‌ی من', en: 'History', tab: 2, rarity: 1, icon: 'r2c5', route: '/s/history'),
          StationItem(fa: 'صندوق اعلان‌ها', en: 'Inbox', tab: 2, rarity: 2, icon: 'r5c3', route: '/tournaments/inbox'),
        ],
      ),
    ];

/// `NAV`: [label, icon, target] — target = 'home' | 'more' | world index; the centre button opens Rooms («روم»).
class StationNavEntry {
  const StationNavEntry(this.fa, this.en, this.icon, this.target);
  final String fa;
  final String en;
  final String? icon;
  final String target;
}

const List<StationNavEntry> kStationNav = <StationNavEntry>[
  StationNavEntry('خانه', 'Home', 'r4c4', 'home'),
  StationNavEntry('چت', 'Chat', 'r3c3', 'chat'),
  StationNavEntry('روم', 'Rooms', null, 'rooms'),
  StationNavEntry('تورنمنت', 'Cups', 'r2c5', 'w7'),
  StationNavEntry('بیشتر', 'More', 'r4c1', 'more'),
];

/// `MORE`: the "بیشتر" popup grid.
const List<StationNavEntry> kStationMore = <StationNavEntry>[
  StationNavEntry('فروشگاه', 'Shop', 'r4c1', 'w5'),
  StationNavEntry('جایزه‌ها', 'Rewards', 'r3c6', 'w2'),
  StationNavEntry('تنظیمات', 'Settings', 'r4c2', '/settings'),
  StationNavEntry('پروفایل', 'Profile', 'r2c4', 'w6'),
  StationNavEntry('هوش مصنوعی', 'AI', 'r5c2', 'w3'),
  StationNavEntry('رویدادها', 'Events', 'r3c5', 'w1'),
];

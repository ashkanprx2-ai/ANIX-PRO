import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../games/game_registry.dart';
import '../screens/game_icons.dart';

/// One destination in a Station world (icon = an `assets/station/hub/*.webp` / `assets/games/icons/*.webp` path) (`it` entries of `W` in NEXORA_Station_Luxe.html).
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

  /// `world:<i>` opens another hub, `action:<name>` is handled by the shell; anything else is a go_router location.
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
    this.tabIcons = const <IconData>[],
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

  /// Chip icons: index 0 = «همه», then one per tab.
  final List<IconData> tabIcons;
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

String _h(String name) => 'assets/station/hub/$name.webp';

/// The worlds, in carousel order; the last one («بیشتر») is opened from the nav bar only.
/// Every destination lives in exactly one world (Settings, theme and sign-in live in «بیشتر»).
List<StationWorld> buildStationWorlds() => <StationWorld>[
      StationWorld(
        k: 'arcade',
        fa: 'بازی‌ها',
        en: 'GAMES',
        icon: _h('controller'),
        tagFa: 'همه‌ی بازی‌ها در یک جا',
        tagEn: 'Every game in one place',
        tabsFa: const <String>['ورزشی', 'میزی', 'کارتی', 'آرکید'],
        tabsEn: const <String>['Sports', 'Table', 'Cards', 'Arcade'],
        tabIcons: const <IconData>[
          Icons.sports_esports_rounded, Icons.sports_soccer_rounded, Icons.casino_rounded, Icons.style_rounded, Icons.bolt_rounded,
        ],
        items: _games(),
      ),
      StationWorld(
        k: 'orbit',
        fa: 'رویدادها',
        en: 'EVENTS',
        icon: _h('calendar'),
        tagFa: 'ماموریت‌ها و رویدادهای ویژه',
        tagEn: 'Missions and special events',
        tabsFa: const <String>['ماموریت', 'رویداد'],
        tabsEn: const <String>['Missions', 'Events'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.flag_rounded, Icons.event_rounded],
        items: <StationItem>[
          StationItem(fa: 'ماموریت روزانه', en: 'Daily mission', tab: 1, rarity: 2, icon: _h('daily'), route: '/s/missions/daily'),
          StationItem(fa: 'ماموریت هفتگی', en: 'Weekly mission', tab: 1, rarity: 3, icon: _h('target'), route: '/s/missions/weekly'),
          StationItem(fa: 'اطلاعیه‌ها', en: 'News', tab: 2, rarity: 2, icon: _h('news'), route: '/s/news'),
          StationItem(fa: 'تقویم رویدادها', en: 'Calendar', tab: 2, rarity: 3, icon: _h('calendar'), route: '/s/calendar'),
          StationItem(fa: 'جامعه‌ها', en: 'Communities', tab: 2, rarity: 3, icon: _h('friends'), route: '/world/social_station'),
        ],
      ),
      StationWorld(
        k: 'nova',
        fa: 'جایزه‌ها',
        en: 'REWARDS',
        icon: _h('gift'),
        tagFa: 'هدیه، جایزه و مدال',
        tagEn: 'Gifts, prizes and medals',
        tabsFa: const <String>['جایزه', 'مبارزه'],
        tabsEn: const <String>['Rewards', 'Battle'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.card_giftcard_rounded, Icons.sports_mma_rounded],
        items: <StationItem>[
          StationItem(fa: 'صندوق هدیه', en: 'Gift box', tab: 1, rarity: 4, icon: _h('gift'), route: '/s/gift'),
          StationItem(fa: 'چرخ شانس', en: 'Lucky wheel', tab: 1, rarity: 3, icon: _h('wheel'), route: '/s/wheel'),
          StationItem(fa: 'مدال‌ها', en: 'Medals', tab: 1, rarity: 3, icon: _h('medal'), route: '/s/medals'),
          StationItem(fa: 'مبارزه', en: 'Duel', tab: 2, rarity: 3, icon: _h('duel'), route: '/s/event/duel'),
          StationItem(fa: 'جام', en: 'Cup', tab: 2, rarity: 4, icon: _h('cup'), route: '/s/event/cup'),
        ],
      ),
      StationWorld(
        k: 'oracle',
        fa: 'هوش مصنوعی',
        en: 'AI',
        icon: _h('ai'),
        tagFa: 'اوراکل و لونا · تحلیل و پیش‌بینی بازی',
        tagEn: 'ORACLE & LUNA · analysis and forecasts',
        tabsFa: const <String>['دستیار', 'تحلیل'],
        tabsEn: const <String>['Assistant', 'Analysis'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.smart_toy_rounded, Icons.insights_rounded],
        items: <StationItem>[
          StationItem(fa: 'اوراکل و لونا', en: 'ORACLE & LUNA', tab: 1, rarity: 4, icon: _h('ai'), route: '/oracle'),
          StationItem(fa: 'پیش‌بینی بازی', en: 'Forecast', tab: 2, rarity: 3, icon: _h('forecast'), route: '/s/forecast'),
          StationItem(fa: 'تحلیل تیم', en: 'Team analysis', tab: 2, rarity: 2, icon: _h('rank'), route: '/s/analysis'),
          StationItem(fa: 'پیشنهاد هوشمند', en: 'Smart tips', tab: 2, rarity: 2, icon: _h('tips'), route: '/s/tips'),
        ],
      ),
      StationWorld(
        k: 'social',
        fa: 'چت',
        en: 'CHAT',
        icon: _h('messages'),
        tagFa: 'دوستان و گفتگو',
        tagEn: 'Friends and talk',
        tabsFa: const <String>['دوستان', 'صدا', 'رسانه'],
        tabsEn: const <String>['Friends', 'Voice', 'Media'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.people_alt_rounded, Icons.mic_rounded, Icons.photo_library_rounded],
        items: <StationItem>[
          StationItem(fa: 'پیام‌ها', en: 'Messages', tab: 1, rarity: 2, icon: _h('messages'), route: '/social'),
          StationItem(fa: 'دوستان', en: 'Friends', tab: 1, rarity: 2, icon: _h('friends'), route: '/s/friends'),
          StationItem(fa: 'ارسال هدیه', en: 'Send gift', tab: 1, rarity: 3, icon: _h('sendgift'), route: '/s/send-gift'),
          StationItem(fa: 'اتاق صوتی', en: 'Voice room', tab: 2, rarity: 3, icon: _h('voice'), route: '/rooms'),
          StationItem(fa: 'گوش دادن', en: 'Listen', tab: 2, rarity: 2, icon: _h('listen'), route: '/s/listen'),
          StationItem(fa: 'تماس‌ها', en: 'Calls', tab: 2, rarity: 2, icon: _h('calls'), route: '/world/orbit_network'),
          StationItem(fa: 'پست و استوری', en: 'Posts & stories', tab: 3, rarity: 3, icon: _h('posts'), route: '/world/nova_gallery'),
        ],
      ),
      StationWorld(
        k: 'exch',
        fa: 'فروشگاه',
        en: 'SHOP',
        icon: _h('shop'),
        tagFa: 'خرید و ظاهر',
        tagEn: 'Shop and looks',
        tabsFa: const <String>['خرید', 'ظاهر'],
        tabsEn: const <String>['Buy', 'Looks'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.shopping_bag_rounded, Icons.palette_rounded],
        items: <StationItem>[
          StationItem(fa: 'فروشگاه', en: 'Shop', tab: 1, rarity: 4, icon: _h('shop'), route: '/s/shop'),
          StationItem(fa: 'جم و بسته‌ها', en: 'Gems & packs', tab: 1, rarity: 3, icon: _h('gems'), route: '/s/gems'),
          StationItem(fa: 'قاب', en: 'Frames', tab: 2, rarity: 3, icon: _h('frame'), route: '/s/frames'),
          StationItem(fa: 'پوسته‌ها', en: 'Themes', tab: 2, rarity: 3, icon: _h('theme'), route: '/s/themes'),
        ],
      ),
      StationWorld(
        k: 'personal',
        fa: 'پروفایل',
        en: 'PROFILE',
        icon: _h('account'),
        tagFa: 'حساب، جام‌ها و رکوردها',
        tagEn: 'Account, trophies and records',
        tabsFa: const <String>['حساب', 'دستاورد'],
        tabsEn: const <String>['Account', 'Achievements'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.person_rounded, Icons.emoji_events_rounded],
        items: <StationItem>[
          StationItem(fa: 'حساب من', en: 'My account', tab: 1, rarity: 2, icon: _h('account'), route: '/s/profile'),
          StationItem(fa: 'فضای من', en: 'My space', tab: 1, rarity: 3, icon: _h('space'), route: '/world/personal_orbit'),
          StationItem(fa: 'کی منو دیده؟', en: 'Who viewed me', tab: 1, rarity: 2, icon: _h('posts'), route: '/s/viewers'),
          StationItem(fa: 'کنترلر', en: 'Controller', tab: 1, rarity: 2, icon: _h('controller'), route: '/s/controller'),
          StationItem(fa: 'جام‌ها', en: 'Trophies', tab: 2, rarity: 4, icon: _h('cup'), route: '/s/trophies'),
          StationItem(fa: 'رکوردها', en: 'Records', tab: 2, rarity: 3, icon: _h('rank'), route: '/s/games?records=1'),
          StationItem(fa: 'نبردها', en: 'Battles', tab: 2, rarity: 2, icon: _h('history'), route: '/s/history'),
        ],
      ),
      StationWorld(
        k: 'tourn',
        fa: 'تورنمنت‌ها',
        en: 'TOURNAMENTS',
        icon: _h('cup'),
        tagFa: 'مسابقه‌ها و لیگ‌ها',
        tagEn: 'Cups and leagues',
        tabsFa: const <String>['فعال', 'نتایج'],
        tabsEn: const <String>['Active', 'Results'],
        tabIcons: const <IconData>[Icons.apps_rounded, Icons.local_fire_department_rounded, Icons.leaderboard_rounded],
        items: <StationItem>[
          StationItem(fa: 'تورنمنت روزانه', en: 'Daily cup', tab: 1, rarity: 3, icon: _h('daily'), route: '/s/event/daily'),
          StationItem(fa: 'لیگ هفتگی', en: 'Weekly league', tab: 1, rarity: 4, icon: _h('cup'), route: '/s/event/league'),
          StationItem(fa: 'مسابقه ویژه', en: 'Special match', tab: 1, rarity: 3, icon: _h('duel'), route: '/s/event/special'),
          StationItem(fa: 'همه‌ی تورنمنت‌ها', en: 'All tournaments', tab: 1, rarity: 4, icon: _h('medal'), route: '/tournaments'),
          StationItem(fa: 'جدول رده‌بندی', en: 'Standings', tab: 2, rarity: 4, icon: _h('rank'), route: '/leaderboard'),
          StationItem(fa: 'صندوق اعلان‌ها', en: 'Inbox', tab: 2, rarity: 2, icon: _h('inbox'), route: '/tournaments/inbox'),
        ],
      ),
      StationWorld(
        k: 'more',
        fa: 'بیشتر',
        en: 'MORE',
        icon: _h('settings'),
        tagFa: 'همه‌ی بخش‌ها و تنظیمات',
        tagEn: 'Every section and settings',
        tabsFa: const <String>[],
        tabsEn: const <String>[],
        items: <StationItem>[
          StationItem(fa: 'رویدادها', en: 'Events', tab: 0, rarity: 3, icon: _h('calendar'), route: 'world:1'),
          StationItem(fa: 'جایزه‌ها', en: 'Rewards', tab: 0, rarity: 3, icon: _h('gift'), route: 'world:2'),
          StationItem(fa: 'هوش مصنوعی', en: 'AI', tab: 0, rarity: 3, icon: _h('ai'), route: 'world:3'),
          StationItem(fa: 'فروشگاه', en: 'Shop', tab: 0, rarity: 3, icon: _h('shop'), route: 'world:5'),
          StationItem(fa: 'پروفایل', en: 'Profile', tab: 0, rarity: 3, icon: _h('account'), route: 'world:6'),
          StationItem(fa: 'تنظیمات', en: 'Settings', tab: 0, rarity: 1, icon: _h('settings'), route: '/settings'),
          StationItem(fa: 'تغییر تم', en: 'Switch theme', tab: 0, rarity: 1, icon: _h('theme'), route: 'action:theme'),
        ],
      ),
    ];

/// Index of the «بیشتر» world (not on the home carousel).
const int kStationMoreWorld = 8;

/// Worlds shown on the home carousel.
const int kStationCarouselWorlds = 8;

/// Bottom nav: label, icon, target — target = `home` | `rooms` | `w<world index>`; the centre button opens Rooms («روم»).
class StationNavEntry {
  const StationNavEntry(this.fa, this.en, this.icon, this.target);
  final String fa;
  final String en;
  final IconData? icon;
  final String target;
}

const List<StationNavEntry> kStationNav = <StationNavEntry>[
  StationNavEntry('خانه', 'Home', Icons.home_rounded, 'home'),
  StationNavEntry('چت', 'Chat', Icons.forum_rounded, 'w4'),
  StationNavEntry('روم', 'Rooms', null, 'rooms'),
  StationNavEntry('تورنمنت', 'Cups', Icons.emoji_events_rounded, 'w7'),
  StationNavEntry('بیشتر', 'More', Icons.grid_view_rounded, 'w$kStationMoreWorld'),
];

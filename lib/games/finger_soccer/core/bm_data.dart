// GENERATED from BERMUDA_NXG www/js/game.js — do not retune. Values are copied 1:1.
// ignore_for_file: lines_longer_than_80_chars
import 'dart:ui' show Color;

class BmField {
  const BmField(this.id, this.name, this.w0, this.h0, this.l0, this.r0, this.t0, this.b0, this.cs0, this.g0, this.gs,
      {this.rc = 70,
      this.gh0 = 0,
      this.gr0 = 0,
      this.gd0 = 0,
      this.asset,
      this.score,
      this.faName = '',
      this.scoreLeft = kBmScoreLeft,
      this.scoreRight = const Color(0xFFFF3B30)});
  final String id, name, gs;
  /// Persian name (shown when the UI is in Persian; empty = use [name]).
  final String faName;
  /// Raw image-space values (before FS scale). l0/r0/t0/b0 = the drawn boundary the ball bounces on (measured on the
  /// art: the touch line, or the barrier's inner edge where the art has no line in front of it).
  final int w0, h0, l0, r0, t0, b0, cs0, g0;
  /// Corner radius of the drawn boundary, in world units (measured per field on the art).
  final double rc;
  /// Fields whose art has the goals built in (gs == 'none'): post-centre half width, post radius and net depth,
  /// image px measured on the art. Unused for fields that draw a separate goal sprite.
  final double gh0, gr0, gd0;
  /// Field image (defaults to `assets/games/bermuda/fields/<id>.webp`).
  final String? asset;
  /// v9: the score displays drawn into the art (null = none). The whole art is then fitted to the screen and the live
  /// score is drawn on these displays instead of a HUD scoreboard.
  final BmScoreDisplay? score;
  /// Colours of the live digits on the left-hand (bottom / home side) and right-hand displays, measured on the art's
  /// printed digits.
  final Color scoreLeft, scoreRight;
  bool get fullArt => score != null;
  bool get builtInGoals => gs == 'none';
}

/// Geometry of the two side score displays drawn into a pitch art (image px of the art, [artW] wide). Each display
/// stacks two seven-segment digit cells: tens on top, ones below. The left display shows the bottom / home side, the
/// right one the other side. v11: measured per art (the five owner arts place and size their displays differently).
class BmScoreDisplay {
  const BmScoreDisplay(this.artW, this.leftCx, this.rightCx, this.tensCy, this.onesCy, this.digitW, this.digitH);
  final double artW, leftCx, rightCx, tensCy, onesCy, digitW, digitH;
}

/// Default colour of the left (bottom / home side) display's digits.
const Color kBmScoreLeft = Color(0xFF2F86FF);

const List<BmField> kBmFieldsRaw = <BmField>[
  // v12 (owner upload 2026-11-24): the owner's eleven pitch arts replace the seven v11 arts. Raw values are measured on
  // each art's own touch lines (in the art's measuring frame: 1086 x 1448, 1216 x 1622 or 837 x 1536, the same aspect
  // as the file); the goals are the separate owner goal sprite ('white', kBmGS). Built by tool/build_fs_v12_assets.py.
  BmField('tropical', 'Tropical', 1086, 1448, 214, 874, 116, 1304, 698, 115, 'white', faName: 'استوایی'),
  BmField('psg', 'Paris SG', 1216, 1622, 228, 987, 129, 1452, 746, 135, 'white', faName: 'پاری سن ژرمن'),
  BmField('campnou', 'Camp Nou Night', 1086, 1448, 194, 892, 104, 1332, 715, 121, 'white', faName: 'شب نیوکمپ'),
  BmField('pitch', 'NEXORA Pitch', 837, 1536, 30, 805, 101, 1432, 768, 128, 'white', faName: 'زمین نکسورا'),
  BmField('checker', 'Checker', 1216, 1622, 216, 997, 114, 1515, 788, 135, 'white', faName: 'شطرنجی'),
  BmField('futsal', 'Futsal', 1216, 1622, 213, 1002, 116, 1476, 781, 137, 'white', faName: 'فوتسال'),
  BmField('arena', 'Arena', 1216, 1622, 223, 990, 132, 1471, 777, 133, 'white', faName: 'آرنا'),
  BmField('blackice', 'Black Ice', 1086, 1448, 206, 880, 114, 1304, 697, 117, 'white', faName: 'یخ سیاه'),
  BmField('autumn', 'Autumn', 1086, 1448, 210, 878, 116, 1304, 695, 116, 'white', faName: 'پاییز'),
  BmField('frost', 'Frost Arena', 1086, 1448, 198, 888, 100, 1336, 700, 120, 'white', faName: 'آرنای یخبندان'),
  BmField('glacier', 'Glacier', 1086, 1448, 208, 888, 116, 1304, 698, 118, 'white', faName: 'یخچال'),
];

/// Ids of pitches removed from the game (v7, v9, v11 and v12). Kept only so tests can check they never come back.
/// v12: 'checker', 'futsal', 'arena' and 'psg' are back (the owner picked them again).
const List<String> kBmRemovedFieldIds = <String>[
  'neon_cup', 'street_cage', 'sockerbox', 'gold_leather', 'neon_grass', 'royal_gold',
  // v9: every older pitch
  'nexora_green', 'forest', 'ice', 'ocean', 'street', 'streetarena', 'lava', 'stadium',
  'arena2', 'desert', 'grove', 'pool', 'neon', 'royal', 'mahogany', 'leather', 'aqua', 'asphalt', 'court', 'cyberbox',
  'realmadrid', 'acmilan', 'barcelona', 'persepolis', 'esteghlal', 'mancity',
  // v11: the three v9 Sockerbox arts
  'nx_neon_arena', 'nx_gold_checker', 'nx_gold_stripes',
  // v12: the seven v11 arts
  'nx_green_plain', 'nx_rings_green_new', 'nx_checker_green', 'nx_stripes_green', 'nx_stripes_teal', 'nx_ember_street',
  'nx_black_sockerbox',
];

/// A saved / synced pitch index -> a valid one: anything missing or out of range (e.g. a removed v6 pitch) is the
/// default pitch 0 (v12: Tropical).
int bmFieldIndex(int? i) => (i == null || i < 0 || i >= kBmFieldsRaw.length) ? 0 : i;

/// Local preference key of the chosen pitch. v11: new key, so an index saved for the old v9 pitches (`bm.field`) is
/// never read as one of the new pitches: every player starts on pitch 0 until they pick again.
const String kBmFieldPref = 'bm.field.v11';

/// Pitch [i]'s name in the UI language (Persian when [fa] and the pitch has one).
String bmFieldName(int i, bool fa) {
  final BmField f = kBmFieldsRaw[bmFieldIndex(i)];
  return fa && f.faName.isNotEmpty ? f.faName : f.name;
}

/// Goal art measured on each sprite (alpha): [width, height, left post centre, right post centre, post half-width,
/// inner edge of the back bar, bottom of the posts] - x values are fractions of the width, y values of the height.
/// The engine builds the posts, the side nets and the back net from these numbers, so the drawn goal is the collider.
const Map<String, List<double>> kBmGS = <String, List<double>>{
  // The only goal art. v12: the owner's new white.webp (1024 x 374, white tubular frame, hexagonal net), measured on
  // its alpha: post centres at the leg feet, leg half-width, inner edge of the back bar, foot of the legs.
  'white': <double>[1024, 374, 0.0488, 0.9517, 0.0151, 0.0936, 0.9973],
};

/// Team categories (owner's NX puck sheets, 2026-11-26): clubs 22, nations 21, brands 13, cars 9, fantasy 12, plus the
/// player-made custom teams.
const List<List<Object>> kBmCats = <List<Object>>[
  <Object>['clubs', 'Clubs', 'باشگاه‌ها'],
  <Object>['nations', 'Nations', 'ملی'],
  <Object>['brands', 'Brands', 'برندها'],
  <Object>['cars', 'Cars', 'ماشین‌ها'],
  <Object>['fantasy', 'Fantasy', 'فانتزی'],
  <Object>['custom', 'Custom', 'اختصاصی'],
];

class BmTeamDef {
  const BmTeamDef(this.id, this.cat, this.name, this.faName, this.art, this.power, this.accuracy);
  final String id, cat, name;
  /// Persian name (shown when the UI is in Persian; the English name above is the canonical one).
  final String faName;
  /// Asset path of the puck art (the owner's iso cut-out, `assets/games/finger_soccer/pucks/iso/<id>.webp`).
  final String art;
  final int power, accuracy;
}

/// The free starter pucks (wolf, shark, eagle): always unlocked, so a new player can always field a team.
const Set<String> kBmFreeTeamIds = <String>{'fx_wolf', 'fx_shark', 'fx_eagle'};

/// Default team for a new player, an unknown id, or a team the player does not own.
const String kBmDefaultTeamId = 'fx_wolf';

/// Every fieldable piece set: the owner's NX pucks (docs/fs_teams_map.py, generated by tool/gen_fs_pucks.py).
/// [BmTeamDef.art] is the iso cut-out; the art is shown exactly as cut, never framed or recoloured.
const List<BmTeamDef> kBmTeamDefs = <BmTeamDef>[
  BmTeamDef('realmadrid', 'clubs', 'Real Madrid', 'رئال مادرید', 'assets/games/finger_soccer/pucks/iso/realmadrid.webp', 10, 10),
  BmTeamDef('barcelona', 'clubs', 'Barcelona', 'بارسلونا', 'assets/games/finger_soccer/pucks/iso/barcelona.webp', 10, 9),
  BmTeamDef('bayern', 'clubs', 'Bayern München', 'بایرن مونیخ', 'assets/games/finger_soccer/pucks/iso/bayern.webp', 9, 10),
  BmTeamDef('psg', 'clubs', 'Paris Saint-Germain', 'پاری سن ژرمن', 'assets/games/finger_soccer/pucks/iso/psg.webp', 10, 9),
  BmTeamDef('mancity', 'clubs', 'Manchester City', 'منچستر سیتی', 'assets/games/finger_soccer/pucks/iso/mancity.webp', 9, 10),
  BmTeamDef('liverpool', 'clubs', 'Liverpool', 'لیورپول', 'assets/games/finger_soccer/pucks/iso/liverpool.webp', 10, 8),
  BmTeamDef('acmilan', 'clubs', 'AC Milan', 'آ.ث. میلان', 'assets/games/finger_soccer/pucks/iso/acmilan.webp', 9, 8),
  BmTeamDef('juventus', 'clubs', 'Juventus', 'یوونتوس', 'assets/games/finger_soccer/pucks/iso/juventus.webp', 9, 8),
  BmTeamDef('inter', 'clubs', 'Inter', 'اینتر', 'assets/games/finger_soccer/pucks/iso/inter.webp', 9, 8),
  BmTeamDef('chelsea', 'clubs', 'Chelsea', 'چلسی', 'assets/games/finger_soccer/pucks/iso/chelsea.webp', 8, 9),
  BmTeamDef('arsenal', 'clubs', 'Arsenal', 'آرسنال', 'assets/games/finger_soccer/pucks/iso/arsenal.webp', 8, 9),
  BmTeamDef('atletico', 'clubs', 'Atlético Madrid', 'اتلتیکو مادرید', 'assets/games/finger_soccer/pucks/iso/atletico.webp', 9, 9),
  BmTeamDef('dortmund', 'clubs', 'Borussia Dortmund', 'بوروسیا دورتموند', 'assets/games/finger_soccer/pucks/iso/dortmund.webp', 9, 8),
  BmTeamDef('persepolis', 'clubs', 'Persepolis', 'پرسپولیس', 'assets/games/finger_soccer/pucks/iso/persepolis.webp', 9, 8),
  BmTeamDef('esteghlal', 'clubs', 'Esteghlal', 'استقلال', 'assets/games/finger_soccer/pucks/iso/esteghlal.webp', 9, 8),
  BmTeamDef('intermiami', 'clubs', 'Inter Miami', 'اینتر میامی', 'assets/games/finger_soccer/pucks/iso/intermiami.webp', 9, 9),
  BmTeamDef('alhilal', 'clubs', 'Al Hilal', 'الهلال', 'assets/games/finger_soccer/pucks/iso/alhilal.webp', 9, 8),
  BmTeamDef('astonvilla', 'clubs', 'Aston Villa', 'استون ویلا', 'assets/games/finger_soccer/pucks/iso/astonvilla.webp', 8, 8),
  BmTeamDef('wolves', 'clubs', 'Wolverhampton', 'ولورهمپتون', 'assets/games/finger_soccer/pucks/iso/wolves.webp', 7, 8),
  BmTeamDef('schalke', 'clubs', 'Schalke 04', 'شالکه ۰۴', 'assets/games/finger_soccer/pucks/iso/schalke.webp', 7, 8),
  BmTeamDef('sevilla', 'clubs', 'Sevilla', 'سویا', 'assets/games/finger_soccer/pucks/iso/sevilla.webp', 8, 8),
  BmTeamDef('lazio', 'clubs', 'Lazio', 'لاتزیو', 'assets/games/finger_soccer/pucks/iso/lazio.webp', 8, 8),
  BmTeamDef('argentina', 'nations', 'Argentina', 'آرژانتین', 'assets/games/finger_soccer/pucks/iso/argentina.webp', 10, 10),
  BmTeamDef('brazil', 'nations', 'Brazil', 'برزیل', 'assets/games/finger_soccer/pucks/iso/brazil.webp', 10, 9),
  BmTeamDef('france', 'nations', 'France', 'فرانسه', 'assets/games/finger_soccer/pucks/iso/france.webp', 9, 9),
  BmTeamDef('germany', 'nations', 'Germany', 'آلمان', 'assets/games/finger_soccer/pucks/iso/germany.webp', 9, 9),
  BmTeamDef('spain', 'nations', 'Spain', 'اسپانیا', 'assets/games/finger_soccer/pucks/iso/spain.webp', 9, 9),
  BmTeamDef('portugal', 'nations', 'Portugal', 'پرتغال', 'assets/games/finger_soccer/pucks/iso/portugal.webp', 9, 8),
  BmTeamDef('england', 'nations', 'England', 'انگلیس', 'assets/games/finger_soccer/pucks/iso/england.webp', 9, 8),
  BmTeamDef('netherlands', 'nations', 'Netherlands', 'هلند', 'assets/games/finger_soccer/pucks/iso/netherlands.webp', 9, 8),
  BmTeamDef('italy', 'nations', 'Italy', 'ایتالیا', 'assets/games/finger_soccer/pucks/iso/italy.webp', 8, 9),
  BmTeamDef('iran', 'nations', 'Iran', 'ایران', 'assets/games/finger_soccer/pucks/iso/iran.webp', 9, 9),
  BmTeamDef('uruguay', 'nations', 'Uruguay', 'اروگوئه', 'assets/games/finger_soccer/pucks/iso/uruguay.webp', 8, 8),
  BmTeamDef('japan', 'nations', 'Japan', 'ژاپن', 'assets/games/finger_soccer/pucks/iso/japan.webp', 7, 8),
  BmTeamDef('usa', 'nations', 'USA', 'آمریکا', 'assets/games/finger_soccer/pucks/iso/usa.webp', 8, 8),
  BmTeamDef('canada', 'nations', 'Canada', 'کانادا', 'assets/games/finger_soccer/pucks/iso/canada.webp', 7, 8),
  BmTeamDef('norway', 'nations', 'Norway', 'نروژ', 'assets/games/finger_soccer/pucks/iso/norway.webp', 8, 7),
  BmTeamDef('finland', 'nations', 'Finland', 'فنلاند', 'assets/games/finger_soccer/pucks/iso/finland.webp', 7, 7),
  BmTeamDef('greece', 'nations', 'Greece', 'یونان', 'assets/games/finger_soccer/pucks/iso/greece.webp', 7, 8),
  BmTeamDef('wales', 'nations', 'Wales', 'ولز', 'assets/games/finger_soccer/pucks/iso/wales.webp', 7, 7),
  BmTeamDef('algeria', 'nations', 'Algeria', 'الجزایر', 'assets/games/finger_soccer/pucks/iso/algeria.webp', 7, 7),
  BmTeamDef('cuba', 'nations', 'Cuba', 'کوبا', 'assets/games/finger_soccer/pucks/iso/cuba.webp', 6, 7),
  BmTeamDef('qatar', 'nations', 'Qatar', 'قطر', 'assets/games/finger_soccer/pucks/iso/qatar.webp', 7, 7),
  BmTeamDef('adidas', 'brands', 'Adidas', 'آدیداس', 'assets/games/finger_soccer/pucks/iso/adidas.webp', 9, 9),
  BmTeamDef('nike', 'brands', 'Nike', 'نایکی', 'assets/games/finger_soccer/pucks/iso/nike.webp', 9, 9),
  BmTeamDef('jordan', 'brands', 'Jordan', 'جردن', 'assets/games/finger_soccer/pucks/iso/jordan.webp', 9, 9),
  BmTeamDef('newbalance', 'brands', 'New Balance', 'نیوبالانس', 'assets/games/finger_soccer/pucks/iso/newbalance.webp', 8, 9),
  BmTeamDef('reebok', 'brands', 'Reebok', 'ریباک', 'assets/games/finger_soccer/pucks/iso/reebok.webp', 8, 8),
  BmTeamDef('puma', 'brands', 'Puma', 'پوما', 'assets/games/finger_soccer/pucks/iso/puma.webp', 8, 9),
  BmTeamDef('starbucks', 'brands', 'Starbucks', 'استارباکس', 'assets/games/finger_soccer/pucks/iso/starbucks.webp', 8, 8),
  BmTeamDef('apple', 'brands', 'Apple', 'اپل', 'assets/games/finger_soccer/pucks/iso/apple.webp', 10, 9),
  BmTeamDef('louisvuitton', 'brands', 'Louis Vuitton', 'لویی ویتون', 'assets/games/finger_soccer/pucks/iso/louisvuitton.webp', 10, 10),
  BmTeamDef('dior', 'brands', 'Dior', 'دیور', 'assets/games/finger_soccer/pucks/iso/dior.webp', 9, 10),
  BmTeamDef('rolex', 'brands', 'Rolex', 'رولکس', 'assets/games/finger_soccer/pucks/iso/rolex.webp', 10, 10),
  BmTeamDef('chanel', 'brands', 'Chanel', 'شنل', 'assets/games/finger_soccer/pucks/iso/chanel.webp', 9, 10),
  BmTeamDef('gucci', 'brands', 'Gucci', 'گوچی', 'assets/games/finger_soccer/pucks/iso/gucci.webp', 10, 9),
  BmTeamDef('bmw', 'cars', 'BMW', 'ب‌ام‌و', 'assets/games/finger_soccer/pucks/iso/bmw.webp', 9, 9),
  BmTeamDef('mercedes', 'cars', 'Mercedes-Benz', 'مرسدس بنز', 'assets/games/finger_soccer/pucks/iso/mercedes.webp', 10, 9),
  BmTeamDef('porsche', 'cars', 'Porsche', 'پورشه', 'assets/games/finger_soccer/pucks/iso/porsche.webp', 10, 9),
  BmTeamDef('lamborghini', 'cars', 'Lamborghini', 'لامبورگینی', 'assets/games/finger_soccer/pucks/iso/lamborghini.webp', 10, 10),
  BmTeamDef('tesla', 'cars', 'Tesla', 'تسلا', 'assets/games/finger_soccer/pucks/iso/tesla.webp', 9, 10),
  BmTeamDef('volkswagen', 'cars', 'Volkswagen', 'فولکس‌واگن', 'assets/games/finger_soccer/pucks/iso/volkswagen.webp', 8, 8),
  BmTeamDef('volvo', 'cars', 'Volvo', 'ولوو', 'assets/games/finger_soccer/pucks/iso/volvo.webp', 8, 9),
  BmTeamDef('hyundai', 'cars', 'Hyundai', 'هیوندای', 'assets/games/finger_soccer/pucks/iso/hyundai.webp', 8, 8),
  BmTeamDef('scania', 'cars', 'Scania', 'اسکانیا', 'assets/games/finger_soccer/pucks/iso/scania.webp', 9, 7),
  BmTeamDef('fx_wolf', 'fantasy', 'Wolf', 'گرگ', 'assets/games/finger_soccer/pucks/iso/fx_wolf.webp', 7, 7),
  BmTeamDef('fx_shark', 'fantasy', 'Shark', 'کوسه', 'assets/games/finger_soccer/pucks/iso/fx_shark.webp', 7, 7),
  BmTeamDef('fx_eagle', 'fantasy', 'Eagle', 'عقاب', 'assets/games/finger_soccer/pucks/iso/fx_eagle.webp', 7, 7),
  BmTeamDef('fx_dragon', 'fantasy', 'Dragon', 'اژدها', 'assets/games/finger_soccer/pucks/iso/fx_dragon.webp', 10, 9),
  BmTeamDef('fx_samurai', 'fantasy', 'Samurai', 'سامورایی', 'assets/games/finger_soccer/pucks/iso/fx_samurai.webp', 9, 10),
  BmTeamDef('fx_crown', 'fantasy', 'Crown', 'تاج', 'assets/games/finger_soccer/pucks/iso/fx_crown.webp', 10, 10),
  BmTeamDef('fx_phoenix', 'fantasy', 'Phoenix', 'ققنوس', 'assets/games/finger_soccer/pucks/iso/fx_phoenix.webp', 10, 9),
  BmTeamDef('fx_shuriken', 'fantasy', 'Shuriken', 'شوریکن', 'assets/games/finger_soccer/pucks/iso/fx_shuriken.webp', 9, 9),
  BmTeamDef('fx_panther', 'fantasy', 'Panther', 'پلنگ سیاه', 'assets/games/finger_soccer/pucks/iso/fx_panther.webp', 9, 9),
  BmTeamDef('fx_lion', 'fantasy', 'Lion', 'شیر', 'assets/games/finger_soccer/pucks/iso/fx_lion.webp', 10, 9),
  BmTeamDef('fx_scorpion', 'fantasy', 'Scorpion', 'عقرب', 'assets/games/finger_soccer/pucks/iso/fx_scorpion.webp', 9, 8),
  BmTeamDef('fx_spartan', 'fantasy', 'Spartan', 'اسپارتان', 'assets/games/finger_soccer/pucks/iso/fx_spartan.webp', 9, 10),
  // Not a team: the lobby's "create your custom team" tile (1000 gems, then a photo). The shared custom teams
  // themselves (cx_<hex>, power 10) are appended to kBmTeams at runtime by FsCustomTeams.
  BmTeamDef('custom_team', 'custom', 'Create Custom Team', 'ساخت تیم اختصاصی', 'assets/games/finger_soccer/pucks/iso/fx_crown.webp', 10, 10),
];

class BmTrail {
  const BmTrail(this.k, this.c);
  final String k;
  final List<int> c;
}

const List<BmTrail> kBmTR = <BmTrail>[
  BmTrail('bolt', <int>[0xFF19B4FF,0xFF8FE6FF,0xFFFFFFFF]),
  BmTrail('prism', <int>[0xFFFF7BD5,0xFF7BD7FF,0xFFFFFFFF]),
  BmTrail('wave', <int>[0xFF2FE0D0,0xFF9FF7EF,0xFFFFFFFF]),
  BmTrail('star', <int>[0xFF5CB6FF,0xFFBFE3FF,0xFFFFFFFF]),
  BmTrail('smoke', <int>[0xFFE8ECF2,0xFF9AA3B0,0xFFFFFFFF]),
  BmTrail('rainbow', <int>[0xFFFF5B5B,0xFFFFD23A,0xFF5BFF8A,0xFF5BD0FF,0xFFC05BFF]),
  BmTrail('neon', <int>[0xFF4DFF2A,0xFFB6FF9A,0xFFFFFFFF]),
  BmTrail('yin', <int>[0xFFFFFFFF,0xFF9B5CFF,0xFF000000]),
  BmTrail('fire', <int>[0xFFFF8A1F,0xFFFFD24A,0xFFFFF3C4]),
  BmTrail('blade', <int>[0xFFFF2B3A,0xFFFF8A92,0xFFFFFFFF]),
  BmTrail('ghost', <int>[0xFFDBE7FF,0xFF8FB0FF,0xFFFFFFFF]),
  BmTrail('ember', <int>[0xFFFF6A1F,0xFFFFB347,0xFFFFF0C8]),
  BmTrail('plasma', <int>[0xFF2F8BFF,0xFF7FC6FF,0xFFFFFFFF]),
  BmTrail('ghost', <int>[0xFFD9915B,0xFFF2C9A0,0xFFFFF4E6]),
  BmTrail('star', <int>[0xFF2F7BFF,0xFF8FD0FF,0xFFFFFFFF]),
  BmTrail('wave', <int>[0xFF9B5CFF,0xFFE0B8FF,0xFFFFFFFF]),
  BmTrail('fire', <int>[0xFFE0A82E,0xFFFFE08A,0xFFFFF7D6]),
  BmTrail('bolt', <int>[0xFF2F6BFF,0xFF7FB4FF,0xFFFFFFFF]),
  BmTrail('neon', <int>[0xFF2F8BFF,0xFFE8B84A,0xFFFFFFFF]),
  BmTrail('prism', <int>[0xFF1FD6A0,0xFF3B9BFF,0xFFFFFFFF]),
  BmTrail('blade', <int>[0xFFFF2B3A,0xFFFF8A92,0xFFFFFFFF]),
  BmTrail('plasma', <int>[0xFF18D8C0,0xFF9FF5E6,0xFFFFFFFF]),
  BmTrail('ember', <int>[0xFF2F5BFF,0xFFFFC83A,0xFFFFF3C4]),
  BmTrail('yin', <int>[0xFFFFFFFF,0xFFE0A82E,0xFF000000]),
  BmTrail('smoke', <int>[0xFFFF4A4A,0xFF9AA3B0,0xFFFFFFFF]),
  BmTrail('star', <int>[0xFFE0A82E,0xFFFFF0B0,0xFFFFFFFF]),
  BmTrail('plasma', <int>[0xFF2F8BFF,0xFFC0C8D8,0xFFFFFFFF]),
  BmTrail('ghost', <int>[0xFF9B5CFF,0xFFFFFFFF,0xFFFFFFFF]),
  BmTrail('neon', <int>[0xFF4DFF2A,0xFFC0C8D8,0xFFFFFFFF]),
  BmTrail('blade', <int>[0xFFE8B84A,0xFF2F6BFF,0xFFFFFFFF]),
  BmTrail('fire', <int>[0xFFFF2B3A,0xFFFF8A92,0xFFFFFFFF]),
  BmTrail('ember', <int>[0xFFFF8A1F,0xFFFFD24A,0xFFFFFFFF]),
  BmTrail('wave', <int>[0xFF3B9BFF,0xFF2FE08A,0xFFFFFFFF]),
  BmTrail('prism', <int>[0xFFFF4A7A,0xFF9B5CFF,0xFFFFFFFF]),
  BmTrail('bolt', <int>[0xFF2F6BFF,0xFFFFFFFF,0xFFFFFFFF]),
  BmTrail('star', <int>[0xFFFFD56B,0xFFFFFFFF,0xFFFFFFFF]),
];

const List<String> kBmTRN = <String>["Bolt", "Prism", "Wave", "Starlight", "Smoke", "Rainbow", "Neon", "Yin", "Fire", "Blade", "Ghost", "Ember", "Plasma", "Copper Ghost", "Stardust", "Twilight", "Gold Flame", "Thunder", "Cobalt Neon", "Aurora", "Crimson Blade", "Teal Storm", "Royal Ember", "Gold Yin", "Red Smoke", "Gilded Star", "Noir Chrome", "Violet Strike", "Emerald Edge", "Royal Blue Gold", "Crimson Noir", "Blaze Orange", "Aqua Wave", "Sunset Pro", "Elite Cobalt", "Crown Luxury"];

/// v12 (owner upload 2026-11-24): the match balls are the owner's 18 new balls (six single arts and two sheets), each
/// cut on its own detected circle, fully transparent outside it, by tool/build_fs_v12_assets.py into
/// `assets/games/bermuda/balls/v9/<slug>.webp` (256 x 256, the ball fills its square; the folder name is kept). The
/// 3D ball renderer (BmBallRenderer) rolls each flat art with the ball's real motion.
const List<String> kBmBallN = <String>[
  'NX Lime',
  'NX Blue',
  'NX Violet',
  'NX Orange',
  'Classic',
  'NX Blue Wave',
  'NX Blue Stripe',
  'NX Cobalt',
  'NX Red Hex',
  'NX Carbon',
  'NX White Strike',
  'NX Black Strike',
  'NX Red Strike',
  'NX Blue Strike',
  'NX Red Flash',
  'NX Blue Flash',
  'Pro Sky',
  'Pro Red',
  'Pro Lime',
  'Pro Violet',
  'Pro Orange',
  'Pro Teal',
];
const List<String> kBmBallFa = <String>[
  'NX لیمویی',
  'NX آبی',
  'NX بنفش',
  'NX نارنجی',
  'کلاسیک',
  'موج آبی',
  'نوار آبی',
  'کبالت',
  'شش‌ضلعی سرخ',
  'کربن',
  'صاعقه سفید',
  'صاعقه سیاه',
  'صاعقه سرخ',
  'صاعقه آبی',
  'آذرخش سرخ',
  'آذرخش آبی',
  'پرو آسمانی',
  'پرو سرخ',
  'پرو لیمویی',
  'پرو بنفش',
  'پرو نارنجی',
  'پرو فیروزه‌ای',
];
/// All 22 Finger Soccer balls in `assets/games/bermuda/balls/v9/` (4 NX v13 + 18 Pro/Strike v12).
const List<String> kBmBallSlug = <String>[
  'nx_lime',
  'nx_blue',
  'nx_violet',
  'nx_orange',
  'nx_red_classic',
  'nx_blue_wave',
  'nx_blue_stripe',
  'nx_cobalt',
  'nx_red_hex',
  'nx_carbon',
  'nx_white_strike',
  'nx_black_strike',
  'nx_red_strike',
  'nx_blue_strike',
  'nx_red_flash',
  'nx_blue_flash',
  'pro_sky',
  'pro_red',
  'pro_lime',
  'pro_violet',
  'pro_orange',
  'pro_teal',
];
const int kBmDefaultBall = 0;

/// Preference key of the player's match ball. v9 uses a new key: every saved index named an old ball.
const String kBmBallPref = 'bm.ball.v13';

/// A saved / synced ball index -> a valid one (missing or unknown = the default ball).
int bmBallIndex(int? i) => (i == null || i < 0 || i >= kBmBallN.length) ? kBmDefaultBall : i;

/// The art of ball [i] (also its picker / shop thumbnail).
String bmBallArt(int i) => 'assets/games/bermuda/balls/v9/${kBmBallSlug[bmBallIndex(i)]}.webp';
String bmBallThumb(int i) => bmBallArt(i);

class BmAnimBall {
  const BmAnimBall(this.sheet, this.frames, this.frameMs, this.thumb, {this.gifTimed = false});
  final String sheet;
  final int frames;
  final int frameMs;
  final String thumb;
  /// GIF balls: frames in the GIF's order at exactly [frameMs] each while the ball moves.
  final bool gifTimed;

  /// Frame shown after [ms] of playback (GIF order, [frameMs] each, looping).
  int frameAt(double ms) => (ms / frameMs).floor() % frames;
}

/// Animated sprite-sheet balls. v9: none (every ball is rolled by the 3D renderer); the painter keeps the sheet path
/// so a future animated ball only needs an entry here.
const Map<int, BmAnimBall> kBmAnimBalls = <int, BmAnimBall>{};

/// Art fills (tool/build_fs_v9_assets.py): disc rim radius / half sprite size, ball radius / half frame size.
/// The painter draws every sprite so the rim lands exactly on the physics radius.
const double kBmDiscArtFill = 120 / 128;
const double kBmBallArtFill = 76 / 80;

/// The owner's NX pucks (`pucks/iso/<id>.webp`): the puck's full width fills its square, so the drawn puck is exactly as
/// wide as the collider. The art is drawn as cut: no rotation, rim, bevel, notch or glow is ever added to it.
const double kBmPuckArtFill = 1.0;

class BmFa {
  const BmFa(this.k, this.c, this.g);
  final int k;
  final List<int> c;
  final double g;
}

const Map<String, BmFa> kBmFA = <String, BmFa>{
  // v11 pitches: firework colours taken from each art's frame / display colours.
  'nx_checker_silver': BmFa(1, <int>[0xFFE8EEF6, 0xFF2F86FF, 0xFF5BD12A], 0),
  'nx_rings_green': BmFa(5, <int>[0xFF2AFF15, 0xFFB6FFA0, 0xFFFFFFFF], 0),
  'nx_street': BmFa(1, <int>[0xFFFFC21F, 0xFF35FF06, 0xFFFFFFFF], 0),
  'nx_neon_blue': BmFa(5, <int>[0xFF2F86FF, 0xFFFF3B30, 0xFFFFC94A], 0),
  'nx_royal_purple': BmFa(1, <int>[0xFFB04DFF, 0xFFFFC94A, 0xFFFFFFFF], 0),
  // v12 pitches: firework colours taken from each art's rails and lights.
  'tropical': BmFa(1, <int>[0xFF3BE0FF, 0xFFFFD27A, 0xFF7CFF4A], 0),
  'psg': BmFa(1, <int>[0xFF2F5BFF, 0xFFFF3B4A, 0xFFFFFFFF], 0),
  'campnou': BmFa(1, <int>[0xFFB0153A, 0xFF2F5BFF, 0xFFFFD86B], 0),
  'pitch': BmFa(1, <int>[0xFFFFFFFF, 0xFF7CFF4A, 0xFFFF4A4A], 0),
  'blackice': BmFa(5, <int>[0xFFBFE6FF, 0xFFFFFFFF, 0xFF6FA8FF], 0),
  'frost': BmFa(5, <int>[0xFFBFE6FF, 0xFFFFFFFF, 0xFF6FA8FF], 0),
  'glacier': BmFa(5, <int>[0xFF8FE8FF, 0xFFFFFFFF, 0xFF3B9BFF], 0),
  'autumn': BmFa(1, <int>[0xFFFF8A1F, 0xFFFFD24A, 0xFFFF4A2A], 0),
  'futsal': BmFa(1, <int>[0xFFFF3B4A, 0xFF2F86FF, 0xFFFFFFFF], 0),
  // fallback used by the engine for any id without its own entry
  'stadium': BmFa(1, <int>[0xFFFFD86B, 0xFFFFFFFF, 0xFFFFE9A8], 0),
};

/// Optional per-team accent for picker chrome (never drawn on the puck art). None for the NX pucks.
const Map<String, Color> kBmTeamAccent = <String, Color>{};

Color? bmTeamAccent(String teamId) => kBmTeamAccent[teamId];

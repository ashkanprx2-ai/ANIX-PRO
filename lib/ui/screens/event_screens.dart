import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/assets/app_assets.dart';
import '../../core/online/online_service.dart';
import '../../core/profile/achievements.dart';
import '../../core/profile/profile_service.dart';
import '../../core/storage/local_store.dart';
import '../../features/tournaments/data/models.dart';
import '../../features/tournaments/data/tournament_repository.dart';
import '../../games/game_registry.dart';
import '../../worlds/personal_orbit/core/challenge_store.dart';
import '../../worlds/personal_orbit/core/challenges.dart';
import '../kit/station_awards.dart';
import '../kit/station_kit.dart';
import 'game_icons.dart';

// =====================================================================================================================
// EVENTS + REWARDS worlds: MIS, NEWS, CAL, GIFT, WHEEL, COLL, EVT, HIST of nexora-screens.js — on real data.
// =====================================================================================================================

/// `MIS` — daily / weekly missions with real progress from the profile, claimed once each.
class StationMissionsScreen extends ConsumerStatefulWidget {
  const StationMissionsScreen({super.key, required this.weekly});
  final bool weekly;

  @override
  ConsumerState<StationMissionsScreen> createState() => _StationMissionsScreenState();
}

class _StationMissionsScreenState extends ConsumerState<StationMissionsScreen> {
  @override
  Widget build(BuildContext context) {
    final ProfileService p = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    final ChallengeBook book = ChallengeStore.touch(p);
    final DateTime now = DateTime.now();
    final List<ChallengeEvent> ev = ChallengeStore.eventsOf(p);
    final List<ChallengeDef> defs = widget.weekly ? kWeeklyChallenges : kDailyChallenges;
    return StationScreen(
      title: widget.weekly ? stx(context, 'ماموریت هفتگی', 'Weekly mission') : stx(context, 'ماموریت روزانه', 'Daily mission'),
      children: <Widget>[
        StationRows(children: <Widget>[
          for (int k = 0; k < defs.length; k++)
            Builder(builder: (BuildContext context) {
              final ChallengeDef d = defs[k];
              final int prog = math.min(book.progress(d, now, p.counters, ev), d.target);
              final bool claimed = book.isClaimed(d);
              final bool can = book.canClaim(d, now, p.counters, ev);
              return StationRow(
                first: k == 0,
                title: fa ? d.titleFa : d.titleEn,
                subtitle: '${nxNum(context, prog)} / ${nxNum(context, d.target)} · ${nxNum(context, d.coins)} ${stx(context, 'سکه', 'coins')} · ${nxNum(context, d.xp)} XP',
                onTap: d.route != null && !can && !claimed ? () => context.push(d.route!) : null,
                trailing: StationButton(
                  small: true,
                  expand: false,
                  ghost: !can,
                  label: claimed ? stx(context, 'دریافت شد', 'Claimed') : can ? stx(context, 'دریافت', 'Claim') : stx(context, 'در جریان', 'In progress'),
                  onTap: can
                      ? () async {
                          final AwardOutcome? o = ChallengeStore.claim(p, d);
                          setState(() {});
                          if (o == null) return;
                          await showStationModal(context,
                              big: '🎁',
                              title: stx(context, 'جایزه دریافت شد', 'Reward claimed'),
                              text: fa ? '${nxNum(context, o.coins)} سکه و ${nxNum(context, o.xp)} XP به حساب شما اضافه شد' : '${o.coins} coins and ${o.xp} XP added');
                          if (context.mounted) await showAwardOutcome(context, o);
                        }
                      : null,
                ),
                child: StationBar(prog / d.target),
              );
            }),
        ]),
      ],
    );
  }
}

/// `NEWS` — announcements from the server (`nx_announcements`), expandable. Empty state when offline.
class StationNewsScreen extends ConsumerStatefulWidget {
  const StationNewsScreen({super.key});

  @override
  ConsumerState<StationNewsScreen> createState() => _StationNewsScreenState();
}

class _StationNewsScreenState extends ConsumerState<StationNewsScreen> {
  List<Map<String, dynamic>>? _rows;
  int _open = -1;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final SupabaseClient? c = ref.read(onlineProvider).client;
    List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    try {
      if (c != null) {
        final List<dynamic> r = await c.from('nx_announcements').select().order('created_at', ascending: false).limit(30);
        rows = r.map((dynamic e) => Map<String, dynamic>.from(e as Map)).where((Map<String, dynamic> m) => m['active'] != false).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _rows = rows);
  }

  String _ago(BuildContext context, String? iso) {
    final DateTime? t = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
    if (t == null) return '';
    final int d = DateTime.now().difference(t).inDays;
    if (d <= 0) return stx(context, 'امروز', 'Today');
    if (d == 1) return stx(context, 'دیروز', 'Yesterday');
    if (d < 7) return stationFa(context) ? '${nxNum(context, d)} روز پیش' : '$d days ago';
    return stationFa(context) ? '${nxNum(context, d ~/ 7)} هفته‌ی پیش' : '${d ~/ 7} weeks ago';
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final List<Map<String, dynamic>>? rows = _rows;
    return StationScreen(
      title: stx(context, 'اطلاعیه‌ها', 'News'),
      children: <Widget>[
        if (rows == null)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (rows.isEmpty)
          StationEmpty(
            text: stx(context, 'فعلاً اطلاعیه‌ای نیست. برای دیدن اطلاعیه‌های تیم نکسورا وارد حساب شو.',
                'No announcements yet. Sign in to see news from the NEXORA team.'),
            icon: 'r5c3',
          )
        else
          for (int k = 0; k < rows.length; k++)
            StationCard(
              onTap: () => setState(() => _open = _open == k ? -1 : k),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(_ago(context, '${rows[k]['created_at']}'), style: TextStyle(fontSize: 11, color: p.gold)),
                const SizedBox(height: 3),
                Text('${rows[k]['title'] ?? ''}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  child: _open == k && '${rows[k]['body'] ?? ''}'.isNotEmpty
                      ? Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('${rows[k]['body']}', style: TextStyle(fontSize: 13, color: p.mute, height: 1.9)),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ]),
            ),
      ],
    );
  }
}

/// Tournaments loaded once for the calendar / event screens.
Future<List<Tournament>> _tournaments(WidgetRef ref) async {
  try {
    return await ref.read(tournamentRepoProvider).list();
  } catch (_) {
    return const <Tournament>[];
  }
}

/// `CAL` — this month's days; a dot marks days with a tournament start; the selected day lists them.
class StationCalendarScreen extends ConsumerStatefulWidget {
  const StationCalendarScreen({super.key});

  @override
  ConsumerState<StationCalendarScreen> createState() => _StationCalendarScreenState();
}

class _StationCalendarScreenState extends ConsumerState<StationCalendarScreen> {
  List<Tournament> _list = const <Tournament>[];
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _sel = DateTime.now().day;

  @override
  void initState() {
    super.initState();
    _tournaments(ref).then((List<Tournament> l) {
      if (mounted) setState(() => _list = l);
    });
  }

  List<Tournament> _on(int day) => _list.where((Tournament t) {
        final DateTime s = t.startAt.toLocal();
        return s.year == _month.year && s.month == _month.month && s.day == day;
      }).toList();

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final int days = DateTime(_month.year, _month.month + 1, 0).day;
    final int lead = DateTime(_month.year, _month.month).weekday % 7; // Sunday-first like the reference grid
    final List<String> wd = fa ? const <String>['ی', 'د', 'س', 'چ', 'پ', 'ج', 'ش'] : const <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final List<String> months = fa
        ? const <String>['ژانویه', 'فوریه', 'مارس', 'آوریل', 'مه', 'ژوئن', 'ژوئیه', 'اوت', 'سپتامبر', 'اکتبر', 'نوامبر', 'دسامبر']
        : const <String>['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final List<Tournament> today = _on(_sel);
    return StationScreen(
      title: stx(context, 'تقویم رویدادها', 'Calendar'),
      children: <Widget>[
        StationCard(
          child: Column(children: <Widget>[
            Row(children: <Widget>[
              StationRoundButton(
                  icon: Icons.chevron_right_rounded, size: 32, onTap: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
              Expanded(
                child: Text('${months[_month.month - 1]} ${nxNum(context, _month.year, group: false)}',
                    textAlign: TextAlign.center, style: TextStyle(color: p.gold, fontSize: 13)),
              ),
              StationRoundButton(
                  icon: Icons.chevron_left_rounded, size: 32, onTap: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
            ]),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 7,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
              children: <Widget>[
                for (final String d in wd) Center(child: Text(d, style: TextStyle(fontSize: 12, color: p.mute))),
                for (int i = 0; i < lead; i++) const SizedBox.shrink(),
                for (int d = 1; d <= days; d++)
                  GestureDetector(
                    onTap: () => setState(() => _sel = d),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: d == _sel ? (p.isLight ? p.plate : p.primary) : p.tileFill,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: d == _sel ? p.gold : p.line),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
                        Text(nxNum(context, d),
                            style: TextStyle(fontSize: 12, color: d == _sel && !p.isLight ? p.primaryInk : p.plateInk)),
                        if (_on(d).isNotEmpty)
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(shape: BoxShape.circle, color: p.gold2),
                          ),
                      ]),
                    ),
                  ),
              ],
            ),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text('${stx(context, 'روز', 'Day')} ${nxNum(context, _sel)}', style: TextStyle(color: p.gold, fontSize: 12.5)),
            const SizedBox(height: 4),
            if (today.isEmpty)
              Text(stx(context, 'رویدادی ثبت نشده', 'No events'), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))
            else
              for (final Tournament t in today)
                StationRow(
                  first: t == today.first,
                  leading: StationIcon(stationGameIcon(t.game), size: 38, radius: 12),
                  title: t.title,
                  subtitle: '${TimeOfDay.fromDateTime(t.startAt.toLocal()).format(context)} · ${gameById(t.game)?.nameFa ?? t.game}',
                  onTap: () => context.push('/tournaments/${t.id}'),
                ),
            if (today.isNotEmpty)
              StationButton(label: stx(context, 'یادآوری کن', 'Remind me'), icon: Icons.notifications_active_rounded, onTap: () {
                context.push('/tournaments/${today.first.id}');
              }),
          ]),
        ),
      ],
    );
  }
}

/// `GIFT` — three boxes; picking one claims today's real daily reward (server-checked, streak bonus).
class StationGiftBoxScreen extends ConsumerStatefulWidget {
  const StationGiftBoxScreen({super.key});

  @override
  ConsumerState<StationGiftBoxScreen> createState() => _StationGiftBoxScreenState();
}

class _StationGiftBoxScreenState extends ConsumerState<StationGiftBoxScreen> {
  int _shaking = -1;

  Future<void> _open(int k) async {
    final ProfileService p = ref.read(profileProvider);
    if (!p.canClaimDaily) {
      stationToast(context, stx(context, 'شانس امروز تمام شد؛ فردا برگرد!', "Today's gift is claimed — come back tomorrow!"));
      return;
    }
    setState(() => _shaking = k);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    final AwardOutcome? o = p.claimDaily();
    if (!mounted) return;
    setState(() => _shaking = -1);
    if (o == null) return;
    final bool fa = stationFa(context);
    await showStationModal(context,
        big: '🎁',
        title: stx(context, 'تبریک!', 'Congrats!'),
        text: fa
            ? '${nxNum(context, o.coins)} سکه و ${nxNum(context, o.xp)} XP بردی · روز ${nxNum(context, p.streak)} پشت‌سرهم'
            : 'You won ${o.coins} coins and ${o.xp} XP · day ${p.streak} streak');
    if (mounted) await showAwardOutcome(context, o);
  }

  @override
  Widget build(BuildContext context) {
    final ProfileService p = ref.watch(profileProvider);
    final StationPalette p2 = StationPalette.of(context);
    return StationScreen(
      title: stx(context, 'صندوق هدیه', 'Gift box'),
      children: <Widget>[
        StationCard(
          hero: true,
          child: Column(children: <Widget>[
            Text(
              p.canClaimDaily
                  ? stx(context, 'یک صندوق را انتخاب کنید · ۱ شانس باقی‌مانده', 'Pick a box · 1 chance left')
                  : stx(context, 'هدیه‌ی امروز گرفته شد · فردا دوباره', "Today's gift is claimed · again tomorrow"),
              style: TextStyle(fontSize: 12, color: p2.isLight ? const Color(0xFFD7E0FF) : p2.mute),
            ),
            const SizedBox(height: 14),
            Row(children: <Widget>[
              for (int k = 0; k < 3; k++)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _open(k),
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey<String>('box$k$_shaking'),
                      tween: Tween<double>(begin: 0, end: _shaking == k ? 1 : 0),
                      duration: const Duration(milliseconds: 900),
                      builder: (_, double v, Widget? c) =>
                          Transform.rotate(angle: math.sin(v * math.pi * 4) * .16, child: Transform.scale(scale: 1 + .1 * math.sin(v * math.pi), child: c)),
                      child: Opacity(opacity: p.canClaimDaily ? 1 : .45, child: const StationIcon('r3c6', size: 86)),
                    ),
                  ),
                ),
            ]),
          ]),
        ),
        StationStats(<(String, String)>[
          (nxNum(context, p.streak), stx(context, 'روز پشت‌سرهم', 'Day streak')),
          (nxNum(context, 50 + math.min(p.streak + 1, 7) * 10), stx(context, 'سکه‌ی هدیه‌ی بعدی', 'Next gift coins')),
        ]),
      ],
    );
  }
}

/// `WHEEL` — the lucky wheel: one free spin per day. Signed in, the server picks the prize (`nx_spin_wheel`);
/// guests spin locally. There are no paid spins (P26: no gambling, no random paid rewards).
class StationWheelScreen extends ConsumerStatefulWidget {
  const StationWheelScreen({super.key});

  @override
  ConsumerState<StationWheelScreen> createState() => _StationWheelScreenState();
}

class _StationWheelScreenState extends ConsumerState<StationWheelScreen> with SingleTickerProviderStateMixin {
  static const List<int> kPrizes = <int>[50, 100, 150, 200, 250, 300, 100, 50];
  static const String _kDay = 'station.wheel_day';
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 4200));
  double _from = 0, _to = 0;
  bool _busy = false;

  String get _today {
    final DateTime n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
  }

  /// Server answer of `nx_wheel_status` / `nx_spin_wheel`: when the next free spin opens (signed-in users only).
  DateTime? _nextAt;

  bool get _signedIn {
    final SupabaseClient? c = ref.read(onlineProvider).client;
    return c != null && c.auth.currentSession != null && !(c.auth.currentUser?.isAnonymous ?? true);
  }

  bool get _spunToday {
    if (_signedIn) return _nextAt != null && _nextAt!.isAfter(DateTime.now());
    return LocalStore.instance.getString(_kDay) == _today;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _status());
  }

  Future<void> _status() async {
    if (!_signedIn) return;
    try {
      final dynamic r = await ref.read(onlineProvider).client!.rpc('nx_wheel_status');
      if (r is Map && mounted) setState(() => _nextAt = DateTime.tryParse('${r['next_at'] ?? ''}')?.toLocal());
    } catch (_) {/* status is cosmetic; the spin RPC enforces the rule */}
  }

  String _nextLabel() {
    final DateTime? n = _nextAt;
    if (n == null) return '';
    final Duration d = n.difference(DateTime.now());
    if (d.isNegative) return '';
    final int h = d.inHours, m = d.inMinutes % 60;
    return stationFa(context)
        ? 'چرخش بعدی تا ${nxNum(context, h)} ساعت و ${nxNum(context, m)} دقیقه‌ی دیگر'
        : 'Next spin in ${h}h ${m}m';
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _spin() async {
    if (_busy) return;
    if (_spunToday) {
      stationToast(context, stx(context, 'چرخش امروز انجام شده؛ فردا دوباره!', 'Already spun today — again tomorrow!'));
      return;
    }
    setState(() => _busy = true);
    final ProfileService p = ref.read(profileProvider);
    int idx = math.Random().nextInt(kPrizes.length);
    int prize = kPrizes[idx];
    int? total;
    final bool server = _signedIn;
    if (server) {
      // Signed in: the server is the only authority (one spin per user per day, reward credited server-side).
      try {
        final dynamic r = await ref.read(onlineProvider).client!.rpc('nx_spin_wheel');
        final Map<String, dynamic> m = r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
        _nextAt = DateTime.tryParse('${m['next_at'] ?? ''}')?.toLocal();
        if (m['ok'] != true) {
          if (mounted) {
            setState(() => _busy = false);
            stationToast(context, stx(context, 'چرخش امروز انجام شده؛ فردا دوباره!', 'Already spun today — again tomorrow!'));
          }
          return;
        }
        idx = ((m['index'] as num?)?.toInt() ?? 0).clamp(0, kPrizes.length - 1);
        prize = (m['prize'] as num?)?.toInt() ?? kPrizes[idx];
        total = (m['coins_total'] as num?)?.toInt();
      } catch (_) {
        if (mounted) {
          setState(() => _busy = false);
          stationToast(context, stx(context, 'اتصال به سرور برقرار نشد؛ دوباره امتحان کن.', 'Could not reach the server; try again.'), error: true);
        }
        return;
      }
    }
    final double seg = 2 * math.pi / kPrizes.length;
    _from = _to % (2 * math.pi);
    _to = _from + 2 * math.pi * 5 + (2 * math.pi - idx * seg - _from % (2 * math.pi));
    await _c.forward(from: 0);
    if (server) {
      p.applyWallet(coins: total);
    } else {
      // Offline / guest fallback: one local spin per calendar day.
      await LocalStore.instance.setString(_kDay, _today);
      p.award('wheel.daily', xp: 5, coins: prize, fa: 'چرخ شانس', en: 'Lucky wheel');
    }
    if (!mounted) return;
    setState(() => _busy = false);
    await showStationModal(context,
        big: '🎡',
        title: stx(context, 'برنده شدید!', 'You won!'),
        text: stationFa(context) ? '${nxNum(context, prize)} سکه' : '$prize coins');
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final double w = math.min(MediaQuery.sizeOf(context).width * .78, 300);
    return StationScreen(
      title: stx(context, 'چرخ شانس', 'Lucky wheel'),
      children: <Widget>[
        const SizedBox(height: 6),
        Center(
          child: SizedBox(
            width: w,
            height: w + 12,
            child: Stack(alignment: Alignment.topCenter, children: <Widget>[
              Positioned(
                top: 12,
                child: AnimatedBuilder(
                  animation: _c,
                  builder: (_, __) {
                    final double v = const Cubic(.12, .7, .1, 1).transform(_c.value);
                    return Transform.rotate(
                      angle: _from + (_to - _from) * v,
                      child: Container(
                        width: w,
                        height: w,
                        decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: <BoxShadow>[BoxShadow(color: p.gold.withValues(alpha: .6), blurRadius: 50, spreadRadius: -8)]),
                        child: CustomPaint(painter: _WheelPainter(kPrizes, p, stationFa(context))),
                      ),
                    );
                  },
                ),
              ),
              CustomPaint(size: const Size(24, 24), painter: _PinPainter(p.gold2)),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        StationButton(
          label: _spunToday ? stx(context, 'فردا دوباره بچرخان', 'Spin again tomorrow') : stx(context, 'بچرخان · رایگان', 'Spin · free'),
          busy: _busy,
          onTap: _spunToday || _busy ? null : _spin,
        ),
        const SizedBox(height: 10),
        if (_spunToday && _nextLabel().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(_nextLabel(), textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: p.gold)),
          ),
        Text(stx(context, 'هر روز یک چرخش رایگان؛ جایزه‌ها سکه‌اند و به حسابت اضافه می‌شوند.', 'One free spin every day; prizes are coins added to your wallet.'),
            textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: p.mute)),
      ],
    );
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter(this.prizes, this.p, this.fa);
  final List<int> prizes;
  final StationPalette p;
  final bool fa;

  @override
  void paint(Canvas canvas, Size s) {
    final Offset c = s.center(Offset.zero);
    final double r = s.width / 2;
    final int n = prizes.length;
    final double a = 2 * math.pi / n;
    for (int k = 0; k < n; k++) {
      final double start = k * a - math.pi / 2 - a / 2;
      final Paint fill = Paint()..color = k.isOdd ? (p.isLight ? const Color(0xFF0A2276) : const Color(0xFF1B1236)) : p.gold;
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, a, true, fill);
      canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, a, true, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = p.gold3);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(k * a);
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: fa ? _fa('${prizes[k]}') : '${prizes[k]}',
          style: TextStyle(fontFamily: kStationFont, fontSize: r * .13, fontWeight: FontWeight.w600, color: k.isOdd ? p.gold2 : const Color(0xFF1A1408)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -r * .78));
      canvas.restore();
    }
    canvas.drawCircle(c, r * .15, Paint()..color = const Color(0xFF0A0A0D));
    canvas.drawCircle(c, r * .15, Paint()..style = PaintingStyle.stroke..strokeWidth = 3..color = p.gold2);
  }

  static String _fa(String s) => s.replaceAllMapped(RegExp(r'\d'), (Match m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]);

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.p != p;
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size s) {
    final Path path = Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width / 2, s.height)
      ..close();
    canvas.drawShadow(path, Colors.black, 3, false);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// `COLL` — medals (achievements) or trophies (tournament places + arcade medals), unlocked vs locked.
class StationCollectionScreen extends ConsumerWidget {
  const StationCollectionScreen({super.key, required this.trophies});
  final bool trophies;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileService p = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    final List<AchievementDef> all = kAchievements;
    final int got = all.where((AchievementDef a) => p.achievements.contains(a.id)).length;
    final List<GameInfo> withWins = kGames.where((GameInfo g) => (p.stats[g.id]?.won ?? 0) > 0).toList();
    return StationScreen(
      title: trophies ? stx(context, 'جام‌ها', 'Trophies') : stx(context, 'مدال‌ها', 'Medals'),
      children: <Widget>[
        if (!trophies) ...<Widget>[
          StationCard(
            child: Column(children: <Widget>[
              StationStat(value: '${nxNum(context, got)} / ${nxNum(context, all.length)}', label: stx(context, 'دریافت‌شده', 'Unlocked')),
              StationBar(all.isEmpty ? 0 : got / all.length),
            ]),
          ),
          StationGrid(columns: 3, gap: 10, children: <Widget>[
            for (final AchievementDef a in all)
              StationTile(
                image: Image.asset(AppAssets.achievement(a.asset), width: 44, height: 40, errorBuilder: (_, __, ___) => const StationIcon('r4c3', size: 40)),
                title: fa ? a.nameFa : a.nameEn,
                subtitle: p.achievements.contains(a.id) ? stx(context, 'باز شده', 'Unlocked') : stx(context, 'قفل', 'Locked'),
                locked: !p.achievements.contains(a.id),
                onTap: () => stationToast(context, fa ? a.descFa : a.descEn),
              ),
          ]),
        ] else ...<Widget>[
          StationCard(
            child: Column(children: <Widget>[
              StationStat(value: nxNum(context, p.totalWins), label: stx(context, 'برد در همه‌ی بازی‌ها', 'Wins across all games')),
              StationBar(p.totalGamesPlayed == 0 ? 0 : p.totalWins / p.totalGamesPlayed),
            ]),
          ),
          if (withWins.isEmpty)
            StationEmpty(text: stx(context, 'هنوز جامی نبردی؛ اولین بردت اولین جامت است!', 'No trophies yet — your first win is your first cup!'), icon: 'r2c5')
          else
            StationGrid(columns: 3, gap: 10, children: <Widget>[
              for (final GameInfo g in withWins)
                StationTile(
                  icon: 'r2c5',
                  title: fa ? g.nameFa : g.nameEn,
                  subtitle: fa ? '${nxNum(context, p.stats[g.id]!.won)} برد' : '${p.stats[g.id]!.won} wins',
                  onTap: () => context.push('/arcade/${g.id}'),
                ),
            ]),
          StationButton(label: stx(context, 'تورنمنت‌ها', 'Tournaments'), icon: Icons.emoji_events_rounded, ghost: true, onTap: () => context.push('/tournaments')),
        ],
      ],
    );
  }
}

/// `EVT` — duel / cup / daily cup / weekly league / special match, fed by the real tournaments list: the next one
/// that fits, its countdown, prize, players and entry, and registration through the tournament page.
class StationEventScreen extends ConsumerStatefulWidget {
  const StationEventScreen({super.key, required this.kind});
  final String kind; // duel | cup | daily | league | special

  @override
  ConsumerState<StationEventScreen> createState() => _StationEventScreenState();
}

class _StationEventScreenState extends ConsumerState<StationEventScreen> {
  List<Tournament>? _list;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tournaments(ref).then((List<Tournament> l) {
      if (mounted) setState(() => _list = l);
    });
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool _fits(Tournament t) {
    final Duration span = t.startAt.difference(t.regOpenAt);
    return switch (widget.kind) {
      'duel' => t.capacity <= 8,
      'daily' => span.inHours <= 30,
      'league' => span.inDays >= 3 || t.format.name.contains('league') || t.format.name.contains('round'),
      'special' => !t.isFree || t.prize.isNotEmpty,
      _ => true,
    };
  }

  String get _title => switch (widget.kind) {
        'duel' => stx(context, 'مبارزه', 'Duel'),
        'daily' => stx(context, 'تورنمنت روزانه', 'Daily cup'),
        'league' => stx(context, 'لیگ هفتگی', 'Weekly league'),
        'special' => stx(context, 'مسابقه ویژه', 'Special match'),
        _ => stx(context, 'جام', 'Cup'),
      };

  String _clock(Duration d) {
    if (d.isNegative) d = Duration.zero;
    String two(int v) => v.toString().padLeft(2, '0');
    final String s = '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
    return stationFa(context) ? s.replaceAllMapped(RegExp(r'\d'), (Match m) => '۰۱۲۳۴۵۶۷۸۹'[int.parse(m[0]!)]) : s;
  }

  @override
  Widget build(BuildContext context) {
    final StationPalette p = StationPalette.of(context);
    final List<Tournament>? all = _list;
    final List<Tournament> open = (all ?? const <Tournament>[]).where((Tournament t) => !t.isOver).toList()
      ..sort((Tournament a, Tournament b) => a.startAt.compareTo(b.startAt));
    final List<Tournament> fit = open.where(_fits).toList();
    final List<Tournament> list = fit.isNotEmpty ? fit : open;
    final Tournament? t = list.isEmpty ? null : list.first;
    final GameInfo? g = t == null ? null : gameById(t.game);
    final bool fa = stationFa(context);
    return StationScreen(
      title: _title,
      children: <Widget>[
        if (all == null)
          StationEmpty(text: stx(context, 'در حال دریافت…', 'Loading…'), loading: true)
        else if (t == null)
          StationEmpty(
            text: stx(context, 'فعلاً رویداد بازی نیست. برای دیدن و ساخت تورنمنت‌ها وارد حساب شو.', 'No open events right now. Sign in to see and create tournaments.'),
            icon: 'r2c5',
            action: stx(context, 'همه‌ی تورنمنت‌ها', 'All tournaments'),
            onAction: () => context.push('/tournaments'),
          )
        else ...<Widget>[
          StationHero(
            icon: stationGameIcon(t.game),
            title: t.title,
            subtitle: t.canRegister ? stx(context, 'شروع تا', 'Starts in') : stx(context, 'وضعیت', 'Status'),
            children: <Widget>[
              Text(_clock(t.startAt.difference(DateTime.now().toUtc())),
                  style: TextStyle(fontSize: 26, color: p.isLight ? const Color(0xFFFFD77A) : p.gold2, letterSpacing: 1.2)),
            ],
          ),
          StationStats(<(String, String)>[
            (t.prize.isEmpty ? '—' : nxNum(context, _prizeTotal(t.prize)), stx(context, 'جایزه کل', 'Prize pool')),
            (nxNum(context, t.capacity), stx(context, 'ظرفیت', 'Capacity')),
            (t.isFree ? stx(context, 'رایگان', 'Free') : nxNum(context, t.feeCoins > 0 ? t.feeCoins : t.feeGems), stx(context, 'ورودی', 'Entry')),
          ]),
          StationCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(stx(context, 'قوانین', 'Rules'), style: TextStyle(color: p.gold, fontSize: 12.5)),
              const SizedBox(height: 6),
              Text(
                t.rules.isNotEmpty ? t.rules : (g == null ? '' : (fa ? g.rulesFa : g.rulesEn)),
                style: TextStyle(color: p.mute, fontSize: 12.5, height: 2),
              ),
            ]),
          ),
          StationButton(
            label: t.canRegister ? stx(context, 'ثبت‌نام', 'Register') : stx(context, 'مشاهده', 'Open'),
            onTap: () => context.push('/tournaments/${t.id}'),
          ),
          if (list.length > 1) ...<Widget>[
            StationTitle(stx(context, 'رویدادهای دیگر', 'More events')),
            StationRows(children: <Widget>[
              for (final Tournament o in list.skip(1).take(8))
                StationRow(
                  first: o == list[1],
                  leading: StationIcon(stationGameIcon(o.game), size: 38, radius: 12),
                  title: o.title,
                  subtitle: _clock(o.startAt.difference(DateTime.now().toUtc())),
                  onTap: () => context.push('/tournaments/${o.id}'),
                ),
            ]),
          ],
        ],
      ],
    );
  }

  int _prizeTotal(Map<String, dynamic> prize) {
    int sum = 0;
    void walk(Object? v) {
      if (v is num) sum += v.toInt();
      if (v is Map) v.values.forEach(walk);
      if (v is List) v.forEach(walk);
    }

    walk(prize);
    return sum;
  }
}

/// `HIST` — recent battles from the activity timeline (wins in green, losses in red).
class StationHistoryScreen extends ConsumerWidget {
  const StationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ProfileService p = ref.watch(profileProvider);
    final bool fa = stationFa(context);
    final List<ActivityEntry> games = p.activity.where((ActivityEntry a) => a.kind.startsWith('game')).take(60).toList();
    String ago(DateTime t) {
      final Duration d = DateTime.now().difference(t);
      if (d.inMinutes < 60) return fa ? '${nxNum(context, math.max(1, d.inMinutes))} دقیقه پیش' : '${math.max(1, d.inMinutes)} min ago';
      if (d.inHours < 24) return fa ? '${nxNum(context, d.inHours)} ساعت پیش' : '${d.inHours} h ago';
      return fa ? '${nxNum(context, d.inDays)} روز پیش' : '${d.inDays} days ago';
    }

    return StationScreen(
      title: stx(context, 'نبردها', 'Battles'),
      children: <Widget>[
        if (games.isEmpty)
          StationEmpty(
            text: stx(context, 'هنوز نبردی ثبت نشده. یک بازی بزن!', 'No battles yet. Play a game!'),
            icon: 'r4c6',
            action: stx(context, 'بازی‌ها', 'Games'),
            onAction: () => context.go('/station/0'),
          )
        else
          StationRows(children: <Widget>[
            for (int k = 0; k < games.length; k++)
              Builder(builder: (BuildContext context) {
                final ActivityEntry a = games[k];
                final bool win = a.kind.endsWith('win');
                final bool loss = a.kind.endsWith('loss');
                return StationRow(
                  first: k == 0,
                  leading: StationLetter(fa ? a.textFa : a.textEn),
                  title: fa ? a.textFa : a.textEn,
                  subtitle: ago(a.at),
                  trailing: Text(
                    a.xp > 0 ? '+${nxNum(context, a.xp)} XP' : (win ? '+' : loss ? '−' : '='),
                    style: TextStyle(color: win ? const Color(0xFF7BE0A4) : loss ? const Color(0xFFE07B7B) : StationPalette.of(context).mute, fontWeight: FontWeight.w500),
                  ),
                );
              }),
          ]),
      ],
    );
  }
}

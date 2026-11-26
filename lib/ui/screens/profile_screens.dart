import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/companion/companion.dart';
import '../../core/online/cloud_profile_sync.dart';
import '../../core/online/online_service.dart';
import '../../core/online/social_api.dart';
import '../../core/profile/achievements.dart';
import '../../core/profile/profile_service.dart';
import '../../core/settings/app_settings.dart';
import '../../core/update/app_updater.dart';
import '../../features/admin/admin_access.dart';
import '../../worlds/settings/delete_account.dart';
import '../kit/station_kit.dart';
import '../widgets/companion_widgets.dart';

// =====================================================================================================================
// PROFILE world: PROF (profile + showcase tabs), ACC (account), SET (settings), CTL (controller) — nexora-social.js /
// nexora-screens.js.
// =====================================================================================================================

/// `PROF` — cover of floating icons, ringed avatar, name, follow counts, edit / contacts, 4 tabs.
class StationProfileScreen extends ConsumerStatefulWidget {
  const StationProfileScreen({super.key});

  @override
  ConsumerState<StationProfileScreen> createState() => _StationProfileScreenState();
}

class _StationProfileScreenState extends ConsumerState<StationProfileScreen> {
  int _tab = 0;
  int? _friends;
  int? _following;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  Future<void> _loadCounts() async {
    final OnlineService o = ref.read(onlineProvider);
    if (o.client == null || !o.isOnline || o.isGuest) return;
    try {
      final SocialApi api = SocialApi(o.client!);
      final List<NxUser> f = await api.friends();
      final List<NxUser> g = await api.following();
      if (mounted) {
        setState(() {
          _friends = f.length;
          _following = g.length;
        });
      }
    } catch (_) {/* counts are optional */}
  }

  @override
  Widget build(BuildContext context) {
    final ProfileService prof = ref.watch(profileProvider);
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final String name = prof.username.isEmpty ? stx(context, 'کاوشگر', 'Explorer') : prof.username;
    const List<String> cover = <String>['r4c4', 'r1c2', 'r3c6', 'r1c1', 'r2c5', 'r4c3'];

    final List<(String, int, String, List<Color>, String?)> shelf = <(String, int, String, List<Color>, String?)>[
      (stx(context, 'قاب پروفایل', 'Profile frame'), prof.inventory.where((String i) => i.startsWith('frame')).length, 'r4c4',
          const <Color>[Color(0xFF7A5AF8), Color(0xFF1B1040)], '/s/frames'),
      (stx(context, 'نشان', 'Badge'), prof.achievements.length, 'r4c3', const <Color>[Color(0xFFE5484D), Color(0xFF33102A)], '/s/medals'),
      (stx(context, 'افکت پروفایل', 'Profile effect'), 0, 'r3c6', const <Color>[Color(0xFF2A5BD7), Color(0xFF0F1A4A)], null),
      (stx(context, 'اینترو', 'Intro'), 0, 'r3c5', const <Color>[Color(0xFFD1288A), Color(0xFF2A0F4A)], null),
      (stx(context, 'تم پروفایل', 'Profile theme'), 0, 'r4c2', const <Color>[Color(0xFFFF7A1A), Color(0xFF6A280A)], '/s/themes'),
    ];

    Widget tabBody() {
      switch (_tab) {
        case 0:
          return Column(children: <Widget>[
            StationGrid(children: <Widget>[
              for (int k = 0; k < 4; k++)
                StationGameCard(
                  title: shelf[k].$1,
                  icon: shelf[k].$3,
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: shelf[k].$4),
                  meta: <String>[stx(context, 'تعداد: ${nxNum(context, shelf[k].$2)}', 'Count: ${shelf[k].$2}')],
                  onTap: () => shelf[k].$5 != null ? context.push(shelf[k].$5!) : stationToast(context, stx(context, '${shelf[k].$1} — خالی است', '${shelf[k].$1} — empty')),
                ),
            ]),
            StationGameCard(
              wide: true,
              title: shelf[4].$1,
              icon: shelf[4].$3,
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: shelf[4].$4),
              meta: <String>[stx(context, 'پوسته‌ی برنامه', 'App skin')],
              onTap: () => context.push('/s/themes'),
            ),
          ]);
        case 1:
          final List<int> week = List<int>.generate(7, (int i) {
            final DateTime d = DateTime.now().subtract(Duration(days: 6 - i));
            return prof.activity
                .where((ActivityEntry a) => a.at.year == d.year && a.at.month == d.month && a.at.day == d.day)
                .fold<int>(0, (int s, ActivityEntry a) => s + a.xp);
          });
          final int peak = week.fold<int>(1, (int m, int v) => v > m ? v : m);
          return Column(children: <Widget>[
            StationCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
                Text(stx(context, 'درآمد هفته', 'This week'), style: StationText.title(context, size: 15)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 110,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                    for (final int v in week)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          height: 8 + 102 * (v / peak),
                          decoration: BoxDecoration(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(8), bottom: Radius.circular(3)),
                            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: <Color>[p.gold2, p.gold3]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ]),
            ),
            StationStats(<(String, String)>[
                (nxNum(context, prof.coins), stx(context, 'سکه', 'Coins')),
                (nxNum(context, prof.gems), stx(context, 'الماس', 'Gems')),
                (nxNum(context, week.fold<int>(0, (int s, int v) => s + v)), stx(context, 'XP این هفته', 'XP this week')),
              ]),
          ]);
        case 2:
          return StationRows(children: <Widget>[
            for (int k = 0; k < kAchievements.length; k++)
              StationRow(
                first: k == 0,
                leading: Opacity(opacity: prof.achievements.contains(kAchievements[k].id) ? 1 : .4, child: const StationIcon('r4c3', size: 44)),
                title: fa ? kAchievements[k].nameFa : kAchievements[k].nameEn,
                subtitle: fa ? kAchievements[k].descFa : kAchievements[k].descEn,
                child: StationBar(prof.achievements.contains(kAchievements[k].id) ? 1 : 0),
              ),
          ]);
        default:
          return StationCard(
            onTap: () => context.push('/account'),
            child: Text(
              prof.bio.isEmpty ? stx(context, 'هنوز چیزی درباره‌ی خودت ننوشته‌ای. برای نوشتن بزن.', 'Nothing about you yet. Tap to write.') : prof.bio,
              style: TextStyle(color: p.mute, height: 2, fontSize: 13),
            ),
          );
      }
    }

    return StationScreen(
      title: stx(context, 'پروفایل', 'Profile'),
      actions: <Widget>[
        StationRoundButton(icon: Icons.settings_rounded, tooltip: stx(context, 'تنظیمات', 'Settings'), onTap: () => context.push('/settings')),
      ],
      children: <Widget>[
        // `.cover`
        Container(
          height: 130,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(26), gradient: p.cardFill),
          clipBehavior: Clip.antiAlias,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints c) => Stack(children: <Widget>[
              for (int k = 0; k < cover.length; k++)
                Positioned(
                  left: c.maxWidth * k * .18,
                  top: (k % 2) * 52.0 + 8,
                  child: Transform.rotate(angle: (k * 23 - 40) * 3.14159 / 180, child: Opacity(opacity: .55, child: StationIcon(cover[k], size: 64))),
                ),
            ]),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -46),
          child: Column(children: <Widget>[
            Center(child: StationAvatarPicker(name: name, size: 96)),
            const SizedBox(height: 8),
            Text(name, style: StationText.title(context, size: 19)),
            Text(
              _friends == null
                  ? (fa ? 'سطح ${nxNum(context, prof.level)} · ${prof.rankTitleFa}' : 'Level ${prof.level} · ${prof.rankTitleEn}')
                  : (fa
                      ? '${nxNum(context, _friends!)} دوست · ${nxNum(context, _following ?? 0)} دنبال‌شده'
                      : '$_friends friends · ${_following ?? 0} following'),
              style: StationText.mute(context),
            ),
            const SizedBox(height: 14),
            Row(children: <Widget>[
              Expanded(child: StationButton(label: stx(context, '✎ ویرایش', '✎ Edit'), ghost: true, small: true, onTap: () => context.push('/account'))),
              const SizedBox(width: 10),
              Expanded(child: StationButton(label: stx(context, '👁 مخاطبین', '👁 Contacts'), ghost: true, small: true, onTap: () => context.push('/s/viewers'))),
            ]),
            const SizedBox(height: 4),
            StationTabs(
              labels: <String>[stx(context, 'ویترین', 'Showcase'), stx(context, 'درآمد', 'Earnings'), stx(context, 'دستاوردها', 'Achievements'), stx(context, 'درباره من', 'About me')],
              index: _tab,
              onChanged: (int i) => setState(() => _tab = i),
            ),
            const SizedBox(height: 12),
            tabBody(),
          ]),
        ),
      ],
    );
  }
}

/// `ACC` — level hero, game stats, change name, explorer id, account / sign-in state.
class StationAccountScreen extends ConsumerStatefulWidget {
  const StationAccountScreen({super.key});

  @override
  ConsumerState<StationAccountScreen> createState() => _StationAccountScreenState();
}

class _StationAccountScreenState extends ConsumerState<StationAccountScreen> {
  late final TextEditingController _name = TextEditingController(text: ref.read(profileProvider).username);
  late final TextEditingController _bio = TextEditingController(text: ref.read(profileProvider).bio);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final String v = _name.text.trim();
    if (v.isEmpty || _saving) return;
    setState(() => _saving = true);
    final OnlineService o = ref.read(onlineProvider);
    String status = 'ok';
    if (o.isOnline && !o.isGuest) {
      status = await ref.read(cloudSyncProvider).setUsername(v);
    } else {
      await ref.read(profileProvider).updateProfile(name: v);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    stationToast(
      context,
      switch (status) {
        'ok' => stx(context, 'ذخیره شد', 'Saved'),
        'taken' => stx(context, 'این نام کاربری قبلاً ثبت شده است.', 'This username is already taken.'),
        'bad_length' => stx(context, 'بین ۳ تا ۲۰ کاراکتر وارد کن.', 'Must be 3–20 characters.'),
        'bad_chars' => stx(context, 'فقط حروف انگلیسی، عدد، . و _ مجاز است.', 'Only English letters, digits, . and _ allowed.'),
        _ => stx(context, 'اتصال به سرور برقرار نشد.', 'Could not save to server.'),
      },
      error: status != 'ok',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ProfileService prof = ref.watch(profileProvider);
    final OnlineService o = ref.watch(onlineProvider);
    final StationPalette p = StationPalette.of(context);
    final bool fa = stationFa(context);
    final bool signedIn = o.user != null && !o.isGuest;
    final int played = prof.totalGamesPlayed;
    final int wins = prof.totalWins;
    final String id = 'NX-${prof.explorerId.replaceAll(RegExp(r'[^0-9A-Za-z]'), '').toUpperCase().padRight(6, '0').substring(0, 6)}';
    return StationScreen(
      title: stx(context, 'حساب من', 'My account'),
      children: <Widget>[
        StationCard(
          hero: true,
          child: Column(children: <Widget>[
            StationRingAvatar(name: prof.username, size: 84, imageUrl: prof.avatarUrl, portrait: prof.portrait),
            const SizedBox(height: 8),
            Text(prof.username.isEmpty ? stx(context, 'کاوشگر', 'Explorer') : prof.username, style: StationText.title(context, size: 20)),
            Text(fa ? 'سطح ${nxNum(context, prof.level)} · ${prof.rankTitleFa}' : 'Level ${prof.level} · ${prof.rankTitleEn}', style: StationText.mute(context)),
            StationBar(prof.levelProgress),
            const SizedBox(height: 4),
            Text('${nxNum(context, prof.xpIntoLevel)} XP', style: StationText.mute(context, size: 11)),
          ]),
        ),
        StationStats(<(String, String)>[
            (nxNum(context, played), stx(context, 'بازی', 'Games')),
            (nxNum(context, wins), stx(context, 'برد', 'Wins')),
            ('${nxNum(context, played == 0 ? 0 : (wins * 100 / played).round())}٪', stx(context, 'نرخ برد', 'Win rate')),
          ]),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'تغییر نام', 'Change name'), style: StationText.title(context, size: 15)),
            const SizedBox(height: 8),
            StationInput(controller: _name, hint: stx(context, 'نام کاربری', 'Username'), maxLength: 20),
            StationButton(label: stx(context, 'ذخیره', 'Save'), busy: _saving, onTap: _saveName),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'درباره من', 'About me'), style: StationText.title(context, size: 15)),
            const SizedBox(height: 8),
            StationInput(controller: _bio, hint: stx(context, 'چند کلمه درباره‌ی خودت…', 'A few words about you…'), maxLines: 3, maxLength: 140),
            StationButton(
              label: stx(context, 'ذخیره', 'Save'),
              ghost: true,
              onTap: () async {
                await ref.read(profileProvider).updateProfile(newBio: _bio.text.trim());
                if (context.mounted) stationToast(context, stx(context, 'ذخیره شد', 'Saved'));
              },
            ),
          ]),
        ),
        StationCard(
          child: StationRow(
            first: true,
            title: stx(context, 'شناسه', 'ID'),
            subtitle: id,
            trailing: StationButton(
              label: stx(context, 'کپی', 'Copy'),
              small: true,
              ghost: true,
              expand: false,
              onTap: () {
                Clipboard.setData(ClipboardData(text: id));
                stationToast(context, stx(context, 'کپی شد', 'Copied'));
              },
            ),
          ),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            StationRow(
              first: true,
              leading: Icon(signedIn ? Icons.verified_user_rounded : Icons.person_outline_rounded, color: signedIn ? const Color(0xFF3DDC97) : p.gold),
              title: signedIn ? stx(context, 'وارد شده‌ای', 'Signed in') : stx(context, 'حساب مهمان', 'Guest'),
              subtitle: signedIn
                  ? (o.isInternalAccount ? '@${o.accountUsername ?? prof.username}' : (o.email ?? ''))
                  : stx(context, 'برای همگام‌سازی پیشرفت وارد شو (گوگل یا نام کاربری).', 'Sign in (Google or username) to sync your progress.'),
            ),
            const SizedBox(height: 8),
            if (!signedIn)
              StationButton(label: stx(context, 'ورود / ثبت‌نام', 'Sign in / Sign up'), icon: Icons.login_rounded, onTap: () => context.go('/auth'))
            else ...<Widget>[
              StationButton(
                  label: stx(context, 'تغییر رمز عبور', 'Change password'),
                  ghost: true,
                  onTap: () async {
                    final String? pw = await showStationPrompt(context,
                        title: stx(context, 'رمز جدید', 'New password'), hint: '••••••', obscure: true, confirm: stx(context, 'ذخیره', 'Save'));
                    if (pw == null || pw.length < 6) {
                      if (pw != null && context.mounted) stationToast(context, stx(context, 'حداقل ۶ کاراکتر', 'At least 6 characters'), error: true);
                      return;
                    }
                    final bool ok = await ref.read(onlineProvider).changePassword(pw);
                    if (context.mounted) stationToast(context, ok ? stx(context, 'رمز تغییر کرد', 'Password changed') : stx(context, 'تغییر رمز انجام نشد', 'Could not change password'), error: !ok);
                  },
                ),
              StationButton(
                label: stx(context, 'خروج از حساب', 'Sign out'),
                danger: true,
                onTap: () async {
                  final bool sure = await showStationConfirm(context,
                      title: stx(context, 'خروج از حساب؟', 'Sign out?'), confirm: stx(context, 'خروج', 'Sign out'), danger: true);
                  if (!sure) return;
                  await ref.read(onlineProvider).signOut();
                  ref.read(settingsProvider).clearAuthMode();
                  if (context.mounted) context.go('/auth');
                },
              ),
            ],
          ]),
        ),
      ],
    );
  }
}

/// `SET` — app theme (neon / white), toggles, graphics quality, language, companion, admin, sign out.
class StationSettingsScreen extends ConsumerWidget {
  const StationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final OnlineService o = ref.watch(onlineProvider);
    final AdminAccess admin = ref.watch(adminAccessProvider);
    final CompanionInfo comp = CompanionInfo.of(ref.watch(companionProvider).active);
    final bool fa = stationFa(context);
    final bool signedIn = o.user != null && !o.isGuest;

    Widget toggle(String title, bool v, ValueChanged<bool> on, {String? sub, bool first = false}) => StationRow(
          first: first,
          title: title,
          subtitle: sub,
          trailing: StationToggle(value: v, onChanged: on),
          onTap: () => on(!v),
        );

    return StationScreen(
      title: stx(context, 'تنظیمات', 'Settings'),
      children: <Widget>[
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'تم برنامه', 'App theme'), style: StationText.title(context, size: 15)),
            StationSeg(
              labels: <String>[stx(context, 'نارنجی ـ سرمه‌ای', 'Orange · navy'), stx(context, 'سفید', 'White')],
              index: s.stationSkin == StationSkin.white ? 1 : 0,
              onChanged: (int i) => s.stationSkin = i == 1 ? StationSkin.white : StationSkin.neon,
            ),
          ]),
        ),
        StationRows(children: <Widget>[
          toggle(stx(context, 'افکت‌های صوتی', 'Sound effects'), s.sound, (bool v) => s.sound = v, first: true),
          toggle(stx(context, 'موسیقی پس‌زمینه', 'Background music'), s.music, (bool v) => s.music = v),
          toggle(stx(context, 'لرزش', 'Vibration'), s.haptics, (bool v) => s.haptics = v),
          toggle(stx(context, 'اعلان‌ها', 'Notifications'), s.notifications, (bool v) => s.notifications = v),
          toggle(stx(context, 'جلوه‌های گرافیکی', 'Visual effects'), !s.reducedMotion, (bool v) => s.reducedMotion = !v),
        ]),
        const SizedBox(height: 12),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'کیفیت گرافیک', 'Graphics quality'), style: StationText.title(context, size: 15)),
            StationSeg(
              labels: <String>[stx(context, 'کم', 'Low'), stx(context, 'متوسط', 'Medium'), stx(context, 'بالا', 'High')],
              index: switch (s.quality) { GraphicsQuality.low => 0, GraphicsQuality.medium => 1, _ => 2 },
              onChanged: (int i) => s.quality = <GraphicsQuality>[GraphicsQuality.low, GraphicsQuality.medium, GraphicsQuality.high][i],
            ),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'زبان', 'Language'), style: StationText.title(context, size: 15)),
            StationSeg(labels: const <String>['فارسی', 'English'], index: s.isFa ? 0 : 1, onChanged: (int i) => s.languageCode = i == 0 ? 'fa' : 'en'),
          ]),
        ),
        StationTitle(stx(context, 'همراه هوشمند', 'AI companion')),
        StationRows(children: <Widget>[
          StationRow(
            first: true,
            leading: const CompanionAvatar(size: 40),
            title: fa ? 'همراه فعال: ${comp.nameFa}' : 'Active companion: ${comp.nameEn}',
            subtitle: stx(context, 'اوراکل یا لونا — در صفحه‌ی هوش مصنوعی عوض کن', 'ORACLE or LUNA — switch on the AI page'),
            trailing: Icon(Icons.chevron_left_rounded, color: StationPalette.of(context).mute),
            onTap: () => context.push('/oracle'),
          ),
          toggle(fa ? '${comp.nameFa} گوشه‌ی صفحه' : '${comp.nameEn} in the corner', s.oracleBuddy, (bool v) => s.oracleBuddy = v,
              sub: stx(context, 'بکش تا جابه‌جا شود؛ دو بار بزن تا کوچک شود؛ نگه دار تا گفتگو باز شود', 'Drag to move; double-tap to minimise; hold to chat')),
          toggle(fa ? 'حرف زدن ${comp.nameFa}' : '${comp.nameEn} talks', s.oracleTalk, (bool v) => s.oracleTalk = v),
        ]),
        const SizedBox(height: 12),
        if (signedIn) ...<Widget>[
          StationRows(children: <Widget>[
            StationRow(
              key: const ValueKey<String>('settings-blocked'),
              first: true,
              leading: const Icon(Icons.block_rounded),
              title: stx(context, 'کاربران مسدودشده', 'Blocked users'),
              onTap: () => context.push('/settings/blocked'),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        StationRows(children: <Widget>[
          StationRow(first: true, title: stx(context, 'کنترلر', 'Controller'), leading: const StationIcon('r4c5', size: 36), onTap: () => context.push('/s/controller')),
          StationRow(title: stx(context, 'حساب من', 'My account'), leading: const StationIcon('r4c4', size: 36), onTap: () => context.push('/account')),
          StationRow(
            title: stx(context, 'درباره‌ی نکسورا', 'About NEXORA'),
            subtitle: AppUpdater.currentVc > 0 ? (fa ? 'بیلد ${nxNum(context, AppUpdater.currentVc, group: false)}' : 'Build ${AppUpdater.currentVc}') : stx(context, 'نسخه‌ی توسعه', 'Development build'),
            leading: const StationIcon('r5c3', size: 36),
          ),
          StationRow(
            key: const ValueKey<String>('settings-privacy'),
            leading: const Icon(Icons.privacy_tip_rounded),
            title: stx(context, 'سیاست حریم خصوصی', 'Privacy Policy'),
            onTap: () => context.push('/legal/privacy'),
          ),
          StationRow(
            key: const ValueKey<String>('settings-terms'),
            leading: const Icon(Icons.gavel_rounded),
            title: stx(context, 'شرایط استفاده', 'Terms of Use'),
            onTap: () => context.push('/legal/terms'),
          ),
        ]),
        if (signedIn) ...<Widget>[
          StationTitle(stx(context, 'مدیریت', 'Admin')),
          StationRows(children: <Widget>[
            StationRow(
              first: true,
              leading: const Icon(Icons.vpn_key_rounded),
              title: stx(context, 'ورود کد دعوت ادمین', 'Redeem admin invitation code'),
              subtitle: stx(context, 'کد را از مدیر اصلی بگیر', 'Use a code issued by the main admin'),
              onTap: () async {
                final String? code = await showStationPrompt(context, title: stx(context, 'کد دعوت ادمین', 'Admin invitation code'), hint: 'NX-XXXXXXXX');
                if (code == null || code.isEmpty || !context.mounted) return;
                final Map<String, dynamic> r = await AdminApi(ref.read(onlineProvider)).redeemAdminCode(code);
                if (!context.mounted) return;
                stationToast(context, r['ok'] == true ? stx(context, 'دسترسی ساخت تورنمنت فعال شد ✓', 'Tournament-admin access enabled ✓') : adminErrorText(r['error'] as String?, fa),
                    error: r['ok'] != true);
                if (r['ok'] == true) await ref.read(adminAccessProvider).refresh();
              },
            ),
            if (admin.isAdmin)
              StationRow(
                leading: const Icon(Icons.admin_panel_settings_rounded),
                title: admin.owner ? stx(context, 'پنل مدیر اصلی', 'Main admin panel') : stx(context, 'پنل مدیریت', 'Admin panel'),
                onTap: () => context.push('/admin'),
              ),
            if (admin.can(AdminPerm.oracle))
              StationRow(
                leading: const Icon(Icons.psychology_alt_rounded),
                title: stx(context, 'شخصیت اوراکل و لونا (مدیر)', 'ORACLE & LUNA personas (admin)'),
                onTap: () => context.push('/admin/oracle'),
              ),
          ]),
        ],
        const SizedBox(height: 14),
        StationButton(
          label: signedIn ? stx(context, 'خروج از حساب', 'Sign out') : stx(context, 'ورود / ثبت‌نام', 'Sign in / Sign up'),
          ghost: true,
          onTap: () async {
            if (!signedIn) {
              context.go('/auth');
              return;
            }
            final bool sure = await showStationConfirm(context, title: stx(context, 'خروج از حساب؟', 'Sign out?'), confirm: stx(context, 'خروج', 'Sign out'), danger: true);
            if (!sure) return;
            await ref.read(onlineProvider).signOut();
            ref.read(settingsProvider).clearAuthMode();
            if (context.mounted) context.go('/auth');
          },
        ),
        const DeleteAccountButton(),
      ],
    );
  }
}

/// `CTL` — knob hero, sensitivity slider, button layout (right / left handed), controller vibration.
class StationControllerScreen extends ConsumerWidget {
  const StationControllerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppSettings s = ref.watch(settingsProvider);
    final StationPalette p = StationPalette.of(context);
    Widget rb(String t) => Container(
          width: 52,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: p.ghost, border: Border.all(color: p.line), boxShadow: <BoxShadow>[BoxShadow(color: p.ghostShadow, offset: const Offset(0, 4))]),
          child: Text(t, style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w500)),
        );
    return StationScreen(
      title: stx(context, 'کنترلر', 'Controller'),
      children: <Widget>[
        StationCard(
          hero: true,
          child: Column(children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Image.asset('assets/station/neon2/knob.webp', width: 110, height: 110, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const StationIcon('r4c5', size: 110)),
            ),
            const SizedBox(height: 8),
            Text(stx(context, 'کنترلر', 'Controller'), style: StationText.title(context, size: 20)),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'حساسیت', 'Sensitivity'), style: StationText.title(context, size: 15)),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(activeTrackColor: p.gold, thumbColor: p.gold2, inactiveTrackColor: p.track),
              child: Slider(
                min: 10,
                max: 100,
                value: s.controllerSensitivity.toDouble(),
                onChanged: (double v) => s.controllerSensitivity = v.round(),
              ),
            ),
            Text('${nxNum(context, s.controllerSensitivity)}٪', style: StationText.mute(context)),
          ]),
        ),
        StationCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: <Widget>[
            Text(stx(context, 'چیدمان دکمه‌ها', 'Button layout'), style: StationText.title(context, size: 15)),
            StationSeg(
              labels: <String>[stx(context, 'راست‌دست', 'Right-handed'), stx(context, 'چپ‌دست', 'Left-handed')],
              index: s.leftHanded ? 1 : 0,
              onChanged: (int i) => s.leftHanded = i == 1,
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                textDirection: TextDirection.ltr,
                mainAxisAlignment: s.leftHanded ? MainAxisAlignment.start : MainAxisAlignment.end,
                children: <Widget>[rb('A'), const SizedBox(width: 10), rb('B')],
              ),
            ),
          ]),
        ),
        StationRows(children: <Widget>[
          StationRow(
            first: true,
            title: stx(context, 'لرزش کنترلر', 'Controller vibration'),
            trailing: StationToggle(value: s.haptics, onChanged: (bool v) => s.haptics = v),
            onTap: () => s.haptics = !s.haptics,
          ),
        ]),
      ],
    );
  }
}

/// The profile photo: ringed avatar with a camera badge. Tap → gallery / camera; the photo is resized to ≤512 px,
/// uploaded to `nx-media/<uid>/avatar.*` (CloudProfileSync.uploadAvatar) and saved on the profile, so every avatar
/// in the app shows it. Without a photo the painted portrait is shown.
class StationAvatarPicker extends ConsumerStatefulWidget {
  const StationAvatarPicker({super.key, required this.name, this.size = 96});
  final String name;
  final double size;

  @override
  ConsumerState<StationAvatarPicker> createState() => _StationAvatarPickerState();
}

class _StationAvatarPickerState extends ConsumerState<StationAvatarPicker> {
  bool _busy = false;

  Future<void> _choose() async {
    final OnlineService o = ref.read(onlineProvider);
    if (!o.isOnline || o.isGuest) {
      stationToast(context, stx(context, 'برای عکس پروفایل وارد حساب شو.', 'Sign in to set a profile photo.'));
      return;
    }
    ImageSource? src;
    await showStationSheet<void>(
      context,
      title: stx(context, 'عکس پروفایل', 'Profile photo'),
      options: <StationSheetOption>[
        StationSheetOption(label: stx(context, '🖼  انتخاب از گالری', '🖼  From gallery'), onTap: () => src = ImageSource.gallery),
        StationSheetOption(label: stx(context, '📷  گرفتن عکس با دوربین', '📷  Take a photo'), onTap: () => src = ImageSource.camera),
      ],
    );
    if (src == null || !mounted) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: src!, maxWidth: 512, maxHeight: 512, imageQuality: 85);
    } catch (_) {
      if (mounted) stationToast(context, stx(context, 'دسترسی به عکس ممکن نشد.', 'Could not open photos.'), error: true);
      return;
    }
    if (file == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final String n = file.name.toLowerCase();
      final String ext = n.contains('.') ? n.split('.').last : 'jpg';
      await ref.read(cloudSyncProvider).uploadAvatar(await file.readAsBytes(), extension: ext);
      if (mounted) stationToast(context, stx(context, 'عکس پروفایل ذخیره شد.', 'Profile photo saved.'));
    } catch (_) {
      if (mounted) stationToast(context, stx(context, 'آپلود عکس ناموفق بود.', 'Profile photo upload failed.'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ProfileService prof = ref.watch(profileProvider);
    final StationPalette p = StationPalette.of(context);
    return GestureDetector(
      onTap: _busy ? null : _choose,
      child: Stack(clipBehavior: Clip.none, children: <Widget>[
        StationRingAvatar(name: widget.name, size: widget.size, imageUrl: prof.avatarUrl, portrait: prof.portrait, level: prof.level),
        PositionedDirectional(
          bottom: 0,
          start: -2,
          child: Tooltip(
            message: stx(context, 'عکس پروفایل', 'Profile photo'),
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: p.primary,
                border: Border.all(color: p.bg, width: 2),
              ),
              child: _busy
                  ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: p.primaryInk))
                  : Icon(Icons.photo_camera_rounded, size: 18, color: p.primaryInk),
            ),
          ),
        ),
      ]),
    );
  }
}

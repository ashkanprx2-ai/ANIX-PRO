import 'dart:async';

import 'package:flutter/material.dart';

import '../core/audio/sfx_service.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/audio/music_service.dart';
import '../core/backend/backend_gateway.dart';
import '../core/companion/companion.dart';
import '../worlds/oracle_core/persona/oracle_persona.dart';
import '../core/online/call_watcher.dart';
import '../core/online/cloud_profile_sync.dart';
import '../core/online/invite_watcher.dart';
import '../core/online/match_resume.dart';
import '../core/online/online_service.dart';
import '../core/push/push_service.dart';
import '../core/settings/app_settings.dart';
import '../core/companion/companion_bus.dart';
import '../ui/theme/station_theme.dart';
import '../ui/widgets/companion_buddy.dart';
import '../core/update/app_gate.dart';
import '../core/update/app_updater.dart';
import '../core/update/update_banner.dart';
import '../features/admin/announcement_watcher.dart';
import '../features/tournaments/tournament_watcher.dart';
import 'router.dart';

class NexoraApp extends ConsumerStatefulWidget {
  const NexoraApp({super.key});

  @override
  ConsumerState<NexoraApp> createState() => _NexoraAppState();
}

class _NexoraAppState extends ConsumerState<NexoraApp> {
  late final GoRouter _router = buildRouter(ref);
  final GlobalKey<ScaffoldMessengerState> _messenger =
      GlobalKey<ScaffoldMessengerState>();
  late final InviteWatcher _invites = InviteWatcher(ref, _messenger,
      (String game, String code) => _router.push('/online/$game?code=$code'),
      onWatch: (String route) => _router.push(route));
  late final MatchResumeWatcher _resume =
      MatchResumeWatcher(ref, _messenger, (String route) => _router.push(route));
  late final TournamentWatcher _tournaments =
      TournamentWatcher(ref, _messenger, (String route) => _router.push(route));
  late final AnnouncementWatcher _announcements = AnnouncementWatcher(ref, _messenger);
  late final CallWatcher _calls = CallWatcher(ref, _messenger,
      (String chat, String call, bool video, String title) {
    _router.push(Uri(path: '/call/$chat', queryParameters: <String, String>{
      'call': call,
      'video': video ? '1' : '0',
      'title': title,
    }).toString());
  });

  @override
  void initState() {
    super.initState();
    // The active companion (ORACLE / LUNA) decides which persona every ORACLE-engine caller talks to.
    CompanionController.onSwitch.add((CompanionId c) => OraclePersona.activate(c.name));
    OraclePersona.activate(ref.read(companionProvider).active.name);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(onlineProvider).addListener(_syncAuthMode);
      _syncAuthMode();
      ref.read(cloudSyncProvider).start();
      ref.read(onlineProvider).addListener(_invites.sync);
      _invites.sync();
      ref.read(onlineProvider).addListener(_calls.sync);
      _calls.sync();
      ref.read(onlineProvider).addListener(_resume.sync);
      _resume.sync();
      _tournaments.start();
      ref.read(onlineProvider).addListener(_tournaments.sync);
      _tournaments.sync();
      ref.read(onlineProvider).addListener(_announcements.sync);
      _announcements.sync();
      AppUpdater.instance.start();
      AppGate.instance.start();
      PushService.instance.onOpen = (String route) => _router.push(route);
      unawaited(PushService.instance.start(locale: () => ref.read(settingsProvider).languageCode));
    });
  }


  /// A real session (email code, magic-link deep link, password/admin login from Account) always counts as the email
  /// mode, so onboarding/cloud sync treat the user as signed in even when they had picked guest mode before.
  void _syncAuthMode() {
    if (!mounted) return;
    final OnlineService o = ref.read(onlineProvider);
    final AppSettings s = ref.read(settingsProvider);
    if (o.user != null && !o.isGuest && s.authMode != 'email') s.setAuthMode('email');
  }

  @override
  void dispose() {
    AppGate.instance.stop();
    PushService.instance.stop();
    _invites.dispose();
    _resume.dispose();
    _announcements.dispose();
    _calls.dispose();
    _tournaments.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(backendProvider);
    final settings = ref.watch(settingsProvider);
    MusicService.instance
        .configure(enabled: false, volume: 0);
    NxSfx.instance.configure(enabled: settings.sound, volume: settings.sfxVolume);
    return MaterialApp.router(
      title: 'NEXORA',
      debugShowCheckedModeBanner: false,
      theme: buildStationTheme(settings.stationSkin),
      locale: settings.locale,
      supportedLocales: const [Locale('fa'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
      scaffoldMessengerKey: _messenger,
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(
            disableAnimations: settings.reducedMotion || mq.disableAnimations,
            textScaler:
                mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
          ),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: (_) => OracleBus.lastTouch = DateTime.now(),
            child: AppGateOverlay(
              child: UpdateOverlay(
                child: Stack(children: <Widget>[
                  child ?? const SizedBox.shrink(),
                  Positioned.fill(child: CompanionBuddy(router: _router)),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

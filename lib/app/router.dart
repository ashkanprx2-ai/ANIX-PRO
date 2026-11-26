import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/catalog/catalog.dart';
import '../core/online/online_service.dart';
import '../core/profile/profile_service.dart';
import '../core/settings/app_settings.dart';
import '../core/storage/local_store.dart';
import '../features/admin/admin_access.dart';
import '../features/admin/admin_page.dart';
import '../features/admin/force_password_page.dart';
import '../features/tournaments/ui/admin/tournament_manage_page.dart';
import '../features/tournaments/ui/admin/tournament_wizard_page.dart';
import '../features/tournaments/ui/tournament_detail_page.dart';
import '../features/tournaments/ui/tournament_inbox_page.dart';
import '../features/tournaments/ui/tournaments_page.dart';
import '../ui/screens/ai_screens.dart';
import '../ui/screens/auth_screens.dart';
import '../ui/screens/board_screen.dart';
import '../ui/screens/event_screens.dart';
import '../ui/screens/game_screens.dart';
import '../ui/screens/profile_screens.dart';
import '../ui/screens/rooms_screens.dart';
import '../ui/screens/shop_screens.dart';
import '../ui/screens/social_screens.dart';
import '../ui/shell/station_page.dart';
import '../worlds/arcade/online/online_lobby_page.dart';
import '../worlds/arcade/online/online_match_page.dart';
import '../worlds/auth/password_reset_pages.dart';
import '../worlds/legal/legal_page.dart';
import '../worlds/nova_gallery/nova_gallery_page.dart';
import '../worlds/oracle_core/persona/oracle_config_page.dart';
import '../worlds/orbit_network/orbit_network_page.dart';
import '../worlds/orbit_network/ui/orbit_call_page.dart';
import '../worlds/settings/blocked_users_page.dart';
import '../worlds/rooms/talk_room_page.dart';
import '../worlds/social_station/social_station_page.dart';
import 'auth_gate.dart';

GoRouter buildRouter(WidgetRef ref) {
  final settings = ref.read(settingsProvider);
  final online = ref.read(onlineProvider);
  final String next;
  NxAccess access() => nxAccess(
        authMode: settings.authMode,
        hasUser: online.user != null,
        anonymous: online.isGuest,
      );
  // Signed-in accounts already picked their username at sign-up; that is their identity, so the identity page is
  // only for guests (local profile) and never comes back once a name exists.
  bool identityReady() {
    final ProfileService p = ref.read(profileProvider);
    if (p.hasIdentity) return true;
    if (access() != NxAccess.signedIn) return false;
    return p.adoptAccountName(ref.read(onlineProvider).accountUsername);
  }

  final NxAccess start = access();
  if (start == NxAccess.needsAuth) {
    next = '/auth';
  } else if (!identityReady()) {
    next = '/onboarding';
  } else {
    next = '/hub';
  }
  // First launch (or a replay from Settings) opens the cinematic intro, then continues to [next]. Returning users who
  // already watched it go straight to their destination (§5.2 / §5.6: the full journey is never forced on every launch).
  final String initial = settings.introSeen
      ? next
      : Uri(path: '/intro', queryParameters: <String, String>{'next': next}).toString();

  return GoRouter(
    initialLocation: initial,
    // Deep link nexora://t/<code> (Android may deliver only the path "/<code>").
    refreshListenable: Listenable.merge(<Listenable>[settings, online, ref.read(adminAccessProvider)]),
    redirect: (BuildContext context, GoRouterState state) {
      final Uri u = state.uri;
      // Email magic-link callback (nexora://login-callback?code=…): supabase_flutter exchanges the code itself; the
      // router only has to leave the callback URL (it has no page) and land where the session decides.
      // Password-recovery link (nexora://login-callback/reset?code=…): supabase_flutter signs in with the code; the
      // user then must choose a new password before anything else.
      if ((u.host == 'login-callback' && u.path.startsWith('/reset')) || u.path.startsWith('/login-callback/reset')) {
        Future<void>.microtask(online.markRecovery);
        return '/reset-password';
      }
      if (online.recoveryPending && u.path != '/reset-password' && u.path != '/forgot-password') {
        return '/reset-password';
      }
      if (u.host == 'login-callback' || u.path == '/login-callback') {
        if (access() != NxAccess.signedIn) return '/auth';
        return identityReady() ? '/hub' : '/onboarding';
      }
      final String? gate = authRedirect(u, access(), hasIdentity: identityReady());
      if (gate != null) return gate;
      // The identity page is a one-time step: once a name exists (or the account brings one) it is never shown again.
      if (u.path == '/onboarding' && identityReady()) return '/hub';
      // Accounts that must change their password (the default main admin on first sign-in) go nowhere else first.
      if (ref.read(adminAccessProvider).mustChangePassword &&
          !<String>{'/force-password', '/intro', '/account'}.contains(u.path)) {
        return '/force-password';
      }
      if (u.scheme == 'nexora' && u.host == 't') {
        return '/tournaments/join?code=${u.pathSegments.isNotEmpty ? u.pathSegments.first : ''}';
      }
      final RegExpMatch? m = RegExp(r'^/([A-HJ-NP-Za-hj-np-z2-9]{8})$').firstMatch(u.path);
      if (m != null && u.path != '/settings' && u.path != '/intro') {
        return '/tournaments/join?code=${m.group(1)!.toUpperCase()}';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/auth', pageBuilder: (context, state) => _fade(state, const StationAuthPage())),
      GoRoute(path: kSignInRequiredPath, builder: (context, state) => StationSignInRequired(from: state.uri.queryParameters['from'] ?? '')),
      GoRoute(
        path: '/intro',
        pageBuilder: (context, state) => _fade(state, StationSplash(next: state.uri.queryParameters['next'] ?? '/hub')),
      ),
      GoRoute(path: '/onboarding', pageBuilder: (context, state) => _fade(state, const StationOnboarding())),
      GoRoute(path: '/hub', pageBuilder: (context, state) => _fade(state, const StationPage())),
      GoRoute(
        path: '/station/:k',
        pageBuilder: (context, state) => _fade(state, StationPage(initialWorld: int.tryParse(state.pathParameters['k'] ?? ''))),
      ),
      // ---- Station screens (`/s/...`)
      GoRoute(path: '/s/profile', builder: (context, state) => const StationProfileScreen()),
      GoRoute(path: '/s/controller', builder: (context, state) => const StationControllerScreen()),
      GoRoute(
          path: '/s/games',
          // The game grid is the Games hub; this route only keeps the «رکوردها» list.
          redirect: (context, state) => state.uri.queryParameters['records'] == '1' ? null : '/station/0',
          builder: (context, state) => const StationGamesScreen()),
      GoRoute(path: '/s/missions/daily', builder: (context, state) => const StationMissionsScreen(weekly: false)),
      GoRoute(path: '/s/missions/weekly', builder: (context, state) => const StationMissionsScreen(weekly: true)),
      GoRoute(path: '/s/news', builder: (context, state) => const StationNewsScreen()),
      GoRoute(path: '/s/calendar', builder: (context, state) => const StationCalendarScreen()),
      GoRoute(path: '/s/gift', builder: (context, state) => const StationGiftBoxScreen()),
      GoRoute(path: '/s/wheel', builder: (context, state) => const StationWheelScreen()),
      GoRoute(path: '/s/medals', builder: (context, state) => const StationCollectionScreen(trophies: false)),
      GoRoute(path: '/s/trophies', builder: (context, state) => const StationCollectionScreen(trophies: true)),
      GoRoute(path: '/s/event/:kind', builder: (context, state) => StationEventScreen(kind: state.pathParameters['kind'] ?? 'daily')),
      GoRoute(path: '/s/history', builder: (context, state) => const StationHistoryScreen()),
      GoRoute(path: '/s/forecast', builder: (context, state) => const StationForecastScreen()),
      GoRoute(path: '/s/analysis', builder: (context, state) => const StationForecastScreen(analysis: true)),
      GoRoute(path: '/s/tips', builder: (context, state) => const StationTipsScreen()),
      GoRoute(path: '/s/friends', builder: (context, state) => const StationFriendsScreen()),
      GoRoute(path: '/s/send-gift', builder: (context, state) => const StationSendGiftScreen()),
      GoRoute(path: '/s/viewers', builder: (context, state) => const StationViewersScreen()),
      GoRoute(path: '/s/listen', builder: (context, state) => const StationRoomsScreen(listenOnly: true)),
      GoRoute(path: '/s/shop', builder: (context, state) => const StationShopScreen()),
      GoRoute(path: '/s/gems', builder: (context, state) => const StationGemsScreen()),
      GoRoute(path: '/s/frames', builder: (context, state) => const StationShopScreen(only: ItemCategory.frame)),
      GoRoute(path: '/s/themes', builder: (context, state) => const StationThemesScreen()),
      GoRoute(path: '/chat/:id', builder: (context, state) => StationChatScreen(chatId: state.pathParameters['id'] ?? '')),
      GoRoute(path: '/rooms', builder: (context, state) => const StationRoomsScreen()),
      GoRoute(path: '/room/:id', builder: (context, state) => TalkRoomPage(roomId: state.pathParameters['id'] ?? '')),
      GoRoute(path: '/social', builder: (context, state) => const StationChatsScreen()),
      GoRoute(path: '/rewards', builder: (context, state) => const StationGiftBoxScreen()),
      GoRoute(path: '/settings', builder: (context, state) => const StationSettingsScreen()),
      GoRoute(path: '/account', builder: (context, state) => const StationAccountScreen()),
      GoRoute(path: '/admin/oracle', builder: (context, state) => const OracleConfigPage()),
      GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),
      GoRoute(path: '/force-password', builder: (context, state) => const ForcePasswordPage()),
      GoRoute(path: '/settings/blocked', builder: (context, state) => const BlockedUsersPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => ForgotPasswordPage(email: state.uri.queryParameters['email']),
      ),
      GoRoute(path: '/reset-password', builder: (context, state) => const ResetPasswordPage()),
      GoRoute(path: '/legal/privacy', builder: (context, state) => const LegalPage(kind: 'privacy')),
      GoRoute(path: '/legal/terms', builder: (context, state) => const LegalPage(kind: 'terms')),
      GoRoute(
        path: '/oracle',
        builder: (context, state) => _WorldVisit(id: 'oracle_core', child: StationAiScreen(initialQuery: state.uri.queryParameters['q'])),
      ),
      GoRoute(
        path: '/world/:id',
        // The arcade world is the Games hub.
        redirect: (context, state) => state.pathParameters['id'] == 'nexora_arcade' ? '/station/0' : null,
        builder: (context, state) {
          final String id = state.pathParameters['id'] ?? '';
          return _WorldVisit(id: id, child: _worldPage(id));
        },
      ),
      GoRoute(
        path: '/online/:gameId',
        builder: (context, state) => OnlineLobbyPage(
          gameId: state.pathParameters['gameId'] ?? '',
          joinCode: state.uri.queryParameters['code'],
          roomId: state.uri.queryParameters['room'],
          action: state.uri.queryParameters['action'],
        ),
      ),
      // Back into a live online match after the app was killed (MatchResumeWatcher, match_resume.dart), or watching
      // one (spectator, '?watch=1').
      GoRoute(
        path: '/match/:id',
        builder: (context, state) => OnlineMatchPage(
          matchId: state.pathParameters['id'] ?? '',
          gameId: state.uri.queryParameters['game'] ?? '',
          tournamentMatchId: state.uri.queryParameters['t'],
          // RS-01: '?watch=1' opens the match read-only (room member / invited to watch)
          spectate: state.uri.queryParameters['watch'] == '1',
        ),
      ),
      GoRoute(
        path: '/call/:chatId',
        builder: (context, state) => OrbitCallPage(
          chatId: state.pathParameters['chatId'] ?? '',
          callId: state.uri.queryParameters['call'],
          video: state.uri.queryParameters['video'] == '1',
          title: state.uri.queryParameters['title'] ?? 'NEXORA',
          startNew: false,
        ),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => StationBoardScreen(initialGame: state.uri.queryParameters['game']),
      ),
      GoRoute(
        path: '/tournaments',
        builder: (context, state) => TournamentsPage(game: state.uri.queryParameters['game']),
      ),
      GoRoute(path: '/tournaments/new', builder: (context, state) => const TournamentWizardPage()),
      GoRoute(path: '/tournaments/inbox', builder: (context, state) => const TournamentInboxPage()),
      GoRoute(
        path: '/tournaments/join',
        builder: (context, state) => TournamentsPage(joinCode: state.uri.queryParameters['code']),
      ),
      GoRoute(
        path: '/t/:code',
        builder: (context, state) => TournamentsPage(joinCode: state.pathParameters['code']),
      ),
      GoRoute(
        path: '/tournaments/:id',
        builder: (context, state) => TournamentDetailPage(
          id: state.pathParameters['id'] ?? '',
          focusMatch: state.uri.queryParameters['match'],
        ),
      ),
      GoRoute(
        path: '/tournaments/:id/manage',
        builder: (context, state) => TournamentManagePage(id: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: '/tournaments/:id/edit',
        builder: (context, state) => TournamentWizardPage(editId: state.pathParameters['id']),
      ),
      GoRoute(
        path: '/arcade/:gameId',
        builder: (context, state) => StationGameScreen(gameId: state.pathParameters['gameId'] ?? ''),
      ),
    ],
    errorBuilder: (context, state) => StationNotFound(location: state.uri.toString()),
  );
}

Widget _worldPage(String id) {
  switch (id) {
    case 'nova_gallery':
      return const NovaGalleryPage();
    case 'orbit_network':
      return const OrbitNetworkPage();
    case 'social_station':
      return const SocialStationPage();
    case 'oracle_core':
      return const StationAiScreen();
    case 'personal_orbit':
      return const StationProfileScreen();
    case 'nexora_exchange':
      return const StationShopScreen();
    default:
      return const StationPage();
  }
}

CustomTransitionPage<void> _fade(GoRouterState state, Widget child) => CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 450),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut), child: child),
    );

/// Records the first visit to each world (for the World Traveler achievement).
class _WorldVisit extends ConsumerStatefulWidget {
  const _WorldVisit({required this.id, required this.child});
  final String id;
  final Widget child;

  @override
  ConsumerState<_WorldVisit> createState() => _WorldVisitState();
}

class _WorldVisitState extends ConsumerState<_WorldVisit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final store = LocalStore.instance;
      final visited = (store.getJsonList('hub.visited') ?? const []).map((e) => '$e').toSet();
      if (visited.add(widget.id)) {
        store.setJson('hub.visited', visited.toList());
        final p = ref.read(profileProvider);
        p.bump('worlds.visited');
        p.award('world.first_visit.${widget.id}', xp: 20, coins: 10);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

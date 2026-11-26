# NEXORA — SCREEN INVENTORY (Station UI, 2026-11-26)

Every route of `lib/app/router.dart` and the screen that draws it. All screens use the NEXORA Station Luxe design
(`lib/ui/kit/station_kit.dart`); pages kept from the integration are drawn through the Station adapters
(`lib/ui/kit/station_compat.dart`). No old UI (`core/ui2`, `core/widgets`, `core/theme`, `worlds/hub`) remains.

## 1. Entry
| Route | Screen | Notes |
|---|---|---|
| `/intro` | `StationSplash` (`ui/screens/auth_screens.dart`) | brand splash → auth / hub |
| `/auth` | `StationAuthPage` | username or e-mail + password (usernames via `nx-login`), sign-up with terms, e-mail code, **Sign in with Google** (always visible; Supabase OAuth → `nexora://login-callback`; plain message when the server's Google provider is off), guest |
| `/onboarding` | `StationOnboarding` | language, username, avatar, companion intro (ORACLE & LUNA) |
| `/force-password`, `/forgot-password`, `/reset-password` | `worlds/auth/password_reset_pages.dart` | re-skinned |
| `/legal/privacy`, `/legal/terms` | `worlds/legal/` | texts mention ORACLE / LUNA |

## 2. Shell
| Route | Screen | Notes |
|---|---|---|
| `/hub` | `StationPage` (`ui/shell/station_page.dart`) | Station scene, profile HUD, balance, 8-world ring, dock, companion buddy (ORACLE/LUNA) |
| `/station/:k` | `StationWorldPage` (`ui/shell/station_worlds.dart`) | 8 worlds with tabs; the GAMES world is generated from `kGames` (sports / table / cards / arcade; any new game lands in arcade) |
| `/world/:id` | world pages (NOVA, ORBIT, social station, …) | re-skinned |

## 3. Games
| Route | Screen | Notes |
|---|---|---|
| `/s/games` | `StationGamesScreen` | all / most played / newest grid + records, from `kGames` (29 games incl. Piano Tiles, Gate Shooter, Water Sort) |
| `/arcade/:gameId` | `StationGameScreen` | hero, mode (bot / friends / online), difficulty, players, stats, daily challenge + medals, rules, tournaments, leaderboard; launches `GameHostPage` or the online lobby |
| `/online/:gameId`, `/match/:id` | `OnlineLobbyPage`, `OnlineMatchPage` | quick match, private code, invites, **rematch**, **spectator** (from talk rooms), report player, victory-effect burst on wins |
| `/leaderboard` | `StationBoardScreen` | per game / global |
| `/tournaments…`, `/t/:code` | `features/tournaments/` | list, create, inbox, join, detail, manage, edit |

## 4. Economy
| Route | Screen | Notes |
|---|---|---|
| `/s/shop`, `/s/frames` | `StationShopScreen` | coin catalogue by category, frames, carrom gear |
| `/s/gems` | `StationGemsScreen` | free daily gems, **Cafe Bazaar coin & gem packs** (`BazaarStore`, server-verified), **victory effects** sheet, wallet history link, finger-soccer teams for gems |
| (push) | `StationWalletHistoryScreen` | append-only ledger (`nx_wallet_history`) |
| `/s/themes` | `StationThemesScreen` | neon / white skin + my-space themes |
| `/s/wheel` | `StationWheelScreen` | server-enforced daily wheel (`nx_spin_wheel`, credited through `nx_wallet_apply`) |
| `/rewards`, `/s/gift`, `/s/medals`, `/s/trophies`, `/s/history` | event screens | daily reward, gift box, collections, history |

## 5. Events & AI
| Route | Screen | Notes |
|---|---|---|
| `/s/missions/daily`, `/s/missions/weekly`, `/s/news`, `/s/calendar`, `/s/event/:kind` | `ui/screens/event_screens.dart` | |
| `/oracle`, `/s/analysis` | `StationAiScreen` | companion selector ORACLE ↔ LUNA, chat (`nx-oracle`, persona sent), offline brain answers in the active companion's voice |
| `/s/forecast`, `/s/tips` | `StationForecastScreen`, `StationTipsScreen` | |
| `/admin/oracle` | `OracleConfigPage` | persona editor for ORACLE and LUNA (admin) |

## 6. Social & rooms
| Route | Screen | Notes |
|---|---|---|
| `/social`, `/chat/:id` | `StationChatsScreen`, `StationChatScreen` | chats, report / block |
| `/s/friends`, `/s/send-gift`, `/s/viewers` | social screens | profile preview with report / block |
| `/rooms`, `/room/:id`, `/s/listen` | `StationRoomsScreen`, `TalkRoomPage` | voice rooms, pick game, spectate live match |
| `/call/:chatId` | call page | |

## 7. Me & settings
| Route | Screen | Notes |
|---|---|---|
| `/s/profile`, `/account` | `StationProfileScreen`, `StationAccountScreen` | |
| `/settings`, `/s/controller` | `StationSettingsScreen`, `StationControllerScreen` | sound, haptics, quality, language, companion, blocked users, delete account |
| `/settings/blocked` | `BlockedUsersPage` | |
| `/admin` | `AdminPage` | permissions-gated, ORACLE & LUNA tab |

## 8. Overlays
Update overlay (`core/update/update_banner.dart`, reads `Ashkani25/NEW-ANIX-` releases), ban guard (banned accounts are
signed out / blocked from rewards and purchases server-side), invite watcher, companion buddy, Station toasts / modals / sheets.

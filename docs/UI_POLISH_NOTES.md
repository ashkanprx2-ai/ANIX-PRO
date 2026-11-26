# ui-polish-crash progress (subagent notes)
Repo: /workspace/work/ANIX-PRO, branch arena/ui-polish-crash (from origin/arena/new-ui-luna d8ba2d4). Not pushed yet.
Flutter: /workspace/work/flutter_sdk (3.50.0, arm64 dart re-downloaded; works). `export PATH=/workspace/work/flutter_sdk/bin:$PATH`. Run long cmds with nohup setsid ... & and poll.
Baseline analyze: 7 infos, 0 errors.

## Findings
- Staggered cards cause: StationPress wraps child in Stack (loose constraints) -> tiles shrink. Fix: StackFit.passthrough.
- Chip garble: _WorldView chip ListView height 52 w/ padding clips descenders (ر و ی). Fix layout.
- Hub = lib/ui/shell/station_page.dart (_WorldView, _ItemTile, _MorePanel, _Drawer, _NavBar); data = station_worlds.dart.
- Icons: lib/ui/screens/game_icons.dart stationGameIcon(); palette neon overrides in lib/ui/theme/station_palette.dart _neonIcons (flat ugly) -> remove.
- Avatar upload exists: CloudProfileSync.uploadAvatar (bucket nx-media, RLS own folder exists in 20261115000200_nx_social.sql). Old UI in efb2614 identity_tab _ProfileAvatarPicker.
- Game result: launch.onFinish(GameResult) -> host awards coins/xp.

## Assets made (scratch/out)
- out/icons/*.webp (stack_tower knife_hit helix_jump pool8 bomb_arena obstacle_race crash_racing) + scratch/icons_cut/*.webp (user sheet: piano_tiles bubble_shooter gate_shooter tetris_rush game_2048 dice_chips bowling water_sort)
- out/crash/*: kart_<6>, char_<6> (fox raccoon numbat glider wombat quokka), itembox fruit mask item_(rocket bowlbomb[BAD bg, redo] crate nitro shield) prop_(palm statue torch pillar hut jtree bush ramp) bg_(jungle temple beach) title
- Tools: scratch/key.py (chroma key), clean_icons.py

## TODO
1 icons wiring  2 grid/card + dedupe  3 profile upload  4 crash game  5 tests fix  6 finger soccer pucks (new req)
7 supabase live migrations (Mgmt API curl)  8 google sign-in  9 CI dart-defines  10 push, build, release

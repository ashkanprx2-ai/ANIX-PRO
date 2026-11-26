/// The unified game icon (512 px, `assets/games/icons/<id>.webp`) of a registered game id.
/// Every game ships its own icon; backgammon uses the dice art, and an unknown id gets the hub controller.
String stationGameIcon(String id) {
  if (id == 'backgammon') return 'assets/games/icons/dice_chips.webp';
  if (_kGameIcons.contains(id)) return 'assets/games/icons/$id.webp';
  return 'assets/station/hub/controller.webp';
}

/// Games with a file in assets/games/icons/ (keep in sync with the folder).
const Set<String> _kGameIcons = <String>{
  'basketball_battle', 'billiards', 'bomb_arena', 'bubble_shooter', 'carrom', 'crash_racing', 'dice_chips',
  'endless_runner', 'finger_soccer', 'fruit_ninja', 'game_2048', 'gate_shooter', 'geo_dash', 'helix_jump',
  'kart_racing', 'knife_hit', 'ludo', 'mafia', 'mini_golf', 'obstacle_race', 'piano_tiles', 'pool8', 'quiz',
  'snakes_ladders', 'spy_mafia', 'stack_tower', 'tetris_rush', 'traffic_racer', 'uno', 'water_sort',
};

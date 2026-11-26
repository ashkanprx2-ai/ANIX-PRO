/// Game art from UI.zip (`assets/station/icons/g_*.webp` covers and the r*c* icon atlas) per registered game id.
String stationGameIcon(String id) => switch (id) {
      'finger_soccer' => 'g_football',
      'basketball_battle' => 'g_basketball',
      'mini_golf' => 'golf',
      'kart_racing' => 'g_kart',
      'traffic_racer' => 'g_traffic',
      'billiards' => 'g_8ball',
      'pool8' => 'r1c1',
      'backgammon' => 'g_backgammon',
      'ludo' => 'g_ludo',
      'snakes_ladders' => 'g_snakes',
      'carrom' => 'g_carrom',
      'uno' => 'g_uno',
      'mafia' => 'g_mafia',
      'spy_mafia' => 'g_guesswho',
      'quiz' => 'quiz',
      'endless_runner' => 'g_runner',
      'obstacle_race' => 'g_runner',
      'geo_dash' => 'g_geodash',
      'fruit_ninja' => 'g_fruit',
      'bomb_arena' => 'r4c6',
      'knife_hit' => 'r5c2',
      'helix_jump' => 'r5c1',
      'bubble_shooter' => 'g_puzzle',
      'stack_tower' => 'g_puzzle',
      'tetris_rush' => 'g_puzzle',
      'game_2048' => 'g_puzzle',
      // Newest games (arena integration): their own pedestal art in the Station object style.
      'piano_tiles' => 'assets/arcade/pedestals/piano_tiles.webp',
      'gate_shooter' => 'assets/arcade/pedestals/gate_shooter.webp',
      'water_sort' => 'assets/arcade/pedestals/water_sort.webp',
      _ => _kPedestals.contains(id) ? 'assets/arcade/pedestals/$id.webp' : 'r4c5',
    };

/// Games that ship a pedestal image in assets/arcade/pedestals/ (fallback art for any game added later).
const Set<String> _kPedestals = <String>{
  'backgammon', 'basketball_battle', 'billiards', 'bomb_arena', 'carrom', 'finger_soccer', 'gate_shooter', 'kart_racing',
  'ludo', 'mafia', 'mini_golf', 'obstacle_race', 'piano_tiles', 'pool8', 'quiz', 'snakes_ladders', 'spy_mafia',
  'traffic_racer', 'uno', 'water_sort',
};

/// Maps sprite group indices to human-readable semantic names.
///
/// The original game references sprites by hex group index within a sprite
/// sheet pointer table (e.g. `0x7F` is the bullet). This module provides a
/// mapping from those internal indices to descriptive names so that the
/// generated atlas JSON — and all downstream game code — can use
/// human-friendly identifiers instead of leaking implementation details.
///
/// ## Naming convention
///
/// **Directional sprites** (8 consecutive groups, one per compass direction):
/// ```
/// {role}_{action}_{direction}
/// ```
/// Where:
/// - **role**: `player` or `enemy`
/// - **action**: `walk`, `throw`, `prone`, `swim`, `death`, `death2`,
///   `still`, `firing`
/// - **direction**: `s`, `sw`, `w`, `nw`, `n`, `ne`, `e`, `se`
///
/// **Non-directional sprites** use a bare descriptive name (e.g. `bullet`,
/// `salute`).
///
/// Groups without a mapping retain the legacy hex-based name (`7f`, `a3`, …).
library;

/// The 8 compass direction suffixes in sprite-group order.
///
/// Index 0 corresponds to the base group offset (+0), which is south /
/// "face forward" in the original data.
const _directions = ['s', 'sw', 'w', 'nw', 'n', 'ne', 'e', 'se'];

/// Expands a directional sprite block into 8 name entries.
///
/// Given a [baseGroup] and a name prefix like `player_walk`, returns entries
/// mapping `baseGroup + 0` → `player_walk_s`, …, `baseGroup + 7` →
/// `player_walk_se`.
Map<int, String> _directional(int baseGroup, String prefix) => {
  for (var i = 0; i < 8; i++) baseGroup + i: '${prefix}_${_directions[i]}',
};

/// Semantic names for groups in the `InGame` sprite sheet type
/// (`mSpriteSheetTypes_InGame_PC`).
///
/// This table covers the army and copt sprite data; the same group indices
/// appear in both atlas files (army sprites live in `junarmy.dat`, copt
/// sprites in `juncopt.dat`, etc.).
final Map<int, String> fontGroupNames = {0: 'font_main'};

final Map<int, String> pstuffGroupNames = {
  0: 'font_briefing_dark_green',
  1: 'font_briefing_light_green',
  2: 'font_briefing_blue',
  3: 'font_briefing_light_blue',
};

final Map<int, String> serviceGroupNames = {
  0: 'ui_bg_panel_tile_dark',
  1: 'ui_bg_panel_tile_light',
  2: 'rank_icon',
  3: 'font_gameplay_caps',
  4: 'font_gameplay_full',
  5: 'ui_bg_panel_strip_dark',
  6: 'ui_bg_panel_strip_light',
  7: 'ui_soldier_large_portrait_left',
  8: 'ui_soldier_large_portrait_right',
  9: 'ui_text_lost_heroes_right',
};

final Map<int, String> inGameGroupNames = {
  ..._directional(0x00, 'player_walk'),
  ..._directional(0x08, 'player_throw'),
  ..._directional(0x10, 'player_prone'),
  ..._directional(0x18, 'player_swim'),
  ..._directional(0x20, 'player_death'),
  ..._directional(0x28, 'player_death2'),

  0x30: 'player_firing_s',
  0x31: 'player_firing_w',
  0x32: 'player_firing_e',
  0x33: 'explosion',
  0x34: 'bones',
  0x35: 'shadow',
  0x36: 'enemy_rocket',
  0x37: 'grenade_box',
  0x38: 'rocket_box',
  0x39: 'soldier_fired_rocket',

  0x3a: 'soldier_rocket_walk_nw',
  0x3b: 'soldier_rocket_walk_n',
  0x3c: 'soldier_rocket_walk_ne',
  0x3d: 'soldier_rocket_walk_e',
  0x3e: 'soldier_rocket_walk_se',
  0x3f: 'soldier_rocket_walk_s',
  0x40: 'soldier_rocket_walk_sw',
  0x41: 'shrub',

  ..._directional(0x42, 'enemy_walk'),
  ..._directional(0x4A, 'enemy_throw'),
  ..._directional(0x52, 'enemy_prone'),
  ..._directional(0x5A, 'enemy_swim'),
  ..._directional(0x62, 'enemy_death'),
  ..._directional(0x6A, 'enemy_death2'),
  ..._directional(0x72, 'enemy_still'),

  0x7A: 'salute',
  0x7B: 'effect_shrapnel_white_0',
  0x7C: 'effect_shrapnel_white_1',
  0x7D: 'effect_shrapnel_white_2',
  0x7E: 'effect_shrapnel_white_3',
  0x7F: 'bullet',

  0x80: 'helicopter_s',
  0x81: 'helicopter_ssw',
  0x82: 'helicopter_sw',
  0x83: 'helicopter_wsw',
  0x84: 'helicopter_w',
  0x85: 'helicopter_wnw',
  0x86: 'helicopter_nw',
  0x87: 'helicopter_nnw',
  0x88: 'helicopter_n',
  0x89: 'helicopter_nne',
  0x8a: 'helicopter_ne',
  0x8b: 'helicopter_ene',
  0x8c: 'helicopter_rotor',
  0x8d: 'helicopter_debris',
  0x8e: 'pilot',

  0x8F: 'env_shrub',
  0x90: 'env_tree',
  0x91: 'env_building_roof',
  0x92: 'env_snowman',
  0x93: 'env_shrub2',
  0x94: 'env_tree_large_alt',
  0x95: 'rank',
  0x96: 'effect_sparks_0',
  0x97: 'effect_sparks_1',
  0x98: 'effect_sparks_2',
  0x99: 'effect_sparks_3',
  0x9a: 'fence_wood',
  0x9b: 'env_building_window',
  0x9c: 'wall_stone',
  0x9d: 'bones_and_shadows',
  0x9e: 'env_building_piece',
  0x9f: 'soldier_rocket_aim',

  0xa0: 'text_phase_complete',
  0xa1: 'text_mission_complete',
  0xa2: 'text_mission_failed',
  0xa3: 'player_parachute_rotation',
  0xa4: 'player_death_face_first',
  0xa5: 'jeep_body',
  0xa6: 'player_death_backwards',
  0xa7: 'player_death_lying_down',
  ..._directional(0xa8, 'player_walk_grenade'),

  ..._directional(0xb0, 'player_firing_alt'),
  ..._directional(0xb8, 'enemy_firing'),

  0xc0: 'building_large',
  0xc1: 'text_game_over',
  0xc2: 'ui_pixel_block_0',
  0xc3: 'ui_pixel_block_1',
  0xc4: 'doorway',
  0xc5: 'box_wood',
  0xc6: 'effect_structure_debris',
  0xc7: 'ui_pixel_block_2',
  0xc8: 'ui_pixel_block_3',
  0xc9: 'death_gibbing_alt',
  0xca: 'ui_pixel_block_4',
  0xcb: 'ui_pixel_block_5',
  0xcc: 'effect_dust',
  0xcd: 'effect_fire_loop',
  0xce: 'effect_smoke_column',
  0xcf: 'effect_explosion_large',
  0xd0: 'effect_explosion_large_alt',

  ..._directional(0xd1, 'tank_body'),
  0xd2: 'tank_turret',
  0xd3: 'bird_fly_right',
  0xd4: 'bird_fly_left',

  0xd8: 'death_burning',
  0xd9: 'death_burning_ash',
  0xda: 'death_ash_pile',
  0xdb: 'death_gibbing',
  0xdc: 'death_gibbing_pre',
  0xdd: 'text_try_again',
  0xde: 'effect_smoke_puff_alt',
  0xdf: 'effect_explosion_dirt',

  0xe0: 'env_building_piece_alt',
  0xe1: 'effect_water_ripple',
  0xe2: 'effect_water_splash',
  0xe3: 'gib_debris',
  0xe4: 'gib_arm',
  0xe5: 'gib_torso',
  0xe6: 'gib_leg',
  0xe7: 'effect_blood_pool',
};

final Map<int, String> hillGroupNames = {
  0x00: 'recruit_face_anim_0',
  0x01: 'recruit_face_anim_1',
  0x02: 'recruit_face_anim_2',
  0x03: 'recruit_face_anim_3',
  0x04: 'recruit_face_anim_4',
  0x05: 'recruit_face_anim_5',
  0x06: 'recruit_face_anim_6',
  0x07: 'recruit_face_anim_7',
  0x08: 'recruit_face_anim_8',
  0x09: 'ui_recruit_tiny_soldier',
  0x0a: 'recruit_face_still_0',
  0x0b: 'recruit_face_still_1',
  0x0c: 'recruit_face_still_2',
  0x0d: 'recruit_face_still_3',
  0x0e: 'recruit_face_still_4',
  0x0f: 'recruit_face_still_5',
  0x10: 'recruit_face_still_6',
  0x11: 'recruit_face_still_7',
  0x12: 'recruit_face_still_8',
  0x13: 'recruit_face_still_9',
  0x14: 'recruit_face_still_10',
  0x15: 'recruit_face_still_11',
  0x16: 'recruit_face_still_12',
  0x17: 'recruit_face_still_13',
  0x18: 'recruit_face_still_14',
  0x19: 'recruit_face_still_15',
  0x1a: 'recruit_face_still_16',
  0x1b: 'recruit_face_still_17',
  0x1c: 'recruit_face_still_18',
  0x1d: 'recruit_face_still_19',
  0x1e: 'recruit_face_still_20',
  0x1f: 'recruit_face_still_21',
  0x20: 'recruit_face_still_22',
  0x21: 'recruit_face_still_23',
  0x22: 'ui_save_load_icons_large',
};

String? spriteGroupName({
  required String sheetTypeName,
  required int groupIndex,
}) {
  final normalised = sheetTypeName
      .toLowerCase()
      .replaceAll('_cf2', '')
      .replaceAll('_cf1', '')
      .replaceAll('briefing', 'pstuff');

  final table = _sheetNameTables[normalised];
  return table?[groupIndex];
}

final Map<String, Map<int, String>> _sheetNameTables = {
  'ingame': inGameGroupNames,
  'service': serviceGroupNames,
  'pstuff': pstuffGroupNames,
  'font': fontGroupNames,
  'hill': hillGroupNames,
  'recruit': hillGroupNames,
};

const _fontChars = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
  '0',
  '1',
  '2',
  '3',
  '4',
  '5',
  '6',
  '7',
  '8',
  '9',
  "'",
  '.',
  ',',
  '!',
  '(',
  ')',
  '-',
  '?',
  '/',
  ':',
  ';',
  '"',
  '+',
  '=',
  '*',
  '&',
  '%',
  r'$',
  '#',
  '@',
  ' ',
  'a',
  'b',
  'c',
  'd',
  'e',
  'f',
  'g',
  'h',
  'i',
  'j',
  'k',
  'l',
  'm',
  'n',
  'o',
  'p',
  'q',
  'r',
  's',
  't',
  'u',
  'v',
  'w',
  'x',
  'y',
  'z',
];

String fontCharacterName(int frameIndex) {
  if (frameIndex < 0 || frameIndex >= _fontChars.length)
    return 'char_${frameIndex}';
  final char = _fontChars[frameIndex];
  return switch (char) {
    ' ' => 'space',
    '/' => 'slash',
    _ => char,
  };
}

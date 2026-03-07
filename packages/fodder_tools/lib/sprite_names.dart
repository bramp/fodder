/// Maps sprite group indices to human-readable semantic names.
///
/// The original game references sprites by hex group index within a sprite
/// sheet pointer table (e.g. `0x7F` is the bullet). This module provides a
/// mapping from those internal indices to descriptive names so that the
/// generated atlas JSON — and all downstream game code — can use
/// human-friendly identifiers instead of leaking implementation details.
///
/// ## Organisation
///
/// Name tables are organised by the **.dat file** that holds the pixel data.
/// Variable names follow the pattern `{datFile}Dat{NiceName}`, e.g.
/// `pstuffDatBriefing` is the briefing-font name table whose frames live in
/// `pstuff.dat`.
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
/// **Font groups** are prefixed `font_` internally so the export tool can
/// detect them and use character-name suffixes (`A`, `space`, …) instead of
/// numeric indices. The `font_` prefix is stripped from the generated frame
/// name, so `font_dark_green` becomes `briefing/dark_green_A`.
///
/// Groups without a mapping retain the legacy hex-based name (`7f`, `a3`, …).
///
/// ## .dat file → nice-name prefix routing
///
/// | .dat file(s)              | Nice name   | Variable              | GfxType              |
/// |---------------------------|-------------|-----------------------|----------------------|
/// | font.dat                  | `font`      | `fontDatFont`         | `font`               |
/// | pstuff.dat                | `briefing`  | `pstuffDatBriefing`   | `briefing`           |
/// | hillbits.dat              | `hill`      | `hillbitsDatHill`     | `hill`               |
/// | hillbits.dat              | `recruit`   | `hillbitsDatRecruit`  | `recruit`            |
/// | \*army.dat               | `ingame`    | `armyDatIngame`       | `inGame`             |
/// | \*copt.dat               | `ingame`    | `coptDatIngame`       | `inGame2`            |
/// | rankfont.dat              | `service`   | `rankfontDatService`  | `rankFont`           |
/// | morphbig.dat              | `service`   | `morphbigDatService`  | `service`            |
///
/// **Example**: `rankfontDatService[3]` is `font_gameplay_caps`. Its frames
/// have `GfxType.rankFont`, so atlas entries like
/// `service/gameplay_caps_A` appear in **rankfont.json** (alongside
/// rankfont.png), not morphbig.json.
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

/// Creates a font group entry.
///
/// Font groups use character names (A, B, …, z) as frame suffixes instead of
/// numeric indices. The [prefix] is automatically prepended with `font_`.
Map<int, String> _font(int group, String prefix) => {group: 'font_$prefix'};

/// Returns `true` if [groupName] represents a font group whose frames should
/// use character-name suffixes.
bool _isFontGroup(String groupName) => groupName.startsWith('font_');

// -----------------------------------------------------------------------
// font.dat — main game font
// -----------------------------------------------------------------------

/// Name table for groups stored in **font.dat** (`GfxType.font`).
final Map<int, String> fontDatFont = {..._font(0, 'main')};

// -----------------------------------------------------------------------
// pstuff.dat — briefing screen fonts
// -----------------------------------------------------------------------

/// Name table for groups stored in **pstuff.dat** (`GfxType.briefing`).
final Map<int, String> pstuffDatBriefing = {
  ..._font(0, 'dark_green'),
  ..._font(1, 'light_green'),
  ..._font(2, 'blue'),
  ..._font(3, 'light_blue'),
};

// -----------------------------------------------------------------------
// rankfont.dat — rank screen fonts & UI
// -----------------------------------------------------------------------

/// Name table for groups stored in **rankfont.dat** (`GfxType.rankFont`).
final Map<int, String> rankfontDatService = {
  0: 'ui_bg_panel_tile_dark',
  1: 'ui_bg_panel_tile_light',
  2: 'rank_icon',
  ..._font(3, 'gameplay_caps'),
  ..._font(4, 'gameplay_full'),
  5: 'ui_bg_panel_strip_dark',
  6: 'ui_bg_panel_strip_light',
  9: 'ui_text_lost_heroes_right',
};

// -----------------------------------------------------------------------
// morphbig.dat — large service screen portraits
// -----------------------------------------------------------------------

/// Name table for groups stored in **morphbig.dat** (`GfxType.service`).
final Map<int, String> morphbigDatService = {
  7: 'ui_soldier_large_portrait_left',
  8: 'ui_soldier_large_portrait_right',
};

// -----------------------------------------------------------------------
// *army.dat — in-game soldier/animation sprites (GfxType.inGame)
// -----------------------------------------------------------------------

/// Name table for groups stored in **\*army.dat** (`GfxType.inGame`).
///
/// These are per-terrain sprite sheets (junarmy.dat, desarmy.dat, etc.)
/// containing all soldier animations, effects, and ground-level visuals.
final Map<int, String> armyDatIngame = {
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

  ..._directional(0xa8, 'player_walk_grenade'),

  ..._directional(0xb0, 'player_firing_alt'),
  ..._directional(0xb8, 'enemy_firing'),

  0xa4: 'player_death_face_first',
  0xa6: 'player_death_backwards',
  0xa7: 'player_death_lying_down',

  0xcc: 'effect_dust',
  0xcd: 'effect_fire_loop',
  0xce: 'effect_smoke_column',
  0xcf: 'effect_explosion_large',
  0xd0: 'effect_explosion_large_alt',

  0xd3: 'bird_fly_right',
  0xd4: 'bird_fly_left',
  0xd5: 'effect_blood_shrapnel',
  0xd6: 'civilian_death',
  0xd7: 'civilian_spear',

  0xd8: 'death_burning',
  0xd9: 'death_burning_ash',
  0xda: 'death_ash_pile',
  0xdb: 'death_gibbing',
  0xdc: 'death_gibbing_pre',
  0xdf: 'effect_explosion_dirt',

  0xe1: 'effect_water_ripple',
  0xe2: 'effect_water_splash',
  0xe3: 'gib_debris',
  0xe4: 'gib_arm',
  0xe5: 'gib_torso',
  0xe6: 'gib_leg',
  0xe7: 'effect_blood_pool',
  0xe8: 'ufo_callpad',
};

// -----------------------------------------------------------------------
// *copt.dat — in-game vehicle/environment sprites (GfxType.inGame2)
// -----------------------------------------------------------------------

/// Name table for groups stored in **\*copt.dat** (`GfxType.inGame2`).
///
/// These are per-terrain sprite sheets (juncopt.dat, descopt.dat, etc.)
/// containing helicopters, environment objects, vehicles, text overlays,
/// and UI elements.
final Map<int, String> coptDatIngame = {
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
  0xa5: 'jeep_body',

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

  0xd1: 'tank_body',
  0xd2: 'tank_turret',

  0xdd: 'text_try_again',
  0xde: 'effect_smoke_puff_alt',

  0xe0: 'env_building_piece_alt',
};

// -----------------------------------------------------------------------
// hillbits.dat — hill terrain pieces
// -----------------------------------------------------------------------

/// Name table for hill terrain groups in **hillbits.dat** (`GfxType.hill`).
final Map<int, String> hillbitsDatHill = {
  0x00: 'hill_base_0',
  0x01: 'hill_base_1',
  0x02: 'hill_base_2',
  0x03: 'hill_base_3',
  0x04: 'hill_base_4',
  0x05: 'hill_base_5',
  0x06: 'hill_base_6',
  0x07: 'hill_base_7',
  0x08: 'hill_base_8',
  0x09: 'hill_piece',
  0x0a: 'hill_variant_0',
  0x0b: 'hill_variant_1',
  0x0c: 'hill_variant_2',
  0x0d: 'hill_variant_3',
  0x0e: 'hill_variant_4',
  0x0f: 'hill_variant_5',
  0x10: 'hill_variant_6',
  0x11: 'hill_variant_7',
  0x12: 'hill_variant_8',
  0x13: 'hill_variant_9',
  0x14: 'hill_variant_10',
  0x15: 'hill_variant_11',
  0x16: 'hill_variant_12',
  0x17: 'hill_variant_13',
  0x18: 'hill_variant_14',
  0x19: 'hill_variant_15',
  0x1a: 'hill_variant_16',
  0x1b: 'hill_variant_17',
  0x1c: 'hill_variant_18',
  0x1d: 'hill_variant_19',
  0x1e: 'hill_variant_20',
  0x1f: 'hill_variant_21',
  0x20: 'hill_variant_22',
  0x21: 'hill_variant_23',
  0x22: 'truck',
};

// -----------------------------------------------------------------------
// hillbits.dat — recruit screen sprites
// -----------------------------------------------------------------------

/// Name table for recruit screen groups in **hillbits.dat** (`GfxType.recruit`).
final Map<int, String> hillbitsDatRecruit = {
  0x00: 'grave',
  0x01: 'face_front_color1',
  0x02: 'face_front_left_color1',
  0x03: 'face_left_color1',
  0x04: 'face_front_color2',
  0x05: 'face_front_left_color2',
  0x06: 'face_left_color2',
  0x07: 'face_front_color3',
  0x08: 'face_front_left_color3',
  0x09: 'face_left_color3',
  0x0a: 'face_front_color4',
  0x0b: 'face_front_left_color4',
  0x0c: 'face_left_color4',
  ..._font(0x0d, 'recruit_alpha'),
  0x0e: 'ui_colon',
  0x0f: 'ui_cursor',
  0x10: 'ui_blank',
  0x11: 'ui_extended_chars',
  0x12: 'ui_caret',
  0x13: 'ui_underscore',
  0x14: 'hill_overlay',
  0x15: 'truck',
  0x16: 'ui_disk_icon',
  0x17: 'ui_disk_part',
  0x18: 'ui_disk_load',
  0x19: 'ui_disk_save',
};

/// Normalises a sheet type name to a canonical lookup key.
String _normaliseSheetName(String sheetTypeName) =>
    sheetTypeName.toLowerCase().replaceAll('_cf2', '').replaceAll('_cf1', '');

String? spriteGroupName({
  required String sheetTypeName,
  required int groupIndex,
}) {
  final table = _sheetNameTables[_normaliseSheetName(sheetTypeName)];
  return table?[groupIndex];
}

/// Returns the fully-qualified sprite name for a single frame.
///
/// The result has the form `{niceName}/{groupLabel}_{frameSuffix}` where
/// *niceName* is the canonical sheet name (e.g. `briefing`, `ingame`),
/// *groupLabel* is the human-readable group name (with the internal `font_`
/// prefix stripped), and *frameSuffix* is a character name for font groups
/// (e.g. `A`, `space`) or a numeric index for everything else.
String spriteFrameName({
  required String sheetTypeName,
  required int groupIndex,
  required int frameIndex,
}) {
  final groupLabel =
      spriteGroupName(sheetTypeName: sheetTypeName, groupIndex: groupIndex) ??
      'unknown_${groupIndex.toRadixString(16).padLeft(2, '0')}';

  final isFont = _isFontGroup(groupLabel);
  final frameSuffix = isFont
      ? fontCharacterName(frameIndex)
      : frameIndex.toString();

  // Strip the internal `font_` marker from the output name.
  final displayLabel = isFont ? groupLabel.substring(5) : groupLabel;

  return '${_normaliseSheetName(sheetTypeName)}/${displayLabel}_$frameSuffix';
}

final Map<String, Map<int, String>> _sheetNameTables = {
  'ingame': {...armyDatIngame, ...coptDatIngame},
  'service': {...rankfontDatService, ...morphbigDatService},
  'briefing': pstuffDatBriefing,
  'font': fontDatFont,
  'hill': hillbitsDatHill,
  'recruit': hillbitsDatRecruit,
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

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
final Map<int, String> inGameGroupNames = {
  // --- Player soldier ---
  ..._directional(0x00, 'player_walk'),
  ..._directional(0x08, 'player_throw'),
  ..._directional(0x10, 'player_prone'),
  ..._directional(0x18, 'player_swim'),
  ..._directional(0x20, 'player_death'),
  ..._directional(0x28, 'player_death2'),

  // Misc player
  0x30: 'start_face_s',
  0x31: 'start_face_w',
  0x32: 'start_face_e',
  0x33: 'explosion',
  0x34: 'bones',
  0x35: 'shadow',
  0x36: 'enemy_rocket',
  0x37: 'grenade_box',
  0x38: 'rocket_box',
  0x39: 'soldier_fired_rocket',

  0x41: 'shrub',

  // --- Enemy soldier ---
  ..._directional(0x42, 'enemy_walk'),
  ..._directional(0x4A, 'enemy_throw'),
  ..._directional(0x52, 'enemy_prone'),
  ..._directional(0x5A, 'enemy_swim'),
  ..._directional(0x62, 'enemy_death'),
  ..._directional(0x6A, 'enemy_death2'),
  ..._directional(0x72, 'enemy_still'),

  0x7A: 'salute',

  // --- Shared / non-directional ---
  0x7F: 'bullet',

  // --- Environment decorations (copt atlas, single-frame overlays) ---
  // These correspond to eSprite_Shrub..eSprite_Shrub2 in the engine.
  // The entity type (13–17) maps to these animation groups via field_8.
  0x8F: 'env_shrub',
  0x90: 'env_tree',
  0x91: 'env_building_roof',
  0x92: 'env_snowman',
  0x93: 'env_shrub2',

  // --- Player firing (standing-with-gun) ---
  ..._directional(0xB0, 'player_firing'),

  // --- Enemy firing (standing-with-gun) ---
  ..._directional(0xB8, 'enemy_firing'),
};

/// Returns the semantic name for a group in the given [sheetTypeName],
/// or `null` if no mapping exists (in which case the caller should fall
/// back to the hex representation).
///
/// [sheetTypeName] is the sprite sheet type name produced by
/// [SpriteDataParser] (e.g. `InGame`, `InGame_CF2`, `Recruit`, `Font`).
/// [groupIndex] is the zero-based index within that sheet type's group list.
String? spriteGroupName({
  required String sheetTypeName,
  required int groupIndex,
}) {
  // Both InGame and InGame_CF2 share the same naming table.
  // Normalise to lowercase and strip the _CF2 suffix.
  final normalised = sheetTypeName.toLowerCase().replaceAll('_cf2', '');

  final table = _sheetNameTables[normalised];
  return table?[groupIndex];
}

/// Master lookup from normalised sheet-type name → group-name table.
final Map<String, Map<int, String>> _sheetNameTables = {
  'ingame': inGameGroupNames,
};

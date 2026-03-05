/// Centralized sprite frame name constants for all atlas lookups.
///
/// All sprite frames in the generated atlas JSONs follow the naming
/// convention `ingame/{groupName}_{frameIndex}`. This file defines the
/// group name constants used throughout the game, organised by atlas and
/// sprite category.
///
/// ## Atlas files
///
/// | Atlas            | Contents                                   |
/// |------------------|--------------------------------------------|
/// | `junarmy.json`   | Soldier walk/throw/swim/death/firing anims  |
/// | `juncopt.json`   | Bullets, environment decorations, misc      |
///
/// These names originate from `inGameGroupNames` in
/// `packages/fodder_tools/lib/sprite_names.dart` and are baked into the
/// generated atlas JSON by the sprite export tool.
library;

// ---------------------------------------------------------------------------
// Soldier animation group names (junarmy atlas)
// ---------------------------------------------------------------------------

/// Death variant 2 — enemy soldiers.
const death2GroupEnemy = 'enemy_death2';

/// Death variant 2 — player soldiers.
const death2GroupPlayer = 'player_death2';

/// Death variant 1 — enemy soldiers.
const deathGroupEnemy = 'enemy_death';

/// Death variant 1 — player soldiers.
const deathGroupPlayer = 'player_death';

/// Standing-with-gun (firing pose) — enemy soldiers.
const firingGroupEnemy = 'enemy_firing';

/// Standing-with-gun (firing pose) — player soldiers.
const firingGroupPlayer = 'player_firing';

/// Prone (lying down) — enemy soldiers.
const proneGroupEnemy = 'enemy_prone';

/// Prone (lying down) — player soldiers.
const proneGroupPlayer = 'player_prone';

/// Swimming — enemy soldiers.
const swimGroupEnemy = 'enemy_swim';

/// Swimming — player soldiers.
const swimGroupPlayer = 'player_swim';

/// Grenade throw — enemy soldiers.
const throwGroupEnemy = 'enemy_throw';

/// Grenade throw — player soldiers.
const throwGroupPlayer = 'player_throw';

/// Walk cycle — enemy soldiers.
const walkGroupEnemy = 'enemy_walk';

/// Walk cycle — player soldiers.
const walkGroupPlayer = 'player_walk';

// ---------------------------------------------------------------------------
// Bullet group names (juncopt atlas)
// ---------------------------------------------------------------------------

/// Bullet sprite group (8 directional frames).
const bulletGroup = 'bullet';

/// Frame index for player bullet appearance (during flight).
const bulletFramePlayer = 0;

/// Frame index for enemy bullet appearance (during flight).
const bulletFrameEnemy = 3;

// ---------------------------------------------------------------------------
// Environment decoration frame keys (juncopt atlas)
// ---------------------------------------------------------------------------

/// Converts a TMX environment object name to its copt atlas frame key.
///
/// The naming convention is `ingame/env_{snake_case_name}_0`, where
/// camelCase TMX names are converted to snake_case.
///
/// Examples:
/// - `shrub`        → `ingame/env_shrub_0`
/// - `tree`         → `ingame/env_tree_0`
/// - `buildingRoof` → `ingame/env_building_roof_0`
String environmentFrameKey(String name) {
  final snakeName = name.replaceAllMapped(
    RegExp('[A-Z]'),
    (m) => '_${m[0]!.toLowerCase()}',
  );
  return 'ingame/env_${snakeName}_0';
}

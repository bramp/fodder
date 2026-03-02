# Plan: Character Movement & Pathfinding

Add a single player soldier that renders using the existing `junarmy.json` sprite
atlas, animates walking in 8 directions, pathfinds via `a_star_algorithm` on a
walkability grid derived from per-tile terrain properties in the `.tsx` tilesets,
responds to tap-to-move input, and has a toggleable debug overlay showing barriers
in transparent purple.

---

## Phase 0 — Terrain Data in Tilesets (fodder_tools)

### Step 1: Parse `.hit` / `.bht` files

Create a new library file `packages/fodder_tools/lib/hit_reader.dart` that reads
the original game's `.hit` files (480 nibbles — one per tile — mapping tile index
→ `eTerrainFeature` enum value) and `.bht` files (sub-tile 8×8 bitmasks for tiles
spanning two terrain types). Expose a function that returns a `List<int>` of 480
terrain type integers for a given terrain set.

Terrain type values from OpenFodder's `eTerrainFeature`:

| Value | Name        | Walkable? |
|-------|-------------|-----------|
| 0     | Land        | Yes       |
| 1     | Rocky       | Yes       |
| 2     | Boulders    | Yes       |
| 3     | Block       | **No**    |
| 4     | Wood/Tree   | Yes       |
| 5     | Mud/Swamp   | Yes       |
| 6     | Water       | Yes*      |
| 7     | Snow        | Yes       |
| 8     | Quick Sand  | Yes       |
| 9     | Wall        | Yes       |
| 10    | Fence       | Yes       |
| 11    | Drop        | Yes       |
| 12    | Drop2       | Yes       |

\* Only terrain type 3 (`Block`) is not walkable per `mTiles_NotWalkable[]`.

Source files are in `original_game/Dos_CD_Extracted/` with names like `junbase.hit`,
`junsub0.hit`, `desbase.hit`, etc.

### Step 2: Embed terrain type as TSX tile property

Extend `generateTsx()` in `packages/fodder_tools/lib/tiled_writer.dart` to accept
an optional `List<int>? terrainTypes` parameter (length = 480). When provided, emit
a `<tile>` element for each tile with a custom property:

```xml
<tile id="0">
  <properties>
    <property name="terrain" type="int" value="0"/>
  </properties>
</tile>
<tile id="3">
  <properties>
    <property name="terrain" type="int" value="3"/>
  </properties>
</tile>
```

Only emit `<tile>` elements for tiles whose terrain type is non-zero (to keep the
file small), or emit all 480 for consistency — either approach works.

### Step 3: Update `maps.dart` CLI

In `packages/fodder_tools/bin/maps.dart`, after loading `.blk` files for each
terrain, also load the corresponding `{terrain}base.hit` and `{terrain}sub0.hit`
files using the new `hit_reader.dart`. Pass the resulting terrain type array to
`generateTsx()` so the `.tsx` files include per-tile terrain metadata.

### Step 4: Regenerate assets

Run `dart run packages/fodder_tools/bin/maps.dart` to produce updated `.tsx` files
with terrain properties. Commit the updated assets in `packages/fodder_assets/`.

---

## Phase 1 — Walkability Grid (fodder_game)

### Step 5: `lib/game/systems/walkability_grid.dart`

A class `WalkabilityGrid` that, given a loaded `TiledComponent`, reads each tile's
`terrain` custom property from the tileset and builds a 2D `List<List<bool>>` grid.
Tiles with terrain type 3 (`Block`) are `false` (impassable); all others are `true`.

Public API:
- `WalkabilityGrid.fromTiled(TiledComponent tiled)`
- `bool isWalkable(int tileX, int tileY)`
- `int get width` / `int get height`

### Step 6: Integrate into `LevelMap`

After `TiledComponent` loads in `lib/game/map/level_map.dart`, construct a
`WalkabilityGrid` from it. Expose as a public getter so other components
(pathfinder, debug overlay) can access it.

---

## Phase 2 — Pathfinding (fodder_game)

### Step 7: `lib/game/systems/pathfinder.dart`

Wraps the `a_star_algorithm` package (already in `pubspec.yaml`). Takes a
`WalkabilityGrid`, a start tile `(x, y)`, and end tile `(x, y)`. Returns a
`List<Vector2>` of waypoints in **pixel coordinates** (tile center at 2× scale).

The `a_star_algorithm` package uses `Barrier` objects for impassable cells.
Convert all non-walkable grid cells to barriers and call `AStar` path computation.

---

## Phase 3 — Player Soldier Display & Animation

### Step 8: `lib/game/components/soldier_animations.dart`

Helper that loads the `junarmy.json` TexturePacker JSON Hash atlas from the
`fodder_assets` package and builds animation maps for each state and direction.

**Direction8 enum** (new, in its own file or shared):

| Index | Enum value  | Compass | Atlas group offset |
|-------|-------------|---------|-------------------|
| 0     | `south`     | ↓       | `+0`              |
| 1     | `southwest` | ↙       | `+1`              |
| 2     | `west`      | ←       | `+2`              |
| 3     | `northwest` | ↖       | `+3`              |
| 4     | `north`     | ↑       | `+4`              |
| 5     | `northeast` | ↗       | `+5`              |
| 6     | `east`      | →       | `+6`              |
| 7     | `southeast` | ↘       | `+7`              |

**Atlas group → animation mapping:**

| State | Base group | Frames/dir | Atlas names                    |
|-------|-----------|------------|--------------------------------|
| Walk  | `0x00`    | 3          | `ingame/00_*` – `ingame/07_*`  |
| Idle  | `0x00`    | 1 (frame 0)| `ingame/00_0` – `ingame/07_0` |
| Throw | `0x08`    | 3          | `ingame/08_*` – `ingame/0f_*`  |
| Prone | `0x10`    | 1          | `ingame/10` – `ingame/17`      |
| Death | `0x20`    | 2          | `ingame/20_*` – `ingame/27_*`  |

For the initial implementation, only **Walk** and **Idle** are needed.

Step time for walk animation: ~150 ms per frame (tunable).

Original sprites are **16×14 px**; render at **2× → 32×28 px** to match the 2×
tile scale (original 16 px tiles → 32 px `_destTileSize`).

Use the atlas `anchor` field (`modX`, `modY`) for correct sprite registration
point.

### Step 9: Refactor `PlayerSoldier`

Update `lib/game/components/player_soldier.dart`:

- Change `SoldierState` to: `idle`, `walking` (shooting/dying deferred).
- Add `Direction8 _facing = Direction8.south`.
- On `onLoad()`: call `SoldierAnimations.load(images)` to populate animation maps.
  Set initial animation to `(idle, south)`.
- Store `List<Vector2> _path` (waypoints from pathfinder). Each `update(dt)`:
  - Move position toward the next waypoint at `speed` px/sec.
  - Compute `Direction8` from the movement vector.
  - When current animation doesn't match the new `(state, direction)`, swap it.
  - When a waypoint is reached, pop it. When path is empty → switch to idle,
    retain last direction.
- Expose `void followPath(List<Vector2> waypoints)` for the game to call.

---

## Phase 4 — Input Handling

### Step 10: Tap handling in `FodderGame`

Override `onTapUp` in `lib/game/fodder_game.dart` (already mixes in
`TapCallbacks`):

1. Convert the tap's screen position to world position.
2. Convert world position to tile coordinates: `tileX = worldX ~/ 32`,
   `tileY = worldY ~/ 32`.
3. If the target tile is walkable (check `WalkabilityGrid`), run pathfinding
   from the soldier's current tile to the target tile.
4. Pass the resulting waypoint list to `playerSoldier.followPath(waypoints)`.
5. If the target is not walkable, either ignore or find the nearest walkable tile.

### Step 11: Spawn the soldier

In `FodderGame.onLoad()`, after loading `LevelMap`:

1. Create a `PlayerSoldier` and add it to `world`.
2. Place it at a known walkable tile (e.g. map center, or first walkable tile
   found via grid scan).
3. Camera stays fixed at top-left (no camera tracking — separate feature).

---

## Phase 5 — Debug Overlay

### Step 12: `lib/game/components/debug_barrier_overlay.dart`

A `Component` that reads `WalkabilityGrid` and, in its `render()` method, draws a
semi-transparent purple rectangle (`Color(0x88800080)`) over every non-walkable
tile cell.

Optionally also render the currently computed A* path as a chain of small dots or
line segments.

### Step 13: Toggle mechanism

Add a `bool debugMode` flag to `FodderGame`. Toggle it via:
- A keyboard key (`D`), or
- A button in the existing dropdown overlay.

When toggled on, add `DebugBarrierOverlay` to `world`. When toggled off, remove it.

---

## Phase 6 — Tests

### Step 14: `test/systems/walkability_grid_test.dart`

Unit test `WalkabilityGrid` with a mock/synthetic tile data array. Verify:
- `isWalkable()` returns `false` for terrain type 3 and `true` for all others.
- Out-of-bounds coordinates return `false`.
- Grid dimensions match the map.

### Step 15: `test/systems/pathfinder_test.dart`

Unit test pathfinding on a small synthetic grid:
- Path avoids barriers.
- Returns empty list for unreachable targets.
- Start == end returns empty path.
- Diagonal movement works.

### Step 16: `test/components/player_soldier_test.dart`

- Direction computation from movement vector is correct for all 8 directions.
- State transitions: idle → walking → idle when path completes.

### Step 17: `test/components/debug_barrier_overlay_test.dart`

- Instantiation test — doesn't crash with an empty grid.

---

## Verification

1. Run `dart run packages/fodder_tools/bin/maps.dart` — regenerate `.tsx` files;
   inspect one in a text editor or Tiled to confirm `<tile>` elements have
   `terrain` properties.
2. Run `flutter test` in `apps/fodder_game/` — all new and existing tests pass.
3. Run `flutter run` — tap on the map; soldier walks along the A* path, animating
   in the correct direction. Tap on a blocked tile → soldier doesn't move (or
   moves to nearest reachable tile).
4. Toggle debug mode — purple overlay appears over walls/blocked tiles.
5. Run `flutter analyze` — no warnings.

---

## Decisions

- **Terrain data approach**: Embed terrain types as per-tile custom properties in
  `.tsx` tileset files (via `<tile><properties>` elements), readable through
  `flame_tiled`'s property API. No separate collision layer or sidecar JSON.
- **Pathfinding library**: `a_star_algorithm ^0.4.1` (already a dependency).
- **Sprite scale**: 2× to match tile rendering (16 px → 32 px).
- **Scope**: Single player soldier. Squad formation deferred.
- **Terrain-specific sprites**: Initially load only `junarmy.json`; per-terrain
  sprite selection deferred to map-switching enhancement.
- **Direction enum**: Dedicated `Direction8` enum — state and facing are orthogonal
  concerns.

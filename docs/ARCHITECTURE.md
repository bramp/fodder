# Technical Architecture & Implementation

## Workspace Structure

```
fodder/                          ← Melos monorepo root
├── apps/fodder_game/            ← Flutter + Flame game (the remake)
│   ├── lib/game/
│   │   ├── components/          ← Flame components (soldier, bullet, …)
│   │   ├── map/                 ← Level loading, spawn data
│   │   ├── sprites/             ← Shared SpriteAtlas loader & frame constants
│   │   ├── systems/             ← Pathfinding, walkability grid
│   │   └── fodder_game.dart     ← Main FlameGame subclass
│   └── test/
├── packages/
│   ├── fodder_assets/           ← Git submodule – generated assets (PNGs, JSONs, TMX)
│   └── fodder_tools/            ← Dart CLI tools for asset conversion
│       ├── bin/                  ← CLI entry-points (sprites, maps, extract, …)
│       └── lib/                  ← Parsers, writers, sprite naming
├── vendor/openfodder/           ← Reference C++ source (read-only)
├── original_game/               ← Original game data files (read-only)
├── docs/                        ← Specifications and design documents
└── PLAN.md                      ← Active step-by-step implementation plan
```

---

## Design Principles

### No Original-Format Leakage

The **remake game** (`apps/fodder_game`) must **never** depend on internal
details of the original Cannon Fodder file formats (`.hit`, `.blk`, `.bht`,
`.map`, `.swp`, etc.). All original-format knowledge lives exclusively in the
**tools** (`packages/fodder_tools`), which convert legacy data into standard,
editor-friendly formats (Tiled `.tmx` / `.tsx`, TexturePacker JSON, PNG, etc.).

The game reads only these standard formats at runtime. This means:

- Maps can be fully edited in a modern tool like **Tiled** without needing
  the original game files or any custom tooling.
- New maps can be created from scratch in Tiled and loaded directly.
- The game code never performs bit-twiddling on raw `.hit` int16 values,
  BHIT bitmask lookups, or any other original-format decoding.
- Sprite frames are referenced by **semantic names** (e.g. `player_walk_s`,
  `bullet`), never by hex group indices from the original engine.

### Semantic Sprite Naming

The original engine identifies sprite groups by hex indices (e.g. `0x00`–`0x07`
for player walk, `0x7F` for bullet). Our pipeline translates these into
human-readable names so the game code is self-documenting and decoupled from
original internals.

**Naming convention** (defined in `fodder_tools/lib/sprite_names.dart`):

| Pattern | Example frame key | Description |
| ------- | ----------------- | ----------- |
| `{role}_{action}_{direction}_{frame}` | `ingame/player_walk_s_0` | 8-directional soldier animation |
| `{name}_{frame}` | `ingame/bullet_3` | Non-directional sprite |

Directions use compass suffixes from `Direction8.suffix`: `s`, `sw`, `w`, `nw`,
`n`, `ne`, `e`, `se`.

When a group index has no mapping, the fallback `{hex}_{frame}` is used.

### Asset Pre-Conversion Pipeline

Original game data is never parsed at runtime. Standalone Dart CLI tools in
`packages/fodder_tools/bin/` run offline to produce game-ready assets:

| Tool | Input | Output |
| ---- | ----- | ------ |
| `sprites.dart` | Raw sprite data + palettes | TexturePacker JSON atlases + PNGs with semantic frame names |
| `maps.dart` | `.map`, `.spt`, `.hit` files | Tiled `.tmx` maps with walkability layers |
| `extract.dart` | `.dat` archive files | Extracted raw files |
| `export_sprite_data.dart` | OpenFodder C++ headers | JSON sprite metadata |

Output is committed to `packages/fodder_assets/` (a git submodule) and loaded
at runtime via Flame's standard asset system.

---

## Component Architecture (Flame FCS)

### Core Game

- **`FodderGame`** (`FlameGame` + `HasCollisionDetection` + `TapCallbacks`)
  - Owns camera, map, soldiers, bullet sprites
  - Left-click/tap → pathfind and move player
  - Right-click → fire bullet (Step 5 — in progress)

### Map & Systems

- **`LevelMap`** — loads Tiled `.tmx` map, provides terrain data
- **`SpawnData`** — reads enemy/player spawn positions from `.spt` object layers
- **`WalkabilityGrid`** — sub-tile (4 px) grid marking walkable/blocked cells
- **`Pathfinder`** — A* pathfinding on the walkability grid

### Soldier Hierarchy

```
Soldier (abstract, SpriteAnimationGroupComponent + CollisionCallbacks)
├── PlayerSoldier — user-controlled, follows waypoint path
└── EnemySoldier  — AI-controlled (idle stub; AI state machine planned)
```

**`SoldierState`** enum: `idle`, `walking`, `firing`, `throwing`, `dying`

**`SoldierAnimations`** builds directional animations from a shared
`SpriteAtlas` via `SoldierAnimations.fromAtlas(atlas)`. Group name
constants are centralised in `sprite_frames.dart`:

| Constant | Value | Used for |
| -------- | ----- | -------- |
| `walkGroupPlayer` | `player_walk` | Player walk cycle (8 dirs × 4 frames) |
| `walkGroupEnemy` | `enemy_walk` | Enemy walk cycle |
| `firingGroupPlayer` | `player_firing` | Player standing-with-gun (8 dirs × 1 frame) |
| `firingGroupEnemy` | `enemy_firing` | Enemy standing-with-gun |
| `throwGroupPlayer` | `player_throw` | Player throwing (8 dirs × 3 frames) |
| `throwGroupEnemy` | `enemy_throw` | Enemy throwing |
| `deathGroupPlayer` | `player_death` | Player death (8 dirs × 1–2 frames) |
| `deathGroupEnemy` | `enemy_death` | Enemy death |

**`Direction8`** enum with `.suffix` getter (`s`, `sw`, …, `se`) for atlas
frame lookups. Full frame key: `ingame/{group}_{suffix}_{frameIndex}`.

### Combat Components

- **`Bullet`** (`PositionComponent` + `CollisionCallbacks`)
  - `Faction` enum: `player`, `enemy`
  - `velocity`, `maxRange` (400 px), `maxLifetime` (5 s)
  - Renders bullet sprite (from copt atlas) or yellow rect fallback
  - `CircleHitbox` for collision detection
  - Auto-removes when range/lifetime exceeded or off-screen

- **`BulletSprites`** — built via `BulletSprites.fromAtlas(coptAtlas)` from a
  shared `SpriteAtlas`. Uses group name `bullet` (frame 0 = player,
  frame 3 = enemy). Constants in `sprite_frames.dart`.

### Shared Atlas Loading (`sprites/`)

- **`SpriteAtlas`** — loads a TexturePacker JSON Hash atlas once and provides
  typed sprite lookups by group name / frame index. Shared across consumers
  (`BulletSprites`, `EnvironmentSprite`, `SoldierAnimations`) to avoid
  redundant image + JSON loading.
- **`sprite_frames.dart`** — centralised constants for all sprite group names
  and frame indices. Contains `environmentFrameKey()` for deriving copt atlas
  keys from TMX object names.

### Collision System

- `FodderGame` has `HasCollisionDetection` mixin for broad-phase
- `Soldier` has `RectangleHitbox` (enemy: 16×16, player: 6×5 — asymmetric per
  original spec)
- `Bullet` has `CircleHitbox`
- `Soldier.onCollisionStart` checks bullet faction vs `opposingFaction` getter;
  mismatches (friendly fire) are ignored
- One-hit kills: `die()` sets `isAlive = false`, plays death animation, starts
  removal timer

---

## Implementation Status

See [PLAN.md](../PLAN.md) for the detailed step-by-step combat implementation
plan with checkboxes.

**Completed:**
- Core game setup (FlameGame, camera, input)
- Map loading with Tiled (LevelMap, WalkabilityGrid)
- A* pathfinding for player movement
- Player soldier with 8-directional walk animation
- Enemy soldiers spawned from .spt data (idle stubs)
- Combat animation loading (firing, death, throw groups)
- Soldier health/death system (isAlive, die(), removal timer)
- Bullet component with faction, range, sprite rendering
- Hitbox system with asymmetric collision boxes
- Semantic sprite naming pipeline (fodder_tools → atlas JSONs)
- BulletSprites loader from copt atlas

**In Progress:**
- Player firing via right-click (Step 5)

**Planned:**
- Enemy AI state machine (idle → chasing → firing)
- Aggression system (ping-pong assignment)
- Line-of-sight checks (Bresenham on walkability grid)
- Staggered enemy fire timers
- Death animation variants with fade-out
- Full game orchestration and win conditions

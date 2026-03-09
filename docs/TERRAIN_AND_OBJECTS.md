# Terrain, NPCs & Map Objects

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> Covers terrain types and effects, civilians/hostages/leaders, interactive map
> objects, and mission objectives.
>
> See also: [ENGINE.md](ENGINE.md) for coordinate system,
> [ENEMY_AI.md](ENEMY_AI.md) for enemy spawning from buildings.

---

## 1. Terrain Types

Terrain is sampled at each sprite's position (offset Y=−3, X=+8) and stored in
`field_60`.

| Value | Name | Effect |
| ----- | ---- | ------ |
| 0 | `Land` | Normal walkable |
| 1 | `Rocky` | Elevates soldier height (toggle 0→1→2) |
| 2 | `Rocky2` | Elevates higher (up to height 6) |
| 3 | `Block` | **Impassable** |
| 4 | `QuickSand` | Sets `field_50 = 3` (movement penalty) |
| 5 | `WaterEdge` | Sets `field_50 = 6` (heavier movement penalty) |
| 6 | `Water` | Sets `field_4F = -1` (in water); **natives immune** |
| 7 | `Snow` | Reduces unit speed |
| 8 | `QuickSandEdge` | 1/64 chance per tick of slide animation |
| 9 | `Drop` | Increments fall counter `field_56` |
| 10 | `Drop2` | Triggers `eSprite_Anim_Hit3` (stumble) |
| 11 | `Sink` | Sets `field_5B = 1` (human sinking) |
| 14 | `Jump` | (Unused / minimal effect) |

### 1.1 Water mechanics

- `field_4F = -1` flags the sprite as in water.
- **All units in water** have speed forced to **6** (regardless of normal speed).
- **Natives** (`eSprite_PersonType_Native`) treat water as walkable — they are
  immune to drowning.
- Soldiers sink gradually (`field_52` increases). At `field_52 ≥ 5`, they get
  the dodge roll vs bullets (same as moving).

### 1.2 Terrain effects on vehicles

- **Tanks** cannot traverse Water or QuickSand tiles.
- **Helicopters** have minimum altitude requirements over certain terrain (see
  [VEHICLES.md §2.2](VEHICLES.md)).
- **Vehicles** entering water trigger sinking animations and sounds.

### 1.3 Drop / cliff mechanics

Drop tiles (types 9 and 10) model cliff edges and steep slopes. Behaviour
differs by entity type:

#### Player soldiers

| Terrain | Per-frame effect | Death condition |
| ------- | ---------------- | --------------- |
| `Drop` (9) | Increments `field_56`. Soldier **slides downward** with accelerating gravity (`Y += field_12`; `field_12` counts 1, 2, 3 …). Walk targets are adjusted so the squad path follows. | `field_12 ≥ 12` (~0.72 s). **Survivable** — if the soldier reaches non-drop terrain before frame 12 the counter resets. |
| `Drop2` (10) | Immediately sets `field_38 = eSprite_Anim_Hit3` (stumble). **Visual height** (`field_52`) accumulates by `field_12` each frame (1+2+3+4+5 = 15). Soldier **stays in place** — no Y displacement. | `field_52 ≥ 14` (~0.3 s / ~5 frames). **Always lethal** in practice because there is no displacement to carry the soldier off the tile. |

Once `field_12 > 5`, a visual dust/debris effect is spawned under the
soldier (original: `sub_223B2`) — Drop only.

If terrain at the new position is still `Drop` (type 9), the fall continues
(return to per-frame loop). `Drop2` (type 10) at the new position triggers
the stumble path instead.

#### Enemies and natives

Enemies and natives **never fall or stumble**. When they step onto a Drop or
Drop2 tile they are **bounced back**: their position is restored to the
previous frame's value, their direction is reversed, and their "reached
target" flag is set (so the AI picks a new goal). This effectively makes
cliff edges impassable for AI soldiers.

#### Vehicles

Vehicles **accelerate** downward on Drop tiles. Each frame on a Drop tile:
`fallSpeed += 4`, then `Y += fallSpeed`. This gives a gravity-like effect
rather than the gradual slide that soldiers experience.

#### Helicopters

Drop/Drop2 tiles set a minimum flight altitude of `0x0E` (14 units).
Helicopters fly over cliffs without falling.

#### Grenades / projectiles

If a grenade is near ground level (`height ≤ 1`) and over a Drop/Drop2 tile,
it continues falling (`field_12 = 1`). Airborne grenades pass over unaffected.

#### Remake conversion notes

| Original field | Remake equivalent | Notes |
| -------------- | ----------------- | ----- |
| `field_56` | (implicit) | Non-zero triggers fall; in the remake the fall starts immediately via `fallTimer` |
| `field_12` (displacement/counter) | `fallTimer` (Drop), `_stumbleTimer` (Drop2) | Drop: counts down from 0.72 s; death at ≤ 0. Drop2: counts down from 0.3 s; death at ≤ 0 |
| `field_52` (visual height) | — | Drop2 only; in the remake the stumble timer replaces the height accumulation |
| `field_38 = 0x02` (Hit2) | `SoldierState.falling` | Gravity slide from Drop terrain |
| `field_38 = 0x03` (Hit3) | `SoldierState.stumbling` | Stumble from Drop2 terrain |
| `field_38 = 0x06` (Die2) | `SoldierState.dying` | Death from either drop type |
| `field_45 = 1` | `die()` | Trigger death sequence |

### 1.4 Height from terrain

Rocky terrain elevates soldiers, creating a pseudo-3D effect:

| Terrain | Height behaviour |
| ------- | ---------------- |
| Rocky | Height toggles between 0, 1, 2 |
| Rocky2 | Height increases up to 6 |

---

## 2. Civilians

| Sprite ID | Constant | Speed | Notes |
| --------- | -------- | ----- | ----- |
| 61 | `eSprite_Civilian` | 6 | Basic civilian, wanders near doors |
| 62 | `eSprite_Civilian2` | 10 | Faster civilian |
| 70 | `eSprite_Civilian_Spear` | — | Native with spear (attacks players) |
| 71 | `eSprite_Civilian_Spear2` | — | Spear projectile |
| 83 | `eSprite_Civilian_Invisible` | — | Invisible civilian |

All civilians have `field_22 = eSprite_PersonType_Native (2)`, sprite sheet
0xD0. They interact with doors via
`Sprite_Handle_Civilian_Within_Range_OpenCloseDoor()`.

### 2.1 Civilian spawning doors

| Sprite ID | Constant | Spawns type |
| --------- | -------- | ----------- |
| 74 | `eSprite_Door_Civilian` | Civilian (61) |
| 75 | `eSprite_Door2_Civilian` | Civilian2 (62) |
| 76 | `eSprite_Door_Civilian_Spear` | Spear civilian (70) |
| 90 | `eSprite_Door_Civilian_Rescue` | Rescue objective civilian |

---

## 3. Hostages

| Sprite ID | Constant | Speed |
| --------- | -------- | ----- |
| 72 | `eSprite_Hostage` | 12 |
| 73 | `eSprite_Hostage_Rescue_Tent` | — (stationary) |

### 3.1 Hostage rescue mechanic

`mHostage_Count` tracks remaining hostages. Each frame, hostages search for
nearby sprites:

1. **Rescue tent found:** Hostage walks toward tent (target X = tent.X+10,
   Y = tent.Y−5). When distance < 3 px → hostage destroyed,
   `mHostage_Count` decremented.
2. **Enemy found nearby:** Enemy "captures" hostage (`field_70` = follow link).
3. **Player found nearby:** Hostage follows player (target = player.X+4,
   player.Y−6). Can also enter stopped vehicles if distance ≤ 10 and vehicle
   speed ≤ 2 and height ≤ 3.

---

## 4. Enemy Leader

| Sprite ID | Constant |
| --------- | -------- |
| 106 | `eSprite_Enemy_Leader` |

The enemy leader delegates entirely to `Sprite_Handle_Hostage()` — it behaves
like a hostage but also has a **flashing light** child sprite. Used for the
"Kidnap Leader" mission objective.

---

## 5. Building Doors (Enemy Spawner)

| Sprite ID | Constant | Notes |
| --------- | -------- | ----- |
| 20 | `eSprite_BuildingDoor` | Standard enemy spawn door |
| 25 | `eSprite_BuildingDoor2` | Variant |
| 88 | `eSprite_BuildingDoor3` | Variant |
| 100 | `eSprite_BuildingDoor_Reinforced` | Only destroyed by explosions |

Doors spawn enemies periodically. Timer formula:
`base = (20 − aggressionMax) × 8 + random(0..15)`. Spawns up to 2 enemies
per door-open cycle (at countdown tick 0x14 and 0x0A). Max enemies on map:
`mSpawnEnemyMax` (default **10**, configurable).

See [ENEMY_AI.md §2.2](ENEMY_AI.md) for full spawning details.

---

## 6. Interactive Map Objects

### 6.1 Pickups

| ID | Constant | Effect |
| -- | -------- | ------ |
| 37 | `eSprite_GrenadeBox` | +4 grenades |
| 38 | `eSprite_RocketBox` | +4 rockets |
| 93 | `eSprite_Bonus_RankToGeneral` | Leader rank → 15 |
| 94 | `eSprite_Bonus_Rockets` | +50 rockets + homing flag |
| 95 | `eSprite_Bonus_Armour` | Invincibility |
| 96 | `eSprite_Bonus_RankHomingInvin_SquadLeader` | Leader: rank 15 + homing + invincibility |
| 110 | `eSprite_Bonus_RankHomingInvin_Squad` | Whole squad: rank 15 + homing + invincibility |

### 6.2 Hazards

| ID | Constant | Effect |
| -- | -------- | ------ |
| 54 | `eSprite_Mine` | Proximity mine — explodes on contact |
| 55 | `eSprite_Mine2` | Second mine type |
| 56 | `eSprite_Spike` | Spike trap — `eSprite_Anim_Die5` death |
| 60 | `eSprite_BoilingPot` | Environmental hazard |
| 91 | `eSprite_Seal_Mine` | Seal carrying a mine |
| 92 | `eSprite_Spider_Mine` | Mobile mine |

### 6.3 Destroyable objects

| ID | Constant | Notes |
| -- | -------- | ----- |
| 39 | `eSprite_Building_Explosion` | Destroyable building |
| 108 | `eSprite_Computer_1` | Mission objective target |
| 109 | `eSprite_Computer_2` | Mission objective target |
| 110 | `eSprite_Computer_3` | Mission objective target |

### 6.4 Switches (CF2)

| ID | Constant | Notes |
| -- | -------- | ----- |
| 111 | `eSprite_UFO_Callpad` | CF2: Controls `mSwitchesActivated` |

---

## 7. Mission Objectives

The phase ends when all active objectives are satisfied:

| Value | Objective | Condition |
| ----- | --------- | --------- |
| 0 | None | — |
| 1 | `Kill_All_Enemy` | All enemy sprites dead (count = 0) |
| 2 | `Destroy_Enemy_Buildings` | All doors/computers destroyed |
| 3 | `Rescue_Hostages` | All hostages freed (`mHostage_Count = 0`) |
| 4 | `Protect_All_Civilians` | No civilians killed |
| 5 | `Kidnap_Enemy_Leader` | Leader captured (reaches rescue tent) |
| 6 | `Destroy_Factory` | Factory buildings destroyed |
| 7 | `Destroy_Computer` | All computer sprites destroyed |
| 8 | `Get_Civilian_Home` | Civilian reached destination |
| 9 | `Activate_All_Switches` | All switches toggled (CF2) |
| 10 | `Rescue_Hostage` | CF2 hostage rescue variant |

The "Kill All Enemy" objective counts all live sprites whose type is in the
`mEnemy_Unit_Types[]` list — this includes soldiers, vehicles, and turrets.
The count is checked every frame in `Phase_Goals_Check()`.

A **phase completion timer** of **100 ticks** (0x64, ~6 seconds) triggers
after all objectives are met, before actually advancing to the next phase.

---

## 8. Environment Decorations

Static overlays rendered from the per-terrain copt atlas (`*copt.dat`).

| ID | Constant | Atlas frame | Notes |
| -- | -------- | ----------- | ----- |
| 13 | `eSprite_Shrub` | `8f_0` | Shrub overlay |
| 14 | `eSprite_Tree` | `90_0` | Tree-top overlay |
| 15 | `eSprite_BuildingRoof` | `91_0` | Building roof overlay |
| 16 | `eSprite_Snowman` | `92_0` | Snowman decoration |
| 17 | `eSprite_Shrub2` | `93_0` | Small shrub overlay |

These are placed in the TMX `Raised` object layer and rendered at priority
above soldiers, creating the illusion of walking under canopies and roofs.
Explosions should destroy environment sprites of types 13–17.

---

## 9. Birds

Ambient flying birds are purely decorative animated sprites. They fly in one
direction, wrap around relative to the camera when offscreen, and play
terrain-specific bird-call sounds at random intervals.

### 9.1 Sprite types

| ID | Constant | Anim sheet | Direction |
| -- | -------- | ---------- | --------- |
| 66 | `eSprite_Bird_Left` | `0xD3` (`bird_fly_left`) | Flies left (−X) |
| 67 | `eSprite_Bird_Right` | `0xD4` (`bird_fly_right`) | Flies right (+X) |
| 19 | `eSprite_Bird2_Left` | `0x98` | Simple two-frame bird, wraps at X < −64 |

Types 66 and 67 are the main bird types placed on maps. Type 19 is a simpler
bird used in test/demo scenarios.

### 9.2 Animation

Each animation group contains **6 frames** (indices 0–5). The bird cycles
through frames in a **ping-pong** pattern: 0→1→2→3→4→5→4→3→2→1→0→…

The frame index advances once per engine tick (~60 ms). A full oscillation
cycle (0→5→0) takes **10 ticks ≈ 0.6 seconds**.

Frames 4 and 5 have Y-anchor offsets:

| Frame | Y offset (original px) | Visual effect |
| ----- | ---------------------- | ------------- |
| 0–3 | 0 | Level flight |
| 4 | 1 | Slight downward dip |
| 5 | 3 | Deeper dip (wing apex) |

These offsets create a bobbing motion that simulates flapping wings.

### 9.3 Movement

Birds move horizontally at a variable speed using 16.16 fixed-point
arithmetic. The speed depends on the frame oscillation direction:

| Oscillation phase | Horizontal speed (original) | Remake (2× scale) |
| ----------------- | --------------------------- | ------------------ |
| Ascending (frames 5→0) | 1.5 px/tick → **25 px/s** | **50 px/s** |
| Descending (frames 0→5) | 2.0 px/tick → **33 px/s** | **67 px/s** |

`Bird_Right` mirrors the direction (+X) with the same speeds.

There is no vertical movement — the Y position stays fixed. The apparent
vertical wobble comes entirely from the per-frame anchor offsets.

### 9.4 Spawning

Birds are placed from map data (`.spt` / TMX `Spawns` layer), like any other
sprite. Their initial position is their map-data position.

On first update, a brief **warm-up timer** of **8 ticks (≈ 0.48 s)** delays
the first offscreen-respawn check. During this time the bird flies from its
initial position.

### 9.5 Offscreen respawn

Each frame the engine checks whether the bird was rendered on-screen in the
previous frame (`field_5C`). Once the bird flies off-screen:

1. A **respawn timer** of **0x3F = 63 ticks (≈ 3.78 s)** counts down.
2. When the timer reaches zero, the bird is repositioned relative to the
   camera:

| Direction | New X | New Y |
| --------- | ----- | ----- |
| `Bird_Left` | `camera.x + windowWidth + random(0..63)` | `camera.y + random(0..255)` |
| `Bird_Right` | `camera.x − random(0..63)` | `camera.y + random(0..255)` |

This places the bird just off the incoming edge of the screen so it flies
across the viewport naturally.

### 9.6 Hit detection

Types 66 and 67 **cannot be shot** — there is no hit-detection call in their
handler. They are purely decorative.

Type 19 (`Bird2_Left`) *can* be hit (it calls `sub_25DCF` for damage
handling), but this type is rarely used on actual maps.

### 9.7 Sound

Each frame, with a **1/128 random chance**, the bird plays a terrain-specific
ambient bird-call sound:

| Terrain type | Sound ID | File |
| ------------ | -------- | ---- |
| Jungle | `0x1A` | `jungle_bird.wav` |
| Ice / AFX | `0x1F` | `ice_bird.wav` |
| Interior / Moors | `0x1A`/`0x1F` | `interior_bird.wav` / `moor_bird.wav` |

### 9.8 Draw order

Birds are drawn with `eSprite_Draw_OnTop` priority, meaning they always
render above soldiers, terrain, and other ground-level sprites.

### 9.9 Remake conversion

| Original | Remake | Notes |
| -------- | ------ | ----- |
| `field_0` / `field_2` | `position.x` | 16.16 fixed-point → float px |
| `field_4` | `position.y` | Pixel position (2× scaled) |
| `field_8` | Atlas group | `bird_fly_left` / `bird_fly_right` |
| `field_A` | `_frameIndex` | Ping-pong 0–5 |
| `field_12` | `_oscillationDir` | +1 or −1 |
| `field_57` | `_respawnTimer` | Seconds (0.48 s initial, 3.78 s respawn) |
| `field_5C` | viewport intersection check | Whether bird is on-screen |
| 1.5–2.0 px/tick | 50–67 px/s | `original × 16.67 fps × 2 scale` |

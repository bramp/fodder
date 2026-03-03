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

### 1.3 Height from terrain

Rocky terrain elevates soldiers, creating a pseudo-3D effect:

| Terrain | Height behaviour |
| ------- | ---------------- |
| Rocky | Height toggles between 0, 1, 2 |
| Rocky2 | Height increases up to 6 |
| Drop/Drop2 | Enemies/natives get bounced back; players stumble |

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

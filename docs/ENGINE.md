# Engine Fundamentals

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> Core engine constants, timing, coordinate system, direction math, and sprite
> limits that underpin all other game systems.

---

## 1. Timing

The engine emulates the **Amiga 50 Hz vertical blank interrupt**.

| Constant | Value | Notes |
| -------- | ----- | ----- |
| Interrupt interval | 20 ms | `mSleepDelta` — 50 interrupts/sec |
| Engine ticks per interrupt | 3 | Main loop waits for 3 interrupts before advancing |
| **Engine tick rate** | **~16.67 ticks/sec** | 50 / 3 ≈ 16.67 |
| Engine tick duration | **~60 ms** | 3 × 20 ms |

All durations in the spec documents expressed as "ticks" refer to **engine
ticks** (~60 ms each). `mMission_EngineTicks` increments once per engine loop.

---

## 2. Coordinate System

- World positions use **16.16 fixed-point** — `field_0` (integer X) +
  `field_2` (fractional X). Same for Y (`field_4` / `field_6`).
- Heights use the same scheme: `field_1E_Big` (32-bit fixed-point),
  `field_20` (integer pixel height above ground).
- Map tiles are **16×16 pixels**. Sub-tile walkability uses an **8×8 grid** per
  tile (2×2 walkability cells per tile).

---

## 3. Direction & Movement System

### 3.1 Direction encoding

Directions use a **512-unit circle** (0x000–0x1FE), but only **even values**
are used, giving **256 effective directions**. All direction values are masked
with `& 0x1FE`.

| Direction | Value | Compass |
| --------- | ----- | ------- |
| North     | 0x000 | Up      |
| East      | 0x080 | Right   |
| South     | 0x100 | Down    |
| West      | 0x180 | Left    |

### 3.2 Direction vector table

`mDirectionVectorTable[256]` is a sine lookup table scaled to 16-bit
fixed-point (max ±32767). Movement deltas per tick:

```
X_velocity = vectorTable[direction / 2] × speed >> shifts
Y_velocity = vectorTable[(direction + 0x80) / 2] × speed >> shifts
```

### 3.3 Direction calculation

`Direction_Between_Points()` computes a direction from delta X/Y using
`mMap_DirectionsBetweenPoints[]` — a 32×32 lookup table mapping (dx, dy)
ratios to direction values (0–64 per quadrant). The quadrant is determined by
the sign of dx/dy, adding 0x80 (128) per 90°.

### 3.4 Turning

A sprite's facing direction (`field_3C`) smoothly interpolates toward its
movement direction (`field_10`) using `mDirectionStepTable`:

```
{ 0, -1, -1, -1, -1, -1, -1, -1, -1, 1, 1, 1, 1, 1, 1, 1 }
```

This creates gradual turning rather than instant snapping. The visible sprite
animation quantises into **8 directions** for walk/fire cycles.

### 3.5 Speed-direction modifier (player only)

When a player fires while moving, speed is modulated by the angle between the
movement and facing direction:

```
mSprite_Speed_Direction_Modifier = { 0x18, 0x14, 0x0E, 0x0A, 0x08, 0x0A, 0x0E, 0x14 }
                                     24    20    14    10     8    10    14    20
```

Fastest (24) when moving in the facing direction, slowest (8) when
perpendicular.

---

## 4. Sprite Limits

| Limit | Value |
| ----- | ----- |
| Max sprites (original) | **45** (`mSpritesMax`) |
| General allocation range | Indices 0–42 (`Sprite_Get_Free_Max42`) |
| Bullet/low-priority range | Indices 0–29 (`Sprite_Get_Free_Max29`) |
| Reserved for text overlays | Indices 40–42 |
| Sentinel sprite | Index 44 (`field_0 = -1`) |
| Max enemies on map | **10** (`mSpawnEnemyMax`, configurable) |
| Total sprite type IDs | **118** (0–117) |

---

## 5. Person Types

| Constant | Value | Description |
| -------- | ----- | ----------- |
| `eSprite_PersonType_Human` | 0 | Player soldiers |
| `eSprite_PersonType_AI` | 1 | Enemy soldiers |
| `eSprite_PersonType_Native` | 2 | Civilians, hostages |

---

## 6. Key Sprite Struct Fields

> `sSprite` (Sprites.hpp:210–330). Most-referenced fields across all systems.

| Field | Type | Purpose |
| ----- | ---- | ------- |
| `field_0` / `field_4` | int16 | X / Y world position (integer part) |
| `field_2` / `field_6` | int16 | X / Y fractional part (16.16 fixed-point) |
| `field_8` | int16 | Sprite sheet index |
| `field_A` | int16 | Animation frame |
| `field_10` | int16 | Movement direction (0–0x1FE) |
| `field_12` | int16 | Countdown timer / lifetime |
| `field_18` | int16 | Sprite type (enum) |
| `field_1A` | int32 | Vertical velocity (fixed-point) |
| `field_1E_Big` | int32 | Height (fixed-point) |
| `field_20` | int16 | Height in pixels (above ground) |
| `field_22` | int16 | Person type (0=Human, 1=AI, 2=Native) |
| `field_26` / `field_28` | int16 | Movement target X / Y |
| `field_2E` / `field_30` | int16 | Weapon target X / Y |
| `field_32` | int16 | Squad index / misc |
| `field_36` | int16 | Movement speed |
| `field_38` | int16 | Animation state (`eSprite_Anim`) |
| `field_3A` | int16 | Misc counter |
| `field_3C` | int16 | Facing direction (display) |
| `field_4F` | int8 | In-water flag |
| `field_52` | int16 | Sink depth / bounce count |
| `field_54` | int16 | Fired weapon type (1=grenade, 2=bullet, 3=rocket) |
| `field_62` | int16 | AI aggression / explosion toggle |
| `field_6E` | int8 | In-vehicle flag (−1 = inside) |
| `field_6F` | int8 | Vehicle type |
| `field_75` | int8 | Flags (0x01=homing, 0x02=invincibility) |

### `field_46` union

```cpp
union {
    int32            field_46;
    sMission_Troop*  field_46_mission_troop;  // player soldiers
    sSprite*         field_46_sprite;          // vehicles, projectiles
};
```

---

## 7. Animation Groups

Player and enemy soldiers use separate animation group ranges within the same
sprite atlas file (e.g. `junarmy.png`):

| Animation       | Player groups | Enemy groups | Semantic prefix (player) | Semantic prefix (enemy) |
| --------------- | ------------- | ------------ | ------------------------ | ----------------------- |
| Walk (8 dirs)   | 0x00–0x07     | 0x42–0x49    | `player_walk`            | `enemy_walk`            |
| Throw (8 dirs)  | 0x08–0x0F     | 0x4A–0x51    | `player_throw`           | `enemy_throw`           |
| Prone (8 dirs)  | 0x10–0x17     | 0x52–0x59    | `player_prone`           | `enemy_prone`           |
| Swim (8 dirs)   | 0x18–0x1F     | 0x5A–0x61    | `player_swim`            | `enemy_swim`            |
| Death (8 dirs)  | 0x20–0x27     | 0x62–0x69    | `player_death`           | `enemy_death`           |
| Death-2 (8 dirs)| 0x28–0x2F     | 0x6A–0x71    | `player_death2`          | `enemy_death2`          |
| Death-3 (8 dirs)| 0x30–0x37     | 0x72–0x79    | `player_death3`          | `enemy_death3`          |
| Rocket (8 dirs) | 0x39–0x40     | 0xA8–0xAF    | `player_rocket`          | `enemy_rocket`          |
| Standing w/ gun | 0xB0–0xB7     | 0xB8–0xBF    | `player_firing`          | `enemy_firing`          |

> **Remake note:** The hex group indices are the original engine's internal IDs.
> In the remake, `fodder_tools` translates these into semantic names. Atlas JSON
> frame keys use the pattern `ingame/{prefix}_{direction}_{frame}` (e.g.
> `ingame/enemy_walk_s_0`). See `packages/fodder_tools/lib/sprite_names.dart`.

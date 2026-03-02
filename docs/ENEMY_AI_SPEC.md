# Enemy AI Specification

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> This document describes how enemy soldiers behave in the original Cannon Fodder
> and serves as a specification for the Fodder remake.

---

## 1. Enemy Types

| Type               | Sprite Enum              | ID  | Behaviour              |
| ------------------ | ------------------------ | --- | ---------------------- |
| Basic soldier      | `eSprite_Enemy`          | 5   | Walks, shoots, grenades |
| Rocket soldier     | `eSprite_Enemy_Rocket`   | 36  | Walks, fires rockets   |
| Enemy leader       | `eSprite_Enemy_Leader`   | 106 | Hostage behaviour (rescue target) |

Additional hostile unit types exist (helicopters, tanks, turrets, vehicles) but
are out of scope for the initial implementation.

All enemy soldiers have `field_22 = eSprite_PersonType_AI (1)`, which selects the
**enemy animation set** and the **enemy AI code path**.

---

## 2. Spawning

### 2.1 Static spawning (from .spt map file)

Enemies are placed via the `.spt` sprite file loaded at mission start. Each entry
contains an X/Y position and a sprite type. The position becomes both the
soldier's current position and initial walk target (so they start standing still).

At load time, `Map_Load_Sprites_Count()` counts enemies into
`mTroops_Enemy_Count` and staggers their initial fire timers:

```
for each enemy sprite:
    fire_delay += 0x0A   (so first enemy fires after 0x14 ticks,
                           second after 0x1E, third 0x28, etc.)
    if aggression > 4:
        fire_delay = 0    (high-aggression enemies fire immediately)
```

### 2.2 Dynamic spawning (from buildings and holes)

Building doors and ground holes spawn enemies dynamically during gameplay:

1. **Gate check:** if `mTroops_Enemy_Count >= mSpawnEnemyMax` (default **10**),
   no spawn occurs.
2. **Door opening cycle:** A random countdown timer (`field_43`, range 6–21
   ticks) triggers a door open. During the open animation, enemies spawn at tick
   thresholds **0x14** and **0x0A**, meaning each cycle spawns **up to 3**
   enemies.
3. **Delay between cycles:**
   `delay = (0x14 − AggressionMax) × 8 + random(0..15)`.
   Higher aggression → shorter delay → faster spawning.
4. **Aggression escalation:** Every 16 dynamically spawned enemies,
   `AggressionMax` increments (up to 0x1E). The game gets harder over time.

### 2.3 `Sprite_Create_Enemy()` details

When a new enemy is created dynamically:

- Position: spawner's X − 6, spawner's Y + 4
- Initial direction: random around 0x1C0
- Initial movement delay: 8–23 ticks (`field_44`) — the soldier wanders in a
  random direction before basic AI kicks in
- Initial target delay: a negative `field_5E` value (−random(0..255) − 0x78) —
  prevents immediate targeting of players
- Aggression: assigned via the ping-pong system (see §4)

---

## 3. Main AI Loop

Each frame, `Sprite_Handle_Enemy()` runs for every living enemy soldier:

```
1. Sprite_Handle_Soldier_Animation()
   → If dying or injured, skip everything (play death anim)

2. if field_38 (anim state) ≠ 0 → skip (dying)

3. if field_44 > 0 → decrement, skip targeting (spawn delay)

4. sub_21CD1()  ← THE CORE AI BRAIN
   → Detect player, choose target, set walk/weapon targets

5. Sprite_Handle_Troop_Weapon()
   → Fire weapon if ready

6. Calculate direction toward walk target

7. Sprite_Handle_Troop_Speed() → move

8. Update animation
```

### 3.1 AI states (implicit)

Enemies don't have an explicit state machine. Their behaviour emerges from the
targeting function:

| Condition | Behaviour |
| --------- | --------- |
| No target found | Stand idle at current position, randomly nudge aim |
| Target acquired (within range) | Walk toward player, fire weapon |
| Spawn delay active (`field_44 > 0`) | Wander in initial random direction |
| Just fired weapon | Pause movement for 12–15 ticks |

---

## 4. Aggression System

Each mission phase defines an aggression **range** (min, max). The default is
`{ 4, 8 }`. Aggression is assigned to enemies via a **ping-pong** pattern:

```
Next starts at average = (min + max) / 2
Each enemy gets Next as their aggression
Next += Increment (starts at +1)
When Next reaches max → Increment flips to −1
When Next reaches min → Increment flips to +1
```

So enemies on the same map have **varying** aggression, spread evenly across the
configured range. Aggression affects nearly every aspect of enemy behaviour:

| Aspect               | Low aggression (0–4) | High aggression (10–20) |
| -------------------- | -------------------- | ----------------------- |
| Movement speed       | 12 (slow)            | 26 (fast, capped)       |
| Fire delay           | 50–81 ticks          | 5–7 ticks               |
| Bullet range         | Short (8 ticks alive) | Long (10–16 ticks alive) |
| Bullet speed         | 60                   | 72–90                   |
| Building spawn delay | Long                 | Short                   |
| Grenade chance       | Same (1/32)          | Same (1/32)             |

---

## 5. Detection and Targeting

### 5.1 Detection ranges

The core targeting function `sub_21CD1()` runs every frame for each enemy:

| Range               | Pixels | Behaviour |
| ------------------- | ------ | --------- |
| > **200** (0xC8)    |        | Player invisible — enemy ignores them |
| 41–200              |        | Line-of-sight check via `Map_PathCheck_CalculateTo()` |
| ≤ **64** (0x40)     |        | Engage even if LOS blocked |
| ≤ **40** (0x28)     |        | Always engage (close range) |

Between 64 and 200 pixels, if path is clear: enemy engages. If path is blocked:
enemy stays idle.

### 5.2 Target selection

Enemies cycle through player squad members (`field_5E_Squad` index 0–29):

- Skip dead, vehicle-riding, or invalid players
- **1/64 random chance** to skip even a valid target — adds unpredictability
- When a valid target is found, calculate distance

### 5.3 Target spreading

When multiple enemies target the same player, they don't all walk to the exact
same pixel. An offset is applied based on the enemy's sprite index:

```
offset_angle = sprite_index × 0x76  (mod 0x1FE)
offset_x = DirectionVectorTable[offset_angle] >> 10
offset_y = DirectionVectorTable[offset_angle + 0x80] >> 10
walk_target = player_position + (offset_x, offset_y)
```

This creates a slight spread around the target player.

### 5.4 Idle behaviour (no target)

When no valid target is found, the enemy:

- Sets walk target to **current position** (stays still)
- Stops firing (`field_4A = 0`)
- **1/16 chance** per tick of applying a random nudge to weapon aim direction —
  creates the look of slowly scanning the area
- Advances to the next squad member index for the next check

**Enemies do NOT patrol.** They either stand still (idle) or walk toward a
detected player. There are no patrol routes, waypoints, or random wandering in
the original game (outside the brief spawn delay period).

---

## 6. Movement

### 6.1 Speed values

Speed is stored in `field_36` and varies by aggression:

```
speed = 0x0C + aggression
if speed > 0x1A: speed = 0x1A  (cap at 26)
```

| Entity           | Speed | Notes |
| ---------------- | ----- | ----- |
| Enemy (aggr. 0)  | 12    | Slower than player |
| Enemy (aggr. 6)  | 18    | Roughly equal to player |
| Enemy (aggr. 14+)| 26    | Faster than player (capped) |
| Player (default) | 16    | Normal walking speed |
| Player (running) | 24    | Moving to waypoint |
| Any (in water)   | 6     | Universal water penalty |

### 6.2 Direction and turning

Direction uses a 512-value circle (0–0x1FE). Each frame, the sprite's facing
direction (`field_3C`) smoothly interpolates toward its movement direction
(`field_10`) using `mDirectionStepTable`. This creates gradual turning rather
than instant snapping.

Movement delta per frame is calculated from `mDirectionVectorTable` using the
current direction and speed. This is a sin/cos lookup producing smooth
sub-pixel movement in any of 256 angles.

The visible sprite animation quantises this into 8 directions for the walk
cycle.

### 6.3 Post-fire pause

After firing, `field_45` is set to:
- **15** ticks for bullets
- **12** ticks for grenades

The enemy pauses movement during this countdown, creating a brief "stop and
shoot" behaviour.

### 6.4 Collision avoidance

When an enemy bumps into another squad member (`mSprite_Bumped_Into_SquadMember`),
the direction is nudged to avoid stacking. This is a simple push — there is no
sophisticated formation or flocking system.

---

## 7. Weapons

### 7.1 Basic enemy soldier (type 5) — Gun + Grenades

**Gun (primary):**
- Fire delay: based on aggression (see §4 table)
- Bullet speed: `60 + aggression` (range 60–90)
- Bullet lifetime: `(aggression >> 3) + 8` ticks (range 8–16), capped at 16
- Bullet spread: fixed at 24
- Max concurrent bullets: 20

**Grenades (occasional):**
- Available only after mission 4
- **1/32 chance** per fire event to throw a grenade instead of shooting
- Range limit: < 130 pixels (0x82)
- Causes 12-tick movement pause instead of 15

### 7.2 Rocket soldier (type 36) — Rockets only

- Bullet and grenade weapons are disabled
- Only fires rockets (`field_54 = 3`)
- Minimum firing range: 24 pixels (won't fire point-blank)
- Always faces the weapon target
- Uses standing-with-rocket animation when idle

### 7.3 Weapon target vs walk target

Enemies maintain **separate** weapon and walk targets:
- **Walk target** (`field_26`, `field_28`): where they walk to (player pos +
  spread offset)
- **Weapon target** (`field_2E`, `field_30`): where they aim (exact player
  position)

This means enemies fire at the player while walking slightly to the side.

---

## 8. Hit Detection and Death

### 8.1 Collision boxes

| Scenario | Box (relative to sprite centre) | Size |
| -------- | ------------------------------- | ---- |
| Player bullet → Enemy | (−6, −10) to (+10, +6) | 16×16 |
| Enemy bullet → Player | (0, −9) to (+6, −4)    | 6×5   |

The asymmetry means **it's much easier to hit enemies than for enemies to hit
the player**.

### 8.2 Health

**All soldiers die in one hit.** There is no health/hitpoint system. A single
bullet, rocket, or grenade hit kills immediately.

### 8.3 Death sequence

1. **Impact:** `field_38` set to a `Hit`/`Die` state. A shadow sprite is
   created. A random death sound plays.
2. **Body launched:** The body flies in an arc. Speed boosted by +15. Height
   controlled by `field_1A` (initial upward velocity). Body may rotate (50%
   chance). Blood trail created.
3. **Gravity:** `field_1A -= 0x18000` each frame (deceleration). When body
   reaches ground, it bounces: `velocity = −velocity >> 2`.
4. **On ground:** 1/128 chance per frame of twitching. Eventually settles into
   final death state.
5. **Fade out:** Over 15 frames, sprite becomes invisible. At frame 7, the
   sprite graphic is hidden. At frame 15, `Sprite_Troop_Dies()` finalises:
   - Increments kill score
   - **Decrements `mTroops_Enemy_Count`** (allows buildings to spawn
     replacements)
   - Credits the kill to the firing soldier

---

## 9. Mission Objectives

The phase ends when all active objectives are satisfied. Relevant to enemies:

| Objective | Condition |
| --------- | --------- |
| `eObjective_Kill_All_Enemy` | All enemy sprites dead (count = 0) |
| `eObjective_Destroy_Enemy_Buildings` | All doors/computers destroyed |
| `eObjective_Kidnap_Leader` | Leader captured |
| `eObjective_Rescue_Hostages` | All hostages freed |
| `eObjective_Get_Civilian_Home` | Civilian reached destination |
| `eObjective_Protect_Civilians` | No civilians killed |
| `eObjective_Activate_All_Switches` | All switches toggled |

The "Kill All Enemy" objective counts all live sprites whose type is in the
`mEnemy_Unit_Types[]` list — this includes soldiers, vehicles, and turrets. The
count is checked every frame in `Phase_Goals_Check()`.

A phase completion timer of **100 ticks** (0x64) triggers after all objectives
are met, before actually advancing.

---

## 10. Animation Groups

Enemy soldiers use a separate set of atlas animation groups from players:

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

Both player and enemy animations share the same sprite atlas file (e.g.
`junarmy.png`). The difference is palette/colour.

> **Remake note:** The hex group indices above are the original engine's internal
> IDs. In the remake, the `fodder_tools` asset pipeline translates these into
> semantic names (see "Semantic prefix" columns). Atlas JSON frame keys use the
> pattern `ingame/{prefix}_{direction}_{frame}` (e.g. `ingame/enemy_walk_s_0`).
> The game code references only semantic prefixes, never hex group indices.
> See `packages/fodder_tools/lib/sprite_names.dart` for the full mapping.

---

## 11. Implementation Priority for Fodder Remake

Based on the above, a suggested incremental implementation order:

### Phase 1 — Static idle enemies (DONE)
- [x] Enemies spawned from `.spt` data at map positions
- [x] Enemy walk animation groups (`enemy_walk` — was 0x42–0x49)
- [x] Standing idle at spawn point

### Phase 1b — Combat foundations (DONE)
- [x] `SoldierState` expanded: `idle`, `walking`, `firing`, `throwing`, `dying`
- [x] Combat animation loading (`player_firing`, `enemy_firing`, `player_death`,
      `enemy_death`, `player_throw`, `enemy_throw` groups)
- [x] `Soldier.die()` with removal timer, `isAlive` flag
- [x] `Bullet` component with `Faction` enum, range/lifetime tracking, sprite
- [x] `BulletSprites` loaded from copt atlas (`bullet` group)
- [x] Asymmetric hitboxes (enemy 16×16, player 6×5) with `CollisionCallbacks`
- [x] Semantic sprite naming pipeline (hex → human-readable atlas keys)

### Phase 2 — Detection and movement (DONE)
- [x] Range-based player detection (200px max, 64px always-engage)
- [x] Walk toward detected player (chase state)
- [x] Aggression-based speed ((12 + aggression) × 5, cap 130 px/s)
- [x] Effective bullet range check before firing (enemies chase to close
      distance before shooting)
- [x] Post-fire movement pause (0.25 s)
- [x] Return to idle when player out of range

### Phase 3 — Firing (DONE — gun only)
- [x] Player firing via right-click (SecondaryTapCallbacks)
- [x] Fire delay based on aggression
- [x] Bullet creation with speed/lifetime from aggression
- [x] Staggered initial fire delays across enemies
- [x] Line-of-sight check (Bresenham on sub-tile walkability grid)
- [ ] Separate walk target vs weapon target (enemies walk-and-shoot)
- [ ] Grenade throwing (deferred)
- [ ] Rocket soldier variant (deferred)

### Phase 4 — Death and scoring (DONE — partial)
- [x] One-hit kill (collision → `die()`)
- [x] Asymmetric hit boxes (16×16 for enemies, 6×5 for players)
- [x] Death animation variants (randomly choose death/death2)
- [x] Fade-out visual (0.5 s opacity fade after death anim)
- [x] `onDeath` callback for game-level cleanup
- [x] Dead enemies removed from `_enemies` list
- [ ] Kill tracking and score

### Phase 5 — Dynamic spawning
- [ ] Building door spawner logic
- [ ] Spawn cap (max 10 live enemies)
- [ ] Aggression escalation over time
- [ ] Ground hole spawners

### Phase 6 — Win conditions
- [ ] Phase objectives (kill all, destroy buildings, etc.)
- [ ] Phase completion timer
- [ ] Mission progression

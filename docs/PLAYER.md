# Player Soldiers, Squads & Rank

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> Covers player soldier stats, squad mechanics, the rank/promotion system, and
> controls.
>
> See also: [ENGINE.md](ENGINE.md) for timing/direction fundamentals,
> [WEAPONS.md](WEAPONS.md) for bullet/grenade/rocket details.

---

## 1. Health & Survivability

### 1.1 One-hit kill

**All soldiers die in one hit.** There is no hitpoint system. A single bullet,
grenade, rocket, or explosion kills immediately.

### 1.2 Dodge mechanic

Moving soldiers have a **1-in-8 chance** of dodging an incoming bullet
(`tool_RandomGet() & 7 == 0`):

| Condition | Dodge? |
| --------- | ------ |
| Soldier is moving (`word_3BED5[squad] ≠ 0`) | 1/8 chance to dodge |
| Soldier is stationary | Always hit |
| Soldier in water (`field_4F`) or sinking (`field_52 ≥ 5`) | 1/8 chance to dodge |
| Very close-range shot (`field_3A ≤ 4`) | Always hit (no dodge) |

### 1.3 Invincibility

The flag `field_75 & 0x02` grants full immunity. Sources:
- Bonus pickup `eSprite_Bonus_Armour` (sprite type 95)
- Bonus pickup `eSprite_Bonus_RankHomingInvin_SquadLeader` (type 96)
- Bonus pickup `eSprite_Bonus_RankHomingInvin_Squad` (type 110)

### 1.4 Death animation states

| State | Value | Trigger |
| ----- | ----- | ------- |
| `eSprite_Anim_Hit` | 0x01 | Standard bullet death |
| `eSprite_Anim_Die1` | 0x05 | Run over / explosion |
| `eSprite_Anim_Die3` | 0x07 | Drowning |
| `eSprite_Anim_Die5` | 0x0A | Spike death |
| `eSprite_Anim_Slide1–3` | 0x32–0x34 | Sliding on terrain |

---

## 2. Movement

### 2.1 Speed values

| Mode | `field_36` | Condition |
| ---- | ---------- | --------- |
| Halted / slow | 8 (0x08) | `word_3BED5[squad] == 0` — speed halved |
| Normal walk | 16 (0x10) | `word_3BED5[squad] == 1` |
| Running (default) | 24 (0x18) | `word_3BED5[squad] == 2` (initial value) |
| In water / sinking | 6 (0x06) | `field_4F ≠ 0` or `field_52 ≠ 0` |

`word_3BED5` is initialised to **2** (running) for all squads. Players
effectively start at running speed (24).

### 2.2 Comparison with enemies

| Entity | Speed | Notes |
| ------ | ----- | ----- |
| Player (running) | 24 | Default |
| Player (normal) | 16 | Mode 1 |
| Player (halted) | 8 | Mode 0 |
| Enemy (aggression 0) | 12 | Slowest |
| Enemy (aggression 6) | 18 | Roughly matches player normal |
| Enemy (aggression 14+) | 26 | Capped, faster than player |
| Any (in water) | 6 | Universal water penalty |

---

## 3. Controls

| Input | Action |
| ----- | ------ |
| Left-click | Set squad **walk target** (waypoint) |
| Right-click | Set squad **weapon target** (fire at position) |
| Left+Right simultaneously | Fire **special weapon** (grenade or rocket) |

On right-click, `mSquad_Member_Fire_CoolDown_Override = true` — the first
shot fires immediately without waiting for cooldown.

### 3.1 Auto-fire (non-selected squads)

Soldiers not in the currently selected squad auto-fire at nearby enemies:

| Parameter | Value |
| --------- | ----- |
| Detection range | 210 px (0xD2) |
| Always-engage range | 40 px (0x28) |
| Line-of-sight | Required between 40–210 px |
| Ignore chance | 1/32 per tick (prevents constant firing) |

---

## 4. Squads

| Parameter | Value |
| --------- | ----- |
| Max squads | **3** (indices 0–2) |
| Max soldiers per squad | **8** |
| Max soldiers per mission | **9** (total across all squads) |
| Walk targets per squad | **30** waypoints |

Squads can be **split** and **merged**. Merging is blocked if the combined
count exceeds 8.

### 4.1 Fire rotation

Squad members take turns firing according to patterns that favour the
**squad leader** (index 0):

| Squad size | Rotation pattern |
| ---------- | ---------------- |
| 1 | `[0, -1]` — leader fires every turn |
| 2 | `[0, 1, -1]` — alternating |
| 3 | `[0, 1, 0, 2, -1]` |
| 4 | `[0, 1, 0, 2, 0, 3, -1]` |
| 5 | `[0, 1, 0, 2, 0, 3, 0, 4, -1]` |
| 6 | `[0, 1, 0, 2, 0, 3, 0, 4, 0, 5, -1]` |
| 7 | `[0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, -1]` |
| 8 | `[0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 5, 0, 4, 0, 3, 0, 2, -1]` |

The `-1` sentinel marks the end; the pattern loops. The squad leader fires
**every other turn** in squads of 3+.

**Fire cooldown** between rotations: `mSprite_Weapon_Data.mCooldown` ticks
(3–7 depending on the leader's rank).

### 4.2 Ammo pools

Ammo is shared per squad, not per soldier.

| Ammo | Starting formula | Availability |
| ---- | ---------------- | ------------ |
| Grenades | soldiers × 2 | After mission 4 (CF1), mission 3 (CF2) |
| Rockets | soldiers × 1 | After mission 5 (CF1), mission 4 (CF2) |

Campaign data can override these values. Pickups:
- `eSprite_GrenadeBox` (type 37): **+4 grenades**
- `eSprite_RocketBox` (type 38): **+4 rockets**

### 4.3 Squad movement — follow-the-leader chain

Squads do **not** use formation offsets or grids. Instead, soldiers walk in a
**chain** where each soldier follows the previous soldier's position, creating
a natural snake-like file.

When the player left-clicks a destination (`Squad_Walk_Target_Set`):

1. **First move (squad is idle):**
   - The click position is placed at the **end** of the waypoint queue.
   - Working from the squad leader (index 0) to the last member, each
     soldier's **current position** is inserted as a waypoint for the soldier
     behind them.
   - The leader gets a waypoint index pointing directly at the click target.
   - Each subsequent member gets an index pointing at the previous member's
     old position, then the chain of positions ahead of it, then the click
     target.
   - Result: the leader walks straight to the target; each follower walks
     first to where the soldier ahead of them **was standing**, then follows
     the chain to the target.

2. **Already moving (append):**
   - The new click position is simply appended to the existing waypoint queue.
   - All soldiers continue along their current chain and will reach the new
     target in order.

3. **Walk steps cooldown:**
   - After each walk target is set, `mSquad_Walk_Target_Steps[squad]` is set
     to **8**. This counter decrements each tick, preventing immediate
     re-queuing of targets (acts as a debounce).

#### Per-soldier movement fields

| Field | Purpose |
| ----- | ------- |
| `field_26/field_28` | Immediate move target (x, y) |
| `field_40` | Current index into the squad's walk target array |
| `field_32` | Squad number (0–2) |
| `field_36` | Movement speed (set by speed mode) |
| `field_43` | Bump flag: 0 = normal, 1 = bumped into squad member, −1 = idle |
| `field_3C` | Current facing direction (0–14, step 2) |

### 4.4 Squad member collision avoidance

When two squad members get too close, the follower's movement is **undone**
for that frame (`Sprite_XY_Restore`), preventing stacking:

| Parameter | Value |
| --------- | ----- |
| X proximity threshold | ±8 pixels |
| Y proximity threshold | ±2 pixels |
| Effective collision box | ~16 × 4 pixels |

The check compares the current sprite against the member **two positions
before** it in the squad array (not the immediately preceding one). When a
bump is detected, `field_43` is set to 1 and the walking animation frame is
frozen to prevent visual jitter.

### 4.5 Direction-based speed modifier

When a soldier's facing direction differs from their movement direction, speed
is reduced. The modifier table (8 entries) maps angular difference to speed:

| Angular diff (index) | Speed |
| -------------------- | ----- |
| 0 (same direction) | 24 (0x18) |
| 1 | 20 (0x14) |
| 2 | 14 (0x0E) |
| 3 | 10 (0x0A) |
| 4 (opposite) | 8 (0x08) |
| 5 | 10 (0x0A) |
| 6 | 14 (0x0E) |
| 7 | 20 (0x14) |

This modifier is applied **after** the base speed from the squad's speed mode
and **only** for the currently selected squad's walking soldiers.

### 4.6 Squad selection

| Input | Action |
| ----- | ------ |
| Key 1 / 2 / 3 | Select squad 0 / 1 / 2 (if it has living members) |
| Auto-select | After 20 ticks (~1.2 s) if current squad is empty |

Selecting a squad centres the camera on its **leader** (first living member in
the squad array). The leader is always `mSquads[n][0]` — determined by
mission troop allocation order.

### 4.7 Squad joining (merge)

When a soldier finishes all waypoints in its chain and
`mSquad_Join_TargetSquad` is set, the soldier attempts to merge into the
target squad:

1. Walk toward the target squad's `mSquad_Join_TargetSprite`.
2. When distance ≤ `12 + 8 × (member_index)` pixels, `Squad_Join` fires.
3. The soldier's squad number is reassigned.
4. Grenades and rockets transfer from the old squad to the new one.
5. `Squad_Troops_Count` rebuilds all squad arrays.

Merging is blocked if the combined count would exceed 8.

### 4.8 Squad leader

The squad leader (`mSquads[n][0]`) has special roles:

- **Camera target** — the viewport centres on the leader.
- **Fire rotation base** — the leader fires every other turn in squads of 3+.
- **Accuracy bonus** — every 4th bullet from the leader has zero deviation.
- **Walk chain head** — the leader walks directly to the click target; all
  others follow the chain.

---

## 5. Rank & Promotion

### 5.1 Soldier data struct

```cpp
struct sMission_Troop {
    int16       mRecruitID;     // Index into global recruit list (-1 = empty)
    uint8       mRank;          // 0x00–0x0F (0–15)
    uint8       mPhaseCount;    // Phases survived this mission (reset each mission)
    sSprite*    mSprite;        // In-game sprite pointer
    uint16      field_6;        // Unused
    int8        mSelected;      // Selected in sidebar
    uint16      mNumberOfKills; // Lifetime kill count
};
```

Up to **9** soldiers allocated per mission (`mSoldiers_Allocated[9]`).

### 5.2 Rank range

Ranks are **0–15** (0x00–0x0F). Displayed as graphical icons — there are no
rank name strings in the original game. The rank icon is rendered from the
`RANKFONT` sprite sheet with the frame index equal to the rank value.

### 5.3 Promotion formula

```
new_rank = min(current_rank + phases_survived_this_mission, 15)
```

Promotion is **not kill-based** — soldiers rank up by **surviving mission
phases**. `mPhaseCount` increments each phase the soldier survives, resets to
0 at the start of each mission, and promotion is applied at the end-of-mission
service screen.

**Example:** A rank-2 soldier surviving a mission with 3 phases → rank 5.

### 5.4 Rank effects on weapon stats

The `mSprite_Bullet_UnitData[]` table (26 entries) is indexed by
`min(rank + 8, 15)`. This means:

- **Ranks 0–7** each have unique weapon stats (table indices 8–15).
- **Ranks 8–15** are all clamped to table index 15 — **identical weapon stats
  to rank 7**. These higher ranks are cosmetic/prestige only.

| Rank | Table Index | Bullet Speed | AliveTime (range) | Cooldown | Deviation (accuracy) |
| ---- | ----------- | ------------ | ------------------ | -------- | -------------------- |
| 0 | 8 | 105 | 7 | 5 | 15 |
| 1 | 9 | 110 | 7 | 5 | 15 |
| 2 | 10 | 130 | 6 | 5 | 15 |
| 3 | 11 | 125 | 7 | 5 | 7 |
| 4 | 12 | 125 | 7 | 4 | 7 |
| 5 | 13 | 130 | 7 | 4 | 7 |
| 6 | 14 | 115 | 8 | 4 | 7 |
| **7–15** | **15** | **120** | **8** | **4** | **7** |

Progression summary (rank 0 → rank 7):
- **Bullet speed:** 105 → 120 (14% faster)
- **Range (AliveTime):** 7 → 8 ticks (14% further)
- **Fire rate (Cooldown):** 5 → 4 ticks (20% faster)
- **Accuracy (Deviation):** 15 → 7 (half the scatter)

### 5.5 Squad leader accuracy bonus

Every 4th bullet fired by the squad leader has **zero deviation** (perfectly
accurate), regardless of rank. Other bullets use the rank-based deviation mask.

### 5.6 Table entries 0–7 (fallback)

Entries 0–7 are used when a sprite's `field_46_mission_troop` pointer is null
(no soldier data attached). These provide weak fallback stats. They are **not
used by enemies** — enemies have their own aggression-based formulas (see
[ENEMY_AI.md](ENEMY_AI.md)).

| Index | Speed | AliveTime | Cooldown | Deviation |
| ----- | ----- | --------- | -------- | --------- |
| 0 | 70 | 8 | 7 | 31 |
| 1 | 75 | 8 | 7 | 31 |
| 2 | 80 | 8 | 7 | 31 |
| 3 | 85 | 8 | 7 | 31 |
| 4 | 85 | 8 | 6 | 31 |
| 5 | 100 | 7 | 6 | 15 |
| 6 | 100 | 7 | 6 | 15 |
| 7 | 105 | 7 | 6 | 15 |

### 5.7 Unreachable super-soldier mode

The original code contains a mysterious block: if `rank > 0x14` (20) AND the
squad has only 1 member, they get: cooldown=1, bullet time modifier=−3, fire
speed +10. Since max rank is 15, this is **unreachable under normal gameplay**
— likely a debug/cheat leftover.

### 5.8 Bonus pickups

| Pickup | Sprite ID | Effect |
| ------ | --------- | ------ |
| Rank to General | 93 | Sets leader's rank to 15 |
| Bonus Rockets | 94 | Grants 50 rockets + homing flag |
| Armour | 95 | Grants invincibility flag |
| Homing+Invincibility (leader) | 96 | Rank 15 + homing + invincibility |
| Homing+Invincibility (squad) | 110 | All members: rank 15 + homing + invincibility |

### 5.9 On death

A soldier's rank resets to **0** on death. Their record is preserved in the
Heroes graveyard as `{recruitID, rank, kills}`, sorted by kills descending
then rank descending.

### 5.10 Sorting

Living soldiers are sorted by rank (descending), then by kills. This affects
squad ordering and the sidebar display.

### 5.11 Total recruits

The global recruit pool contains **360 names** (`Recruits.cpp`). Once all are
killed, the game is over.

---

## 6. Hit Detection

### 6.1 Collision boxes (asymmetric)

| Scenario | Box (relative to sprite pos) | Size |
| -------- | ---------------------------- | ---- |
| Player bullet → Enemy | (−6, −10) to (+10, +6) | 16×16 |
| Enemy bullet → Player | (0, −9) to (+6, −4) | 6×5 |

The asymmetry means **it's much easier to hit enemies than for enemies to hit
the player**.

### 6.2 Height check

Sprites at height ≥ 11 px (`field_20 >= 0x0B`) are immune to ground-level
projectile hits.

---

## 7. Death Sequence

1. **Impact:** `field_38` set to a `Hit`/`Die` state. A shadow sprite is
   created. A random death sound plays.
2. **Body launched:** Speed boosted by +15. Height controlled by `field_1A`
   (initial upward velocity). Body may rotate (50% chance). Blood trail.
3. **Gravity:** `field_1A -= 0x18000` each tick. When body reaches ground,
   it bounces: `velocity = −velocity >> 2`.
4. **On ground:** 1/128 chance per tick of twitching.
5. **Fade out:** Over 15 frames, sprite becomes invisible. At frame 7, the
   graphic is hidden. At frame 15, `Sprite_Troop_Dies()` finalises:
   - Increments kill score
   - Decrements `mTroops_Enemy_Count` (if enemy)
   - Credits the kill to the firing soldier

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

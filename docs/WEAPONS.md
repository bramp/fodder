# Weapons & Explosions

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> Covers all projectile types: bullets, grenades, rockets, missiles, and
> explosions.
>
> See also: [PLAYER.md](PLAYER.md) for rank-based weapon stats and squad fire
> rotation, [ENEMY_AI.md](ENEMY_AI.md) for enemy-specific weapon behaviour,
> [VEHICLES.md](VEHICLES.md) for vehicle-mounted weapons.

---

## 1. Bullets

### 1.1 Player bullet properties (by rank)

Player weapon stats come from the `mSprite_Bullet_UnitData[]` table, indexed
by `min(rank + 8, 15)`. See [PLAYER.md §5.4](PLAYER.md) for the full table.

Summary of the rank-accessible range:

| Rank | Speed | AliveTime (ticks) | Cooldown (ticks) | Deviation |
| ---- | ----- | ----------------- | ---------------- | --------- |
| 0 | 105 | 7 | 5 | 15 |
| 1 | 110 | 7 | 5 | 15 |
| 2 | 130 | 6 | 5 | 15 |
| 3 | 125 | 7 | 5 | 7 |
| 4 | 125 | 7 | 4 | 7 |
| 5 | 130 | 7 | 4 | 7 |
| 6 | 115 | 8 | 4 | 7 |
| 7–15 | 120 | 8 | 4 | 7 |

- **Speed:** Bullet travel velocity.
- **AliveTime:** Ticks the bullet exists — this is the effective range.
- **Cooldown:** Ticks between squad fire rotations.
- **Deviation:** Bitmask for random aim scatter (`randomValue & deviation`,
  randomly ±, applied to bullet direction angle). Lower = more accurate.

### 1.2 Enemy bullet properties

Enemies do **not** use the weapon data table. Their bullets use hardcoded
formulas based on aggression:

| Property | Formula |
| -------- | ------- |
| Speed | `60 + aggression` (range 60–90) |
| AliveTime | `(aggression >> 3) + 8`, capped at 16 |
| Spread | Fixed at 24 |

### 1.3 Bullet deviation / accuracy

- **Squad leader:** Every 4th bullet has **zero deviation** (perfectly
  accurate). Others use the rank-based deviation mask.
- **Non-leader soldiers:** Use `Mission_Troop_GetDeviatePotential()` which
  indexes the same table by rank.
- **Enemies:** Fixed deviation of 24.

### 1.4 Bullet limits

| Limit | Value |
| ----- | ----- |
| Max simultaneous bullets (per side) | **20** (0x14) |
| Post-fire cooldown on sprite | 8 ticks (`field_57`) |

### 1.5 Bullet initial speed

On creation, each bullet gets a random initial speed component:
`field_36 = (tool_RandomGet() & 0x0F) << 3` — range 0–120 in steps of 8.
This is independent of the weapon-data speed.

---

## 2. Grenades

### 2.1 Creation

| Property | Value |
| -------- | ----- |
| Max active (per side) | **2** |
| Initial speed | 50 (0x32) |
| Initial height | 7 px |
| Launch delay | 4 ticks (grenade stays attached to soldier) |
| Player range | Unlimited |
| Enemy range limit | 130 px (0x82) |
| Enemy chance to throw | 1/32 per fire event |
| Enemy grenade availability | After mission 4 |
| Ammo source | `mSquad_Grenades` pool |
| Pickup bonus | +4 grenades |

### 2.2 Arc physics

| Mechanic | Value |
| -------- | ----- |
| Gravity | `field_1A -= 0x18000` per tick (fixed-point) |
| Initial vertical velocity | `(lifetime << 16) >> 1`, capped at 0x0E0000 |
| Bounce | On ground contact: `velocity = −velocity / 2` |
| Speed decay | −1 per tick until 0 |
| Near target | Distance ≤ 1: speed = 0; ≤ 4: speed halved |
| Animation frame | `height >> 4` (0–3) |

### 2.3 Lifetime calculation

```
lifetime = distance_to_target / 5, capped at 100
         + random(0..15)
         + 28 (if enemy)
```

### 2.4 Detonation

| Condition | Result |
| --------- | ------ |
| `field_38` set (hit by something) | Explode |
| `field_12 == 0` (timer expired) | Explode |
| Bounce count ≥ 8 | **Dud** — destroyed without explosion |
| Bounce count < 8 | Explosion (`eSprite_Explosion`) |

### 2.5 Helicopter grenades

Grenades dropped from helicopters differ from soldier-thrown grenades:

| Property | Soldier grenade | Helicopter grenade |
| -------- | --------------- | ------------------ |
| Initial height | 7 px | Helicopter altitude + 2 |
| Initial vertical velocity | Calculated from distance | **0** (drops straight) |
| Enemy lifetime bonus | +28 ticks | +10 ticks |

---

## 3. Rockets

Fired by enemy rocket soldiers (`eSprite_Enemy_Rocket`, type 36) and as the
player's special weapon.

### 3.1 Properties

| Property | Value |
| -------- | ----- |
| Max active (per side) | **2** |
| Speed | 100 (0x64) |
| Initial height | 10 px (0x0A) |
| Launch delay | 6 ticks (`field_56`) — rocket stays attached to soldier |
| Enemy range limit | 130 px (0x82) |
| Impact distance | ≤ 7 px from target → explode |
| Sprite sheet | 0xA3 |
| 16-direction facing | Based on `field_10` |
| Sound | `eSound_Effect_Rocket` (0x2E), plays when delay expires |
| Ammo source | `mSquad_Rockets` pool |
| Pickup bonus | +4 rockets |

### 3.2 Player weapon selection

When the player fires the special weapon with rockets selected:

| Condition | Projectile |
| --------- | ---------- |
| Has homing flag (`field_75 & 1`) | `eSprite_MissileHoming2` (lock-on) |
| No homing flag | `eSprite_Missile` (straight) |

### 3.3 Enemy rocket soldiers

Enemy rocket soldiers fire `eSprite_Rocket` (ballistic). They:
- Disable bullet and grenade weapons (`field_54 = 3`)
- Have a minimum firing range of 24 px (won't fire point-blank)
- Always face the weapon target
- Use the standing-with-rocket animation when idle

---

## 4. Missiles

Missiles are vehicle-launched projectiles (tanks, turrets, jeeps, helicopters).
They are distinct from soldier-fired rockets.

### 4.1 Straight missiles

| Property | Value |
| -------- | ----- |
| Max active (per side) | **2** |
| Initial speed | Inherited from launcher's `field_36` |
| Acceleration | `field_3A` doubles every 4 ticks, added to speed |
| Max speed | 96 (0x60) |
| Gravity | `field_1E_Big -= 0xA000` when height > 4 px |
| Terrain collision | Enabled (`field_32 = -1`) |
| On impact | Becomes `eSprite_Explosion2` (large explosion), Y−4 offset |
| Sprite sheet | 0xA3 |
| Shadow | `eSprite_ShadowSmall` |
| Sound | `eSound_Effect_Missile_Launch` (0x2D), volume 0x0F |

### 4.2 Homing missiles

| Property | Value |
| -------- | ----- |
| Target tracking | Via `field_1A_sprite` (target sprite pointer) |
| Explode distance | ≤ `(speed / 16) + 1` from target |
| Height tracking | ±0x8000 to ±0x28000 per tick (fixed-point) |
| Human max speed | 60 (0x3C) |
| Human turn rate | Starts at `field_6A = 0x10000`, +0x200 per tick |
| Enemy turn rate | Starts at `field_6A = 0x400` (much slower) |
| Enemy heli-launched | `field_6A = 0x2000` (faster than ground turret) |
| Direction change penalty | Speed −2/tick (min 0), turn rate resets to 0 |
| Fire trail | Created each tick while in flight |
| Target lost | Speed +2/tick, altitude −2 until crash |

### 4.3 Lock-on

- Player aims the mouse cursor near a lockable target.
- **Lock distance:** 22 px (0x16) from cursor to target centre.
- **Lockable targets:** enemy soldiers (type 5), all helicopter types (40–44,
  107), tanks (65, 69), vehicles (63–64, 80–82), turrets, computers, etc.

---

## 5. Bullets vs Grenades vs Rockets — Comparison

| Property | Bullet | Grenade | Rocket | Missile |
| -------- | ------ | ------- | ------ | ------- |
| Max active (per side) | 20 | 2 | 2 | 2 |
| Fired by | Soldiers | Soldiers, helis | Soldiers | Vehicles, turrets |
| Trajectory | Straight | Arc (gravity) | Straight | Straight / homing |
| Speed | 70–130 (rank) | 50 | 100 | Up to 96 |
| Explosion on impact | No | Yes | Yes | Yes (large) |
| Area damage | No | Via explosion | Via explosion | Via explosion |
| Ammo limited | No (infinite) | Yes (per squad) | Yes (per squad) | Vehicle-based |
| Controls | Right-click | Left+Right | Left+Right | Right-click in vehicle |
| Enemy accuracy | Fixed 24 spread | N/A | N/A | N/A |

---

## 6. Explosions

### 6.1 Visual sizes

| Sprite sheet | Type | Frames |
| ------------ | ---- | ------ |
| 0x8E | Regular | 7 |
| 0xC0 | Large (aerial / upgraded) | 4 |

If the explosion is airborne (`field_20 > 0`) and frame ≥ 2, it upgrades from
regular to large.

### 6.2 Damage area

The initial damage box (relative to explosion sprite position):

| Edge | Offset |
| ---- | ------ |
| X Left | sprite.X + 8 |
| X Right | sprite.X + 0x24 (36) |
| Y Top | sprite.Y − 0x20 (−32) |
| Y Bottom | sprite.Y − 6 |

The box grows/shrinks each frame using `mSprite_Explosion_Area_PerFrame[]`:
```
5, 7, 0, 0, 1, 4, 2, 3, 1, 0,
1, 0, 0, -1, -2, -2, -1, -5, -2, 1,
1, 2, 1, 0, 1, -1, 0, -1
```
Each pair is (X-left-shrink, X-right-shrink) applied cumulatively per frame.

### 6.3 Damage alternation

- **Even ticks:** damages player squad.
- **Odd ticks:** damages enemies.
- Toggle via `field_62 = ~field_62`.

Explosions are **faction-neutral** — they damage both sides on alternating
frames.

### 6.4 Tile destruction

Explosions check **25 surrounding tile positions** for destructible terrain
using `mSprite_Explosion_Positions[]`:

```
{0,0}, {16,16}, {-16,-32}, {-16,16}, {32,-16},
{-32,32}, {32,-16}, {-16,16}, {-16,-32}, {48,48},
{-64,-48}, {48,-16}, {-32,64}, {48,-64}, {0,32},
{-48,-32}, {-16,48}, {64,-32}, {-32,48}, {0,-64},
{-32,32}, {48,32}, {-48,-64}, {64,48}, {-64,16}
```

Destructible tiles trigger **chain explosions**. Building doors can be blown
open (`Sprite_Handle_BuildingDoor_Explode`).

---

## 7. Sprite Type Reference

| ID | Constant | Category |
| -- | -------- | -------- |
| 2 | `eSprite_Grenade` | Grenade projectile |
| 12 | `eSprite_Explosion` | Standard explosion |
| 33 | `eSprite_Rocket` | Enemy rocket projectile |
| 37 | `eSprite_GrenadeBox` | Grenade ammo pickup |
| 38 | `eSprite_RocketBox` | Rocket ammo pickup |
| 39 | `eSprite_Building_Explosion` | Building destruction |
| 45 | `eSprite_Missile` | Straight missile |
| 46 | `eSprite_MissileHoming` | Homing missile |
| 77 | `eSprite_Cannon` | Cannon/jeep projectile |
| 89 | `eSprite_Explosion2` | Large / aerial explosion |
| 97 | `eSprite_MissileHoming2` | Homing missile alt. (player rocket) |

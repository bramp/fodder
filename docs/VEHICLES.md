# Vehicles — Helicopters, Tanks, Jeeps & Turrets

> Derived from the OpenFodder C++ source code (`vendor/openfodder/Source/`).
> Covers all driveable vehicles and stationary turrets: properties, weapons,
> AI behaviour, and enter/exit mechanics.
>
> See also: [WEAPONS.md](WEAPONS.md) for missile/grenade projectile details,
> [ENGINE.md](ENGINE.md) for direction and timing fundamentals.

---

## 1. Vehicle Type Enum

| Constant | Value | Category |
| -------- | ----- | -------- |
| `eVehicle_Turret_Cannon` | 0 | Stationary |
| `eVehicle_Turret_Missile` | 1 | Stationary |
| `eVehicle_Jeep` | 2 | Ground (unarmed) |
| `eVehicle_JeepRocket` | 3 | Ground (armed) |
| `eVehicle_Tank` | 4 | Ground |
| `eVehicle_Helicopter` | 5 | Air (unarmed) |
| `eVehicle_Helicopter_Grenade` | 6 | Air |
| `eVehicle_Helicopter_Missile` | 7 | Air |
| `eVehicle_Helicopter_Homing` | 8 | Air |
| `eVehicle_Turret_Homing` | 9 | Stationary |
| `eVehicle_DontTargetPlayer` | 10 | Special |

---

## 2. Helicopters

### 2.1 Core flight

| Mechanic | Value | Notes |
| -------- | ----- | ----- |
| Cruise altitude | **32 px** (0x20) | Climbs until `field_20 ≥ 0x20` |
| Climb rate | `field_1E_Big += 0x18000` | Per tick during ascent |
| Max speed | **48** (0x30) | `field_36`, increases by 2/tick |
| Approach deceleration | `speed = distance / 2` | When distance < 96 px (0x60) |
| Landing descent | `field_1E_Big -= 0xC000` | Per tick when landing |
| Rotor animation | 4 frames | `field_A = (field_A + 1) & 3` every tick |
| Shadow sprite | Sheet 0x8D | Size = `min(height >> 4, 2)` |
| Run-over zone | X to X+30, Y−20 to Y | Kills troops underneath |
| Crash → explosion | `eSprite_Explosion` | + propeller crash sprite in random dir |
| Sounds | `{4, 51, 52, 53, 54, 4, 51, 52}` | Played when `field_20 ≥ 2` |

### 2.2 Terrain clearance

| Terrain | Minimum height |
| ------- | -------------- |
| Rocky, QuickSand, Water, Sink | 12 px (0x0C) |
| BounceOff (block) | 20 px (0x14) |
| Rocky2, Drop, Drop2 | 14 px (0x0E) |

If below minimum → height rises by 1/tick.

### 2.3 Human helicopter weapons

**Prerequisite:** Altitude > 31 px (0x1F).

| Weapon variant | `field_6F` value | Action |
| -------------- | ---------------- | ------ |
| Grenade | `eVehicle_Helicopter_Grenade` | Drops grenade (straight down) |
| Missile | `eVehicle_Helicopter_Missile` | Fires straight missile, offset X=14, Y=−12 |
| Homing | `eVehicle_Helicopter_Homing` | Fires homing missile, same offsets + lock-on |

### 2.4 Enemy helicopter AI

| Mechanic | Value |
| -------- | ----- |
| **Invulnerable to bullets** | Yes — hit animation immediately cleared |
| Aggression accumulation | +1 + AggressionAverage per evaluation cycle |
| Attack threshold | 500 (0x1F4) — 50% attack, 50% reposition |
| Detection range | 250 px (0xFA) |
| Cooldown after repositioning | 90 ticks (0x5A) |
| Troop drop | 1/16 random chance when altitude = 0 |
| Flashing light | Child sprite at `mSprite_Helicopter_Light_Positions[]` |

**Enemy helicopter weapon firing:**

| Variant | Condition | Details |
| ------- | --------- | ------- |
| Grenade | Every 16 ticks (`EngineTicks & 0x0F`) | Targets player squad; 1/16 chance to stop |
| Missile | Distance 60–140 px, alt ≥ 25 px, every 16 ticks | Straight missile |
| Homing | Same as missile + `field_6A = 0x2000`, speed 20 | Faster turn than ground homing |

### 2.5 Helicopter call pad

- **Pad sprite:** Sheet 0xE7, animates 4 frames: `{1, 2, 3, 2}`.
- **Troop-in-range check:** Distance < 9 px from pad centre.
- **Called helicopter:** Flies to `mHelicopterCall_X/Y`; when distance < 44 px
  (0x2C), lands (`field_75 = −1`, `field_6E = −1`).

### 2.6 Sprite types

| ID | Constant | Description |
| -- | -------- | ----------- |
| 40 | `eSprite_Helicopter_Grenade_Enemy` | Enemy heli w/ grenades |
| 42 | `eSprite_Helicopter_Unarmed_Enemy` | Enemy heli unarmed |
| 43 | `eSprite_Helicopter_Missile_Enemy` | Enemy heli w/ missiles |
| 44 | `eSprite_Helicopter_Homing_Enemy` | Enemy heli w/ homing |
| 49 | `eSprite_Helicopter_Grenade_Human` | Human heli w/ grenades |
| 50 | `eSprite_Helicopter_Unarmed_Human` | Human heli unarmed |
| 51 | `eSprite_Helicopter_Missile_Human` | Human heli w/ missiles |
| 52 | `eSprite_Helicopter_Homing_Human` | Human heli w/ homing |
| 53 | `eSprite_Helicopter_PropCrash` | Crashing rotor blade |
| 99 | `eSprite_Helicopter_CallPad` | Landing pad |
| 101–104 | `eSprite_Helicopter_*_Human_Called` | Called variants |
| 107 | `eSprite_Helicopter_Homing_Enemy2` | Alt. enemy homing heli |

---

## 3. Tanks

### 3.1 Movement

| Mechanic | Value |
| -------- | ----- |
| Max speed | **24** (0x18) |
| Acceleration | +1 every 2 ticks (when distance ≥ 30 px) |
| Near deceleration | `speed = distance` (when distance < speed) |
| Run-over zone | X to X+30, Y−20 to Y, height range 0–14 |
| Smoke trail | Creates `eSprite_Draw_First` sprite each tick |
| 16-direction facing | Based on target bearing |
| Sprite sheets | 0xD1 (body), 0xD2 (turret at pSprite+1) |

### 3.2 Tank weapon — missiles

| Property | Value |
| -------- | ----- |
| Projectile | `eSprite_Missile` (straight) |
| Launch offset | `mSprite_Turret_Positions[direction]` (16 entries) |
| Missile height | `field_20 + 17` (17 px above tank) |
| Missile speed | 60 (0x3C) |
| Sound | Effect 5, volume 0x1E |

**Turret position offsets** (16 directions):
```
{ 0,7  -9,6  -14,3  -16,0  -19,-7  -19,-12  -16,-16  -10,-20
  -2,-22  6,-20  12,-15  16,-12  18,-6  16,0  12,2  6,5 }
```

### 3.3 Human tank

- **Indestructible** — `Die1` animation is reset to `Anim_None`.
- Uses same movement and missile code as enemy tanks.

### 3.4 Enemy tank AI

| Mechanic | Value |
| -------- | ----- |
| Detection range | 250 px |
| Cannot traverse | Water, QuickSand |
| Line-of-sight check | Path tracing to target |
| Fire chance | 1/32 random (when distance > 50 px) |
| Cooldown after reposition | 90 ticks (0x5A) |

### 3.5 Sprite types

| ID | Constant | Description |
| -- | -------- | ----------- |
| 65 | `eSprite_Tank_Human` | Human tank |
| 69 | `eSprite_Tank_Enemy` | Enemy tank |

---

## 4. Jeeps

### 4.1 Unarmed jeep (`eVehicle_Jeep` = 2)

Basic transport, no offensive capability. Controlled via `Vehicle_Input_Handle`.

### 4.2 Armed jeep (`eVehicle_JeepRocket` = 3)

| Property | Value |
| -------- | ----- |
| Projectile | `eSprite_Cannon` |
| Initial upward | `field_1E_Big += 0x60000` |
| Cannon speed | Vehicle speed + 80 (0x50) |
| Max active | 20 per person type |

### 4.3 Sprite types

| ID | Constant | Description |
| -- | -------- | ----------- |
| 63 | `eSprite_VehicleNoGun_Human` | Human jeep (unarmed) |
| 64 | `eSprite_VehicleGun_Human` | Human jeep (armed) |
| 80 | `eSprite_VehicleNoGun_Enemy` | Enemy jeep (unarmed) |
| 81 | `eSprite_VehicleGun_Enemy` | Enemy jeep (armed) |

---

## 5. Turrets

### 5.1 General mechanics

| Mechanic | Value |
| -------- | ----- |
| Detection range | 210 px (0xD2) |
| Fire range (close) | < 40 px — always fires |
| Fire range (far) | Path must be clear |
| Fire chance | 1/32 or 1/64 (based on aggression) |
| Fire sound | `eSound_Effect_Turret_Fire` (0x2C), volume 0x1E |
| Missile properties | Height +17, speed 60 |
| Turret types | Cannon (0), Missile (1), Homing (9) |

### 5.2 Invulnerable turrets

Some turrets are indestructible: `field_38` is reset to `None` on hit. These
include `eSprite_Turret_Cannon_Invulnerable` (112) and
`eSprite_Turret_Missile_Invulnerable` (113). Also, turrets on Moors/Interior
tilesets in CF1 are invulnerable.

### 5.3 Sprite types

| ID | Constant | Description |
| -- | -------- | ----------- |
| 78 | `eSprite_Turret_Missile_Human` | Human missile turret |
| 79 | `eSprite_Turret_Missile2_Human` | Human missile turret variant |
| 105 | `eSprite_Turret_HomingMissile_Enemy` | Enemy homing turret |
| 112 | `eSprite_Turret_Cannon_Invulnerable` | Indestructible cannon |
| 113 | `eSprite_Turret_Missile_Invulnerable` | Indestructible missile |

---

## 6. Vehicle Enter / Exit

### 6.1 Entering

| Mechanic | Value |
| -------- | ----- |
| Entry distance | 13 px (0x0D) from vehicle centre |
| Vehicle centre offset | X+16 (turrets: X+4), Y−9 |
| In-vehicle flag | `field_6E = −1`, `field_6A_sprite = vehicle` |
| Timer | `mSquad_EnteredVehicleTimer = 400` ticks (0x190) |
| Entry animation | `eSprite_Anim_Vehicle_Enter` (0x5A) |
| Inside animation | `eSprite_Anim_Vehicle_Inside` (0x5B) |
| Terrain check | Must be walkable around vehicle |

### 6.2 Exiting

- Exit position: Vehicle X + 15, Vehicle Y − 10 (non-turret).
- Turret exit: at vehicle position directly.
- Movement target set to exit pos − 6 (X), + 16 (Y).
- On vehicle destruction: soldier ejected with random direction, `Hit`
  animation.

### 6.3 Vehicle input (when riding)

- Left-click sets movement target (`field_26`/`field_28`) to mouse world pos.
- Camera offset: X−28, Y+6 (clamped: Y ≥ 20).
- Helicopter extra offset: Y+32 when near destination (`field_50 ≤ 8`).

---

## 7. Vehicle Sinking

When a vehicle enters water:

| Mechanic | Value |
| -------- | ----- |
| Sound | `eSound_Effect_Vehicle_Sinking` (0x2B), volume 0x0F |
| Sinking animation type 1 | Sheet 0xDE, frame 4, counts down frames |
| Sinking animation type 2 | Sheet 0xDF, frame 0, counts up to 6 then destroyed |
| Bubble position | Vehicle position ± random jitter (X: ±31, Y: 0–15) |

Tanks **cannot traverse** water or quicksand.

---

## 8. Looping Vehicles

Background/scripted vehicles that travel in one direction continuously:

| ID | Constant | Direction |
| -- | -------- | --------- |
| 114 | `eSprite_Looping_Vehicle_Left` | Left |
| 115 | `eSprite_Looping_Vehicle_Right` | Right |
| 116 | `eSprite_Looping_Vehicle_Up` | Up |
| 117 | `eSprite_Looping_Vehicle_Down` | Down |

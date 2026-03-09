# Fodder Game — Implementation TODO

Comprehensive checklist derived from [ENGINE.md](../../docs/ENGINE.md),
[PLAYER.md](../../docs/PLAYER.md), [ENEMY_AI.md](../../docs/ENEMY_AI.md), and
[TERRAIN_AND_OBJECTS.md](../../docs/TERRAIN_AND_OBJECTS.md).

Legend: ✅ = implemented, 🔶 = partial, ❌ = not started

---

## 1. Engine Fundamentals (ENGINE.md)

### 1.1 Timing

- [x] Engine tick system (50 Hz interrupt, 3 interrupts per tick ≈ 16.67 ticks/sec, ~60 ms/tick)
- [x] Currently using real-time `dt`; all spec tick values converted in `game_config.dart`
- [ ] `mMission_EngineTicks` counter incrementing once per engine loop

### 1.2 Coordinate System

- [x] Map tiles are 16×16 px (rendered at 2× = 32×32)
- [x] Sub-tile walkability uses 8×8 grid per tile
- [ ] 🔶 World positions use pixel floats; spec uses 16.16 fixed-point
- [ ] Height system: `field_1E_Big` (32-bit fixed-point height), `field_20` (pixel height above ground)

### 1.3 Direction System

- [x] 8-direction enum (`Direction8`) for animation selection
- [ ] 512-unit direction circle (0x000–0x1FE, even values only, 256 effective)
- [ ] Direction vector table (`mDirectionVectorTable[256]`) — sine lookup for movement deltas
- [ ] `Direction_Between_Points()` — 32×32 lookup table for dx/dy → direction
- [ ] Smooth turning interpolation via `mDirectionStepTable` (`field_3C` → `field_10`)
- [ ] Speed-direction modifier when firing while moving (24/20/14/10/8/10/14/20)

### 1.4 Sprite Limits

- [ ] Max 45 sprites total (`mSpritesMax`)
- [ ] General allocation range indices 0–42
- [ ] Bullet/low-priority range indices 0–29
- [ ] Reserved text overlay indices 40–42
- [ ] Sentinel sprite at index 44
- [x] Max 10 enemies on map (spawn cap — referenced in enemy spawning)

### 1.5 Person Types

- [x] 🔶 Faction enum exists (`player`/`enemy`); spec has 3 types: Human(0), AI(1), Native(2)
- [ ] Native person type for civilians/hostages

### 1.6 Sprite Struct Fields

- [ ] Most `sSprite` fields not modelled (`field_0` through `field_75`)
- [ ] `field_46` union (mission troop pointer / sprite pointer / raw int32)
- [ ] In-vehicle flag (`field_6E`), vehicle type (`field_6F`)
- [ ] Homing flag (`field_75 & 0x01`), invincibility flag (`field_75 & 0x02`)

### 1.7 Animation Groups

- [x] Walk (8 dirs), Firing (8 dirs), Throw (8 dirs), Death (8 dirs), Death2 (8 dirs)
- [x] Prone animation (8 dirs: player 0x10–0x17, enemy 0x52–0x59)
- [x] Swim animation (8 dirs: player 0x18–0x1F, enemy 0x5A–0x61)
- [ ] Death3 animation (8 dirs: player 0x30–0x37, enemy 0x72–0x79) — not in atlas
- [ ] Rocket animation (8 dirs: player 0x39–0x40, enemy 0xA8–0xAF) — not in atlas
- [ ] Slide animations (`eSprite_Anim_Slide1–3`, values 0x32–0x34) — not in atlas

---

## 2. Player Soldiers (PLAYER.md)

### 2.1 Health & Survivability

- [x] One-hit kill (no hitpoints)
- [x] Dodge mechanic: moving soldiers have 1/8 chance to dodge bullets
- [x] Dodge blocked when stationary
- [ ] Dodge works in water or sinking (`field_52 ≥ 5`)
- [x] Dodge blocked at very close range (`field_3A ≤ 4` → bullet age ≤ 0.24s)
- [ ] Invincibility flag (`field_75 & 0x02`) from bonus pickups

### 2.2 Death Animation States

- [x] Standard bullet death — random death/death2 variant
- [ ] Run-over / explosion death (`eSprite_Anim_Die1`)
- [ ] Drowning death (`eSprite_Anim_Die3`)
- [ ] Spike death (`eSprite_Anim_Die5`)
- [ ] Terrain sliding (`eSprite_Anim_Slide1–3`)

### 2.3 Movement Speeds

- [x] Player speed determined by squad's SpeedMode (halted/normal/running)
- [x] Halted/slow: 8 (mode 0) → 40 px/s
- [x] Normal walk: 16 (mode 1) → 80 px/s
- [x] Running (default): 24 (mode 2) → 120 px/s
- [x] In water/sinking: forced to 6 → 30 px/s
- [x] Speed modes switchable per squad (starts at mode 2 = running)

### 2.4 Controls

- [x] Left-click → set walk target (waypoint)
- [x] Right-click → set weapon target (fire at position)
- [ ] Left+Right simultaneously → fire special weapon (grenade or rocket)
- [ ] First shot on right-click fires immediately (cooldown override)
- [ ] Squad switching (Tab / number keys)

### 2.5 Auto-fire (Non-Selected Squads)

- [ ] Detection range: 210 px
- [ ] Always-engage range: 40 px
- [ ] Line-of-sight required between 40–210 px
- [ ] 1/32 ignore chance per tick (prevents constant firing)

### 2.6 Squads

- [x] Max 3 squads (indices 0–2) — `Squad` model created
- [x] Max 8 soldiers per squad
- [x] Max 9 soldiers per mission (total across all squads)
- [x] 30 waypoints per squad walk queue (constant defined)
- [ ] Squad split and merge (merge blocked if combined > 8)
- [ ] Multiple player soldiers moving as a group

### 2.7 Fire Rotation

- [x] Squad members take turns firing (rotation pattern arrays)
- [x] Squad leader (index 0) fires every other turn in squads of 3+
- [x] `-1` sentinel marks end, pattern loops
- [x] Fire cooldown between rotations: `mSprite_Weapon_Data.mCooldown` ticks (3–7 by rank)

### 2.8 Ammo Pools

- [x] Shared per squad (not per soldier)
- [x] Grenades: soldiers × 2 (available after mission 4 CF1, mission 3 CF2)
- [x] Rockets: soldiers × 1 (available after mission 5 CF1, mission 4 CF2)
- [ ] Campaign override for ammo values
- [ ] Grenade box pickup: +4 grenades (sprite type 37)
- [ ] Rocket box pickup: +4 rockets (sprite type 38)

### 2.9 Rank & Promotion

- [ ] Reverse engineer the rank names PLAYER.md 5.2 Rank range - This might be easier found online?
- [x] `sMission_Troop` struct: recruitID, rank (0–15), phaseCount, sprite, kills
- [x] Up to 9 soldiers allocated per mission
- [ ] Rank icons from `RANKFONT` sprite sheet (frame index = rank)
- [x] Promotion formula: `new_rank = min(current_rank + phases_survived, 15)`
- [x] Promotion is phase-survival-based, NOT kill-based
- [x] `phaseCount` increments each phase survived, resets each mission

### 2.10 Rank Effects on Weapon Stats

- [x] `mSprite_Bullet_UnitData[26]` table indexed by `min(rank + 8, 15)`
- [x] Ranks 0–7 have unique weapon stats (table indices 8–15)
- [x] Ranks 8–15 clamp to index 15 (same as rank 7, cosmetic prestige)
- [x] Bullet speed: 105 → 120 (rank 0 → 7)
- [x] Alive time (range): 7 → 8 ticks
- [x] Cooldown: 5 → 4 ticks
- [x] Deviation (accuracy): 15 → 7

### 2.11 Squad Leader Accuracy Bonus

- [ ] Every 4th bullet from squad leader has zero deviation (perfectly accurate)

### 2.12 Bonus Pickups

- [ ] Rank to General (sprite 93): leader rank → 15
- [ ] Bonus Rockets (sprite 94): +50 rockets + homing flag
- [ ] Armour (sprite 95): invincibility
- [ ] Homing+Invincibility leader (sprite 96): rank 15 + homing + invincibility
- [ ] Homing+Invincibility squad (sprite 110): all members rank 15 + homing + invincibility

### 2.13 Death & Graveyard

- [x] Death triggers removal
- [ ] Rank resets to 0 on death
- [ ] Heroes graveyard: `{recruitID, rank, kills}`, sorted by kills desc then rank desc
- [ ] Living soldiers sorted by rank desc, then kills (sidebar display)
- [ ] 360 total recruits — game over when all killed

### 2.14 Hit Detection

- [x] Player bullet → Enemy hitbox: 16×16
- [x] Enemy bullet → Player hitbox: 6×5
- [ ] Height check: sprites at height ≥ 11 px immune to ground-level projectiles

### 2.15 Death Sequence (Full)

- [x] 🔶 Random death anim + fade — spec has multi-step physics:
- [ ] Shadow sprite created on impact
- [ ] Random death sound
- [ ] Body speed boosted by +15
- [ ] Height controlled by `field_1A` (upward velocity)
- [ ] 50% chance body rotates
- [ ] Blood trail created
- [ ] Gravity: `field_1A -= 0x18000` each tick
- [ ] Bounce on ground: `velocity = -velocity >> 2`
- [ ] 1/128 chance per tick of twitching on ground
- [ ] 15-frame fade out; graphic hidden at frame 7; finalised at frame 15
- [ ] Kill score credited to firing soldier

---

## 3. Enemy AI (ENEMY_AI.md)

### 3.1 Enemy Types

- [x] Basic soldier (type 5) — walks, shoots
- [ ] Rocket soldier (type 36) — rockets only, no bullets/grenades, min range 24 px
- [ ] Enemy leader (type 106) — hostage behaviour, flashing light child sprite
- [ ] Separate animation group for rocket soldiers (standing-with-rocket idle)

### 3.2 Static Spawning

- [x] Enemies placed from `.spt` data (Tiled "Sprites" layer)
- [x] Staggered initial fire timers (+0.5s per enemy ≈ +0x0A ticks)
- [x] High aggression (>4) enemies fire immediately (delay = 0)

### 3.3 Dynamic Spawning (Buildings)

- [ ] Building door sprites (types 20, 25, 88, 100)
- [ ] Gate check: no spawn if `mTroops_Enemy_Count >= mSpawnEnemyMax` (10)
- [ ] Door open/close animation cycle
- [ ] Random countdown timer (`field_43`, 6–21 ticks)
- [ ] Spawn up to 3 enemies per door-open cycle (at ticks 0x14 and 0x0A)
- [ ] Delay between cycles: `(0x14 − AggressionMax) × 8 + random(0..15)`
- [ ] Aggression escalation: every 16 dynamic spawns, `AggressionMax++` (up to 0x1E)
- [ ] Reinforced door (type 100): only destroyed by explosions
- [ ] `Sprite_Create_Enemy()` details: position offset, random direction, movement delay, target delay

### 3.4 AI Loop

- [x] Per-frame `update()` loop for each enemy
- [x] Skip AI when dying
- [x] 🔶 Three-state machine (idle/chasing/firing); spec has implicit states from targeting
- [ ] `field_44 > 0` spawn delay: wander in random direction before AI activates
- [ ] Full 8-step per-frame process matching original order

### 3.5 Aggression System

- [x] Ping-pong assignment: range [4, 8], start at midpoint
- [ ] Per-mission configurable aggression range (min, max)
- [ ] Aggression escalation from dynamic spawning

### 3.6 Detection & Targeting

- [x] Max detection range: 200 px
- [x] Close range: 64 px (engage even without LOS)
- [x] Line-of-sight check between 64–200 px
- [ ] Always-engage range: 40 px (spec has separate 40 px threshold)
- [ ] Target selection cycles through squad member indices (0–29)
- [ ] 1/64 random chance to skip valid target (unpredictability)
- [ ] Target spreading: offset based on sprite index (`sprite_index × 0x76`)
- [ ] Idle scan: 1/16 chance per tick of random nudge to weapon aim direction

### 3.7 Enemy Movement

- [x] Speed: `(12 + aggression)`, capped at 26 (× 5 = px/s)
- [ ] Smooth direction turning (not instant snap)
- [x] Post-fire pause: 15 ticks (0.9s) for bullets, 12 ticks for grenades
- [ ] Collision avoidance: nudge direction on bump with squad member
- [x] No patrol behaviour (confirmed correct: idle when no target)

### 3.8 Enemy Weapons (Basic Soldier)

- [x] Bullet speed: `60 + aggression`
- [x] Bullet lifetime: `((aggression >> 3) + 8)` ticks, capped 8–16
- [ ] Bullet spread: fixed at 24 (deviation not implemented)
- [ ] Max 20 concurrent enemy bullets
- [ ] Grenade: 1/32 chance per fire, range < 130 px, 12-tick pause
- [ ] Grenades available only after mission 4

### 3.9 Enemy Weapons (Rocket Soldier)

- [ ] Only fires rockets (bullets and grenades disabled)
- [ ] Minimum firing range: 24 px
- [ ] Always faces weapon target
- [ ] Standing-with-rocket animation when idle

### 3.10 Separate Walk/Weapon Targets

- [ ] Walk target: player position + spread offset
- [ ] Weapon target: exact player position
- [ ] Enemies fire at player while walking slightly to the side

### 3.11 Hit Detection & Death

- [x] 1-hit kill
- [x] Death animation with fade-out
- [ ] Full death sequence (shadow, launch, gravity, bounce, twitch, 15-frame fade)
- [ ] Kill score credited to firing soldier
- [ ] `mTroops_Enemy_Count` decrement on death (allows building respawns)

---

## 4. Terrain & Map Objects (TERRAIN_AND_OBJECTS.md)

### 4.1 Terrain Types

- [x] 15 terrain types defined in `TerrainType` enum
- [x] `block` (type 3) blocks walking
- [ ] `rocky` (type 1): elevate soldier height (toggle 0→1→2)
- [ ] `rocky2` (type 2): elevate height up to 6
- [ ] `quickSand` (type 4): movement penalty (`field_50 = 3`)
- [x] `waterEdge` (type 5): heavier movement penalty (`field_50 = 6`)
- [x] `water` (type 6): in-water flag, speed → 6, natives immune
- [ ] `snow` (type 7): reduce unit speed
- [ ] `quickSandEdge` (type 8): 1/64 chance per tick of slide animation
- [x] `drop` (type 9): fall counter, gravity slide, death at ≥ 12 ticks
- [x] `drop2` (type 10): stumble animation (same as drop in remake)
- [ ] `sink` (type 11): human sinking

### 4.2 Water Mechanics

- [x] In-water flag (`field_4F = -1`)
- [x] All units in water have speed forced to 6
- [ ] Natives immune to drowning
- [ ] Soldiers sink gradually (`field_52` increases)
- [ ] At `field_52 ≥ 5`, dodge roll vs bullets
- [x] Swimming animation (8 dirs)

### 4.3 Terrain Vehicle Effects

- [ ] Tanks cannot traverse Water or QuickSand tiles
- [ ] Helicopters have minimum altitude over certain terrain
- [ ] Vehicles entering water trigger sinking animation/sound

### 4.4 Height from Terrain

- [ ] Rocky terrain elevates soldiers (pseudo-3D)
- [x] Drop/Drop2: enemies/natives bounced back, players fall (survive short drops)

### 4.5 Civilians

- [ ] Basic civilian (type 61): speed 6, wanders near doors
- [ ] Faster civilian (type 62): speed 10
- [ ] Spear native (type 70): attacks players
- [ ] Spear projectile (type 71)
- [ ] Invisible civilian (type 83)
- [ ] PersonType_Native (2) and sprite sheet 0xD0
- [ ] Civilian door interaction (open/close)

### 4.6 Civilian Spawning Doors

- [ ] Door_Civilian (type 74): spawns type 61
- [ ] Door2_Civilian (type 75): spawns type 62
- [ ] Door_Civilian_Spear (type 76): spawns type 70
- [ ] Door_Civilian_Rescue (type 90): spawns rescue-objective civilian

### 4.7 Hostages

- [ ] Hostage (type 72): speed 12
- [ ] Rescue tent (type 73): stationary
- [ ] Hostage walks toward tent (target X = tent.X+10, Y = tent.Y−5)
- [ ] Distance < 3 px → hostage destroyed, `mHostage_Count` decremented
- [ ] Enemy captures hostage (follow link)
- [ ] Player nearby → hostage follows player (target = player.X+4, Y−6)
- [ ] Hostage can enter stopped vehicles (distance ≤ 10, speed ≤ 2, height ≤ 3)

### 4.8 Enemy Leader

- [ ] Type 106: delegates to hostage handler
- [ ] Flashing light child sprite
- [ ] "Kidnap Leader" mission objective

### 4.9 Building Doors (Enemy Spawner)

- [ ] Standard door (type 20)
- [ ] Door variant 2 (type 25)
- [ ] Door variant 3 (type 88)
- [ ] Reinforced door (type 100): only destroyed by explosions
- [ ] Timer: `base = (20 − aggressionMax) × 8 + random(0..15)`
- [ ] Spawn up to 2 enemies per door-open cycle (at ticks 0x14 and 0x0A)
- [ ] Max enemies: `mSpawnEnemyMax` (default 10)

### 4.10 Pickups

- [ ] Grenade box (type 37): +4 grenades
- [ ] Rocket box (type 38): +4 rockets
- [ ] Rank to General (type 93): leader rank → 15
- [ ] Bonus Rockets (type 94): +50 rockets + homing
- [ ] Armour (type 95): invincibility
- [ ] Homing+Invincibility leader (type 96)
- [ ] Homing+Invincibility squad (type 110)

### 4.11 Hazards

- [ ] Proximity mine (type 54): explodes on contact
- [ ] Mine2 (type 55)
- [ ] Spike trap (type 56): spike death animation
- [ ] Boiling pot (type 60): environmental hazard
- [ ] Seal mine (type 91): seal carrying a mine
- [ ] Spider mine (type 92): mobile mine

### 4.12 Environment Decorations (copt atlas)

- [x] Shrub overlay (type 13, atlas frame `8f_0`)
- [x] Tree-top overlay (type 14, atlas frame `90_0`)
- [ ] Building roof overlay (type 15, atlas frame `91_0`) — untested, no CF1 maps use it
- [ ] Snowman decoration (type 16, atlas frame `92_0`) — untested, no CF1 maps use it
- [ ] Shrub2 overlay (type 17, atlas frame `93_0`) — untested, no CF1 maps use it
- [ ] Waterfall animation (type 18) — not yet implemented
- [x] Bird animation (type 66) — basic flight, ping-pong animation, offscreen respawn
- [ ] Explodable environment sprites: explosions should destroy types 13–17
- [ ] Y-sort environment sprites with soldiers (currently fixed priority 15)
- [ ] Load copt atlas (`juncopt.json`/`juncopt.png`) once and share between `BulletSprites` and `EnvironmentSprite`
- [ ] Let's ensure packages/fodder_tools/lib/sprite_names.dart lists every available sprite.

### 4.13 Destroyable Objects

- [ ] Destroyable building (type 39)
- [ ] Computer 1 (type 108): mission objective target
- [ ] Computer 2 (type 109): mission objective target
- [ ] Computer 3 (type 110): mission objective target

### 4.14 Switches (CF2)

- [ ] UFO callpad (type 111): controls `mSwitchesActivated`

### 4.15 Mission Objectives

- [ ] Objective system: phase ends when all objectives satisfied
- [x] Defined `MissionObjective` enum attached to `LevelMap`
- [ ] Kill All Enemy (1): all enemy sprites dead
- [ ] Destroy Enemy Buildings (2): all doors/computers destroyed
- [ ] Rescue Hostages (3): `mHostage_Count = 0`
- [ ] Protect All Civilians (4): no civilians killed
- [ ] Kidnap Enemy Leader (5): leader reaches rescue tent
- [ ] Destroy Factory (6): factory buildings destroyed
- [ ] Destroy Computer (7): all computer sprites destroyed
- [ ] Get Civilian Home (8): civilian reached destination
- [ ] Activate All Switches (9): all switches toggled (CF2)
- [ ] Rescue Hostage CF2 (10)
- [ ] `mEnemy_Unit_Types[]` list for counting live enemies
- [ ] Phase completion timer: 100 ticks (~6 seconds) after objectives met

---

## 5. Cross-Cutting Concerns

### 5.1 Weapons (WEAPONS.md)

- [ ] Player bullets: rank-based speed/range/cooldown/deviation
- [ ] Enemy bullets: aggression-based speed/range, fixed 24 spread
- [ ] Bullet spread/deviation system (random angular deviation mask)
- [ ] Max 20 concurrent bullets per side
- [ ] Grenades: arcing projectile, gravity 0x18000/tick, bounce ≥ 8 = dud, max 2 in flight
- [ ] Helicopter grenades: drop straight (no arc)
- [ ] Rockets: speed 100, max 2, 6-tick delay between shots, homing vs straight
- [ ] Missiles: straight (acceleration to max 96) vs homing (different turn rates)
- [ ] Lock-on distance: 22 px
- [ ] Explosions: 7 or 4 frames, faction-neutral, alternating damage, 25-position tile destruction, chain reactions

### 5.2 Vehicles (VEHICLES.md)

- [ ] Helicopters: 32 px cruise altitude, max speed 48, climb/descent, 4 weapon variants
- [ ] Enemy helicopter AI: 500 aggression threshold, 250 px detection, bullet-invulnerable
- [ ] Helicopter call pad
- [ ] Tanks: max speed 24, missile speed 60, 16-direction turret offsets
- [ ] Jeeps: armed/unarmed, cannon speed = vehicle + 80
- [ ] Turrets: 210 px detection, 1/32–1/64 fire chance, invulnerable variants
- [ ] Vehicle enter/exit: 13 px entry distance, animations
- [ ] Vehicle sinking, looping vehicles

### 5.3 UI & Meta

- [ ] Squad selection sidebar
- [ ] Rank icon display (`RANKFONT` sprite sheet)
- [ ] Kill counter / score display
- [ ] Heroes graveyard screen
- [ ] Recruit roster (360 names from `Recruits.cpp`)
- [ ] Mission briefing / service screen
- [ ] Game over when all 360 recruits killed
- [ ] Campaign progression (missions → phases)

### 5.4 Audio

- [ ] Death sounds (random per death)
- [ ] Weapon sounds (bullet, grenade, rocket, explosion)
- [ ] Vehicle sounds (helicopter, tank)
- [ ] Ambient / terrain sounds
- [ ] Music (`.adl` / `.rol` tracker files from original)

### 5.5 Camera & Rendering

- [ ] Camera panning (follow player squad)
- [ ] Scalable view window (4× or window-fit)
- [ ] Z-ordering by Y position (southern sprites on top)
- [ ] Sprite priority system matching original allocation zones

### 5.6 Input

- [x] Right-click on web (context menu blocks it)
- [x] Keyboard shortcuts (squad switching, speed modes)

---

## 6. Bugs (Known)

- [x] In pathfinding Clicking unwalkable area should path to nearest walkable cell between the player and unwalkable area.
- [ ] Z-order: sprites should sort by Y position (south on top)
- [ ] When a solider dies, their corpse should remain visible.
- [x] The bullets coming from the enemeires start at the wrong position relative to the enermy sprite
- [x] When the player fire, they squat, which seems wrong.
- [x] The bullets go though trees, etc
- [x] The bullets seem to go forever
- [ ] The bullets enemies fire at the player - the bullets seems to aim at 0,0 of the player, where it should be aimed at the player's center.
- [ ] If you run away from a enemie, while they are swimming. They just stay in the water.
- [x] Draw the colission boxes on players/enermies.
- [ ] We seem to start swimming at the water's edge. I think we should just be walking slow.
- [ ] The bullet colission box is really large.
- [x] Trees aren't shown correctly (see `EnvironmentSprite`)
- [ ] The enemy seems too aggressive compared to the original game
- [ ] The enemies should wander around.
- [ ] If you walk to the bottom of a cliff, the player seems to stop falling
- [ ] When swimming and you stop moving, the swim animation continuses.
- [x] After the solider falls (and dies) their state is still dying.
- [ ] Support jumping over ROCKY terrian
- [ ] When dead the corpse should not fade out. It should stay there.
- [ ] Display the rank above the head of the active solder.
- [ ] Where the bullet lands, makes a little splash animation
- [ ] The bullet comes from the center of the sprite

## 7. Other

- [ ] Change path finding to consider cost of different terrain (drop/drop2 blocked)
- [x] How do enermies detect players? Should we use large colissions boxes? or is what we doing now appropriate? What's Flame best practice?
- [x] Show  enemy detection radii in debug overlay
- [ ] Can debug overlay work like the Tiles, so its cheaper to render
- [ ] Add loading screen (and pre-loading on html page)
- [x] URL routing with go_router (`/map/cf1/mapm1?debug=true`)
- [x] We need to support dropping off a cliff
- [x] Change path finding to avoid drop/drop2 tiles
- [ ] Let's consider changing how we control.
  - [ ] Arrow keys to move, and click/point to fire
  - [ ] Press and do - press on a enemy and they will be fired at. Press on a land tile, it will be walked to.
- [ ] Add support for SpriteFontRenderer / SpriteFont for the various fonts in the game.
- [x] Delete packages/fodder_tools/bin/export_sprite_data.dart and packages/fodder_tools/tool/sprites/data (replaced by audit_sprite_names.dart)

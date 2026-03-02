Bugs:

- [ ] When you click on a unwalkable area, you should still try and move as close as possible.
- [ ] Change the z-order of the people (depending who is more south)
- [x] The dying animation doesn't work
- [x] I don't see any bullets flying
- [ ] Right click doesn't work on the web-based version. Right click brings up a context menu

Features

- [x] Identify where the goodies spawn
- [x] Identify where the baddies spawn
- [ ] Add a few soldiers (that move as a group)
- [x] Add firing
  - [x] Bullet component with faction, range, sprite rendering
  - [x] Bullet sprites loaded from copt atlas (semantic name `bullet`)
  - [x] Hitboxes on soldiers (enemy 16×16, player 6×5)
  - [x] Collision detection (bullet ↔ soldier) with one-hit kill
  - [x] Combat animation groups (firing, death, throw) loaded
  - [x] Player firing via right-click
  - [x] Enemy AI firing (aggression-based, LOS, staggered timers)
  - [ ] Gun (done — single bullet)
  - [ ] Missile (deferred)
  - [ ] Grenade (deferred)
- [ ] Add swimming
- [ ] Change path finding to consider cost of different terrain
- [ ] The camera should pan
- [ ] Increase the drawing size, maybe to 4x. Or scale with the window (keeping a view window)
- [ ] Add sound effects

Architecture

- [x] Semantic sprite naming (atlas frames use `player_walk_s`, `bullet`, etc.)
- [x] Asset pipeline: fodder_tools generates atlas JSONs with semantic names
- [x] Soldier hierarchy: Soldier → PlayerSoldier / EnemySoldier
- [x] SoldierState enum: idle, walking, firing, throwing, dying
- [x] Direction8 with compass suffix getter for atlas lookups
- [x] Enemy AI state machine (idle → chasing → firing)
- [x] Aggression system (ping-pong assigner, affects speed/fire rate/range)
- [x] Line-of-sight (Bresenham on sub-tile walkability grid)
- [x] Death system (random variant, fade-out, onDeath callback)

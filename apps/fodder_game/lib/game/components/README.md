# Components

This directory contains the visual and logical game objects used by the Fodder Game, following the Flame Component System (FCS).

## Key Files
* `soldier.dart`: Base class containing shared logic for all soldier entities.
* `player_soldier.dart`: The playable character logic and controls.
* `enemy_soldier.dart`: AI-controlled enemy characters.
* `soldier_animations.dart`: Management of soldier sprites and animation states. Uses `SoldierAnimations.fromAtlas()` with a shared `SpriteAtlas`.
* `bullet.dart` & `bullet_sprites.dart`: Logic and visuals for projectiles. Uses `BulletSprites.fromAtlas()` with a shared `SpriteAtlas`.
* `environment_sprite.dart`: Static environment decorations (trees, shrubs, roofs) from the TMX `Raised` layer, rendered above soldiers.
* `direction8.dart`: Utility for handling 8-way directional movement.
* `debug_barrier_overlay.dart`: Developer overlay for viewing collision boundaries.

Sprite atlas loading and frame-name constants live in `../sprites/` — see [sprites/README.md](../sprites/README.md).

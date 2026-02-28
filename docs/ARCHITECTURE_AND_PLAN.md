# Technical Plan & Implementation

## Asset Pre-Conversion Pipeline
We will not parse `.MAP` or `.SPT` files in the game loop. Instead, a standalone Dart CLI script located in `tool/` will run offline.

- **`tool/convert_assets.dart`**: Parses OpenFodder legacy binary formats and palette info.
- Outputs into:
  - `assets/images/spritesheet.png`
  - `assets/tiles/map1.tmx` (XML format compatible with Tiled and Flame).

## Game Implementation Steps (FCS Pattern)

1. **Core Setup**
   - Initialize Flutter project. Add `flame` and `flame_tiled`.
   - Setup `FodderGame` class extending `FlameGame`. Add `HasCollisionDetection`.

2. **Map Loading Component**
   - Implement `LevelMapComponent` managing `TiledComponent.load('map1.tmx')`.
   - Implement logic to hook Flame's `CameraComponent` to the map boundaries.

3. **Input Handling System**
   - Implement global gesture components handling taps vs. long-presses to separate mobile Movement vs Shooting logic.

4. **Player Component (FCS)**
   - Create `PlayerSoldier` extending `SpriteAnimationGroupComponent`.
   - Define states (Idle, Walking, Shooting) and orientations via Sprite Sheet metrics.

5. **Pathfinding & AI Component**
   - Translate TMX object layers into an impassable 2D collision grid.
   - Using A* algorithms, dynamically update `PlayerSoldier.position` towards the tapped target node sequence.

6. **Combat Components**
   - Create `BulletComponent` with a `CircleHitbox`.
   - Apply vector velocities towards touch coordinates.

7. **Enemy & Collision System**
   - Implement `EnemyComponent` with `RectangleHitbox`.
   - Intercept Flame's `onCollisionStart` between `BulletComponent` and `EnemyComponent` to execute hit logic and remove entities.

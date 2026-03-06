---
name: flutter-flame
description: Quickly master the Flame game engine for Flutter.
---

# Flame Game Engine Skills

This skill provides a comprehensive overview of the Flame game engine, covering its core architecture, component lifecycle, essential components, input handling, collision detection, effects system, camera control, asset management, common pitfalls, and practical examples. By mastering these concepts, you'll be well-equipped to build your own games using Flame in Flutter.

## 1. Core Architecture (FCS - Flame Component System)

Flame is built on a tree-based component system (similar to Flutter's widget tree).

- **`FlameGame`**: The root of your game. Owns the game loop, `world`, and `camera`.
- **`World`**: The container for all game-world entities (players, enemies, level). Components added to `world` are rendered by the camera.
- **`CameraComponent`**: Controls how the `world` is viewed. Includes:
  - **`Viewport`**: The "window" on the screen (e.g., `MaxViewport`, `FixedResolutionViewport`).
  - **`Viewfinder`**: Controls zoom, rotation, and center of view.
- **`GameWidget`**: The Flutter widget that hosts a `FlameGame`.

### Standard Setup Pattern
```dart
void main() {
  // Use world for game entities, camera for HUD/View
  final game = FlameGame(world: MyWorld());
  runApp(GameWidget(game: game));
}

class MyWorld extends World with HasCollisionDetection {
  @override
  Future<void> onLoad() async {
    await add(Player());
  }
}
```

## 2. Component Lifecycle

Every `Component` follows a strict lifecycle:

1. **`onLoad()`**: Asynchronous initialization (e.g., loading sprites). Guaranteed to run once. **Use `await` here for assets.**
2. **`onMount()`**: Called when the component is added to a mounted tree. May run multiple times if re-parented.
3. **`update(double dt)`**: Runs every tick. `dt` is delta time in seconds.
4. **`render(Canvas canvas)`**: Custom drawing logic (rarely needed if using built-in components).
5. **`onRemove()`**: Cleanup logic.

## 3. Essential Components

- **`PositionComponent`**: Base for anything with `position`, `size`, `scale`, `angle`, and `anchor`.
  - *Tip*: Local origin for children is always the top-left of the parent, regardless of parent's anchor.
- **`SpriteComponent`**: Renders a single image.
  - `sprite = await Sprite.load('player.png');`
- **`SpriteAnimationComponent`**: Renders a flip-book animation.
  - `animation = await SpriteAnimation.load(...);`
- **`ParallaxComponent`**: Multi-layered scrolling backgrounds.

## 4. Input Handling (Modern Mixins)

Add these mixins to **components** to handle input. Components must have a correct `size` and implement `containsLocalPoint()` (default in `PositionComponent`).

- **`TapCallbacks`**: `onTapDown`, `onTapUp`, `onTapCancel`, `onLongTapDown`.
- **`DragCallbacks`**: `onDragStart`, `onDragUpdate`, `onDragEnd`.
- **`KeyboardHandler`**: `onKeyEvent`. (Requires `HasKeyboardHandlerComponents` on the `FlameGame`).

### Input Propagation
Set `event.continuePropagation = true` in `onTapDown` if you want components below to also receive the event.

## 5. Collision Detection

1.  Add `HasCollisionDetection` to your `FlameGame` or `World`.
2.  Add `CollisionCallbacks` mixin to your component.
3.  Add at least one `ShapeHitbox` (e.g., `RectangleHitbox`, `CircleHitbox`) as a child of your component.

```dart
class Bullet extends SpriteComponent with CollisionCallbacks {
  @override
  Future<void> onLoad() async {
    add(CircleHitbox()); // Hitbox fills parent size by default
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Enemy) removeFromParent();
    super.onCollisionStart(intersectionPoints, other);
  }
}
```

## 6. Effects (Smooth Transitions)

Instead of manually updating values in `update()`, use `Effect`s for smooth, fire-and-forget animations.

- **`MoveEffect`**: Animate position.
- **`ScaleEffect`**: Animate size/scale.
- **`RotateEffect`**: Animate rotation.
- **`SequenceEffect`**: Run effects in order.

```dart
// Smoothly move to a point over 1 second
player.add(
  MoveEffect.to(
    Vector2(100, 100),
    EffectController(duration: 1.0),
  ),
);
```

## 7. Camera & Viewport Control

- **Follow a target**: `camera.follow(player);`
- **Zoom**: `camera.viewfinder.zoom = 2.0;`
- **Static HUD**: Add components directly to the `camera.viewport` instead of `world`.
- **World Bounds**: `camera.setBounds(Rectangle.fromRect(...));`

## 7. Assets Structure

By default, Flame expects:
- `assets/images/` -> Sprites and Animations.
- `assets/audio/` -> Sound effects and music.
- `assets/tiles/` -> Tiled Map Editor (`.tmx`) files.

## 8. Pro Tips (80/20)

- **Priorities**: Use `priority` (z-index) to control rendering order. Higher = On top.
- **Anchor**: Use `Anchor.center` for rotation-heavy components (like bullets or players).
- **Removal**: Use `component.removeFromParent()` instead of parent `remove(component)` for safer self-removal.
- **Batched Loading**: Use `game.images.loadAll(['a.png', 'b.png'])` in `onLoad` for efficiency.
## 9. Game-Wide Systems as Components

Systems that provide cross-cutting services (audio, AI management, score tracking, etc.) should be `Component` subclasses added to the `FlameGame` tree — **not** plain classes stored as fields on the game.

### Why?
- **Lifecycle**: `onLoad()` for async setup (e.g. preloading audio), `onRemove()` for cleanup.
- **Testability**: Provide a silent/mock subclass that records calls without loading real resources.
- **Decoupling**: Consumers use a `Has<System>` mixin to find the system in the tree, avoiding tight coupling to a concrete game class.

### Pattern
```dart
/// The real system — added to the FlameGame tree.
class AudioSystem extends Component {
  @override
  Future<void> onLoad() async {
    // Preload assets...
  }

  void playGunshot() { /* ... */ }
}

/// Silent test double that records calls.
class SilentAudioSystem extends AudioSystem {
  final List<String> calls = [];

  @override
  Future<void> onLoad() async {} // No-op

  @override
  void playGunshot() => calls.add('playGunshot');
}

/// Mixin for consumers — decoupled from the concrete game class.
mixin HasAudioSystem on Component {
  AudioSystem? _audioSystem;

  AudioSystem get audioSystem {
    return _audioSystem ??=
        findGame()!.children.whereType<AudioSystem>().first;
  }
}

/// Usage in a game entity:
class Soldier extends PositionComponent with HasAudioSystem {
  void shoot() => audioSystem.playGunshot();
}
```

### Registration
```dart
class MyGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    await add(AudioSystem());
    // ... add other systems and world entities
  }
}
```

## 10. Common Bridge Packages

Flame has several official "bridge" packages for extra functionality:
- **`flame_audio`**: Simple audio players. `FlameAudio.play('sfx.mp3');`
- **`flame_tiled`**: Support for Tiled Map Editor (`.tmx`).
- **`flame_forge2d`**: Full physics engine (box2d wrapper). Use if you need realistic physics (friction, joints, etc.).
- **`flame_svg`**: Render SVG files as sprites.
- **`flame_rive`**: Support for Rive animations.

## 11. Common Mistakes & Fixes

- **Missing `await` in `onLoad`**: Assets will not be loaded by the time `update()` or `render()` are called. Always `await` asset loads.
- **Wrong `size`**: Input and collision detection depend on `size`. If your component has `size: Vector2.zero()`, it won't be clickable.
- **Adding to `FlameGame` instead of `World`**: In the new camera system, adding to the game root makes components ignore camera movements. **Always add game entities to `world`.**
- **Ignoring `dt`**: Always multiply movement speeds by `dt` in `update()` to ensure frame-rate independence. `position.x += speed * dt;`
- **Overriding `render` without `super.render`**: This will prevent child components from rendering. Always call `super.render(canvas)`.

## 12. Practical Examples

### 12.1 Player Movement (Keyboard)
```dart
class Player extends PositionComponent with KeyboardHandler, HasGameReference<FlameGame> {
  Vector2 velocity = Vector2.zero();
  final double speed = 200;

  @override
  bool onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final isDown = event is KeyDownEvent;
    // Set movement velocity based on keys
    velocity.x = (keysPressed.contains(LogicalKeyboardKey.keyA) ? -1 : 0) +
                 (keysPressed.contains(LogicalKeyboardKey.keyD) ? 1 : 0);
    velocity.y = (keysPressed.contains(LogicalKeyboardKey.keyW) ? -1 : 0) +
                 (keysPressed.contains(LogicalKeyboardKey.keyS) ? 1 : 0);
    return true;
  }

  @override
  void update(double dt) {
    // Standard dt-dependent movement
    position += velocity * speed * dt;

    // Simple screen clamping
    position.clamp(Vector2.zero(), game.size);
  }
}
```

### 12.2 Spawning & Collisions (Shooting)
```dart
class MyWorld extends World with TapCallbacks, HasCollisionDetection {
  @override
  void onTapDown(TapDownEvent event) {
    // Spawn a bullet at the local world tap location
    add(Bullet(position: event.localPosition));
  }
}

class Bullet extends SpriteComponent with CollisionCallbacks {
  Bullet({required super.position})
    : super(size: Vector2.all(16), anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    sprite = await Sprite.load('bullet.png');
    add(CircleHitbox()); // Hitbox for collision detection
  }

  @override
  void update(double dt) {
    position.y -= 500 * dt; // Fly up
    if (position.y < -100) removeFromParent(); // Off-screen cleanup
  }

  @override
  void onCollisionStart(Set<Vector2> intersectionPoints, PositionComponent other) {
    if (other is Enemy) {
      other.removeFromParent(); // Kill enemy
      removeFromParent();       // Kill bullet
    }
    super.onCollisionStart(intersectionPoints, other);
  }
}
```

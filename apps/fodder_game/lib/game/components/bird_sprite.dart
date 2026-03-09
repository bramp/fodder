import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/sprites/sprite_atlas.dart';
import 'package:meta/meta.dart';

/// Direction a bird flies.
enum BirdDirection {
  /// Flies leftward (−X).
  left,

  /// Flies rightward (+X).
  right,
}

/// Horizontal speed (rendered px/s) when frame oscillation is ascending
/// (frames 5→0). Original: 1.5 px/tick × 16.67 tps × 2× scale.
@visibleForTesting
const double baseSpeed = 1.5 * config.tickRate * 2;

/// Additional horizontal speed (rendered px/s) when oscillation is descending.
/// Original adds 0.5 px/tick on top of base.
@visibleForTesting
const double fastSpeed = 2.0 * config.tickRate * 2;

/// Number of animation frames per direction.
const int _frameCount = 6;

/// Time between animation frame steps (one original tick).
const double _frameStepTime = config.tickDuration;

/// Duration of the initial warm-up timer before the first respawn check.
/// Original: 8 ticks.
@visibleForTesting
const double warmUpTime = config.tickDuration * 8;

/// Duration of the respawn timer once the bird is offscreen.
/// Original: 0x3F = 63 ticks.
@visibleForTesting
const double respawnTime = config.tickDuration * 63;

/// Per-frame Y anchor offsets (original pixels, scaled 2× on render).
/// Creates a visual bobbing/flapping effect.
@visibleForTesting
const List<double> frameYOffsets = [0, 0, 0, 0, 1, 3];

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const double _spriteScale = 2;

/// An animated bird that flies across the screen.
///
/// Birds are ambient decorations spawned from map data (sprite types 66/67).
/// They fly continuously in one direction with a ping-pong wing-flap
/// animation, respawning at the camera edge when they leave the viewport.
///
/// See `docs/TERRAIN_AND_OBJECTS.md §9` for full behaviour specification.
class BirdSprite extends SpriteComponent with HasGameReference<FlameGame> {
  /// Creates a bird sprite.
  ///
  /// [direction] controls whether the bird flies left or right.
  /// [position] is the initial world position.
  /// [sprites] is the list of 6 animation frames from the atlas.
  /// [random] can be injected for deterministic testing.
  BirdSprite({
    required this.direction,
    required List<Sprite> sprites,
    required super.position,
    Random? random,
  }) : assert(sprites.length == _frameCount, 'Expected $_frameCount frames'),
       _sprites = sprites,
       _random = random ?? Random(),
       super(
         sprite: sprites[0],
         size: sprites[0].srcSize * _spriteScale,
         anchor: Anchor.topLeft,
         // Draw on top of soldiers and terrain.
         priority: 20,
       );

  /// Creates a [BirdSprite] from the army [atlas].
  ///
  /// Returns `null` if the atlas doesn't contain bird frames.
  static BirdSprite? fromAtlas({
    required BirdDirection direction,
    required Vector2 position,
    required SpriteAtlas atlas,
    Random? random,
  }) {
    final groupName = direction == BirdDirection.left
        ? 'bird_fly_left'
        : 'bird_fly_right';

    final sprites = <Sprite>[];
    for (var i = 0; i < _frameCount; i++) {
      final s = atlas.sprite(groupName, i);
      if (s == null) return null;
      sprites.add(s);
    }

    return BirdSprite(
      direction: direction,
      sprites: sprites,
      position: position,
      random: random,
    );
  }

  /// The flight direction.
  final BirdDirection direction;

  final List<Sprite> _sprites;
  final Random _random;

  /// Current animation frame index (0–5, ping-pong).
  int _frameIndex = 0;

  /// Oscillation direction: +1 (ascending toward frame 5) or
  /// −1 (descending toward frame 0).
  int _oscillationDir = 1;

  /// Accumulated time for the animation frame stepper.
  double _frameTimer = 0;

  /// Respawn/warm-up countdown timer. While > 0, the bird's respawn check
  /// defers to the timer. When it reaches 0 the bird repositions.
  double _respawnTimer = warmUpTime;

  /// The base Y offset applied by the current animation frame's anchor.
  double _currentYOffset = 0;

  /// Whether to initialise oscillation on the first update.
  bool _initialised = false;

  /// Exposes the current frame index for testing.
  int get frameIndex => _frameIndex;

  /// Exposes the oscillation direction for testing.
  int get oscillationDir => _oscillationDir;

  /// Exposes the respawn timer for testing.
  double get respawnTimer => _respawnTimer;

  @override
  void update(double dt) {
    super.update(dt);

    // First-frame initialisation (randomise oscillation start).
    if (!_initialised) {
      _initialised = true;
      final r = _random.nextInt(65536);
      _frameIndex = (r & 3) + 1; // 1–4
      _oscillationDir = (r & 0x8000) != 0 ? -1 : 1;
      _applyFrame();
    }

    // Advance animation frame.
    _frameTimer += dt;
    while (_frameTimer >= _frameStepTime) {
      _frameTimer -= _frameStepTime;
      _advanceFrame();
    }

    // Move horizontally.
    final speed = _oscillationDir < 0 ? fastSpeed : baseSpeed;
    final dx = speed * dt;
    if (direction == BirdDirection.left) {
      position.x -= dx;
    } else {
      position.x += dx;
    }

    // Offscreen respawn check.
    if (_respawnTimer > 0) {
      _respawnTimer -= dt;
    } else if (!_isOnScreen()) {
      _respawn();
    }
  }

  /// Advances the frame index in ping-pong fashion and applies the new frame.
  void _advanceFrame() {
    _frameIndex += _oscillationDir;
    if (_frameIndex <= 0 || _frameIndex >= _frameCount - 1) {
      _oscillationDir = -_oscillationDir;
    }
    _frameIndex = _frameIndex.clamp(0, _frameCount - 1);
    _applyFrame();
  }

  /// Sets the sprite and adjusts Y for the current frame's anchor offset.
  void _applyFrame() {
    sprite = _sprites[_frameIndex];
    final newOffset = frameYOffsets[_frameIndex] * _spriteScale;
    // Shift position to compensate for anchor change.
    position.y += newOffset - _currentYOffset;
    _currentYOffset = newOffset;
  }

  /// Whether the bird is within the camera's visible area (with margin).
  bool _isOnScreen() {
    final cam = game.camera.viewfinder;
    final vp = game.camera.viewport;

    // Camera top-left in world coords.
    final camX = cam.position.x;
    final camY = cam.position.y;
    final viewW = vp.size.x / cam.zoom;
    final viewH = vp.size.y / cam.zoom;

    // Add generous margin so the bird doesn't respawn too eagerly.
    const margin = 64.0;
    return position.x > camX - margin &&
        position.x < camX + viewW + margin &&
        position.y > camY - margin &&
        position.y < camY + viewH + margin;
  }

  /// Repositions the bird at the incoming edge of the viewport.
  void _respawn() {
    _respawnTimer = respawnTime;

    final cam = game.camera.viewfinder;
    final vp = game.camera.viewport;
    final camX = cam.position.x;
    final camY = cam.position.y;
    final viewW = vp.size.x / cam.zoom;

    // Undo current Y offset before repositioning.
    position.y -= _currentYOffset;
    _currentYOffset = 0;

    if (direction == BirdDirection.left) {
      // Spawn to the right of the viewport.
      position.x = camX + viewW + (_random.nextDouble() * 64);
    } else {
      // Spawn to the left of the viewport.
      position.x = camX - (_random.nextDouble() * 64);
    }
    position.y = camY + (_random.nextDouble() * 256 * _spriteScale);
  }
}

import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Which side fired this bullet.
enum Faction {
  /// Fired by a player soldier.
  player,

  /// Fired by an enemy soldier.
  enemy,
}

/// A small fast-moving projectile that damages soldiers of the opposing
/// [Faction].
///
/// When a bullet sprite is provided it is rendered at 2× scale; otherwise a
/// small yellow square is drawn as a fallback.  The bullet is automatically
/// removed when it exceeds its maximum range or lifetime.

/// Pixel size of one walkability sub-tile cell.
const double _subTilePixelSize = 4;

class Bullet extends PositionComponent with CollisionCallbacks {
  Bullet({
    required Vector2 position,
    required this.velocity,
    required this.faction,
    this.bulletSprite,
    this.walkabilityGrid,
    this.maxRange = 400,
    this.maxLifetime = 5,
    Vector2? size,
  }) : super(
         position: position,
         size: size ?? Vector2(4, 4),
         anchor: Anchor.center,
         // Render above soldiers (priority 10) so bullets are visible.
         priority: 15,
       );

  /// Direction and speed of the bullet (pixels / second).
  final Vector2 velocity;

  /// Which side fired this bullet.
  final Faction faction;

  /// Optional sprite to render (from the copt atlas).
  final Sprite? bulletSprite;

  /// Walkability grid for terrain collision (bullets stop at trees, walls).
  final WalkabilityGrid? walkabilityGrid;

  /// Maximum distance (pixels) before automatic removal.
  final double maxRange;

  /// Maximum time (seconds) before automatic removal.
  final double maxLifetime;

  /// Total distance the bullet has travelled since creation.
  double distanceTravelled = 0;

  /// Time elapsed since creation (seconds).
  double age = 0;

  /// Whether this bullet has been destroyed (by terrain, range, or lifetime).
  ///
  /// Once true the bullet no longer updates. Also calls [removeFromParent] to
  /// clean up from the component tree when mounted.
  bool _destroyed = false;

  /// Whether this bullet has been destroyed.
  bool get isDestroyed => _destroyed;

  static const _fallbackColor = Color(0xFFFFFF00);

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
  }

  @override
  void render(Canvas canvas) {
    if (bulletSprite != null) {
      bulletSprite!.render(canvas, size: size);
    } else {
      // Fallback: small yellow dot.
      canvas.drawRect(
        const Rect.fromLTWH(1, 1, 2, 2),
        Paint()..color = _fallbackColor,
      );
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_destroyed) return;

    final step = velocity * dt;
    position += step;
    distanceTravelled += step.length;
    age += dt;

    if (distanceTravelled >= maxRange || age >= maxLifetime) {
      _destroyed = true;
      removeFromParent();
      return;
    }

    // Stop at non-walkable terrain (trees, walls, etc.).
    final grid = walkabilityGrid;
    if (grid != null) {
      final subX = (position.x / _subTilePixelSize).floor();
      final subY = (position.y / _subTilePixelSize).floor();
      if (!grid.isSubTileWalkable(subX, subY)) {
        _destroyed = true;
        removeFromParent();
      }
    }
  }
}

import 'dart:ui';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

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
/// When a [bulletSprite] is provided it is rendered at 2× scale; otherwise a
/// small yellow square is drawn as a fallback.  The bullet is automatically
/// removed when it exceeds [maxRange] pixels of travel or [maxLifetime]
/// seconds have elapsed.
class Bullet extends PositionComponent with CollisionCallbacks {
  Bullet({
    required Vector2 position,
    required this.velocity,
    required this.faction,
    this.bulletSprite,
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

  /// Maximum distance (pixels) before automatic removal.
  final double maxRange;

  /// Maximum time (seconds) before automatic removal.
  final double maxLifetime;

  /// Total distance the bullet has travelled since creation.
  double distanceTravelled = 0;

  /// Time elapsed since creation.
  double _elapsed = 0;

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

    final step = velocity * dt;
    position += step;
    distanceTravelled += step.length;
    _elapsed += dt;

    if (distanceTravelled >= maxRange || _elapsed >= maxLifetime) {
      removeFromParent();
    }
  }
}

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

// TODO(bramp): Add more details rules in the comment
// TODO(bramp): The bullet has a limited distance, and can be removed when it
// goes outside the map boundaries
// TODO(bramp): Add a grenade and rocket launcher
class Bullet extends PositionComponent with CollisionCallbacks {
  Bullet({
    required Vector2 position,
    required this.velocity,
    this.damage = 1.0,
  }) : super(
         position: position,
         size: Vector2(4, 4),
         anchor: Anchor.center,
       );

  final Vector2 velocity;
  final double damage;

  @override
  Future<void> onLoad() async {
    add(CircleHitbox());
    // In actual implementation, we might use a SpriteComponent
  }

  @override
  void update(double dt) {
    super.update(dt);
    position += velocity * dt;

    // TODO(owner): Add boundaries to remove offline bullets
    // if (isOutsideMap()) {
    //   removeFromParent();
    // }
  }
}

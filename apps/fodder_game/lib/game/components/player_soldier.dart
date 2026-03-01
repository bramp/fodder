import 'package:flame/components.dart';

enum SoldierState {
  idle,
  walking,
  shooting,
  dying,
}

class PlayerSoldier extends SpriteAnimationGroupComponent<SoldierState> {
  PlayerSoldier() : super(size: Vector2(32, 32), anchor: Anchor.center);

  Vector2? targetPosition;
  double speed = 50; // pixels per second

  @override
  Future<void> onLoad() async {
    // Load animations here
    // animations = {
    //   SoldierState.idle: idleAnimation,
    //   SoldierState.walking: walkAnimation,
    // };
    // current = SoldierState.idle;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // Simple movement logic towards targetPosition
    if (targetPosition != null) {
      final direction = (targetPosition! - position)..normalize();
      position += direction * speed * dt;

      // Stop moving when close enough
      if (position.distanceTo(targetPosition!) < 2.0) {
        position = targetPosition!;
        targetPosition = null;
        current = SoldierState.idle;
      }
    }
  }

  void moveTo(Vector2 destination) {
    targetPosition = destination;
    current = SoldierState.walking;
  }

  void startShooting(Vector2 targetDirection) {
    // Add logic to rotate/change orientation and spawn bullets
    current = SoldierState.shooting;
  }

  void stopShooting() {
    current = SoldierState.idle;
  }
}

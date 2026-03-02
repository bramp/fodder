import 'package:flame/components.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// The high-level state of a soldier.
enum SoldierState {
  /// Standing still, showing idle animation.
  idle,

  /// Moving along a path, showing walk animation.
  walking,
}

/// Base class for all soldier entities (player and enemy).
///
/// Manages 8-directional walk/idle sprite animations loaded from the army
/// sprite atlas via [SoldierAnimations].
abstract class Soldier extends SpriteAnimationGroupComponent<SoldierState> {
  Soldier({required this.soldierAnimations, super.priority = 10})
    : super(size: soldierAnimations.scaledSize, anchor: Anchor.center);

  /// The loaded walk/idle animation set.
  final SoldierAnimations soldierAnimations;

  /// Current facing direction.
  Direction8 facing = Direction8.south;

  @override
  Future<void> onLoad() async {
    updateAnimations();
    current = SoldierState.idle;
  }

  /// Rebuilds the animation map based on the current [facing] direction.
  void updateAnimations() {
    animations = {
      SoldierState.walking:
          soldierAnimations.walkAnimations[facing] ??
          soldierAnimations.walkAnimations[Direction8.south]!,
      SoldierState.idle:
          soldierAnimations.idleAnimations[facing] ??
          soldierAnimations.idleAnimations[Direction8.south]!,
    };
  }

  /// Sets the current state if it has changed.
  void setState(SoldierState state) {
    if (current != state) {
      current = state;
    }
  }
}

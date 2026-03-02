import 'package:flame/components.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// The high-level state of a player soldier.
enum SoldierState {
  idle,
  walking,
}

/// A player-controlled soldier that walks along a path of waypoints.
///
/// Uses [SoldierAnimations] for 8-directional walk/idle sprite animations
/// loaded from the army sprite atlas.
class PlayerSoldier extends SpriteAnimationGroupComponent<SoldierState> {
  PlayerSoldier({required this.soldierAnimations})
    : super(
        size: soldierAnimations.scaledSize,
        anchor: Anchor.center,
        priority: 10,
      );

  final SoldierAnimations soldierAnimations;

  /// Movement speed in pixels per second.
  double speed = 80;

  /// Current facing direction.
  Direction8 _facing = Direction8.south;

  /// Waypoints to follow (pixel coordinates). The soldier walks toward
  /// `_path.first` and removes it when reached.
  final List<Vector2> _path = [];

  /// The current list of path waypoints (read-only view, for debug overlay).
  List<Vector2> get currentPath => List.unmodifiable(_path);

  @override
  Future<void> onLoad() async {
    // Build animation map: each SoldierState maps to the current direction's
    // animation. We start facing south.
    _updateAnimations();
    current = SoldierState.idle;
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_path.isEmpty) return;

    final target = _path.first;
    final delta = target - position;
    final distance = delta.length;
    final step = speed * dt;

    if (distance <= step) {
      // Reached this waypoint.
      position.setFrom(target);
      _path.removeAt(0);

      if (_path.isEmpty) {
        _setState(SoldierState.idle);
      }
    } else {
      // Move toward waypoint.
      final direction = delta.normalized();
      position += direction * step;

      // Update facing direction based on movement vector.
      final newFacing = Direction8.fromVector(direction.x, direction.y);
      if (newFacing != _facing) {
        _facing = newFacing;
        _updateAnimations();
      }

      _setState(SoldierState.walking);
    }
  }

  /// Replaces the current path. The soldier will immediately begin walking
  /// toward the first waypoint.
  void followPath(List<Vector2> waypoints) {
    _path
      ..clear()
      ..addAll(waypoints);

    if (_path.isNotEmpty) {
      _setState(SoldierState.walking);
    }
  }

  void _setState(SoldierState state) {
    if (current != state) {
      current = state;
    }
  }

  void _updateAnimations() {
    animations = {
      SoldierState.walking:
          soldierAnimations.walkAnimations[_facing] ??
          soldierAnimations.walkAnimations[Direction8.south]!,
      SoldierState.idle:
          soldierAnimations.idleAnimations[_facing] ??
          soldierAnimations.idleAnimations[Direction8.south]!,
    };
  }
}

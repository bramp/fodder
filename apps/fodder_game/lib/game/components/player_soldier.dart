import 'package:flame/components.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';

/// A player-controlled soldier that walks along a path of waypoints.
///
/// Uses `SoldierAnimations` for 8-directional walk/idle sprite animations
/// loaded from the army sprite atlas.
class PlayerSoldier extends Soldier {
  PlayerSoldier({required super.soldierAnimations});

  /// Movement speed in pixels per second.
  double speed = 80;

  /// Waypoints to follow (pixel coordinates). The soldier walks toward
  /// `_path.first` and removes it when reached.
  final List<Vector2> _path = [];

  /// The current list of path waypoints (read-only view, for debug overlay).
  List<Vector2> get currentPath => List.unmodifiable(_path);

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
        setState(SoldierState.idle);
      }
    } else {
      // Move toward waypoint.
      final direction = delta.normalized();
      position += direction * step;

      // Update facing direction based on movement vector.
      final newFacing = Direction8.fromVector(direction.x, direction.y);
      if (newFacing != facing) {
        facing = newFacing;
        updateAnimations();
      }

      setState(SoldierState.walking);
    }
  }

  /// Replaces the current path. The soldier will immediately begin walking
  /// toward the first waypoint.
  void followPath(List<Vector2> waypoints) {
    _path
      ..clear()
      ..addAll(waypoints);

    if (_path.isNotEmpty) {
      setState(SoldierState.walking);
    }
  }
}

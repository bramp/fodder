import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';

/// Duration (seconds) the player holds the firing pose before returning
/// to the previous state.
const firingHoldDuration = 0.3;

/// Bullet speed in pixels per second for player-fired bullets.
const playerBulletSpeed = 350.0;

/// A player-controlled soldier that walks along a path of waypoints.
///
/// Uses `SoldierAnimations` for 8-directional walk/idle sprite animations
/// loaded from the army sprite atlas.
class PlayerSoldier extends Soldier {
  PlayerSoldier({required super.soldierAnimations});

  /// Player hitbox is 6×5 per the original game spec (harder to hit).
  @override
  Vector2 get hitboxSize => Vector2(6, 5);

  @override
  Faction get opposingFaction => Faction.enemy;

  /// Movement speed in pixels per second.
  double speed = 80;

  /// Waypoints to follow (pixel coordinates). The soldier walks toward
  /// `_path.first` and removes it when reached.
  final List<Vector2> _path = [];

  /// Whether the soldier is currently in a firing hold.
  bool _isFiring = false;

  /// Countdown timer for the firing hold duration.
  double _firingTimer = 0;

  /// The state to return to after the firing hold ends.
  SoldierState _preFireState = SoldierState.idle;

  /// The current list of path waypoints (read-only view, for debug overlay).
  List<Vector2> get currentPath => List.unmodifiable(_path);

  /// Whether the soldier is currently in a firing hold.
  bool get isFiring => _isFiring;

  @override
  void update(double dt) {
    super.update(dt);

    // Skip movement when dead.
    if (!isAlive) return;

    // Handle firing hold countdown.
    if (_isFiring) {
      _firingTimer -= dt;
      if (_firingTimer <= 0) {
        _isFiring = false;
        // Return to previous state.
        setState(_path.isNotEmpty ? SoldierState.walking : _preFireState);
      }
      return; // Don't move while firing.
    }

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

  /// Fires a bullet toward [targetWorld].
  ///
  /// The soldier turns to face the target, enters the firing pose for
  /// [firingHoldDuration] seconds (during which movement is paused), and
  /// returns a [Bullet] that the caller should add to the world.
  ///
  /// Returns `null` if the soldier is dead or already firing.
  Bullet? fire(Vector2 targetWorld) {
    if (!isAlive || _isFiring) return null;

    // Calculate direction from soldier to target.
    final delta = targetWorld - position;
    if (delta.isZero()) return null;

    // Turn to face the target.
    facing = Direction8.fromVector(delta.x, delta.y);
    updateAnimations();

    // Enter firing hold.
    _preFireState = _path.isNotEmpty ? SoldierState.walking : SoldierState.idle;
    _isFiring = true;
    _firingTimer = firingHoldDuration;
    setState(SoldierState.firing);

    // Create the bullet.
    final direction = delta.normalized();
    return Bullet(
      position: position.clone(),
      velocity: direction * playerBulletSpeed,
      faction: Faction.player,
    );
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

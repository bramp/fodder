import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/config/weapon_data.dart';
import 'package:fodder_game/game/models/mission_troop.dart';
import 'package:fodder_game/game/models/squad.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Offset (pixels) from soldier centre to bullet spawn point.
///
/// Approximately half the sprite size at 2× scale, so bullets appear to
/// leave from the edge of the sprite rather than the centre.
const double _bulletSpawnOffset = 16;

/// Default bullet speed when no troop data is available (pixels/second).
const double playerBulletSpeed = config.defaultPlayerBulletSpeed;

/// A player-controlled soldier that walks along a path of waypoints.
///
/// Uses `SoldierAnimations` for 8-directional walk/idle sprite animations
/// loaded from the army sprite atlas.
///
/// Movement speed is determined by the [squad]'s current [SpeedMode], or
/// falls back to [config.playerSpeedNormal] if no squad is assigned.
/// Weapon stats come from the [troop]'s rank, or use a default fallback.
class PlayerSoldier extends Soldier {
  PlayerSoldier({required super.soldierAnimations, super.random});

  /// Player hitbox is 6×5 per the original game spec (harder to hit).
  @override
  Vector2 get hitboxSize => Vector2(6, 5);

  @override
  Faction get opposingFaction => Faction.enemy;

  /// The squad this soldier belongs to (if any).
  Squad? squad;

  /// The troop data for this soldier (rank, kills, weapon stats).
  MissionTroop? troop;

  /// Movement speed in pixels per second.
  ///
  /// When on water terrain, speed is forced to [config.playerSpeedWater]
  /// regardless of squad speed mode. Otherwise derived from the squad's
  /// speed mode, or [config.playerSpeedNormal] if no squad is assigned.
  double get speed {
    if (isInWater) return config.playerSpeedWater;
    return squad?.speedMode.pixelsPerSecond ?? config.playerSpeedNormal;
  }

  /// Weapon stats for this soldier (based on rank).
  WeaponStats get weaponStats => troop?.weaponStats ?? fallbackWeaponStats(0);

  /// Waypoints to follow (pixel coordinates). The soldier walks toward
  /// `_path.first` and removes it when reached.
  final List<Vector2> _path = [];

  /// Countdown timer for fire cooldown between shots.
  double _fireCooldownTimer = 0;

  /// The current list of path waypoints (read-only view, for debug overlay).
  List<Vector2> get currentPath => List.unmodifiable(_path);

  /// Whether the soldier is currently in a fire cooldown.
  bool get isFiring => _fireCooldownTimer > 0;

  @override
  void update(double dt) {
    super.update(dt);

    // Skip movement when dead.
    if (!isAlive) {
      isMoving = false;
      return;
    }

    // Check terrain under the soldier for water effects.
    _updateTerrainState();

    // Tick fire cooldown.
    if (_fireCooldownTimer > 0) {
      _fireCooldownTimer -= dt;
    }

    if (_path.isEmpty) {
      isMoving = false;
      return;
    }

    final target = _path.first;
    final delta = target - position;
    final distance = delta.length;
    final step = speed * dt;

    if (distance <= step) {
      // Reached this waypoint.
      position.setFrom(target);
      _path.removeAt(0);

      if (_path.isEmpty) {
        isMoving = false;
        setState(isInWater ? SoldierState.swimming : SoldierState.idle);
      }
    } else {
      // Move toward waypoint.
      final direction = delta.normalized();
      position += direction * step;
      isMoving = true;

      // Update facing direction based on movement vector.
      final newFacing = Direction8.fromVector(direction.x, direction.y);
      if (newFacing != facing) {
        facing = newFacing;
        updateAnimations();
      }

      setState(isInWater ? SoldierState.swimming : SoldierState.walking);
    }
  }

  /// Updates [isInWater] based on the terrain under the soldier.
  void _updateTerrainState() {
    final terrain = terrainUnderFoot();
    final wasInWater = isInWater;
    isInWater =
        terrain == TerrainType.water ||
        terrain == TerrainType.waterEdge ||
        terrain == TerrainType.sink;

    // If water state changed, rebuild animations so swimming is available.
    if (isInWater != wasInWater) {
      updateAnimations();
    }
  }

  /// Fires a bullet toward [targetWorld].
  ///
  /// Returns a [Bullet] that the caller should add to the world, or `null`
  /// if the soldier is dead or still on cooldown.
  ///
  /// The soldier does **not** change animation or facing direction; in the
  /// original Cannon Fodder the player keeps walking while firing.
  Bullet? fire(Vector2 targetWorld) {
    if (!isAlive || isFiring) return null;

    // Calculate direction from soldier to target.
    final delta = targetWorld - position;
    if (delta.isZero()) return null;

    // Start fire cooldown.
    _fireCooldownTimer = weaponStats.cooldown;

    // Create the bullet using rank-based weapon stats, spawning slightly
    // ahead of the soldier centre so it appears from the sprite edge.
    final stats = weaponStats;
    final direction = delta.normalized();
    return Bullet(
      position: position + direction * _bulletSpawnOffset,
      velocity: direction * stats.bulletSpeed,
      faction: Faction.player,
      maxRange: stats.range,
      maxLifetime: stats.aliveTime,
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

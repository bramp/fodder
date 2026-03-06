import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/config/weapon_data.dart';
import 'package:fodder_game/game/fodder_game.dart';
import 'package:fodder_game/game/models/mission_troop.dart';
import 'package:fodder_game/game/models/squad.dart';
import 'package:fodder_game/game/systems/squad_movement.dart';
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
class PlayerSoldier extends Soldier with HasGameReference<FodderGame> {
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

  /// The soldier directly ahead of this one in the squad.
  ///
  /// `null` for the squad leader (index 0). When set, this soldier will
  /// pause movement whenever it is within [squadMemberSpacing] pixels of
  /// its predecessor, preventing soldiers from bunching up.
  PlayerSoldier? predecessor;

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

    // Check terrain under the soldier for water and drop effects.
    _updateTerrainState();

    // If currently falling (Drop) or stumbling (Drop2), process and skip
    // normal movement.
    if (isFalling) {
      _updateFalling(dt);
      return;
    }
    if (isStumbling) {
      _updateStumbling(dt);
      return;
    }

    // Tick fire cooldown.
    if (_fireCooldownTimer > 0) {
      _fireCooldownTimer -= dt;
    }

    // Update facing direction based on mouse position (PLAYER.md §1.3).
    // In the remake, player soldiers always look toward the cursor.
    if (isMounted) {
      final mousePos = game.mousePosition;
      if (mousePos != null) {
        updateDirection(mousePos);
      }
    }

    if (_path.isEmpty) {
      isMoving = false;
      return;
    }

    // Runtime squad spacing: if we have a predecessor (soldier ahead in the
    // squad), pause movement when we're too close to them. This prevents
    // soldiers from bunching up during the walk, matching the original
    // game's Sprite_Handle_Player_Close_To_SquadMember behaviour.
    if (predecessor != null && predecessor!.isAlive) {
      final gap = position.distanceTo(predecessor!.position);
      if (gap < squadMemberSpacing) {
        // Too close — hold position this frame.
        isMoving = false;
        setState(isInWater ? SoldierState.swimming : SoldierState.idle);
        return;
      }
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

      setState(isInWater ? SoldierState.swimming : SoldierState.walking);
    }
  }

  /// Updates [isInWater] and detects Drop / Drop2 terrain.
  void _updateTerrainState() {
    final terrain = terrainUnderFoot();

    // --- Water detection ---
    final wasInWater = isInWater;
    isInWater =
        terrain == TerrainType.water ||
        terrain == TerrainType.waterEdge ||
        terrain == TerrainType.sink;

    if (isInWater != wasInWater) {
      updateAnimations();
    }

    // --- Drop / cliff detection ---
    // Drop (type 9): gravity slide downward. The soldier accelerates down
    // and can survive if they reach non-drop terrain before the timer
    // expires (matching the original `field_12 < 12` check).
    if (!isFalling && !isStumbling && terrain == TerrainType.drop) {
      fallTimer = config.dropFallDuration;
      fallSpeed = 0;
      setState(SoldierState.falling);
    }

    // Drop2 (type 10): stumble in place. Visual height accumulates
    // rapidly (~5 original frames ≈ 0.3 s) and is always lethal.
    if (!isFalling && !isStumbling && terrain == TerrainType.drop2) {
      stumbleTimer = config.dropStumbleDuration;
      setState(SoldierState.stumbling);
    }
  }

  /// Processes one frame of the falling state.
  ///
  /// The soldier accelerates downward. After displacement, the terrain at
  /// the new position is checked:
  /// - Still on Drop/Drop2 → continue falling.
  /// - Non-drop terrain AND timer not expired → **survive** (reset).
  /// - Timer expired → **die**.
  ///
  /// This matches the original game's `loc_1E9EC` check: `field_12 < 12`
  /// means survive, `field_12 ≥ 12` means death.
  void _updateFalling(double dt) {
    // Accelerate downward.
    fallSpeed += config.dropFallAcceleration * dt;
    position.y += fallSpeed * dt;

    // Count down toward death.
    fallTimer -= dt;

    // Check terrain at the new position.
    final terrain = terrainUnderFoot();

    // The soldier survives only if they've landed on walkable, non-drop
    // ground before the timer expires. Out-of-bounds returns `block`,
    // which correctly prevents survival (matching the original game's
    // `if (Y >= mapHeight) → force death` check).
    final isDeadlyGround =
        terrain == TerrainType.drop ||
        terrain == TerrainType.drop2 ||
        terrain.blocksWalking;

    if (!isDeadlyGround && fallTimer > 0) {
      // Landed on solid ground before the timer expired — survive.
      resetFallState();
      setState(SoldierState.idle);
      return;
    }

    if (fallTimer <= 0) {
      die();
    }
  }

  /// Processes one frame of the Drop2 stumble.
  ///
  /// The soldier stays in place (no Y displacement) while the stumble
  /// timer counts down. When the timer expires the soldier dies.
  /// This is effectively always lethal — matching the original game where
  /// visual height accumulates to ≥ 14 in ~5 frames.
  void _updateStumbling(double dt) {
    stumbleTimer -= dt;
    if (stumbleTimer <= 0) {
      die();
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

    audioSystem.playGunshot();

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

  /// Updates the soldier's facing direction to look toward [targetWorld].
  void updateDirection(Vector2 targetWorld) {
    final toTarget = targetWorld - position;
    if (toTarget.isZero()) return;

    final newFacing = Direction8.fromVector(toTarget.x, toTarget.y);
    if (newFacing != facing) {
      facing = newFacing;
      updateAnimations();
    }
  }
}

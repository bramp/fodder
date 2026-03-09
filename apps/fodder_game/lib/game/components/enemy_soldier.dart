import 'dart:math';

import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/systems/line_of_sight.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Terrain types that count as water for movement purposes.
const Set<TerrainType> _waterTerrains = {
  TerrainType.water,
  TerrainType.waterEdge,
  TerrainType.sink,
};

/// Offset (pixels) from soldier centre to bullet spawn point.
const double _bulletSpawnOffset = 16;

/// Internal AI states for enemy soldiers.
enum EnemyAiState {
  /// Standing still, scanning for players.
  idle,

  /// Walking toward a detected player.
  chasing,

  /// Holding the standing-with-gun pose and firing.
  firing,
}

/// Fire delay ticks base value for aggression → seconds conversion.
///
/// Per spec: delay_ticks = (20 - aggression) * random(1..3) + aggression.
/// We simplify: delay_seconds ≈ (20 - aggression) * 0.05 + 0.3
/// Low aggression ~1.1 s, high aggression ~0.4 s.
const _baseFireDelayFactor = 0.05;
const _minFireDelay = 0.3;

/// An AI-controlled enemy soldier.
///
/// Uses a simple state machine: idle → chasing → firing → chasing.
/// Requires [aggression], [walkabilityGrid], and [players] to be set
/// before the first update.
class EnemySoldier extends Soldier {
  EnemySoldier({required super.soldierAnimations});

  /// Enemy hitbox is 16×16 per the original game spec (easier to hit).
  @override
  Vector2 get hitboxSize => Vector2(16, 16);

  @override
  Faction get opposingFaction => Faction.player;

  /// Aggression level (typically 4–8). Affects speed, fire rate, bullet range.
  int aggression = 6;

  /// Phase-level aggression average. Controls movement-targeting scatter.
  ///
  /// When `aggressionAverage < 5`, enemies scatter more widely around the
  /// player (±63 px) instead of tightly (±31 px).
  int aggressionAverage = 6;

  /// Initial fire delay (seconds) before this enemy can fire for the first
  /// time. Set at spawn time for staggered fire timers (Step 9).
  double initialFireDelay = 0;

  /// Live player soldiers to target.
  List<PlayerSoldier> players = [];

  /// Current AI state.
  EnemyAiState aiState = EnemyAiState.idle;

  /// The player currently being targeted (if any).
  PlayerSoldier? _target;

  /// Countdown timer for fire delay between shots.
  double _fireTimer = 0;

  /// Post-fire pause countdown.
  double _pauseTimer = 0;

  /// Whether the initial fire delay has been consumed.
  bool _initialDelayConsumed = false;

  /// Last known safe (non-drop) position, used to restore on bounce-back.
  final Vector2 _safePosition = Vector2.zero();

  /// Random scatter offset applied to the walk target so enemies don’t all
  /// converge on the exact same pixel. Recomputed each time a new target is
  /// acquired.
  final Vector2 _targetScatter = Vector2.zero();

  /// RNG for scatter offsets.
  static final Random _random = Random();

  /// Callback for spawning a bullet into the world.
  ///
  /// Set by `FodderGame` during enemy spawning. The enemy creates a [Bullet]
  /// and passes it to this callback so it can be added to the world.
  void Function(Bullet bullet)? onFireBullet;

  /// Movement speed derived from aggression: `(12 + aggression) * 5`, capped.
  ///
  /// When on water terrain, speed is forced to [config.playerSpeedWater].
  double get _speed {
    if (isInWater) return config.playerSpeedWater;
    final raw = (config.enemySpeedBase + aggression) * config.speedScale;
    return raw.clamp(0, config.enemySpeedMax);
  }

  /// Fire delay derived from aggression.
  double get _fireDelay {
    return ((20 - aggression) * _baseFireDelayFactor + _minFireDelay).clamp(
      _minFireDelay,
      2.0,
    );
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isAlive) return;

    // Record the current position as safe if we're on valid terrain.
    // This is checked *before* movement so that if the AI walks onto a
    // cliff edge we can restore to the last known safe spot.
    final terrain = terrainUnderFoot();
    if (terrain != TerrainType.drop && terrain != TerrainType.drop2) {
      _safePosition.setFrom(position);
    }

    // Update water state BEFORE the AI so speed and animation queries
    // see the correct isInWater flag.
    _updateWaterState();

    // Consume initial fire delay.
    if (!_initialDelayConsumed) {
      initialFireDelay -= dt;
      if (initialFireDelay > 0) return;
      _initialDelayConsumed = true;
    }

    // AI state machine (may move position).
    switch (aiState) {
      case EnemyAiState.idle:
        _updateIdle(dt);
      case EnemyAiState.chasing:
        _updateChasing(dt);
      case EnemyAiState.firing:
        _updateFiring(dt);
    }

    // After movement, check for cliff edges and bounce back.
    _checkDropBounceBack();
  }

  void _updateIdle(double dt) {
    _target = _findTarget();
    if (_target != null) {
      _recomputeScatter();
      _transitionTo(EnemyAiState.chasing);
    }
  }

  void _updateChasing(double dt) {
    // Post-fire pause — stay still but remain in chasing state.
    if (_pauseTimer > 0) {
      _pauseTimer -= dt;
      return;
    }

    // Re-check target validity.
    if (_target == null || !_target!.isAlive) {
      _target = _findTarget();
      if (_target == null) {
        _transitionTo(EnemyAiState.idle);
        return;
      }
      _recomputeScatter();
    }

    final toTarget = _target!.position - position;
    final dist = toTarget.length;

    // Lost target — too far away.
    if (dist > config.detectionRange) {
      _target = null;
      _transitionTo(EnemyAiState.idle);
      return;
    }

    // In range and has LOS (or close enough) → fire.
    if (_canFireAt(dist)) {
      _transitionTo(EnemyAiState.firing);
      return;
    }

    // Walk toward target (with scatter offset).
    final walkTarget = _target!.position + _targetScatter;
    final toWalkTarget = walkTarget - position;
    final walkDist = toWalkTarget.length;
    if (walkDist > 1) {
      final direction = toWalkTarget.normalized();
      position += direction * _speed * dt;

      final newFacing = Direction8.fromVector(direction.x, direction.y);
      if (newFacing != facing) {
        facing = newFacing;
        updateAnimations();
      }
      setState(isInWater ? SoldierState.swimming : SoldierState.walking);
    }
  }

  void _updateFiring(double dt) {
    _fireTimer -= dt;

    if (_fireTimer <= 0) {
      // Fire a bullet.
      if (_target != null && _target!.isAlive) {
        _fireBulletAt(_target!);
      }

      // Apply post-fire pause and return to chasing.
      _pauseTimer = config.enemyPostFirePauseBullet;
      _fireTimer = _fireDelay;
      _transitionTo(EnemyAiState.chasing);
    }
  }

  void _fireBulletAt(PlayerSoldier target) {
    final toTarget = target.position - position;
    if (toTarget.isZero()) return;

    // Face the target.
    facing = Direction8.fromVector(toTarget.x, toTarget.y);
    updateAnimations();

    audioSystem.playGunshot();

    final direction = toTarget.normalized();
    final bulletSpeed = 60.0 + aggression;
    // Bullet lifetime in ticks → seconds.
    final lifetimeTicks = ((aggression >> 3) + 8).clamp(8, 16);
    final lifetimeSeconds = lifetimeTicks * config.tickDuration;
    final bulletRange = bulletSpeed * config.speedScale * lifetimeSeconds;

    final bullet = Bullet(
      position: position + direction * _bulletSpawnOffset,
      velocity: direction * bulletSpeed * config.speedScale,
      faction: Faction.enemy,
      maxRange: bulletRange,
      maxLifetime: lifetimeSeconds,
    );

    onFireBullet?.call(bullet);
  }

  /// Finds the nearest alive player within detection range.
  PlayerSoldier? _findTarget() {
    PlayerSoldier? best;
    var bestDist = double.infinity;

    for (final player in players) {
      if (!player.isAlive) continue;

      final dist = position.distanceTo(player.position);
      if (dist > config.detectionRange) continue;
      if (dist < bestDist) {
        best = player;
        bestDist = dist;
      }
    }

    if (best == null) return null;

    // Close range — always engage.
    if (bestDist <= config.closeRange) return best;

    // Check line of sight.
    if (walkabilityGrid != null &&
        hasLineOfSight(
          grid: walkabilityGrid!,
          startX: position.x,
          startY: position.y,
          endX: best.position.x,
          endY: best.position.y,
        )) {
      return best;
    }

    // No LOS and not close enough.
    return null;
  }

  /// Effective bullet range (pixels) derived from aggression.
  ///
  /// Bullets can only travel this far, so firing beyond this is pointless.
  double get effectiveBulletRange {
    final bulletSpeed = 60.0 + aggression;
    final lifetimeTicks = ((aggression >> 3) + 8).clamp(8, 16);
    final lifetimeSeconds = lifetimeTicks * config.tickDuration;
    return bulletSpeed * config.speedScale * lifetimeSeconds;
  }

  /// Returns `true` if this enemy can fire at a target at [distance].
  ///
  /// Only returns true when the target is within effective bullet range *and*
  /// the enemy has line-of-sight (or is within close range). Without this
  /// range check, the enemy would never walk — it would always fire as soon
  /// as it detects a player (since detection already requires LOS).
  bool _canFireAt(double distance) {
    if (_target == null || !_target!.isAlive) return false;

    // Close range — always fire.
    if (distance <= config.closeRange) return true;

    // Beyond effective bullet range — need to walk closer first.
    if (distance > effectiveBulletRange) return false;

    // Need LOS for longer range.
    if (walkabilityGrid == null) return true; // No grid → assume clear.

    return hasLineOfSight(
      grid: walkabilityGrid!,
      startX: position.x,
      startY: position.y,
      endX: _target!.position.x,
      endY: _target!.position.y,
    );
  }

  void _transitionTo(EnemyAiState newState) {
    if (aiState == newState) return;
    aiState = newState;

    switch (newState) {
      case EnemyAiState.idle:
        setState(isInWater ? SoldierState.swimming : SoldierState.idle);
      case EnemyAiState.chasing:
        setState(isInWater ? SoldierState.swimming : SoldierState.walking);
      case EnemyAiState.firing:
        setState(SoldierState.firing);
        _fireTimer = 0; // Fire immediately on entering firing state.
    }
  }

  /// Computes a random scatter offset based on [aggressionAverage].
  ///
  /// Low aggression (< 5): ±0..63 px. High aggression: ±0..31 px.
  /// See `docs/ENEMY_AI.md` §4.5 for the original algorithm.
  void _recomputeScatter() {
    final mask = aggressionAverage < config.aggressionScatterThreshold
        ? config.scatterMaskLow
        : config.scatterMaskHigh;
    _targetScatter
      ..x = (_random.nextInt(mask + 1) * (_random.nextBool() ? 1.0 : -1.0))
      ..y = (_random.nextInt(mask + 1) * (_random.nextBool() ? 1.0 : -1.0));
  }

  /// Updates [isInWater] from the terrain under the soldier.
  ///
  /// Called before the AI state machine so speed / animation queries see
  /// the correct flag.
  void _updateWaterState() {
    final terrain = terrainUnderFoot();
    final wasInWater = isInWater;
    isInWater = _waterTerrains.contains(terrain);

    if (isInWater != wasInWater) {
      updateAnimations();
    }
  }

  /// Checks whether the enemy ended up on a cliff edge after movement and,
  /// if so, restores it to the last safe position.
  void _checkDropBounceBack() {
    final terrain = terrainUnderFoot();
    if (terrain == TerrainType.drop || terrain == TerrainType.drop2) {
      _bounceBack();
    }
  }

  /// Restores the enemy to its previous position and abandons the current
  /// target, mimicking the original game's `loc_20251` bounce-back for
  /// enemies on Drop/Drop2 tiles.
  void _bounceBack() {
    position.setFrom(_safePosition);
    _target = null;
    _transitionTo(EnemyAiState.idle);
  }
}

import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/player_soldier.dart';
import 'package:fodder_game/game/components/soldier.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/systems/line_of_sight.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

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

  /// Initial fire delay (seconds) before this enemy can fire for the first
  /// time. Set at spawn time for staggered fire timers (Step 9).
  double initialFireDelay = 0;

  /// The walkability grid used for line-of-sight checks.
  WalkabilityGrid? walkabilityGrid;

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

  /// Callback for spawning a bullet into the world.
  ///
  /// Set by `FodderGame` during enemy spawning. The enemy creates a [Bullet]
  /// and passes it to this callback so it can be added to the world.
  void Function(Bullet bullet)? onFireBullet;

  /// Movement speed derived from aggression: `(12 + aggression) * 5`, capped.
  double get _speed {
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

    // Consume initial fire delay.
    if (!_initialDelayConsumed) {
      initialFireDelay -= dt;
      if (initialFireDelay > 0) return;
      _initialDelayConsumed = true;
    }

    // AI state machine.
    switch (aiState) {
      case EnemyAiState.idle:
        _updateIdle(dt);
      case EnemyAiState.chasing:
        _updateChasing(dt);
      case EnemyAiState.firing:
        _updateFiring(dt);
    }
  }

  void _updateIdle(double dt) {
    _target = _findTarget();
    if (_target != null) {
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

    // Walk toward target.
    if (dist > 1) {
      final direction = toTarget.normalized();
      position += direction * _speed * dt;

      final newFacing = Direction8.fromVector(direction.x, direction.y);
      if (newFacing != facing) {
        facing = newFacing;
        updateAnimations();
      }
      setState(SoldierState.walking);
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

    final direction = toTarget.normalized();
    final bulletSpeed = 60.0 + aggression;
    // Bullet lifetime in ticks → seconds: ((aggression >> 3) + 8) * 0.05
    final lifetimeTicks = ((aggression >> 3) + 8).clamp(8, 16);
    final bulletRange = bulletSpeed * lifetimeTicks * 0.05 * 5;

    final bullet = Bullet(
      position: position.clone(),
      velocity: direction * bulletSpeed * 5, // Convert tick speed to px/s
      faction: Faction.enemy,
      maxRange: bulletRange,
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
    return bulletSpeed * lifetimeTicks * 0.05 * 5;
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
        setState(SoldierState.idle);
      case EnemyAiState.chasing:
        setState(SoldierState.walking);
      case EnemyAiState.firing:
        setState(SoldierState.firing);
        _fireTimer = 0; // Fire immediately on entering firing state.
    }
  }
}

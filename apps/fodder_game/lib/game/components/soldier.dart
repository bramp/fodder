import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';
import 'package:flutter/foundation.dart' show protected;
import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';
import 'package:fodder_game/game/config/game_config.dart' as config;
import 'package:fodder_game/game/map/level_map.dart';
import 'package:fodder_game/game/systems/walkability_grid.dart';

/// The high-level state of a soldier.
enum SoldierState {
  /// Standing still, showing idle animation.
  idle,

  /// Moving along a path, showing walk animation.
  walking,

  /// Swimming in water.
  swimming,

  /// Lying prone on the ground.
  prone,

  /// Holding the standing-with-gun pose while firing.
  firing,

  /// Playing a throw animation (grenade / rocket).
  throwing,

  /// Falling off a cliff edge (Drop terrain — gravity slide downward).
  falling,

  /// Stumbling forward off a steep ledge (Drop2 terrain — in-place tumble).
  stumbling,

  /// Playing death animation before removal.
  dying,
}

/// Duration (seconds) a dying soldier is visible before fade-out starts.
const double _deathAnimDuration = config.deathAnimDuration;

/// Duration (seconds) for the post-death fade-out effect.
const double deathFadeDuration = config.deathFadeDuration;

/// Total time from death until removal.
const double _deathRemovalDelay = _deathAnimDuration + deathFadeDuration;

/// Base class for all soldier entities (player and enemy).
///
/// Manages 8-directional walk/idle sprite animations loaded from the army
/// sprite atlas via [SoldierAnimations].
abstract class Soldier extends SpriteAnimationGroupComponent<SoldierState>
    with CollisionCallbacks {
  Soldier({
    required this.soldierAnimations,
    Random? random,
    super.priority = 10,
  }) : _random = random ?? Random(),
       super(size: soldierAnimations.scaledSize, anchor: Anchor.center);

  /// The loaded walk/idle animation set.
  final SoldierAnimations soldierAnimations;

  /// Current facing direction.
  Direction8 facing = Direction8.south;

  /// Whether this soldier is still alive.
  bool isAlive = true;

  /// Whether this soldier is invincible (immune to bullet damage).
  ///
  /// When true, bullet collisions are ignored. This is a cheat/debug
  /// feature matching the original game's F9 key.
  bool isInvincible = false;

  /// Whether this soldier is currently moving (affects dodge chance).
  bool isMoving = false;

  /// Whether the death sequence (animation + fade) has finished.
  ///
  /// Once true the corpse stays on screen but no longer updates.
  bool _deathComplete = false;

  /// Whether this soldier's death sequence has finished and the corpse is
  /// frozen in place.
  bool get isCorpse => _deathComplete;

  /// Counts down after death; when it reaches zero the corpse is finalised.
  double _deathTimer = 0;

  /// Random number generator for death variant selection and dodge.
  final Random _random;

  /// Callback invoked when this soldier dies.
  ///
  /// Set by the game to perform cleanup (e.g. remove from enemy list,
  /// decrement counters).
  void Function()? onDeath;

  /// The collision hitbox size for this soldier.
  ///
  /// Per the original game spec, enemies use 16×16 and players use 6×5. Each
  /// concrete subclass must provide its own value.
  Vector2 get hitboxSize;

  /// The [Faction] that opposes this soldier (bullets from this faction hurt).
  Faction get opposingFaction;

  /// The walkability grid used for terrain queries (water, quicksand, etc.).
  WalkabilityGrid? walkabilityGrid;

  /// Whether this soldier is currently standing on a water tile.
  ///
  /// Updated each frame by subclasses calling [terrainUnderFoot].
  bool isInWater = false;

  // ---------------------------------------------------------------------------
  // Drop / cliff state
  // ---------------------------------------------------------------------------

  /// Whether this soldier is currently falling or stumbling off a cliff.
  bool get isFalling => fallTimer > 0;

  /// Whether this soldier is in a Drop2 stumble (as opposed to a Drop slide).
  bool get isStumbling => stumbleTimer > 0;

  /// Countdown timer for the Drop gravity-slide (seconds).
  ///
  /// Set to [config.dropFallDuration] when the soldier steps on a Drop tile.
  /// Counts down each frame. If the soldier slides onto non-drop terrain
  /// before the timer expires they survive (matching the original game's
  /// `field_12 < 12` check). If the timer reaches zero, the soldier dies.
  @protected
  double fallTimer = 0;

  /// Downward velocity accumulated during a Drop fall (pixels/second).
  @protected
  double fallSpeed = 0;

  /// Countdown timer for the Drop2 stumble (seconds).
  ///
  /// In the original game, visual height (`field_52`) accumulates rapidly
  /// (1+2+3+4+5 = 15 in ~5 frames). Death occurs when `field_52 ≥ 14`
  /// (~0.3 s). The soldier stays in place — no Y displacement.
  @protected
  double stumbleTimer = 0;

  /// Resets all fall / stumble state.
  @protected
  void resetFallState() {
    fallTimer = 0;
    fallSpeed = 0;
    stumbleTimer = 0;
  }

  /// Returns the [TerrainType] under this soldier's current position.
  ///
  /// Uses tile-level terrain lookup. Returns [TerrainType.land] when no
  /// walkability grid is available.
  TerrainType terrainUnderFoot() {
    final grid = walkabilityGrid;
    if (grid == null) return TerrainType.land;

    final tileX = (position.x / LevelMap.destTileSize).floor();
    final tileY = (position.y / LevelMap.destTileSize).floor();
    return grid.terrainAt(tileX, tileY);
  }

  @override
  Future<void> onLoad() async {
    updateAnimations();
    current = SoldierState.idle;

    // Add the collision hitbox, centred on the sprite.
    add(
      RectangleHitbox(
        size: hitboxSize,
        position: (size - hitboxSize) / 2,
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);

    if (!isAlive) return;
    if (other is Bullet && other.faction == opposingFaction) {
      // Invincibility cheat: ignore all incoming damage.
      if (isInvincible) return;

      // Dodge mechanic (PLAYER.md §1.2): moving soldiers have a 1/8 chance
      // to dodge. Close-range bullets (age ≤ 0.24s) cannot be dodged.
      if (isMoving && other.age > config.dodgeMinBulletAge) {
        if (_random.nextInt(config.dodgeChanceOneIn) == 0) {
          return; // Dodged! Bullet continues.
        }
      }

      other.removeFromParent();
      die();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isAlive) {
      if (_deathComplete) return; // Corpse — nothing more to do.

      _deathTimer -= dt;
      if (_deathTimer <= 0) {
        // Death sequence finished — freeze the corpse in place.
        opacity = 0;
        _deathComplete = true;

        // Remove the collision hitbox so corpses don't interact with bullets.
        children.whereType<RectangleHitbox>().forEach(remove);
        return;
      }

      // Fade out during the last [deathFadeDuration] seconds.
      if (_deathTimer < deathFadeDuration) {
        opacity = (_deathTimer / deathFadeDuration).clamp(0, 1);
      }
    }
  }

  /// Kills this soldier: randomly picks a death animation variant, transitions
  /// to the dying state and schedules removal after fade-out.
  ///
  /// Has no effect if the soldier is already dead. Falls back to idle
  /// if no death animation is available for the current facing direction.
  void die() {
    if (!isAlive) return;
    isAlive = false;
    _deathTimer = _deathRemovalDelay;

    // Randomly pick a death variant (death or death2).
    _pickDeathVariant();

    // Only switch to dying if the animation exists; otherwise keep current.
    if (animations?.containsKey(SoldierState.dying) ?? false) {
      setState(SoldierState.dying);
    }

    onDeath?.call();
  }

  /// Randomly swaps the dying animation from the available death variants.
  void _pickDeathVariant() {
    final variants = [
      if (soldierAnimations.deathAnimations != null)
        soldierAnimations.deathAnimations!,
      if (soldierAnimations.death2Animations != null)
        soldierAnimations.death2Animations!,
    ];

    if (variants.isEmpty) return;

    final chosen = variants[_random.nextInt(variants.length)];
    final anim = chosen[facing];
    if (animations != null) {
      // Flame wraps animations in UnmodifiableMapView, so we must create a
      // new map with the chosen variant rather than modifying in place.
      animations = Map<SoldierState, SpriteAnimation>.of(animations!)
        ..[SoldierState.dying] = anim;
    }
  }

  /// Rebuilds the animation map based on the current [facing] direction.
  void updateAnimations() {
    animations = {
      SoldierState.walking: soldierAnimations.walkAnimations[facing],
      SoldierState.idle: soldierAnimations.idleAnimations[facing],
      if (soldierAnimations.firingAnimations != null)
        SoldierState.firing: soldierAnimations.firingAnimations![facing],
      if (soldierAnimations.throwAnimations != null)
        SoldierState.throwing: soldierAnimations.throwAnimations![facing],
      if (soldierAnimations.proneAnimations != null)
        SoldierState.prone: soldierAnimations.proneAnimations![facing],
      if (soldierAnimations.swimAnimations != null)
        SoldierState.swimming: soldierAnimations.swimAnimations![facing],
      if (soldierAnimations.deathAnimations != null)
        SoldierState.dying: soldierAnimations.deathAnimations![facing],
    };
  }

  /// Sets the current state if it has changed.
  ///
  /// If the requested [state] has no loaded animation, falls back to the
  /// closest equivalent that does. This prevents assertion failures when
  /// e.g. swimming animations are not available.
  void setState(SoldierState state) {
    if (current == state) return;

    // If the animation exists, use it directly.
    if (animations?.containsKey(state) ?? false) {
      current = state;
      return;
    }

    // Fallback mapping when animation is missing.
    // TODO(bramp): Should we allow fallbacks? or fail the game?
    final fallback = switch (state) {
      SoldierState.swimming => SoldierState.walking,
      SoldierState.prone => SoldierState.idle,
      SoldierState.falling => SoldierState.walking,
      SoldierState.stumbling => SoldierState.dying,
      _ => null,
    };
    if (fallback != null && (animations?.containsKey(fallback) ?? false)) {
      current = fallback;
    }
  }
}

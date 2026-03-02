import 'dart:math';

import 'package:flame/collisions.dart';
import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/components/soldier_animations.dart';

/// The high-level state of a soldier.
enum SoldierState {
  /// Standing still, showing idle animation.
  idle,

  /// Moving along a path, showing walk animation.
  walking,

  /// Holding the standing-with-gun pose while firing.
  firing,

  /// Playing a throw animation (grenade / rocket).
  throwing,

  /// Playing death animation before removal.
  dying,
}

/// Duration (seconds) a dying soldier is visible before fade-out starts.
const _deathAnimDuration = 0.5;

/// Duration (seconds) for the post-death fade-out effect.
const deathFadeDuration = 0.5;

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

  /// Counts down after death; when it reaches zero the component is removed.
  // TODO(bramp): Consider leaving a dead body forever
  double _deathTimer = 0;

  /// Random number generator for death variant selection.
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
      other.removeFromParent();
      die();
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (!isAlive) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) {
        removeFromParent();
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
    final anims = <Map<Direction8, SpriteAnimation>>[
      if (soldierAnimations.deathAnimations.isNotEmpty)
        soldierAnimations.deathAnimations,
      if (soldierAnimations.death2Animations.isNotEmpty)
        soldierAnimations.death2Animations,
    ];

    if (anims.isEmpty) return;

    final chosen = anims[_random.nextInt(anims.length)];
    final anim = chosen[facing] ?? chosen[Direction8.south];
    if (anim != null && animations != null) {
      // Flame wraps animations in UnmodifiableMapView, so we must create a
      // new map with the chosen variant rather than modifying in place.
      animations = Map<SoldierState, SpriteAnimation>.of(animations!)
        ..[SoldierState.dying] = anim;
    }
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
      if (soldierAnimations.firingAnimations.containsKey(facing))
        SoldierState.firing: soldierAnimations.firingAnimations[facing]!,
      if (soldierAnimations.throwAnimations.containsKey(facing))
        SoldierState.throwing: soldierAnimations.throwAnimations[facing]!,
      if (soldierAnimations.deathAnimations.containsKey(facing))
        SoldierState.dying: soldierAnimations.deathAnimations[facing]!,
    };
  }

  /// Sets the current state if it has changed.
  void setState(SoldierState state) {
    if (current != state) {
      current = state;
    }
  }
}

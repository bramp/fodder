import 'package:flame/components.dart';

import 'package:fodder_game/game/components/direction8.dart';
import 'package:fodder_game/game/sprites/sprite_atlas.dart';
import 'package:fodder_game/game/sprites/sprite_frames.dart';

/// Default step time for walk animation frames (seconds).
const _walkStepTime = 0.15;

/// Default step time for idle animation (single frame, held indefinitely).
const double _idleStepTime = double.infinity;

/// Default step time for death animation frames (seconds).
const _deathStepTime = 0.2;

/// Default step time for throw animation frames (seconds).
const _throwStepTime = 0.12;

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const _spriteScale = 2.0;

/// Loads soldier sprite animations from a TexturePacker JSON Hash atlas.
///
/// The atlas is expected to contain frames named
/// `ingame/{prefix}_{direction}_{frame}` where `prefix` is a semantic name
/// (e.g. `player_walk`), `direction` is a compass suffix (`s`, `sw`, …),
/// and `frame` is a zero-based frame index.
class SoldierAnimations {
  SoldierAnimations._({
    required this.walkAnimations,
    required this.idleAnimations,
    required this.firingAnimations,
    required this.throwAnimations,
    required this.proneAnimations,
    required this.swimAnimations,
    required this.deathAnimations,
    required this.death2Animations,
  });

  /// Creates a [SoldierAnimations] from pre-built animation maps.
  ///
  /// Intended for testing; production code should use
  /// [SoldierAnimations.fromAtlas].
  /// Required maps must contain all 8 directions.
  /// Optional maps (firing, throw, etc.) must either contain all 8 directions
  /// or be empty (defaulting to null).
  SoldierAnimations.fromMaps({
    required Map<Direction8, SpriteAnimation> walkAnimations,
    required Map<Direction8, SpriteAnimation> idleAnimations,
    Map<Direction8, SpriteAnimation> firingAnimations = const {},
    Map<Direction8, SpriteAnimation> throwAnimations = const {},
    Map<Direction8, SpriteAnimation> proneAnimations = const {},
    Map<Direction8, SpriteAnimation> swimAnimations = const {},
    Map<Direction8, SpriteAnimation> deathAnimations = const {},
    Map<Direction8, SpriteAnimation> death2Animations = const {},
  }) : walkAnimations = Directional.fromMap(walkAnimations),
       idleAnimations = Directional.fromMap(idleAnimations),
       firingAnimations = firingAnimations.isEmpty
           ? null
           : Directional.fromMap(firingAnimations),
       throwAnimations = throwAnimations.isEmpty
           ? null
           : Directional.fromMap(throwAnimations),
       proneAnimations = proneAnimations.isEmpty
           ? null
           : Directional.fromMap(proneAnimations),
       swimAnimations = swimAnimations.isEmpty
           ? null
           : Directional.fromMap(swimAnimations),
       deathAnimations = deathAnimations.isEmpty
           ? null
           : Directional.fromMap(deathAnimations),
       death2Animations = death2Animations.isEmpty
           ? null
           : Directional.fromMap(death2Animations);

  /// Builds soldier animations from a pre-loaded [SpriteAtlas].
  ///
  /// [walkGroup] is the animation group for the 8-direction walk cycle.
  /// Defaults to [walkGroupPlayer]; use [walkGroupEnemy] for enemies.
  ///
  /// [firingGroup] is the group for standing-with-gun (firing pose).
  /// Defaults to [firingGroupPlayer].
  ///
  /// [throwGroup] is the group for throw animations.
  /// Defaults to [throwGroupPlayer].
  ///
  /// [deathGroup] is the group for death animations.
  /// Defaults to [deathGroupPlayer].
  ///
  /// [death2Group] is the group for the second death variant.
  /// Defaults to [death2GroupPlayer].
  factory SoldierAnimations.fromAtlas(
    SpriteAtlas atlas, {
    String walkGroup = walkGroupPlayer,
    String firingGroup = firingGroupPlayer,
    String throwGroup = throwGroupPlayer,
    String proneGroup = proneGroupPlayer,
    String swimGroup = swimGroupPlayer,
    String deathGroup = deathGroupPlayer,
    String death2Group = death2GroupPlayer,
  }) {
    final walkAnims = <Direction8, SpriteAnimation>{};
    final idleAnims = <Direction8, SpriteAnimation>{};
    final firingAnims = <Direction8, SpriteAnimation>{};
    final throwAnims = <Direction8, SpriteAnimation>{};
    final proneAnims = <Direction8, SpriteAnimation>{};
    final swimAnims = <Direction8, SpriteAnimation>{};
    final deathAnims = <Direction8, SpriteAnimation>{};
    final death2Anims = <Direction8, SpriteAnimation>{};

    for (final dir in Direction8.values) {
      final dirSuffix = dir.suffix;

      // --- Walk / Idle ---
      final walkFrames = atlas.animationFrames(
        '${walkGroup}_$dirSuffix',
        _walkStepTime,
      );
      if (walkFrames.isEmpty) {
        throw StateError('Missing walk animation for $dir ($walkGroup)');
      }
      walkAnims[dir] = SpriteAnimation(walkFrames);
      idleAnims[dir] = SpriteAnimation([
        SpriteAnimationFrame(walkFrames.first.sprite, _idleStepTime),
      ]);

      // --- Firing (standing-with-gun) ---
      final firingFrames = atlas.animationFrames(
        '${firingGroup}_$dirSuffix',
        _idleStepTime,
      );
      if (firingFrames.isNotEmpty) {
        firingAnims[dir] = SpriteAnimation(firingFrames, loop: false);
      }

      // --- Throw ---
      final throwFrameList = atlas.animationFrames(
        '${throwGroup}_$dirSuffix',
        _throwStepTime,
      );
      if (throwFrameList.isNotEmpty) {
        throwAnims[dir] = SpriteAnimation(throwFrameList, loop: false);
      }

      // --- Prone ---
      final proneFrames = atlas.animationFrames(
        '${proneGroup}_$dirSuffix',
        _idleStepTime,
      );
      if (proneFrames.isNotEmpty) {
        proneAnims[dir] = SpriteAnimation(proneFrames, loop: false);
      }

      // --- Swim ---
      final swimFrames = atlas.animationFrames(
        '${swimGroup}_$dirSuffix',
        _walkStepTime,
      );
      if (swimFrames.isNotEmpty) {
        swimAnims[dir] = SpriteAnimation(swimFrames);
      }

      // --- Death ---
      final deathFrames = atlas.animationFrames(
        '${deathGroup}_$dirSuffix',
        _deathStepTime,
      );
      if (deathFrames.isNotEmpty) {
        deathAnims[dir] = SpriteAnimation(deathFrames, loop: false);
      }

      // --- Death-2 ---
      final death2Frames = atlas.animationFrames(
        '${death2Group}_$dirSuffix',
        _deathStepTime,
      );
      if (death2Frames.isNotEmpty) {
        death2Anims[dir] = SpriteAnimation(death2Frames, loop: false);
      }
    }

    Directional<SpriteAnimation>? toDir(Map<Direction8, SpriteAnimation> map) {
      if (map.isEmpty) return null;
      if (map.length != 8) {
        throw StateError('Animation must have all 8 directions if any exist');
      }
      return Directional.fromMap(map);
    }

    return SoldierAnimations._(
      walkAnimations: Directional(
        Direction8.values.map((d) => walkAnims[d]!).toList(),
      ),
      idleAnimations: Directional(
        Direction8.values.map((d) => idleAnims[d]!).toList(),
      ),
      firingAnimations: toDir(firingAnims),
      throwAnimations: toDir(throwAnims),
      proneAnimations: toDir(proneAnims),
      swimAnimations: toDir(swimAnims),
      deathAnimations: toDir(deathAnims),
      death2Animations: toDir(death2Anims),
    );
  }

  /// Walk animations keyed by direction (3 frames each, looping).
  final Directional<SpriteAnimation> walkAnimations;

  /// Idle animations keyed by direction (single frame, non-looping).
  final Directional<SpriteAnimation> idleAnimations;

  /// Standing-with-gun (firing pose) keyed by direction (single frame).
  final Directional<SpriteAnimation>? firingAnimations;

  /// Throw animations keyed by direction (3 frames each).
  final Directional<SpriteAnimation>? throwAnimations;

  /// Prone (lying down) animations keyed by direction.
  final Directional<SpriteAnimation>? proneAnimations;

  /// Swimming animations keyed by direction.
  final Directional<SpriteAnimation>? swimAnimations;

  /// Death animations keyed by direction (1–2 frames, non-looping).
  final Directional<SpriteAnimation>? deathAnimations;

  /// Death-2 variant animations keyed by direction (1–2 frames, non-looping).
  final Directional<SpriteAnimation>? death2Animations;

  /// Returns the sprite size at 2× scale based on the first walk-south frame.
  Vector2 get scaledSize {
    final frame = walkAnimations[Direction8.south].frames.first.sprite;
    return Vector2(
      frame.srcSize.x * _spriteScale,
      frame.srcSize.y * _spriteScale,
    );
  }
}

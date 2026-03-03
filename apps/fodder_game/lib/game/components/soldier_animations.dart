import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'package:fodder_game/game/components/direction8.dart';

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

/// Walk animation name prefix for player (human) soldiers.
const walkPrefixPlayer = 'player_walk';

/// Walk animation name prefix for enemy (AI) soldiers.
const walkPrefixEnemy = 'enemy_walk';

/// Throw animation name prefix for player soldiers.
const throwPrefixPlayer = 'player_throw';

/// Throw animation name prefix for enemy soldiers.
const throwPrefixEnemy = 'enemy_throw';

/// Death-1 animation name prefix for player soldiers.
const deathPrefixPlayer = 'player_death';

/// Death-1 animation name prefix for enemy soldiers.
const deathPrefixEnemy = 'enemy_death';

/// Death-2 animation name prefix for player soldiers.
const death2PrefixPlayer = 'player_death2';

/// Death-2 animation name prefix for enemy soldiers.
const death2PrefixEnemy = 'enemy_death2';

/// Prone animation name prefix for player soldiers.
const pronePrefixPlayer = 'player_prone';

/// Prone animation name prefix for enemy soldiers.
const pronePrefixEnemy = 'enemy_prone';

/// Swimming animation name prefix for player soldiers.
const swimPrefixPlayer = 'player_swim';

/// Swimming animation name prefix for enemy soldiers.
const swimPrefixEnemy = 'enemy_swim';

/// Standing-with-gun animation name prefix for player soldiers.
const firingPrefixPlayer = 'player_firing';

/// Standing-with-gun animation name prefix for enemy soldiers.
const firingPrefixEnemy = 'enemy_firing';

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
  /// Intended for testing; production code should use [load].
  /// The [firingAnimations], [throwAnimations], and [deathAnimations] maps
  /// default to empty when omitted, preserving backward compatibility with
  /// existing tests.
  SoldierAnimations.fromMaps({
    required this.walkAnimations,
    required this.idleAnimations,
    this.firingAnimations = const {},
    this.throwAnimations = const {},
    this.proneAnimations = const {},
    this.swimAnimations = const {},
    this.deathAnimations = const {},
    this.death2Animations = const {},
  });

  // TODO(bramp): Replace Map with List with fixed offsets.

  /// Walk animations keyed by direction (3 frames each, looping).
  final Map<Direction8, SpriteAnimation> walkAnimations;

  /// Idle animations keyed by direction (single frame, non-looping).
  final Map<Direction8, SpriteAnimation> idleAnimations;

  /// Standing-with-gun (firing pose) keyed by direction (single frame).
  final Map<Direction8, SpriteAnimation> firingAnimations;

  /// Throw animations keyed by direction (3 frames each).
  final Map<Direction8, SpriteAnimation> throwAnimations;

  /// Prone (lying down) animations keyed by direction.
  final Map<Direction8, SpriteAnimation> proneAnimations;

  /// Swimming animations keyed by direction.
  final Map<Direction8, SpriteAnimation> swimAnimations;

  /// Death animations keyed by direction (1–2 frames, non-looping).
  final Map<Direction8, SpriteAnimation> deathAnimations;

  /// Death-2 variant animations keyed by direction (1–2 frames, non-looping).
  final Map<Direction8, SpriteAnimation> death2Animations;

  /// Loads animations from the given atlas JSON and sprite sheet image.
  ///
  /// [prefix] is the asset path prefix (e.g.
  /// `packages/fodder_assets/assets/cf1/sprites/`).
  ///
  /// [imageFile] is the image file name (e.g. `junarmy.png`).
  ///
  /// [atlasJsonFile] is the atlas JSON file name (e.g. `junarmy.json`).
  ///
  /// [walkPrefix] is the semantic name prefix for the 8-direction walk cycle.
  /// Defaults to [walkPrefixPlayer]; use [walkPrefixEnemy] for enemies.
  ///
  /// [firingPrefix] is the name prefix for standing-with-gun (firing pose)
  /// animations. Defaults to [firingPrefixPlayer].
  ///
  /// [throwPrefix] is the name prefix for throw animations.
  /// Defaults to [throwPrefixPlayer].
  ///
  /// [deathPrefix] is the name prefix for death animations.
  /// Defaults to [deathPrefixPlayer].
  ///
  /// [death2Prefix] is the name prefix for the second death variant.
  /// Defaults to [death2PrefixPlayer].
  static Future<SoldierAnimations> load({
    required String prefix,
    required String imageFile,
    required String atlasJsonFile,
    String walkPrefix = walkPrefixPlayer,
    String firingPrefix = firingPrefixPlayer,
    String throwPrefix = throwPrefixPlayer,
    String pronePrefix = pronePrefixPlayer,
    String swimPrefix = swimPrefixPlayer,
    String deathPrefix = deathPrefixPlayer,
    String death2Prefix = death2PrefixPlayer,
  }) async {
    // Use a custom Images instance whose prefix matches the package path.
    final images = Images(prefix: prefix);
    final image = await images.load(imageFile);

    // Load and parse the atlas JSON.
    final jsonString = await rootBundle.loadString(
      '$prefix$atlasJsonFile',
    );
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final framesMap = jsonData['frames'] as Map<String, dynamic>;

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
      final walkFrames = _loadFrames(
        framesMap,
        image,
        '${walkPrefix}_$dirSuffix',
        _walkStepTime,
      );
      if (walkFrames.isNotEmpty) {
        walkAnims[dir] = SpriteAnimation(walkFrames);
        idleAnims[dir] = SpriteAnimation(
          [SpriteAnimationFrame(walkFrames.first.sprite, _idleStepTime)],
        );
      }

      // --- Firing (standing-with-gun) ---
      final firingFrames = _loadFrames(
        framesMap,
        image,
        '${firingPrefix}_$dirSuffix',
        _idleStepTime, // single frame held indefinitely
      );
      if (firingFrames.isNotEmpty) {
        firingAnims[dir] = SpriteAnimation(firingFrames, loop: false);
      }

      // --- Throw ---
      final throwFrameList = _loadFrames(
        framesMap,
        image,
        '${throwPrefix}_$dirSuffix',
        _throwStepTime,
      );
      if (throwFrameList.isNotEmpty) {
        throwAnims[dir] = SpriteAnimation(
          throwFrameList,
          loop: false,
        );
      }

      // --- Prone ---
      final proneFrames = _loadFrames(
        framesMap,
        image,
        '${pronePrefix}_$dirSuffix',
        _idleStepTime, // single frame held
      );
      if (proneFrames.isNotEmpty) {
        proneAnims[dir] = SpriteAnimation(proneFrames, loop: false);
      }

      // --- Swim ---
      final swimFrames = _loadFrames(
        framesMap,
        image,
        '${swimPrefix}_$dirSuffix',
        _walkStepTime,
      );
      if (swimFrames.isNotEmpty) {
        swimAnims[dir] = SpriteAnimation(swimFrames);
      }

      // --- Death ---
      final deathFrames = _loadFrames(
        framesMap,
        image,
        '${deathPrefix}_$dirSuffix',
        _deathStepTime,
      );
      if (deathFrames.isNotEmpty) {
        deathAnims[dir] = SpriteAnimation(deathFrames, loop: false);
      }

      // --- Death-2 ---
      final death2Frames = _loadFrames(
        framesMap,
        image,
        '${death2Prefix}_$dirSuffix',
        _deathStepTime,
      );
      if (death2Frames.isNotEmpty) {
        death2Anims[dir] = SpriteAnimation(death2Frames, loop: false);
      }
    }

    return SoldierAnimations._(
      walkAnimations: walkAnims,
      idleAnimations: idleAnims,
      firingAnimations: firingAnims,
      throwAnimations: throwAnims,
      proneAnimations: proneAnims,
      swimAnimations: swimAnims,
      deathAnimations: deathAnims,
      death2Animations: death2Anims,
    );
  }

  /// Parses atlas frames for a named sprite group.
  ///
  /// Looks for keys `ingame/{groupName}_{frameIndex}` in [framesMap].
  /// Returns an empty list when no frames are found.
  static List<SpriteAnimationFrame> _loadFrames(
    Map<String, dynamic> framesMap,
    Image image,
    String groupName,
    double stepTime,
  ) {
    final frames = <SpriteAnimationFrame>[];

    for (var f = 0; ; f++) {
      final key = 'ingame/${groupName}_$f';
      final frameData = framesMap[key] as Map<String, dynamic>?;
      if (frameData == null) break;

      final frame = frameData['frame'] as Map<String, dynamic>;
      final fx = (frame['x'] as num).toDouble();
      final fy = (frame['y'] as num).toDouble();
      final fw = (frame['w'] as num).toDouble();
      final fh = (frame['h'] as num).toDouble();

      final sprite = Sprite(
        image,
        srcPosition: Vector2(fx, fy),
        srcSize: Vector2(fw, fh),
      );

      frames.add(SpriteAnimationFrame(sprite, stepTime));
    }

    return frames;
  }

  /// Returns the sprite size at 2× scale based on the first walk-south frame.
  Vector2 get scaledSize {
    final anim = walkAnimations[Direction8.south];
    if (anim == null) return Vector2.all(32);
    final frame = anim.frames.first.sprite;
    return Vector2(
      frame.srcSize.x * _spriteScale,
      frame.srcSize.y * _spriteScale,
    );
  }
}

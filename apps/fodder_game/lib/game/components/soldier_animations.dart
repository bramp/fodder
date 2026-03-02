import 'dart:convert';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'package:fodder_game/game/components/direction8.dart';

/// Default step time for walk animation frames (seconds).
const _walkStepTime = 0.15;

/// Default step time for idle animation (single frame, held indefinitely).
const double _idleStepTime = double.infinity;

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const _spriteScale = 2.0;

/// Walk animation base group index in the atlas (groups 0x00–0x07).
const _walkBaseGroup = 0x00;

/// Loads soldier sprite animations from a TexturePacker JSON Hash atlas.
///
/// The atlas is expected to contain frames named `ingame/{groupHex}_{frame}`
/// where group indices 0x00–0x07 are walk animations for 8 directions and
/// frame 0 of each group doubles as the idle animation.
class SoldierAnimations {
  SoldierAnimations._({
    required this.walkAnimations,
    required this.idleAnimations,
  });

  /// Walk animations keyed by direction (3 frames each, looping).
  final Map<Direction8, SpriteAnimation> walkAnimations;

  /// Idle animations keyed by direction (single frame, non-looping).
  final Map<Direction8, SpriteAnimation> idleAnimations;

  /// Loads animations from the given atlas JSON and sprite sheet image.
  ///
  /// [prefix] is the asset path prefix (e.g.
  /// `packages/fodder_assets/assets/cf1/sprites/`).
  ///
  /// [imageFile] is the image file name (e.g. `junarmy.png`).
  ///
  /// [atlasJsonFile] is the atlas JSON file name (e.g. `junarmy.json`).
  static Future<SoldierAnimations> load({
    required String prefix,
    required String imageFile,
    required String atlasJsonFile,
  }) async {
    // Use a custom Images instance whose prefix matches the package path.
    final images = Images(prefix: prefix);
    final image = await images.load(imageFile);

    // Load and parse the atlas JSON.
    final jsonString = await rootBundle.loadString('$prefix$atlasJsonFile');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final framesMap = jsonData['frames'] as Map<String, dynamic>;

    final walkAnims = <Direction8, SpriteAnimation>{};
    final idleAnims = <Direction8, SpriteAnimation>{};

    for (final dir in Direction8.values) {
      final groupIndex = _walkBaseGroup + dir.index;
      final groupHex = groupIndex.toRadixString(16).padLeft(2, '0');

      // Collect frames for this direction's walk cycle.
      final walkFrames = <SpriteAnimationFrame>[];
      for (var f = 0; ; f++) {
        final key = 'ingame/${groupHex}_$f';
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

        walkFrames.add(SpriteAnimationFrame(sprite, _walkStepTime));
      }

      if (walkFrames.isNotEmpty) {
        walkAnims[dir] = SpriteAnimation(walkFrames);

        // Idle = first frame of the walk cycle, held indefinitely.
        idleAnims[dir] = SpriteAnimation(
          [SpriteAnimationFrame(walkFrames.first.sprite, _idleStepTime)],
        );
      }
    }

    return SoldierAnimations._(
      walkAnimations: walkAnims,
      idleAnimations: idleAnims,
    );
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

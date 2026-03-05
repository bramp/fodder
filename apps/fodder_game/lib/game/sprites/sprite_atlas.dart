import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

/// A loaded sprite atlas (image + frame metadata).
///
/// Wraps a TexturePacker JSON Hash atlas, providing typed sprite lookups by
/// group name and frame index. Load once via [SpriteAtlas.load] and share
/// across all consumers that need frames from the same sprite sheet.
///
/// ## Frame naming convention
///
/// Frames in the atlas JSON follow the pattern:
/// ```text
/// ingame/{groupName}_{frameIndex}
/// ```
/// For example, `ingame/bullet_0`, `ingame/player_walk_s_2`.
class SpriteAtlas {
  SpriteAtlas._({required this.image, required this.framesMap});

  /// Creates a [SpriteAtlas] from pre-built data.
  ///
  /// Intended for testing; production code should use [SpriteAtlas.load].
  SpriteAtlas.fromData({required this.image, required this.framesMap});

  /// The loaded sprite sheet image.
  final Image image;

  /// Raw frames map from the atlas JSON (`frames` key).
  ///
  /// Keys are frame names (e.g. `ingame/bullet_0`), values are frame
  /// metadata objects with `frame`, `sourceSize`, `anchor`, etc.
  final Map<String, dynamic> framesMap;

  /// Loads a sprite atlas from the given asset files.
  ///
  /// [prefix] is the asset path prefix (e.g.
  /// `packages/fodder_assets/assets/cf1/sprites/`).
  ///
  /// [jsonFile] is the atlas JSON file name (e.g. `juncopt.json`).
  ///
  /// [imageFile] is the sprite sheet image (e.g. `juncopt.png`).
  static Future<SpriteAtlas> load({
    required String prefix,
    required String jsonFile,
    required String imageFile,
  }) async {
    final images = Images(prefix: prefix);
    final image = await images.load(imageFile);

    final jsonString = await rootBundle.loadString('$prefix$jsonFile');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final framesMap = jsonData['frames'] as Map<String, dynamic>;

    return SpriteAtlas._(image: image, framesMap: framesMap);
  }

  /// Returns a [Sprite] for the given atlas frame [key].
  ///
  /// The [key] is the full frame name (e.g. `ingame/bullet_0`).
  /// Returns `null` if the frame is not found.
  Sprite? spriteByKey(String key) {
    final frameData = framesMap[key] as Map<String, dynamic>?;
    if (frameData == null) return null;

    final frame = frameData['frame'] as Map<String, dynamic>;
    return Sprite(
      image,
      srcPosition: Vector2(
        (frame['x'] as num).toDouble(),
        (frame['y'] as num).toDouble(),
      ),
      srcSize: Vector2(
        (frame['w'] as num).toDouble(),
        (frame['h'] as num).toDouble(),
      ),
    );
  }

  /// Returns a [Sprite] for the given [groupName] and [frameIndex].
  ///
  /// Looks up `ingame/{groupName}_{frameIndex}` in the atlas.
  /// Returns `null` if the frame is not found.
  Sprite? sprite(String groupName, int frameIndex) =>
      spriteByKey('ingame/${groupName}_$frameIndex');

  /// Returns all frames for a given [groupName] as a list of
  /// [SpriteAnimationFrame]s.
  ///
  /// Iterates `ingame/{groupName}_0`, `ingame/{groupName}_1`, … until
  /// no more frames are found. Returns an empty list if no frames exist.
  List<SpriteAnimationFrame> animationFrames(
    String groupName,
    double stepTime,
  ) {
    final frames = <SpriteAnimationFrame>[];
    for (var i = 0; ; i++) {
      final s = sprite(groupName, i);
      if (s == null) break;
      frames.add(SpriteAnimationFrame(s, stepTime));
    }
    return frames;
  }
}

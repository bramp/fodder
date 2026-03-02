import 'dart:convert';
import 'dart:ui';

import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'package:fodder_game/game/components/bullet.dart';

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const _spriteScale = 2.0;

/// Atlas group name for bullet sprites (produced by `fodder_tools`).
const _bulletGroupName = 'bullet';

/// Frame index used for player bullet appearance (during flight).
const _playerBulletFrame = 0;

/// Frame index used for enemy bullet appearance (during flight).
const _enemyBulletFrame = 3;

/// Loads bullet sprites from the copt atlas (where bullet frames live).
///
/// The original game stores bullet frames in the helicopter / copt sprite
/// sheet. The atlas uses the semantic name `bullet` with 8 directional
/// frames. During flight the game uses frame 0 for player bullets and
/// frame 3 for enemy bullets.
class BulletSprites {
  BulletSprites._({
    required this.playerSprite,
    required this.enemySprite,
    required this.scaledSize,
  });

  /// Sprite used for player-fired bullets.
  final Sprite playerSprite;

  /// Sprite used for enemy-fired bullets.
  final Sprite enemySprite;

  /// Bullet size at 2× display scale.
  final Vector2 scaledSize;

  /// Returns the appropriate sprite for the given [faction].
  Sprite spriteFor(Faction faction) {
    switch (faction) {
      case Faction.player:
        return playerSprite;
      case Faction.enemy:
        return enemySprite;
    }
  }

  /// Loads bullet sprites from the atlas at [prefix].
  ///
  /// [imageFile] is the copt sprite sheet image (e.g. `juncopt.png`).
  /// [atlasJsonFile] is the corresponding atlas JSON (e.g. `juncopt.json`).
  static Future<BulletSprites> load({
    required String prefix,
    required String imageFile,
    required String atlasJsonFile,
  }) async {
    final images = Images(prefix: prefix);
    final image = await images.load(imageFile);

    final jsonString = await rootBundle.loadString('$prefix$atlasJsonFile');
    final jsonData = json.decode(jsonString) as Map<String, dynamic>;
    final framesMap = jsonData['frames'] as Map<String, dynamic>;

    final playerSprite = _loadFrame(
      framesMap,
      image,
      _bulletGroupName,
      _playerBulletFrame,
    );
    final enemySprite = _loadFrame(
      framesMap,
      image,
      _bulletGroupName,
      _enemyBulletFrame,
    );

    return BulletSprites._(
      playerSprite: playerSprite,
      enemySprite: enemySprite,
      scaledSize: Vector2(
        playerSprite.srcSize.x * _spriteScale,
        playerSprite.srcSize.y * _spriteScale,
      ),
    );
  }

  static Sprite _loadFrame(
    Map<String, dynamic> framesMap,
    Image image,
    String groupName,
    int frameIndex,
  ) {
    final key = 'ingame/${groupName}_$frameIndex';
    final frameData = framesMap[key] as Map<String, dynamic>;
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
}

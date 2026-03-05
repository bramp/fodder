import 'package:flame/components.dart';

import 'package:fodder_game/game/components/bullet.dart';
import 'package:fodder_game/game/sprites/sprite_atlas.dart';
import 'package:fodder_game/game/sprites/sprite_frames.dart';

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const _spriteScale = 2.0;

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

  /// Creates [BulletSprites] from a pre-loaded [SpriteAtlas].
  ///
  /// The [atlas] must be the copt sprite atlas (e.g. `juncopt`).
  factory BulletSprites.fromAtlas(SpriteAtlas atlas) {
    final playerSprite = atlas.sprite(bulletGroup, bulletFramePlayer);
    if (playerSprite == null) {
      throw StateError(
        'Missing player bullet frame: $bulletGroup frame $bulletFramePlayer',
      );
    }

    final enemySprite = atlas.sprite(bulletGroup, bulletFrameEnemy);
    if (enemySprite == null) {
      throw StateError(
        'Missing enemy bullet frame: $bulletGroup frame $bulletFrameEnemy',
      );
    }

    return BulletSprites._(
      playerSprite: playerSprite,
      enemySprite: enemySprite,
      scaledSize: Vector2(
        playerSprite.srcSize.x * _spriteScale,
        playerSprite.srcSize.y * _spriteScale,
      ),
    );
  }

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
}

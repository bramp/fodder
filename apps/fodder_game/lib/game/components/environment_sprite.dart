import 'package:flame/components.dart';

import 'package:fodder_game/game/sprites/sprite_atlas.dart';
import 'package:fodder_game/game/sprites/sprite_frames.dart';

/// Sprite scale factor (original 16 px tiles rendered at 32 px).
const _spriteScale = 2.0;

/// A static environment decoration rendered from the copt sprite atlas.
///
/// These sprites (shrubs, tree tops, building roofs, etc.) are defined in
/// the TMX `Raised` object layer. The original engine draws them as normal
/// sprites sorted by Y position, so that soldiers walking below the
/// sprite's anchor appear behind the decoration — creating the illusion
/// of walking under tree canopies.
///
/// We use `priority: 15` (above soldiers at 10, below debug overlay at 20)
/// so environment sprites always render on top of soldiers, matching the
/// original game's visual behaviour for tree-top / canopy overlays.
class EnvironmentSprite extends SpriteComponent {
  EnvironmentSprite({
    required super.sprite,
    required super.position,
    required super.size,
  }) : super(anchor: Anchor.bottomLeft, priority: 15);

  /// Creates an [EnvironmentSprite] for the given spawn [name] from the
  /// copt [atlas].
  ///
  /// The [name] is the TMX object name (e.g. `"shrub"`, `"tree"`).
  /// Returns `null` if the name is not a known environment sprite.
  static EnvironmentSprite? fromSpawnData({
    required String name,
    required Vector2 position,
    required SpriteAtlas atlas,
  }) {
    final frameKey = environmentFrameKey(name);
    final sprite = atlas.spriteByKey(frameKey);
    if (sprite == null) return null;

    return EnvironmentSprite(
      sprite: sprite,
      position: position,
      size: sprite.srcSize * _spriteScale,
    );
  }
}

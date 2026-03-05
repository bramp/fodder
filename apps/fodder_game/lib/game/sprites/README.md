# Sprites

Shared sprite atlas loading and centralized frame-name constants.

## Key Files
* `sprite_atlas.dart`: Reusable atlas loader (`SpriteAtlas`) — load a TexturePacker JSON Hash atlas once and share the instance across all consumers that need frames from the same sprite sheet.
* `sprite_frames.dart`: Centralized constants for all sprite group names and frame indices across both atlases (`junarmy` and `juncopt`). Also contains `environmentFrameKey()` for deriving environment decoration frame keys from TMX object names.

## Atlas Files

| Atlas          | Image          | Contents                                   |
|----------------|----------------|--------------------------------------------|
| `junarmy.json` | `junarmy.png`  | Soldier walk/throw/swim/death/firing anims  |
| `juncopt.json` | `juncopt.png`  | Bullets, environment decorations, misc      |

## Usage Pattern

```dart
// Load once in FodderGame.onLoad():
final coptAtlas = await SpriteAtlas.load(..., jsonFile: 'juncopt.json', imageFile: 'juncopt.png');
final armyAtlas = await SpriteAtlas.load(..., jsonFile: 'junarmy.json', imageFile: 'junarmy.png');

// Share with consumers:
final bullets = BulletSprites.fromAtlas(coptAtlas);
final anims   = SoldierAnimations.fromAtlas(armyAtlas);
```

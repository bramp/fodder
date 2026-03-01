import 'dart:convert';

/// A single sprite entry within a texture atlas.
///
/// Describes the rectangular region and anchor offset of one sprite
/// on a sprite sheet image.
class AtlasEntry {
  /// Creates a new atlas entry.
  const AtlasEntry({
    required this.name,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.anchorX = 0,
    this.anchorY = 0,
  });

  /// Unique name for this sprite (e.g. `InGame/00_0`).
  final String name;

  /// X pixel coordinate of the sprite's top-left corner on the atlas image.
  final int x;

  /// Y pixel coordinate of the sprite's top-left corner on the atlas image.
  final int y;

  /// Sprite width in pixels.
  final int width;

  /// Sprite height in pixels.
  final int height;

  /// X rendering anchor offset (from OpenFodder's mModX).
  final int anchorX;

  /// Y rendering anchor offset (from OpenFodder's mModY).
  final int anchorY;
}

/// Generates a **TexturePacker JSON Hash** atlas file from sprite entries.
///
/// The TexturePacker JSON Hash format is widely supported by game engines
/// including Flame (via `SpritesheetData.fromJson()`), Phaser, PixiJS, etc.
///
/// Each sprite is described by a `frame` rectangle (x, y, w, h) on the
/// atlas image, plus standard fields (`rotated`, `trimmed`,
/// `spriteSourceSize`, `sourceSize`).
///
/// An additional non-standard `anchor` field stores OpenFodder's mModX/mModY
/// offsets. Standard parsers ignore unknown fields.
///
/// The [imageFilename] should be just the filename (e.g. `junarmy.png`),
/// not a full path. [imageWidth] and [imageHeight] describe the dimensions
/// of the atlas PNG image.
String generateAtlasJson({
  required String imageFilename,
  required int imageWidth,
  required int imageHeight,
  required List<AtlasEntry> entries,
}) {
  final frames = <String, Object>{};

  for (final entry in entries) {
    frames[entry.name] = <String, Object>{
      'frame': <String, int>{
        'x': entry.x,
        'y': entry.y,
        'w': entry.width,
        'h': entry.height,
      },
      'rotated': false,
      'trimmed': false,
      'spriteSourceSize': <String, int>{
        'x': 0,
        'y': 0,
        'w': entry.width,
        'h': entry.height,
      },
      'sourceSize': <String, int>{'w': entry.width, 'h': entry.height},
      'anchor': <String, int>{'x': entry.anchorX, 'y': entry.anchorY},
    };
  }

  final atlas = <String, Object>{
    'frames': frames,
    'meta': <String, Object>{
      'app': 'fodder/tool/sprites',
      'version': '1.1',
      'image': imageFilename,
      'format': 'RGBA8888',
      'size': <String, int>{'w': imageWidth, 'h': imageHeight},
      'scale': 1,
    },
  };

  return const JsonEncoder.withIndent('  ').convert(atlas);
}

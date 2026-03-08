/// Metadata for a single sprite frame within a 4-bit packed sprite sheet.
///
/// Each frame describes a rectangular region of a sprite sheet image.
/// The position is derived from `byteOffset` using the 4-bit sheet layout:
///
/// - row = `byteOffset` ~/ `pitch` (default pitch = 160 bytes)
/// - column (pixels) = (`byteOffset` % `pitch`) * 2
/// - width = `width` pixels, reading `width` ~/ 2 bytes per row
/// - height = `height` pixel rows
class SpriteFrame {
  /// Creates a sprite frame from parsed C++ sprite sheet data.
  const SpriteFrame({
    required this.byteOffset,
    required this.gfxType,
    required this.width,
    required this.height,
    required this.paletteIndex,
    required this.modX,
    required this.modY,
    this.description,
  });

  /// Byte offset into the raw .dat file (mLoadOffset).
  final int byteOffset;

  /// Which graphics file/sheet this sprite belongs to (mLoadSegment).
  final GfxType gfxType;

  /// Sprite width in pixels (mColCount).
  final int width;

  /// Sprite height in pixel rows (mRowCount).
  final int height;

  /// Base palette index for 4-bit OR (mPalleteIndex).
  final int paletteIndex;

  /// X rendering offset / anchor adjustment (mModX).
  final int modX;

  /// Y rendering offset / anchor adjustment (mModY).
  final int modY;

  /// Optional human-readable description (extracted from C++ comments).
  final String? description;

  /// The pixel X coordinate of this sprite on the 320-wide canvas.
  int pixelX({int pitch = 160}) => (byteOffset % pitch) * 2;

  /// The pixel Y coordinate of this sprite on the canvas.
  int pixelY({int pitch = 160}) => byteOffset ~/ pitch;

  /// Converts the frame metadata to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
    'byteOffset': byteOffset,
    'gfxType': gfxType.name,
    'width': width,
    'height': height,
    'paletteIndex': paletteIndex,
    'modX': modX,
    'modY': modY,
    if (description != null) 'description': description,
  };

  @override
  String toString() =>
      'SpriteFrame('
      'offset=$byteOffset, '
      'gfx=${gfxType.name}, '
      '${width}x$height, '
      'pal=0x${paletteIndex.toRadixString(16)}, '
      'mod=($modX,$modY))';
}

/// The graphics file types that sprite sheets reference.
///
/// These correspond to the `eGFX_Types` enum in OpenFodder.
enum GfxType {
  /// In-game sprites (from *army.dat).
  inGame,

  /// In-game sprites 2 (from *copt.dat).
  inGame2,

  /// Font sprites (from font.dat).
  font,

  /// Hill/recruit screen overlays (from hillbits.dat).
  hill,

  /// Recruit screen sprites (from hillbits.dat).
  recruit,

  /// Briefing screen sprites (from pstuff.dat).
  briefing,

  /// Service screen sprites (from morphbig.dat / rankfont.dat).
  service,

  /// Rank font (from rankfont.dat).
  rankFont,

  /// HUD/sidebar/cursor sprites (from pstuff.dat).
  pstuff,

  /// Unknown type.
  unknown;

  /// The .dat filename this [GfxType] maps to.
  String get datFileName => switch (this) {
    GfxType.inGame => 'army.dat',
    GfxType.inGame2 => 'copt.dat',
    GfxType.font => 'font.dat',
    GfxType.hill => 'hillbits.dat',
    GfxType.recruit => 'hillbits.dat',
    GfxType.briefing => 'pstuff.dat',
    GfxType.service => 'morphbig.dat',
    GfxType.rankFont => 'rankfont.dat',
    GfxType.pstuff => 'pstuff.dat',
    GfxType.unknown => '?',
  };

  /// Converts a string name back to its [GfxType] enum value.
  static GfxType fromName(String name) =>
      GfxType.values.byName(name == 'unknown' ? 'unknown' : name);
}

/// A named group of sprite frames, corresponding to one of the
/// `mSpriteSheetTypes_*_PC` pointer arrays in OpenFodder.
class SpriteSheetType {
  /// Creates a sprite sheet type definition.
  const SpriteSheetType({required this.name, required this.entries});

  /// Loads a [SpriteSheetType] from a JSON-compatible list.
  factory SpriteSheetType.fromJson(String name, List<dynamic> json) {
    final entries = json.map((groupJson) {
      return (groupJson as List).map((frameJson) {
        final map = frameJson as Map<String, dynamic>;
        final dynamic jsonGfxType = map['gfxType'];
        final GfxType gfxType;
        if (jsonGfxType is String) {
          gfxType = GfxType.fromName(jsonGfxType);
        } else {
          gfxType = GfxType.values[jsonGfxType as int];
        }

        return SpriteFrame(
          byteOffset: map['byteOffset'] as int,
          gfxType: gfxType,
          width: map['width'] as int,
          height: map['height'] as int,
          paletteIndex: map['paletteIndex'] as int,
          modX: map['modX'] as int,
          modY: map['modY'] as int,
          description: map['description'] as String?,
        );
      }).toList();
    }).toList();

    return SpriteSheetType(name: name, entries: entries);
  }

  /// Human-readable name (e.g. 'InGame', 'Font', 'Recruit').
  final String name;

  /// Ordered list of sprite groups. Each group is a list of animation frames
  /// (typically 1–12 frames). The outer index is the "sprite type" index
  /// used by the engine to look up sprites.
  final List<List<SpriteFrame>> entries;

  /// Converts the sheet type metadata to a JSON-compatible list.
  List<dynamic> toJson() => entries
      .map((group) => group.map((frame) => frame.toJson()).toList())
      .toList();
}

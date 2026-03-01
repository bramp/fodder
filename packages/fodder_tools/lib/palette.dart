import 'dart:typed_data';

/// A 256-color VGA palette.
///
/// Stores RGBA values for each of the 256 palette indices.
/// Index 0 is always fully transparent (used for sprite transparency).
class Palette {
  /// Creates a new palette initialised to all-transparent black.
  Palette() : colors = Uint32List(256);

  /// The RGBA color for each palette index, stored as 0xAARRGGBB.
  ///
  /// Index 0 is reserved as transparent (`0x00000000`).
  final Uint32List colors;

  /// Loads VGA 6-bit RGB triplets from [data] starting at byte [offset].
  ///
  /// Reads [count] sequential RGB triplets (3 bytes each). Each channel value
  /// is in the VGA 6-bit range (0–63) and is scaled to 8-bit (0–255) by
  /// left-shifting by 2.
  ///
  /// The palette entries are written starting at [startIndex] in [colors].
  ///
  /// Index 0 is always reset to fully transparent after loading.
  void load({
    required Uint8List data,
    required int offset,
    required int count,
    int startIndex = 0,
  }) {
    var src = offset;
    for (var i = startIndex; i < startIndex + count; i++) {
      final r = (data[src++] & 0x3F) << 2;
      final g = (data[src++] & 0x3F) << 2;
      final b = (data[src++] & 0x3F) << 2;
      colors[i] = (0xFF << 24) | (r << 16) | (g << 8) | b;
    }
    // Index 0 is always transparent.
    colors[0] = 0x00000000;
  }

  /// Returns the RGBA color for a 4-bit pixel value combined with a base
  /// palette index.
  ///
  /// For 4-bit sprite sheets, each non-zero nibble value (1–15) is OR'd with
  /// [basePaletteIndex] to produce the final 256-color palette index.
  /// A nibble value of 0 is transparent.
  int resolve4Bit(int nibble, int basePaletteIndex) {
    if (nibble == 0) return 0x00000000;
    return colors[nibble | basePaletteIndex];
  }

  /// Returns the RGBA color for an 8-bit pixel value.
  ///
  /// A value of 0 may be treated as transparent depending on context.
  int resolve8Bit(int index, {bool zeroTransparent = false}) {
    if (zeroTransparent && index == 0) return 0x00000000;
    return colors[index];
  }
}

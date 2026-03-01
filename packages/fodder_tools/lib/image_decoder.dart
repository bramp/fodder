import 'dart:typed_data';

import 'package:fodder_tools/palette.dart';
import 'package:fodder_tools/sprite_frame.dart';

/// Decodes a 4-bit packed "nibble" sprite sheet into an RGBA pixel buffer.
///
/// The input [data] is a flat byte array where each byte stores two 4-bit
/// pixels (high nibble = left, low nibble = right). The virtual canvas has a
/// fixed [pitch] of 160 bytes (320 pixels wide).
///
/// Returns a [Uint32List] of RGBA pixels (width × height) where width is
/// `pitch * 2` and height is `data.length ~/ pitch` (capped at
/// [paletteOffset] ~/ [pitch] if present, since palette bytes follow the
/// image data).
Uint32List decode4Bit({
  required Uint8List data,
  required Palette palette,
  required int basePaletteIndex,
  int pitch = 160,
  int? paletteOffset,
}) {
  final pixelWidth = pitch * 2; // 2 pixels per byte.
  final imageBytes = paletteOffset ?? data.length;
  final rows = imageBytes ~/ pitch;
  final pixels = Uint32List(pixelWidth * rows);

  var src = 0;
  var dst = 0;
  for (var y = 0; y < rows; y++) {
    for (var x = 0; x < pitch; x++) {
      final byte = data[src++];
      pixels[dst++] = palette.resolve4Bit((byte >> 4) & 0x0F, basePaletteIndex);
      pixels[dst++] = palette.resolve4Bit(byte & 0x0F, basePaletteIndex);
    }
  }

  return pixels;
}

/// Decodes an 8-bit linear image into an RGBA pixel buffer.
///
/// Each byte in [data] is a direct index into the 256-color [palette].
/// The image is [width] pixels wide (typically 320) and the height is derived
/// from [pixelCount] ÷ [width].
///
/// If [zeroTransparent] is true, index 0 maps to fully transparent.
Uint32List decode8Bit({
  required Uint8List data,
  required Palette palette,
  int width = 320,
  int? pixelCount,
  bool zeroTransparent = false,
}) {
  final count = pixelCount ?? data.length;
  final pixels = Uint32List(count);

  for (var i = 0; i < count; i++) {
    pixels[i] = palette.resolve8Bit(data[i], zeroTransparent: zeroTransparent);
  }

  return pixels;
}

/// De-interleaves a VGA Mode X planar image into an RGBA pixel buffer.
///
/// The input [data] is exactly 64 000 bytes (320 × 200), divided into four
/// 16 000-byte planes. Each plane stores pixels for every 4th column:
///
/// - Plane 0 → columns 0, 4, 8, …
/// - Plane 1 → columns 1, 5, 9, …
/// - Plane 2 → columns 2, 6, 10, …
/// - Plane 3 → columns 3, 7, 11, …
Uint32List decodePlanar({
  required Uint8List data,
  required Palette palette,
  int width = 320,
  int height = 200,
  bool zeroTransparent = false,
}) {
  final pixels = Uint32List(width * height);
  var src = 0;

  for (var plane = 0; plane < 4; plane++) {
    for (var y = 0; y < height; y++) {
      for (var x = plane; x < width; x += 4) {
        pixels[y * width + x] = palette.resolve8Bit(
          data[src++],
          zeroTransparent: zeroTransparent,
        );
      }
    }
  }

  return pixels;
}

/// Extracts a single sprite frame from a 4-bit packed sprite sheet.
///
/// The [data] buffer is the raw bytes of the sprite sheet file. The [frame]
/// defines the byte offset, width, and height of the sprite within the sheet.
///
/// The sheet has a fixed [pitch] of 160 bytes (320 pixels wide). The sprite's
/// top-left pixel position is:
///   x = (frame.byteOffset % pitch) * 2
///   y = frame.byteOffset ~/ pitch
///
/// Returns an RGBA [Uint32List] of `frame.width × frame.height` pixels.
Uint32List extractSprite({
  required Uint8List data,
  required SpriteFrame frame,
  required Palette palette,
  int pitch = 160,
}) {
  final bytesPerRow = frame.width ~/ 2;
  final startRow = frame.byteOffset ~/ pitch;
  final startCol = frame.byteOffset % pitch;
  final pixels = Uint32List(frame.width * frame.height);

  var dst = 0;
  for (var y = 0; y < frame.height; y++) {
    final rowOffset = (startRow + y) * pitch + startCol;
    for (var b = 0; b < bytesPerRow; b++) {
      final byte = data[rowOffset + b];
      pixels[dst++] = palette.resolve4Bit(
        (byte >> 4) & 0x0F,
        frame.paletteIndex,
      );
      pixels[dst++] = palette.resolve4Bit(byte & 0x0F, frame.paletteIndex);
    }
  }

  return pixels;
}

/// Extracts a single 16×16 tile from an 8-bit tile canvas.
///
/// The tile canvas is laid out as a 320-pixel-wide (20 tiles across) linear
/// buffer. Tiles are arranged in a 20-column × N-row grid where each tile
/// occupies 16 × 16 pixels.
///
/// [tileIndex] is the sequential tile number (0, 1, 2, …). The tile's
/// position in the canvas is:
///   column = tileIndex % 20
///   row = tileIndex ~/ 20
///   byte offset = (row × 16 × 320) + (column × 16)
Uint32List decodeTile({
  required Uint8List data,
  required Palette palette,
  required int tileIndex,
  int canvasWidth = 320,
  int tileSize = 16,
  bool zeroTransparent = false,
}) {
  final tilesPerRow = canvasWidth ~/ tileSize;
  final col = tileIndex % tilesPerRow;
  final row = tileIndex ~/ tilesPerRow;
  final baseOffset = (row * tileSize * canvasWidth) + (col * tileSize);

  final pixels = Uint32List(tileSize * tileSize);
  var dst = 0;

  for (var y = 0; y < tileSize; y++) {
    final rowStart = baseOffset + y * canvasWidth;
    for (var x = 0; x < tileSize; x++) {
      pixels[dst++] = palette.resolve8Bit(
        data[rowStart + x],
        zeroTransparent: zeroTransparent,
      );
    }
  }

  return pixels;
}

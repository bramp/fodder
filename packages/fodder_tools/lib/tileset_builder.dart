import 'dart:typed_data';

import 'package:fodder_tools/image_decoder.dart';
import 'package:fodder_tools/palette.dart';
import 'package:fodder_tools/png_writer.dart';

/// Number of tiles per .blk file (20 columns × 12 rows).
const tilesPerBlk = 240;

/// Total tiles in a combined base + sub tileset.
const int totalTileCount = tilesPerBlk * 2;

/// Tile size in pixels.
const tileSize = 16;

/// Columns per row in a .blk canvas.
const blkColumns = 20;

/// Expected size of a `.blk` file in bytes (0xFD00).
///
/// Layout: 240 tiles × 16 × 16 bytes of pixel data (0xFA00 = 64000) plus
/// 128 palette entries × 3 bytes each (0x0180 = 384) starting at offset
/// 0xFA00, total 0xFD00 = 64768.
const expectedBlkSize = 0xFD00;

/// Builds a combined tileset PNG from a base and sub `.blk` tile block.
///
/// The resulting image places all 480 tiles (240 base + 240 sub) in a grid
/// that is [blkColumns] (20) tiles wide and 24 tiles tall, matching the
/// original `.blk` canvas layout.
///
/// The palette is loaded from the [baseBlk] data at offset `0xFA00`
/// (128 VGA colours, indices 0x00–0x7F).
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
///
/// Returns the encoded PNG bytes.
Uint8List buildTilesetPng({
  required Uint8List baseBlk,
  required Uint8List subBlk,
  void Function(String)? warn,
}) {
  if (baseBlk.length != expectedBlkSize) {
    warn?.call(
      'Base BLK file size ${baseBlk.length} (0x${baseBlk.length.toRadixString(16)}) '
      'differs from expected $expectedBlkSize (0x${expectedBlkSize.toRadixString(16)}).',
    );
  }
  if (subBlk.length != expectedBlkSize) {
    warn?.call(
      'Sub BLK file size ${subBlk.length} (0x${subBlk.length.toRadixString(16)}) '
      'differs from expected $expectedBlkSize (0x${expectedBlkSize.toRadixString(16)}).',
    );
  }

  final palette = Palette()..load(data: baseBlk, offset: 0xFA00, count: 0x80);

  const columns = blkColumns;
  const rows = totalTileCount ~/ columns; // 24
  const width = columns * tileSize; // 320
  const height = rows * tileSize; // 384

  final pixels = Uint32List(width * height);

  for (var tileId = 0; tileId < totalTileCount; tileId++) {
    final blkData = tileId < tilesPerBlk ? baseBlk : subBlk;
    final localIndex = tileId < tilesPerBlk ? tileId : tileId - tilesPerBlk;

    final tilePixels = decodeTile(
      data: blkData,
      palette: palette,
      tileIndex: localIndex,
    );

    // Place tile into the output grid.
    final dstCol = tileId % columns;
    final dstRow = tileId ~/ columns;
    final dstX = dstCol * tileSize;
    final dstY = dstRow * tileSize;

    for (var py = 0; py < tileSize; py++) {
      for (var px = 0; px < tileSize; px++) {
        pixels[(dstY + py) * width + (dstX + px)] =
            tilePixels[py * tileSize + px];
      }
    }
  }

  return encodePng(pixels: pixels, width: width, height: height);
}

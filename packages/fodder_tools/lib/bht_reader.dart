import 'dart:typed_data';

/// Bytes per tile in a `.bht` (BHIT) file.
///
/// Each tile has 8 rows, one byte per row, where each bit selects between
/// the primary (bit=0) and secondary (bit=1) terrain type in the
/// corresponding `.hit` entry.
const bhtBytesPerTile = 8;

/// Number of base tiles that have `.bht` data.
const _baseBhtTileCount = 240;

/// Number of sub tiles that have `.bht` data.
const _subBhtTileCount = 160;

/// Expected size of a base `.bht` file.
const _expectedBaseBhtSize = _baseBhtTileCount * bhtBytesPerTile; // 1920

/// Expected size of a sub `.bht` file.
const _expectedSubBhtSize = _subBhtTileCount * bhtBytesPerTile; // 1280

/// Reads a `.bht` (BHIT) sub-tile bitmask file.
///
/// `.bht` files store an 8×8 bitmask per tile, with no header. Each tile
/// occupies [bhtBytesPerTile] (8) consecutive bytes, one per row. Within
/// each byte, bit 7 is the leftmost column and bit 0 is the rightmost.
///
/// For a **mixed-terrain** tile (negative `.hit` value):
///   - Bit = 0 → primary terrain (`.hit` lower nibble)
///   - Bit = 1 → secondary terrain (`.hit` bits 4–7)
///
/// Returns a list of [tileCount] bitmasks, each a [Uint8List] of 8 bytes.
/// Tiles beyond the file data receive an all-zero bitmask (= all-primary).
///
/// File sizes:
/// - Base `.bht`: 1920 bytes → 240 tiles × 8 bytes.
/// - Sub `.bht`:  1280 bytes → 160 tiles × 8 bytes (remaining 80 sub tiles
///   default to all-zero).
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
List<Uint8List> readBhtFile(
  Uint8List data, {
  required int tileCount,
  void Function(String)? warn,
}) {
  final fileEntryCount = data.length ~/ bhtBytesPerTile;

  if (data.isNotEmpty &&
      data.length != _expectedBaseBhtSize &&
      data.length != _expectedSubBhtSize) {
    warn?.call(
      'BHT file size ${data.length} bytes ($fileEntryCount tiles) '
      'is unexpected (expected $_expectedBaseBhtSize for base '
      'or $_expectedSubBhtSize for sub).',
    );
  }

  if (data.length % bhtBytesPerTile != 0) {
    warn?.call(
      'BHT file size ${data.length} is not a multiple of '
      '$bhtBytesPerTile; trailing bytes will be ignored.',
    );
  }

  if (fileEntryCount < tileCount) {
    warn?.call(
      'BHT file has $fileEntryCount tiles but $tileCount were requested; '
      '${tileCount - fileEntryCount} tiles will default to all-primary.',
    );
  }

  return List<Uint8List>.generate(tileCount, (i) {
    if (i >= fileEntryCount) return Uint8List(bhtBytesPerTile);
    final offset = i * bhtBytesPerTile;
    return Uint8List.fromList(data.sublist(offset, offset + bhtBytesPerTile));
  });
}

/// Builds a combined BHIT bitmask list for a full 480-tile tileset.
///
/// The first 240 entries come from [baseBhtData] and the next 240 from
/// [subBhtData]. Both lists are padded to 240 if shorter.
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
List<Uint8List> buildCombinedBhtMasks({
  required Uint8List baseBhtData,
  required Uint8List subBhtData,
  void Function(String)? warn,
}) {
  final base = readBhtFile(
    baseBhtData,
    tileCount: _baseBhtTileCount,
    warn: warn != null ? (msg) => warn('base: $msg') : null,
  );
  final sub = readBhtFile(
    subBhtData,
    tileCount: _baseBhtTileCount,
    warn: warn != null ? (msg) => warn('sub: $msg') : null,
  );
  return [...base, ...sub];
}

import 'dart:typed_data';

/// Number of tiles in a base `.blk` file.
const _baseTileCount = 240;

/// Expected file size (in bytes) for base `.hit` files.
const _expectedBaseHitSize = _baseTileCount * 2; // 480

/// Expected file size (in bytes) for sub `.hit` files.
const _expectedSubHitSize = 160 * 2; // 320

/// Maximum valid terrain type value (0x0E = Jump).
const _maxTerrainType = 0x0E;

/// Reads a `.hit` terrain type file and returns one terrain type per tile.
///
/// `.hit` files store per-tile terrain data as **big-endian signed int16**
/// values. Each entry maps a tile index to an `eTerrainFeature` value from
/// the original Cannon Fodder engine:
///
/// | Value | Name          | Walkable? |
/// |-------|---------------|-----------|
/// |   0   | Land          | yes       |
/// |   1   | Rocky         | yes       |
/// |   2   | Rocky2        | yes       |
/// |   3   | Block         | **no**    |
/// |   4   | QuickSand     | yes       |
/// |   5   | WaterEdge     | yes       |
/// |   6   | Water         | yes*      |
/// |   7   | Snow          | yes       |
/// |   8   | QuickSandEdge | yes       |
/// |   9   | Drop          | yes       |
/// |  10   | Drop2         | yes       |
/// |  11   | Sink          | yes       |
/// |  12   | C             | yes       |
/// |  13   | D             | yes       |
/// |  14   | Jump          | yes       |
///
/// A **negative** value (bit 15 set) indicates the tile has **mixed terrain**
/// and uses the BHIT table for sub-tile (8×8) resolution.
///
/// For both positive and negative values, the terrain encoding is:
///   - Lower 4 bits (`& 0x0F`): primary terrain type.
///   - Bits 4–7 (`>> 4 & 0x0F`): secondary terrain type (only meaningful
///     when the value is negative and uses BHIT sub-tile lookup).
///
/// The raw int16 is returned as-is so the game can apply the full
/// OpenFodder terrain resolution logic (see `Tile_Terrain_Get`).
///
/// File sizes:
/// - Base `.hit`: 480 bytes → 240 entries (one per base tile).
/// - Sub `.hit`:  320 bytes → 160 entries (tiles 0–159); the remaining 80
///   sub tiles default to terrain type 0.
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
List<int> readHitFile(
  Uint8List data, {
  required int tileCount,
  void Function(String)? warn,
}) {
  if (data.length % 2 != 0) {
    warn?.call(
      'HIT file has odd byte count (${data.length}); '
      'last byte will be ignored.',
    );
  }

  final entryCount = data.length ~/ 2;

  if (data.isNotEmpty &&
      data.length != _expectedBaseHitSize &&
      data.length != _expectedSubHitSize) {
    warn?.call(
      'HIT file size ${data.length} bytes ($entryCount entries) '
      'is unexpected (expected $_expectedBaseHitSize for base '
      'or $_expectedSubHitSize for sub).',
    );
  }

  if (entryCount < tileCount) {
    warn?.call(
      'HIT file has $entryCount entries but $tileCount were requested; '
      '${tileCount - entryCount} tiles will default to Land (0).',
    );
  }

  final bd = ByteData.sublistView(data);

  var negativeCount = 0;
  var overMaxCount = 0;

  final result = List<int>.generate(tileCount, (i) {
    if (i >= entryCount) return 0; // default: Land
    final raw = bd.getInt16(i * 2, Endian.big);

    if (raw < 0) {
      negativeCount++;
      // Validate both nibbles of a mixed-terrain entry.
      final primary = raw & 0x0F;
      final secondary = (raw >> 4) & 0x0F;
      if (primary > _maxTerrainType || secondary > _maxTerrainType) {
        warn?.call(
          'HIT tile $i: mixed-terrain entry 0x${raw.toUnsigned(16).toRadixString(16).padLeft(4, '0')} '
          'has nibble outside 0–$_maxTerrainType '
          '(primary=$primary, secondary=$secondary).',
        );
      }
    } else if (raw > _maxTerrainType) {
      overMaxCount++;
      // Still valid — upper bits carry secondary terrain data that
      // OpenFodder masks away with `& 0x0F`.
      final primary = raw & 0x0F;
      if (primary > _maxTerrainType) {
        warn?.call(
          'HIT tile $i: value $raw has primary nibble $primary '
          'outside 0–$_maxTerrainType.',
        );
      }
    }

    return raw;
  });

  warn?.call(
    'HIT: ${result.length} entries — $negativeCount mixed-terrain, '
    '$overMaxCount positive-with-upper-bits, '
    '${result.length - negativeCount - overMaxCount} simple.',
  );

  return result;
}

/// Builds a combined terrain type list for a full 480-tile tileset.
///
/// The first 240 entries come from [baseHitData] and the next 240 from
/// [subHitData]. Both lists are padded to 240 if shorter.
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
List<int> buildCombinedTerrainTypes({
  required Uint8List baseHitData,
  required Uint8List subHitData,
  void Function(String)? warn,
}) {
  final base = readHitFile(
    baseHitData,
    tileCount: _baseTileCount,
    warn: warn != null ? (msg) => warn('base: $msg') : null,
  );
  final sub = readHitFile(
    subHitData,
    tileCount: _baseTileCount,
    warn: warn != null ? (msg) => warn('sub: $msg') : null,
  );
  return [...base, ...sub];
}

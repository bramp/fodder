import 'dart:typed_data';

/// Number of tiles in a base `.blk` file.
const _baseTileCount = 240;

/// Reads a `.hit` terrain type file and returns one terrain type per tile.
///
/// `.hit` files store per-tile terrain data as **big-endian signed int16**
/// values. Each entry maps a tile index to an `eTerrainFeature` value from
/// the original Cannon Fodder engine:
///
/// | Value | Name       | Walkable? |
/// |-------|------------|-----------|
/// |   0   | Land       | yes       |
/// |   1   | Rocky      | yes       |
/// |   2   | Boulders   | yes       |
/// |   3   | Block      | **no**    |
/// |   4   | Wood/Tree  | yes       |
/// |   5   | Mud/Swamp  | yes       |
/// |   6   | Water      | yes*      |
/// |   7   | Snow       | yes       |
/// |   8   | QuickSand  | yes       |
/// |   9   | Wall       | yes       |
/// |  10   | Fence      | yes       |
/// |  11   | Drop       | yes       |
/// |  12   | Drop2      | yes       |
///
/// A **negative** value (bit 15 set) indicates the tile has mixed terrain and
/// uses the BHIT table for sub-tile (8×8) resolution. For tile-level queries
/// these are stored as `-1`.
///
/// File sizes:
/// - Base `.hit`: 480 bytes → 240 entries (one per base tile).
/// - Sub `.hit`:  320 bytes → 160 entries (tiles 0–159); the remaining 80
///   sub tiles default to terrain type 0.
List<int> readHitFile(Uint8List data, {required int tileCount}) {
  final bd = ByteData.sublistView(data);
  final entryCount = data.length ~/ 2;

  return List<int>.generate(tileCount, (i) {
    if (i >= entryCount) return 0; // default: Land
    final value = bd.getInt16(i * 2, Endian.big);
    return value < 0 ? -1 : value;
  });
}

/// Builds a combined terrain type list for a full 480-tile tileset.
///
/// The first 240 entries come from [baseHit] and the next 240 from [subHit].
/// Both lists are padded to 240 if shorter.
List<int> buildCombinedTerrainTypes({
  required Uint8List baseHitData,
  required Uint8List subHitData,
}) {
  final base = readHitFile(baseHitData, tileCount: _baseTileCount);
  final sub = readHitFile(subHitData, tileCount: _baseTileCount);
  return [...base, ...sub];
}

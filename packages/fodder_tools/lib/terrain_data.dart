import 'dart:typed_data';

import 'package:fodder_tools/bht_reader.dart';

/// Maximum valid terrain type value (0x0E = Jump).
const maxTerrainType = 0x0E;

/// Resolved terrain data for a single tile.
///
/// This is the clean representation produced by combining `.hit` and `.bht`
/// data. All original-format bit-twiddling is done during conversion; the
/// game only sees these clean values.
class TileTerrainData {
  /// Creates terrain data for a **single-terrain** tile.
  const TileTerrainData.simple(this.primary) : secondary = null, mask = null;

  /// Creates terrain data for a **mixed-terrain** tile with sub-tile detail.
  ///
  /// [primary] is the terrain where the BHIT mask bit is 0.
  /// [secondary] is the terrain where the BHIT mask bit is 1.
  /// [mask] is the 8-byte BHIT bitmask (8 rows × 8 columns per tile).
  const TileTerrainData.mixed({
    required this.primary,
    required int this.secondary,
    required Uint8List this.mask,
  });

  /// Primary terrain type (0–14). Always present.
  ///
  /// For single-terrain tiles this is the only terrain type.
  /// For mixed-terrain tiles this is used where the [mask] bit is 0.
  final int primary;

  /// Secondary terrain type (0–14), or `null` for single-terrain tiles.
  ///
  /// Used where the [mask] bit is 1.
  final int? secondary;

  /// 8-byte BHIT bitmask, or `null` for single-terrain tiles.
  ///
  /// Row 0 is the topmost row. Within each byte, bit 7 is the leftmost
  /// column and bit 0 is the rightmost. A set bit selects [secondary];
  /// a clear bit selects [primary].
  final Uint8List? mask;

  /// Whether this tile has mixed (sub-tile) terrain.
  bool get isMixed => secondary != null;
}

/// Builds resolved [TileTerrainData] for a full 480-tile tileset.
///
/// [rawHitValues] is the list of raw `.hit` int16 values (480 entries).
/// [bhtMasks] is the list of 8-byte BHIT bitmasks (480 entries).
///
/// For each tile:
/// - If the raw hit value is negative (bit 15 set), the tile has mixed
///   terrain: primary = `raw & 0x0F`, secondary = `(raw >> 4) & 0x0F`,
///   and the BHIT mask selects between them per sub-pixel.
/// - Otherwise, primary = `raw & 0x0F` (a single terrain type).
///
/// Pass [warn] to receive diagnostic messages about unexpected data.
List<TileTerrainData> buildTileTerrainData({
  required List<int> rawHitValues,
  required List<Uint8List> bhtMasks,
  void Function(String)? warn,
}) {
  if (rawHitValues.length != bhtMasks.length) {
    warn?.call(
      'HIT (${rawHitValues.length} entries) and BHT '
      '(${bhtMasks.length} entries) lengths do not match.',
    );
  }

  final count = rawHitValues.length;
  var mixedCount = 0;

  final result = List<TileTerrainData>.generate(count, (i) {
    final raw = rawHitValues[i];
    final primary = raw & 0x0F;

    if (raw < 0) {
      // Mixed terrain tile.
      mixedCount++;
      final secondary = (raw >> 4) & 0x0F;
      final mask = i < bhtMasks.length
          ? bhtMasks[i]
          : Uint8List(bhtBytesPerTile);

      // Validate terrain type range.
      if (primary > maxTerrainType) {
        warn?.call(
          'Tile $i: mixed primary terrain $primary > $maxTerrainType.',
        );
      }
      if (secondary > maxTerrainType) {
        warn?.call(
          'Tile $i: mixed secondary terrain $secondary > $maxTerrainType.',
        );
      }

      return TileTerrainData.mixed(
        primary: primary,
        secondary: secondary,
        mask: mask,
      );
    }

    // Single terrain tile.
    if (primary > maxTerrainType) {
      warn?.call('Tile $i: terrain $primary > $maxTerrainType.');
    }
    return TileTerrainData.simple(primary);
  });

  warn?.call(
    'Terrain: $count tiles — $mixedCount mixed, '
    '${count - mixedCount} single.',
  );

  return result;
}

import 'package:flame_tiled/flame_tiled.dart';

/// Terrain types matching OpenFodder's `eTerrainFeature` enum.
///
/// See `docs/PC_GRAPHICS_FORMATS.md` §5.1 for the full table and
/// `vendor/openfodder/Source/Tiles.hpp` for the canonical names.
enum TerrainType {
  land(0, 'Land'),
  rocky(1, 'Rocky'),
  rocky2(2, 'Rocky2'),
  block(3, 'Block'),
  quickSand(4, 'Quick Sand'),
  waterEdge(5, 'Water Edge'),
  water(6, 'Water'),
  snow(7, 'Snow'),
  quickSandEdge(8, 'Quick Sand Edge'),
  drop(9, 'Drop'),
  drop2(10, 'Drop2'),
  sink(11, 'Sink'),
  terrainC(12, 'C'),
  terrainD(13, 'D'),
  jump(14, 'Jump')
  ;

  const TerrainType(this.value, this.label);

  /// The raw integer value stored in `.hit` files and TSX properties.
  final int value;

  /// Human-readable name for debug display.
  final String label;

  /// Whether this terrain type blocks walking.
  bool get blocksWalking => this == block;

  /// Look up a [TerrainType] by its integer [value].
  ///
  /// Returns [land] for unknown or negative values.
  static TerrainType fromValue(int value) {
    if (value < 0 || value >= values.length) return land;
    return values[value];
  }

  /// Resolves a raw `.hit` int16 value into a [TerrainType] for tile-level
  /// queries.
  ///
  /// The `.hit` file encodes terrain in the lower 4 bits (`raw & 0x0F`).
  /// Negative values (bit 15 set) indicate **mixed terrain**: the lower
  /// nibble is the primary type and bits 4–7 (`(raw >> 4) & 0x0F`) are the
  /// secondary type (selected per sub-pixel by the BHIT bitmask).
  ///
  /// Since we don't have sub-pixel coordinates at tile level, we apply a
  /// conservative policy: if **either** terrain type blocks walking, we
  /// return [block]. Otherwise we return the non-[land] type (or [land] if
  /// both nibbles are 0).
  static TerrainType fromRawHit(int raw) {
    final primary = TerrainType.fromValue(raw & 0x0F);

    if (raw >= 0) return primary;

    // Mixed terrain — extract secondary type from bits 4–7.
    // Dart's >> is arithmetic (sign-extending), which matches the C behaviour
    // in OpenFodder's `Tile_Terrain_Get`.
    final secondary = TerrainType.fromValue((raw >> 4) & 0x0F);

    // If either type blocks walking, the whole tile is conservatively blocked.
    if (primary.blocksWalking) return primary;
    if (secondary.blocksWalking) return secondary;

    // Return the more "interesting" (non-land) type for the debug overlay.
    if (primary != land) return primary;
    return secondary;
  }
}

/// A 2D grid of terrain types derived from a Tiled map's tileset terrain
/// properties.
///
/// Each cell stores a [TerrainType] from the tileset's `terrain` custom
/// property. Use [isWalkable] for pathfinding or [terrainAt] for detailed
/// terrain inspection.
class WalkabilityGrid {
  WalkabilityGrid._({
    required List<List<TerrainType>> grid,
    required this.width,
    required this.height,
  }) : _grid = grid;

  /// Builds a [WalkabilityGrid] from a loaded [TiledComponent].
  ///
  /// Reads the `"Tiles"` layer's GID data, resolves each GID to its tileset
  /// `Tile`, and reads the custom `terrain` integer property.
  factory WalkabilityGrid.fromTiled(TiledComponent tiled) {
    final map = tiled.tileMap.map;
    final tilesLayer = map.layerByName('Tiles');

    if (tilesLayer is! TileLayer) {
      throw StateError('Expected a TileLayer named "Tiles"');
    }

    final tileData = tilesLayer.tileData;
    if (tileData == null || tileData.isEmpty) {
      return WalkabilityGrid._(grid: [], width: 0, height: 0);
    }

    final mapHeight = tileData.length;
    final mapWidth = tileData.first.length;

    // Pre-build a lookup from local tile ID → terrain type for the tileset.
    final terrainByLocalId = <int, int>{};
    for (final tileset in map.tilesets) {
      for (final tile in tileset.tiles) {
        final t = tile.properties.getValue<int>('terrain');
        if (t != null) {
          terrainByLocalId[tile.localId] = t;
        }
      }
    }

    final grid = List<List<TerrainType>>.generate(mapHeight, (y) {
      return List<TerrainType>.generate(mapWidth, (x) {
        final gid = tileData[y][x];
        if (gid.tile == 0) return TerrainType.land; // empty tile → land

        final tileset = map.tilesetByTileGId(gid.tile);
        final localId = gid.tile - (tileset.firstGid ?? 0);
        final raw = terrainByLocalId[localId];
        return raw != null ? TerrainType.fromRawHit(raw) : TerrainType.land;
      });
    });

    return WalkabilityGrid._(grid: grid, width: mapWidth, height: mapHeight);
  }

  /// Creates a [WalkabilityGrid] from raw [TerrainType] data (for testing).
  factory WalkabilityGrid.fromData(List<List<TerrainType>> grid) {
    final h = grid.length;
    final w = h > 0 ? grid.first.length : 0;
    return WalkabilityGrid._(grid: grid, width: w, height: h);
  }

  final List<List<TerrainType>> _grid;

  /// Map width in tiles.
  final int width;

  /// Map height in tiles.
  final int height;

  /// Returns the [TerrainType] at the given tile coordinate.
  ///
  /// Out-of-bounds coordinates return [TerrainType.block].
  TerrainType terrainAt(int tileX, int tileY) {
    if (tileX < 0 || tileX >= width || tileY < 0 || tileY >= height) {
      return TerrainType.block;
    }
    return _grid[tileY][tileX];
  }

  /// Returns `true` if the given tile coordinate is walkable.
  ///
  /// Out-of-bounds coordinates return `false`.
  bool isWalkable(int tileX, int tileY) {
    return !terrainAt(tileX, tileY).blocksWalking;
  }
}

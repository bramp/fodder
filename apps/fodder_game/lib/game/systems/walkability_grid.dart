import 'dart:typed_data';

import 'package:flame_tiled/flame_tiled.dart';

/// Terrain types from the Tiled tileset `terrain` property.
///
/// These values (0–14) correspond to Cannon Fodder's terrain features.
/// The tools pipeline resolves all original-format encoding; the game
/// only ever sees clean integer values in the TSX properties.
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

  /// The integer value stored in the TSX `terrain` property.
  final int value;

  /// Human-readable name for debug display.
  final String label;

  /// Whether this terrain type blocks walking.
  bool get blocksWalking => this == block;

  /// Look up a [TerrainType] by its integer [value].
  ///
  /// Returns [land] for unknown or out-of-range values.
  static TerrainType fromValue(int value) {
    if (value < 0 || value >= values.length) return land;
    return values[value];
  }
}

/// A 2D grid of terrain types derived from a Tiled map's tileset terrain
/// properties.
///
/// Each cell stores a [TerrainType] from the tileset's `terrain` custom
/// property. For mixed-terrain tiles (those with `terrain_secondary` and
/// `terrain_mask` properties), a conservative tile-level policy is applied:
/// if either terrain type blocks walking the whole tile is treated as
/// blocked. The sub-tile bitmask is also stored for future sub-pixel
/// resolution.
///
/// Use [isWalkable] for pathfinding or [terrainAt] for detailed terrain
/// inspection.
class WalkabilityGrid {
  WalkabilityGrid._({
    required List<List<TerrainType>> grid,
    required this.width,
    required this.height,
    List<List<SubTileTerrain?>>? subTileGrid,
  }) : _grid = grid,
       _subTileGrid = subTileGrid;

  /// Builds a [WalkabilityGrid] from a loaded [TiledComponent].
  ///
  /// Reads the `"Tiles"` layer's GID data, resolves each GID to its tileset
  /// `Tile`, and reads the custom terrain properties:
  ///   - `terrain` (int 0–14): primary terrain type
  ///   - `terrain_secondary` (int 0–14): secondary type for mixed tiles
  ///   - `terrain_mask` (string, 16 hex chars): BHIT sub-tile bitmask
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

    // Pre-build lookups from local tile ID → terrain properties.
    final terrainByLocalId = <int, int>{};
    final secondaryByLocalId = <int, int>{};
    final maskByLocalId = <int, Uint8List>{};

    for (final tileset in map.tilesets) {
      for (final tile in tileset.tiles) {
        final t = tile.properties.getValue<int>('terrain');
        if (t != null) {
          terrainByLocalId[tile.localId] = t;
        }
        final s = tile.properties.getValue<int>('terrain_secondary');
        if (s != null) {
          secondaryByLocalId[tile.localId] = s;
        }
        final m = tile.properties.getValue<String>('terrain_mask');
        if (m != null && m.length == 16) {
          maskByLocalId[tile.localId] = _parseHexMask(m);
        }
      }
    }

    final hasMixed = secondaryByLocalId.isNotEmpty;
    final subTileGrid = hasMixed
        ? List<List<SubTileTerrain?>>.generate(
            mapHeight,
            (_) => List<SubTileTerrain?>.filled(mapWidth, null),
          )
        : null;

    final grid = List<List<TerrainType>>.generate(mapHeight, (y) {
      return List<TerrainType>.generate(mapWidth, (x) {
        final gid = tileData[y][x];
        if (gid.tile == 0) return TerrainType.land;

        final tileset = map.tilesetByTileGId(gid.tile);
        final localId = gid.tile - (tileset.firstGid ?? 0);
        final primaryVal = terrainByLocalId[localId];
        if (primaryVal == null) return TerrainType.land;

        final primary = TerrainType.fromValue(primaryVal);
        final secondaryVal = secondaryByLocalId[localId];

        if (secondaryVal != null) {
          final secondary = TerrainType.fromValue(secondaryVal);
          final mask = maskByLocalId[localId];

          // Store sub-tile data for future pixel-level queries.
          if (subTileGrid != null && mask != null) {
            subTileGrid[y][x] = SubTileTerrain(
              primary: primary,
              secondary: secondary,
              mask: mask,
            );
          }

          // Conservative tile-level policy: if either blocks, tile blocks.
          if (primary.blocksWalking || secondary.blocksWalking) {
            return TerrainType.block;
          }

          // Return the more "interesting" (non-land) type for display.
          if (primary != TerrainType.land) return primary;
          return secondary;
        }

        return primary;
      });
    });

    return WalkabilityGrid._(
      grid: grid,
      width: mapWidth,
      height: mapHeight,
      subTileGrid: subTileGrid,
    );
  }

  /// Creates a [WalkabilityGrid] from raw [TerrainType] data (for testing).
  factory WalkabilityGrid.fromData(List<List<TerrainType>> grid) {
    final h = grid.length;
    final w = h > 0 ? grid.first.length : 0;
    return WalkabilityGrid._(grid: grid, width: w, height: h);
  }

  final List<List<TerrainType>> _grid;

  /// Optional sub-tile terrain data for mixed-terrain tiles.
  ///
  /// `null` if no mixed-terrain tiles exist. Otherwise, same dimensions as
  /// [_grid]; entries are `null` for single-terrain cells.
  final List<List<SubTileTerrain?>>? _subTileGrid;

  /// Map width in tiles.
  final int width;

  /// Map height in tiles.
  final int height;

  /// Grid width in sub-tile units (each tile has 8 sub-tile columns).
  int get subTileWidth => width * 8;

  /// Grid height in sub-tile units (each tile has 8 sub-tile rows).
  int get subTileHeight => height * 8;

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

  /// Returns the sub-tile terrain at a **pixel** coordinate, or `null` if
  /// the tile is not mixed terrain.
  ///
  /// [subX] and [subY] are the sub-tile column/row (0–7) within the tile's
  /// 8×8 grid (each sub-cell covers 2×2 pixels of the 16×16 tile).
  ///
  /// Use this for pixel-level terrain queries where sub-tile accuracy matters
  /// (e.g. determining whether a soldier's exact pixel position is on water
  /// vs land within a mixed tile).
  TerrainType? subTileTerrainAt(int tileX, int tileY, int subX, int subY) {
    if (_subTileGrid == null) return null;
    if (tileX < 0 || tileX >= width || tileY < 0 || tileY >= height) {
      return null;
    }
    final st = _subTileGrid[tileY][tileX];
    if (st == null) return null;
    return st.terrainAt(subX, subY);
  }

  /// Returns the [TerrainType] at global sub-tile coordinates.
  ///
  /// [globalSubX] and [globalSubY] are indices in the sub-tile grid
  /// (0..subTileWidth-1, 0..subTileHeight-1). Each sub-cell covers
  /// 2×2 pixels within the original 16×16 tile.
  ///
  /// For tiles without mixed terrain, returns the tile-level terrain type.
  /// For mixed tiles, uses the sub-tile bitmask to select primary or
  /// secondary.
  TerrainType subTileTerrainAtGlobal(int globalSubX, int globalSubY) {
    final tileX = globalSubX ~/ 8;
    final tileY = globalSubY ~/ 8;
    if (tileX < 0 || tileX >= width || tileY < 0 || tileY >= height) {
      return TerrainType.block;
    }
    final st = _subTileGrid?[tileY][tileX];
    if (st == null) return _grid[tileY][tileX];
    final subX = globalSubX % 8;
    final subY = globalSubY % 8;
    return st.terrainAt(subX, subY);
  }

  /// Returns `true` if the sub-tile at global coordinates is walkable.
  bool isSubTileWalkable(int globalSubX, int globalSubY) {
    return !subTileTerrainAtGlobal(globalSubX, globalSubY).blocksWalking;
  }

  /// Returns `true` if the tile at [tileX], [tileY] has sub-tile data
  /// (i.e. it is a mixed-terrain tile).
  bool hasSubTileData(int tileX, int tileY) {
    if (_subTileGrid == null) return false;
    if (tileX < 0 || tileX >= width || tileY < 0 || tileY >= height) {
      return false;
    }
    return _subTileGrid[tileY][tileX] != null;
  }

  /// Parses a 16-character hex string into an 8-byte [Uint8List].
  static Uint8List _parseHexMask(String hex) {
    final result = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}

/// Sub-tile terrain data for a mixed-terrain tile.
///
/// Stores two terrain types and an 8×8 bitmask that selects between them
/// per sub-pixel (each sub-cell is 2×2 pixels within a 16×16 tile).
class SubTileTerrain {
  /// Creates sub-tile terrain data.
  const SubTileTerrain({
    required this.primary,
    required this.secondary,
    required this.mask,
  });

  /// Terrain where the mask bit is 0.
  final TerrainType primary;

  /// Terrain where the mask bit is 1.
  final TerrainType secondary;

  /// 8-byte bitmask (8 rows × 8 columns). Bit 7 = leftmost column.
  final Uint8List mask;

  /// Returns the terrain at sub-tile position ([subX], [subY]).
  ///
  /// [subX] and [subY] are 0–7, mapping to the 8×8 grid within the tile.
  TerrainType terrainAt(int subX, int subY) {
    if (subX < 0 || subX > 7 || subY < 0 || subY > 7) return primary;
    final bitIndex = 7 - subX; // bit 7 = leftmost column
    final row = mask[subY];
    return (row & (1 << bitIndex)) != 0 ? secondary : primary;
  }
}

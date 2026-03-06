import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:fodder_game/game/systems/walkability_grid.dart';

/// Shorthand aliases for readability.
const TerrainType _land = TerrainType.land;
const TerrainType _block = TerrainType.block;
const TerrainType _water = TerrainType.water;

void main() {
  group('WalkabilityGrid', () {
    test('fromData creates grid with correct dimensions', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _block, _land],
        [_land, _land, _block],
      ]);
      expect(grid.width, 3);
      expect(grid.height, 2);
    });

    test('isWalkable returns correct values', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _block, _land],
        [_block, _land, _block],
      ]);
      expect(grid.isWalkable(0, 0), isTrue);
      expect(grid.isWalkable(1, 0), isFalse);
      expect(grid.isWalkable(2, 0), isTrue);
      expect(grid.isWalkable(0, 1), isFalse);
      expect(grid.isWalkable(1, 1), isTrue);
      expect(grid.isWalkable(2, 1), isFalse);
    });

    test('terrainAt returns correct terrain types', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _water, _block],
      ]);
      expect(grid.terrainAt(0, 0), TerrainType.land);
      expect(grid.terrainAt(1, 0), TerrainType.water);
      expect(grid.terrainAt(2, 0), TerrainType.block);
    });

    test('out-of-bounds returns false / block', () {
      final grid = WalkabilityGrid.fromData([
        [_land, _land],
        [_land, _land],
      ]);
      expect(grid.isWalkable(-1, 0), isFalse);
      expect(grid.isWalkable(0, -1), isFalse);
      expect(grid.isWalkable(2, 0), isFalse);
      expect(grid.isWalkable(0, 2), isFalse);
      expect(grid.isWalkable(100, 100), isFalse);
      expect(grid.terrainAt(-1, 0), TerrainType.block);
    });

    test('empty grid has zero dimensions', () {
      final grid = WalkabilityGrid.fromData([]);
      expect(grid.width, 0);
      expect(grid.height, 0);
      expect(grid.isWalkable(0, 0), isFalse);
    });
  });

  group('TerrainType', () {
    test('fromValue returns correct enum for known values', () {
      expect(TerrainType.fromValue(0), TerrainType.land);
      expect(TerrainType.fromValue(3), TerrainType.block);
      expect(TerrainType.fromValue(6), TerrainType.water);
      expect(TerrainType.fromValue(14), TerrainType.jump);
    });

    test('fromValue returns land for unknown / negative values', () {
      expect(TerrainType.fromValue(-1), TerrainType.land);
      expect(TerrainType.fromValue(99), TerrainType.land);
    });

    test('blocksWalking is true only for block', () {
      expect(TerrainType.block.blocksWalking, isTrue);
      expect(TerrainType.land.blocksWalking, isFalse);
      expect(TerrainType.water.blocksWalking, isFalse);
      expect(TerrainType.drop.blocksWalking, isFalse);
    });

    test('label returns human-readable name', () {
      expect(TerrainType.land.label, 'Land');
      expect(TerrainType.quickSand.label, 'Quick Sand');
      expect(TerrainType.waterEdge.label, 'Water Edge');
    });
  });

  group('SubTileTerrain', () {
    test('terrainAt selects primary where mask bit is 0', () {
      // Mask: all zeros → all primary
      final st = SubTileTerrain(
        primary: _land,
        secondary: _water,
        mask: Uint8List(8),
      );
      expect(st.terrainAt(0, 0), _land);
      expect(st.terrainAt(7, 7), _land);
    });

    test('terrainAt selects secondary where mask bit is 1', () {
      // Mask: all 0xFF → all secondary
      final st = SubTileTerrain(
        primary: _land,
        secondary: _water,
        mask: Uint8List.fromList([
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
        ]),
      );
      expect(st.terrainAt(0, 0), _water);
      expect(st.terrainAt(7, 7), _water);
    });

    test('terrainAt resolves individual bits correctly', () {
      // Row 0: 0x80 = bit 7 set (leftmost column = secondary)
      // Rows 1-7: 0x00 = all primary
      final st = SubTileTerrain(
        primary: _land,
        secondary: _block,
        mask: Uint8List.fromList([0x80, 0, 0, 0, 0, 0, 0, 0]),
      );
      // subX=0 → bit 7 of row 0 → set → secondary (block)
      expect(st.terrainAt(0, 0), _block);
      // subX=1 → bit 6 of row 0 → clear → primary (land)
      expect(st.terrainAt(1, 0), _land);
      // subX=0, subY=1 → row 1 bit 7 → clear → primary
      expect(st.terrainAt(0, 1), _land);
    });

    test('terrainAt returns primary for out-of-range coordinates', () {
      final st = SubTileTerrain(
        primary: _land,
        secondary: _block,
        mask: Uint8List.fromList([
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
          0xFF,
        ]),
      );
      expect(st.terrainAt(-1, 0), _land);
      expect(st.terrainAt(8, 0), _land);
      expect(st.terrainAt(0, -1), _land);
      expect(st.terrainAt(0, 8), _land);
    });
  });
}
